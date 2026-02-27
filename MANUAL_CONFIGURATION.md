# Manual Configuration Guide — OneSignal Push Notifications

Complete this checklist to finish the OneSignal push notification integration for ChatZilla.

---

## 1. OneSignal Dashboard Setup

1. Go to **[https://onesignal.com](https://onesignal.com)** → sign in / create an account.
2. Click **New App/Website** and name it `ChatZilla`.
3. Select platform **Google Android (FCM)** and follow the wizard.
   - You'll need your **Firebase Server Key** (or FCM v1 Service Account JSON):
     - Firebase Console → Project Settings → Cloud Messaging → Enable Cloud Messaging API (v1) if not already → copy the **Server Key** or download the **Service Account JSON**.
4. After completing the wizard, go to **Settings → Keys & IDs**.
   - Copy your **OneSignal App ID** — this is the value you paste into:
     - `lib/data/services/service_locator.dart` → `'YOUR_ONESIGNAL_APP_ID'`
     - `functions/index.js` → `ONESIGNAL_APP_ID`
   - Copy your **REST API Key** — this is the secret you'll store in Firebase (see Step 3 below).

---

## 2. Initialize Firebase Cloud Functions

If you haven't already set up Firebase Functions in your project, run:

```bash
# Install Firebase CLI (if not installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Cloud Functions in your project root
cd /Users/muhammadmuneebrehman/flutter_projects/chatzilla/chatzilla
firebase init functions
```

During `firebase init functions`:
- Select **Use an existing project** → pick `chatzilla-2eb30`.
- Select **JavaScript** as the language.
- Say **No** to ESLint (optional).
- Say **Yes** to install dependencies.

> **Important:** Since we've already created the `functions/` directory with `package.json` and `index.js`, Firebase may ask if you want to overwrite them. Choose **No** to keep the existing files. If it overwrites them, simply re-copy from this repo.

After init, install the function dependencies:

```bash
cd functions
npm install
```

---

## 3. Store the OneSignal REST API Key Securely

**Never hardcode your REST API Key in `index.js`.** Use Firebase Secrets:

```bash
# Set the secret (you'll be prompted to paste the key)
firebase functions:secrets:set ONESIGNAL_REST_API_KEY
```

When prompted, paste your **REST API Key** from the OneSignal dashboard (Step 1).

The `index.js` already references this secret via `defineSecret("ONESIGNAL_REST_API_KEY")`.

---

## 4. Deploy the Cloud Functions

```bash
# From the project root
firebase deploy --only functions
```

This deploys both `onNewIndividualMessage` and `onNewGroupMessage` triggers.

---

## 5. Replace Placeholder App IDs

Search for `YOUR_ONESIGNAL_APP_ID` in the codebase and replace it with your real OneSignal App ID:

| File                                             | Location                        |
| ------------------------------------------------ | ------------------------------- |
| `lib/data/services/service_locator.dart`         | Line with `.initialize(...)`    |
| `functions/index.js`                             | `ONESIGNAL_APP_ID` constant     |

---

## 6. Test End-to-End

1. **Build and run** the Flutter app on a physical device (push notifications don't work on emulators).
2. **Sign in** → open Firestore Console → verify that the user's document has `fcmToken` populated.
3. **Sign out** → verify `fcmToken` is set to `null`.
4. **Send a message** from User A to User B → User B should receive a push notification.
5. **Send a group message** → all group members (except the sender) should receive a notification.
