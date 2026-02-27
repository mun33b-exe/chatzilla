ser# Render.com Deployment Guide — ChatZilla Notification Server

## 1. Push the Backend to GitHub

The `backend/` directory lives inside the main ChatZilla repo. When you push or have already pushed this repo to GitHub, the `backend/` folder will be included automatically.

```bash
git add backend/
git commit -m "Add standalone notification server for OneSignal"
git push origin main
```

---

## 2. Create a Web Service on Render.com

1. Go to **[https://render.com](https://render.com)** → sign in / create a free account.
2. Click **New** → **Web Service**.
3. Connect your **GitHub** account and select the **chatzilla** repository.
4. Configure the service:

| Setting            | Value                          |
|--------------------|--------------------------------|
| **Name**           | `chatzilla-notifications`      |
| **Region**         | Choose the closest to your users |
| **Root Directory** | `backend`                      |
| **Runtime**        | `Node`                         |
| **Build Command**  | `npm install`                  |
| **Start Command**  | `node server.js`               |
| **Plan**           | Free                           |

5. Click **Create Web Service**.

---

## 3. Add Environment Variables

In your Render service dashboard, go to **Environment** → **Add Environment Variable**:

| Key                      | Value                                    |
|--------------------------|------------------------------------------|
| `ONESIGNAL_APP_ID`       | Your OneSignal App ID (from OneSignal dashboard → Settings → Keys & IDs) |
| `ONESIGNAL_REST_API_KEY` | Your OneSignal REST API Key (same page)  |

> **Do NOT add `PORT`** — Render automatically sets this.

---

## 4. Update the Flutter App's Backend URL

Once Render deploys your service, it will give you a URL like:
```
https://chatzilla-notifications.onrender.com
```

Open `lib/data/services/notification_service.dart` and update `_baseUrl`:

```dart
// Replace the local IP with your Render URL for production
static const String _baseUrl = 'https://chatzilla-notifications.onrender.com';
```

---

## 5. Verify

1. Visit `https://chatzilla-notifications.onrender.com/` in a browser — you should see:
   ```json
   { "status": "ok", "service": "chatzilla-notification-server" }
   ```
2. Build and run the Flutter app on a device.
3. Send a message → the receiver should get a push notification.

> **Note:** The Render free tier spins down after 15 minutes of inactivity. The first request after inactivity may take ~30 seconds to cold-start.
