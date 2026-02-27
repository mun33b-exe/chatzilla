/**
 * Firebase Cloud Functions for ChatZilla Push Notifications
 *
 * Two triggers:
 *   1. Individual chat  — chatRooms/{roomId}/messages/{messageId}
 *   2. Group chat        — groups/{groupId}/messages/{messageId}
 *
 * Uses the OneSignal REST API to deliver notifications.
 * The REST API Key is stored securely via Firebase Secrets.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

// ── Secrets ─────────────────────────────────────────────────────────────
// Set this via:  firebase functions:secrets:set ONESIGNAL_REST_API_KEY
const ONESIGNAL_REST_API_KEY = defineSecret("ONESIGNAL_REST_API_KEY");

// TODO: Replace with your real OneSignal App ID.
const ONESIGNAL_APP_ID = "e031531f-e118-4f0b-b43d-22a423cea978";

// ── Helper: send notification via OneSignal REST API ────────────────────
async function sendOneSignalNotification({ subscriptionIds, title, body, apiKey }) {
  if (!subscriptionIds || subscriptionIds.length === 0) {
    console.log("No subscription IDs to target — skipping notification.");
    return;
  }

  const payload = {
    app_id: ONESIGNAL_APP_ID,
    include_subscription_ids: subscriptionIds,
    headings: { en: title },
    contents: { en: body },
  };

  const response = await fetch("https://api.onesignal.com/notifications", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Basic ${apiKey}`,
    },
    body: JSON.stringify(payload),
  });

  const result = await response.json();
  console.log("OneSignal response:", JSON.stringify(result));
}

// ═══════════════════════════════════════════════════════════════════════
// TRIGGER 1 — Individual Chat Message
// ═══════════════════════════════════════════════════════════════════════
exports.onNewIndividualMessage = onDocumentCreated(
  {
    document: "chatRooms/{roomId}/messages/{messageId}",
    secrets: [ONESIGNAL_REST_API_KEY],
  },
  async (event) => {
    const messageData = event.data.data();
    if (!messageData) {
      console.log("No message data found.");
      return;
    }

    const { senderId, receiverId, content, senderName } = messageData;

    if (!receiverId) {
      console.log("No receiverId in message — skipping.");
      return;
    }

    // Don't notify the sender about their own message
    if (senderId === receiverId) {
      console.log("Sender is the receiver — skipping.");
      return;
    }

    // Fetch the receiver's OneSignal subscription ID from Firestore
    const receiverDoc = await db.collection("users").doc(receiverId).get();
    if (!receiverDoc.exists) {
      console.log(`Receiver user ${receiverId} not found.`);
      return;
    }

    const receiverToken = receiverDoc.data().fcmToken;
    if (!receiverToken) {
      console.log(`Receiver ${receiverId} has no fcmToken.`);
      return;
    }

    const title = senderName || "New Message";
    const body = content || "You have a new message.";

    await sendOneSignalNotification({
      subscriptionIds: [receiverToken],
      title,
      body,
      apiKey: ONESIGNAL_REST_API_KEY.value(),
    });

    console.log(`Notification sent to ${receiverId} for individual message.`);
  }
);

// ═══════════════════════════════════════════════════════════════════════
// TRIGGER 2 — Group Chat Message
// ═══════════════════════════════════════════════════════════════════════
exports.onNewGroupMessage = onDocumentCreated(
  {
    document: "groups/{groupId}/messages/{messageId}",
    secrets: [ONESIGNAL_REST_API_KEY],
  },
  async (event) => {
    const messageData = event.data.data();
    if (!messageData) {
      console.log("No message data found.");
      return;
    }

    const { senderId, content, senderName } = messageData;
    const groupId = event.params.groupId;

    // Fetch the parent group document for members list and group name
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) {
      console.log(`Group ${groupId} not found.`);
      return;
    }

    const groupData = groupDoc.data();
    const groupName = groupData.name || "Group";
    const members = groupData.members || [];

    // Remove the sender so they don't get notified for their own message
    const recipientIds = members.filter((id) => id !== senderId);

    if (recipientIds.length === 0) {
      console.log("No other members in group to notify.");
      return;
    }

    // Batch-fetch fcmTokens for all recipients
    // Firestore "in" queries support up to 30 items at a time
    const subscriptionIds = [];
    const batchSize = 30;

    for (let i = 0; i < recipientIds.length; i += batchSize) {
      const batch = recipientIds.slice(i, i + batchSize);
      const snapshot = await db
        .collection("users")
        .where("__name__", "in", batch)
        .get();

      snapshot.forEach((doc) => {
        const token = doc.data().fcmToken;
        if (token) {
          subscriptionIds.push(token);
        }
      });
    }

    if (subscriptionIds.length === 0) {
      console.log("No recipients have fcmTokens — skipping notification.");
      return;
    }

    const title = `[${groupName}] ${senderName || "Someone"}`;
    const body = content || "New message in group.";

    await sendOneSignalNotification({
      subscriptionIds,
      title,
      body,
      apiKey: ONESIGNAL_REST_API_KEY.value(),
    });

    console.log(
      `Group notification sent to ${subscriptionIds.length} member(s) in ${groupName}.`
    );
  }
);
