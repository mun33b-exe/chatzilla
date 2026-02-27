/**
 * ChatZilla Notification Server
 *
 * Standalone Express server that proxies push notifications
 * through the OneSignal REST API.
 *
 * Endpoints:
 *   POST /api/notifications/individual
 *   POST /api/notifications/group
 */

require("dotenv").config();
const express = require("express");
const cors = require("cors");
const axios = require("axios");

const app = express();
app.use(cors());
app.use(express.json());

// ── Environment Variables ───────────────────────────────────────────────
const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID;
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;
const PORT = process.env.PORT || 3000;

if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
  console.error(
    "ERROR: ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY must be set in environment variables."
  );
  process.exit(1);
}

// ── Helper: send notification via OneSignal ─────────────────────────────
async function sendOneSignalNotification({ subscriptionIds, title, body }) {
  const payload = {
    app_id: ONESIGNAL_APP_ID,
    include_subscription_ids: subscriptionIds,
    headings: { en: title },
    contents: { en: body },
  };

  const response = await axios.post(
    "https://api.onesignal.com/notifications",
    payload,
    {
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
    }
  );

  return response.data;
}

// ── Health Check ────────────────────────────────────────────────────────
app.get("/", (req, res) => {
  res.json({ status: "ok", service: "chatzilla-notification-server" });
});

// ══════════════════════════════════════════════════════════════════════════
// POST /api/notifications/individual
// Body: { senderName, content, subscriptionId }
// ══════════════════════════════════════════════════════════════════════════
app.post("/api/notifications/individual", async (req, res) => {
  try {
    const { senderName, content, subscriptionId } = req.body;

    if (!subscriptionId) {
      return res.status(400).json({ error: "subscriptionId is required." });
    }

    const title = senderName || "New Message";
    const body = content || "You have a new message.";

    const result = await sendOneSignalNotification({
      subscriptionIds: [subscriptionId],
      title,
      body,
    });

    console.log(`[Individual] Notification sent to ${subscriptionId}`);
    return res.json({ success: true, data: result });
  } catch (error) {
    console.error("[Individual] Error:", error.response?.data || error.message);
    return res.status(500).json({
      error: "Failed to send notification.",
      details: error.response?.data || error.message,
    });
  }
});

// ══════════════════════════════════════════════════════════════════════════
// POST /api/notifications/group
// Body: { groupName, senderName, content, subscriptionIds }
// ══════════════════════════════════════════════════════════════════════════
app.post("/api/notifications/group", async (req, res) => {
  try {
    const { groupName, senderName, content, subscriptionIds } = req.body;

    if (!subscriptionIds || subscriptionIds.length === 0) {
      return res.status(400).json({ error: "subscriptionIds array is required." });
    }

    const title = `[${groupName || "Group"}] ${senderName || "Someone"}`;
    const body = content || "New message in group.";

    const result = await sendOneSignalNotification({
      subscriptionIds,
      title,
      body,
    });

    console.log(
      `[Group] Notification sent to ${subscriptionIds.length} member(s) in ${groupName}`
    );
    return res.json({ success: true, data: result });
  } catch (error) {
    console.error("[Group] Error:", error.response?.data || error.message);
    return res.status(500).json({
      error: "Failed to send notification.",
      details: error.response?.data || error.message,
    });
  }
});

// ── Start Server ────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`ChatZilla Notification Server running on port ${PORT}`);
});
