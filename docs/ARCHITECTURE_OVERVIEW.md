# ChatZilla — Architectural Overview for Push Notification Implementation

---

## 1. Tech Stack & Architecture

| Layer | Technology |
|---|---|
| **Framework** | Flutter (SDK `^3.7.2`) |
| **State Management** | **flutter_bloc / Cubit** (`^9.1.1`) — all business logic is in Cubits, not full Blocs |
| **Dependency Injection** | **get_it** (`^8.0.3`) — registered in `lib/data/services/service_locator.dart` via `setupServiceLocator()` |
| **Backend / BaaS** | **Firebase** (Auth + Cloud Firestore + Realtime Database) |
| **Authentication** | `firebase_auth: ^5.5.3` |
| **Database** | `cloud_firestore: ^5.6.7` (primary), `firebase_database: ^11.3.7` (declared but unused in app code) |
| **Push Notification SDK** | `onesignal_flutter: ^5.3.4` (declared in `pubspec.yaml` but **zero Dart-side initialization exists**) |
| **Routing** | Custom `AppRouter` class wrapping a `GlobalKey<NavigatorState>` — no named routes, imperative navigation |

### Layered Architecture

```
lib/
├── main.dart                         # Entry point, lifecycle observer setup
├── SplashScreen.dart                 # Animated splash → RootScreen
├── config/theme/                     # ThemeData definitions
├── core/common/ & core/utils/        # Shared widgets (CustomButton, CustomTextField) & UiUtils
├── data/
│   ├── models/                       # UserModel, ChatMessage, ChatRoomModel, GroupModel
│   ├── repositories/                 # AuthRepository, ChatRepository, ContactRepository, GroupRepository
│   └── services/                     # BaseRepository (abstract), ServiceLocator, NotificationService (EMPTY)
├── logic/
│   ├── cubit/auth/                   # AuthCubit + AuthState
│   ├── cubit/chat/                   # ChatCubit + ChatState (1:1 chats)
│   ├── cubit/group/                  # GroupChatCubit, GroupsCubit + states
│   └── observer/                     # AppLifeCycleObserver (online status)
├── presentation/
│   ├── screens/auth/                 # LoginScreen, SignupScreen
│   ├── home/                         # HomeScreen (tabbed: Chats / Groups)
│   ├── chat/                         # ChatMessageScreen (1:1)
│   ├── group/                        # Group screens
│   └── widgets/                      # Shared UI widgets
└── router/                           # AppRouter
```

---

## 2. Database Schema (Firestore)

### Collection: `users`

Document ID = Firebase Auth UID.

| Field | Type | Notes |
|---|---|---|
| `username` | `String` | |
| `fullName` | `String` | |
| `email` | `String` | |
| `phoneNumber` | `String` | Normalized, used for contact matching |
| `isOnline` | `bool` | Toggled by `AppLifeCycleObserver` |
| `lastSeen` | `Timestamp` | |
| `createdAt` | `Timestamp` | |
| `fcmToken` | `String?` | **Field exists in model & serialization but is NEVER written to by any code** |
| `blockedUsers` | `List<String>` | UIDs of blocked users |

**Source:** `lib/data/models/user_model.dart`

### Collection: `chatRooms`

Document ID = sorted `"uid1_uid2"` string (deterministic).

| Field | Type | Notes |
|---|---|---|
| `participants` | `List<String>` | Exactly 2 UIDs, sorted |
| `participantsName` | `Map<String, String>` | `{uid: fullName}` |
| `lastMessage` | `String?` | Content of the most recent message |
| `lastMessageSenderId` | `String?` | |
| `lastMessageTime` | `Timestamp?` | Used for ordering on home screen |
| `lastReadTime` | `Map<String, Timestamp>` | Per-user last-read cursor |
| `isTyping` | `bool` | |
| `typingUserId` | `String?` | |
| `isCallActive` | `bool` | |

**Source:** `lib/data/models/chat_room_model.dart`

#### Sub-collection: `chatRooms/{roomId}/messages`

| Field | Type | Notes |
|---|---|---|
| `chatRoomId` | `String` | Redundant parent ref |
| `senderId` | `String` | UID of sender |
| `receiverId` | `String` | UID of receiver (**key for notification targeting**) |
| `content` | `String` | |
| `type` | `String` | Enum string: `MessageType.text`, `.image`, `.video`, `.systemMessage` |
| `status` | `String` | Enum string: `MessageStatus.sent` / `MessageStatus.read` |
| `timestamp` | `Timestamp` | |
| `readBy` | `List<String>` | UIDs who have read |
| `replyToMessageId` | `String?` | |
| `replyToContent` | `String?` | |
| `replyToSenderId` | `String?` | |
| `replyToSenderName` | `String?` | |
| `chatType` | `String` | `ChatType.individual` / `ChatType.group` |
| `senderName` | `String?` | Populated for group messages |

**Source:** `lib/data/models/chat_message.dart`

### Collection: `groups`

Document ID = auto-generated.

| Field | Type | Notes |
|---|---|---|
| `name` | `String` | |
| `description` | `String` | |
| `members` | `List<String>` | UIDs (**all recipients for group notifications**) |
| `admins` | `List<String>` | |
| `createdBy` | `String` | |
| `membersName` | `Map<String, String>` | `{uid: fullName}` |
| `lastMessage`, `lastMessageSenderId`, `lastMessageTime` | Same pattern as chatRooms | |
| `lastReadTime` | `Map<String, Timestamp>` | |
| `settings` | `Map` | `GroupSettings` (admin-only messaging, etc.) |

**Source:** `lib/data/models/group_model.dart`

#### Sub-collection: `groups/{groupId}/messages`

Identical schema to `chatRooms/{roomId}/messages`, with `receiverId` set to `''` and `chatType` = `ChatType.group`.

---

## 3. Message Flow — Sending a 1:1 Message (User A → User B)

### Step-by-step trace:

```
1.  User A types in ChatMessageScreen and taps send
      → lib/presentation/chat/chat_message_screen.dart
      → _handleSendMessage()

2.  Calls ChatCubit.sendMessage(content, receiverId, ...)
      → lib/logic/cubit/chat/chat_cubit.dart : sendMessage()

3.  ChatCubit delegates to ChatRepository.sendMessage(...)
      → lib/data/repositories/chat_repository.dart : sendMessage()

4.  Inside sendMessage():
      a. Creates a Firestore batch
      b. Generates a new doc ref under chatRooms/{roomId}/messages
      c. Constructs a ChatMessage with:
           - senderId = currentUserId (User A)
           - receiverId = User B's UID
           - status = MessageStatus.sent
           - readBy = [senderId]
      d. batch.set(messageDoc, message.toMap())
      e. batch.update(chatRooms/{roomId}) with lastMessage metadata
      f. batch.commit()

5.  User B receives the message via Firestore real-time listener:
      → ChatCubit._subscribeToMessages() → _chatRepository.getMessages(chatRoomId)
      → Firestore snapshots() stream delivers the new document
```

### Group Message Flow:

```
1.  GroupChatCubit.sendMessage()
      → lib/logic/cubit/group/group_chat_cubit.dart

2.  Delegates to GroupRepository.sendGroupMessage()
      → lib/data/repositories/group_repository.dart : sendGroupMessage()

3.  Same batch pattern: writes to groups/{groupId}/messages + updates group metadata
      - receiverId = '' (empty)
      - senderName = currentUserName
      - chatType = ChatType.group
```

### Critical Insertion Points for Notifications

- **`ChatRepository.sendMessage()`** (line ~68 of `chat_repository.dart`) — after `batch.commit()`, trigger notification to `receiverId`
- **`GroupRepository.sendGroupMessage()`** (line ~98 of `group_repository.dart`) — after `batch.commit()`, trigger notification to all `members` except `senderId`

---

## 4. Existing Notification Logic

### Declared Packages

| Package | Version | Status |
|---|---|---|
| `onesignal_flutter` | `^5.3.4` | ✅ In `pubspec.yaml`, ✅ iOS Pods installed (`OneSignalXCFramework 5.2.14`). **❌ Zero Dart initialization.** |
| `firebase_messaging` | — | **NOT in `pubspec.yaml`** |
| `flutter_local_notifications` | — | **NOT in `pubspec.yaml`** |

### Native Configuration

| File | Status |
|---|---|
| **`android/app/src/main/AndroidManifest.xml`** | Has `INTERNET`, `READ_CONTACTS`, `WRITE_CONTACTS` permissions. **No notification channel, no FCM service, no OneSignal metadata.** |
| **`ios/Runner/AppDelegate.swift`** | Stock Flutter boilerplate. **No `UNUserNotificationCenter` delegate, no Firebase Messaging setup, no OneSignal initialization.** |
| **`android/app/build.gradle.kts`** | Google Services plugin applied (`com.google.gms.google-services`). `google-services.json` present. No OneSignal plugin. |

### Dart-Side Notification Code

| File | Status |
|---|---|
| `lib/data/services/notification_service.dart` | **Exists but is EMPTY (0 bytes)** |
| `lib/presentation/screens/notification_test_screen.dart` | **Exists but is EMPTY (0 bytes)** |
| `NOTIFICATION_SETUP.md` | **Exists but is EMPTY (0 bytes)** |

### Backend

| File | Status |
|---|---|
| `backend/server.js` | **EMPTY** |
| `backend/package.json` | **EMPTY** |

### FCM Token Handling

The `UserModel` declares `fcmToken` as an optional `String?` field and it is correctly serialized in both `toMap()` and `fromFirestore()`. However, **no code anywhere in the codebase writes, updates, or reads this field**. It will always be `null` in Firestore.

### Summary

The project has the **scaffolding intent** for notifications (empty files, `fcmToken` in the model, OneSignal dependency) but **zero functional implementation**.

---

## 5. User Authentication & Lifecycle

### Authentication Flow

```
App Start
  → main() → setupServiceLocator() (Firebase.initializeApp, registers all singletons)
  → MyApp → SplashScreen (4-second animated splash)
  → RootScreen (BlocBuilder on AuthCubit)
      ├── AuthStatus.authenticated → HomeScreen
      └── AuthStatus.unauthenticated → LoginScreen
```

### Session Management

- **`AuthCubit`** (`lib/logic/cubit/auth/auth_cubit.dart`) is the single source of truth for auth state.
- On construction, it subscribes to `FirebaseAuth.authStateChanges()` in `_init()`.
- When a `User` is detected, it fetches `UserModel` from Firestore and emits `AuthStatus.authenticated`.
- The cubit is registered as a **lazy singleton** in `get_it`, so it persists for the app lifetime.

### Key Login Success Points

1. **`AuthCubit.signIn()`** (line ~47 of `auth_cubit.dart`) — After `_authRepository.signIn()` succeeds, emits `AuthStatus.authenticated`. **This is where you should register the device token.**

2. **`AuthCubit._init()`** (line ~23 of `auth_cubit.dart`) — The `authStateChanges` listener fires on cold app start if a persisted session exists. **This is where you should refresh the device token on app relaunch.**

3. **`AuthCubit.signUp()`** (line ~57 of `auth_cubit.dart`) — After successful registration. **Also needs token registration.**

4. **`AuthCubit.signOut()`** (line ~80 of `auth_cubit.dart`) — **This is where you should clear/invalidate the device token** from Firestore to stop notifications.

### Online/Offline Lifecycle

- **`AppLifeCycleObserver`** (`lib/logic/observer/app_life_cycle_observer.dart`) tracks app lifecycle via `WidgetsBindingObserver`.
- Registered in `main.dart` → `_MyAppState._initializeAppLifeCycleObserver()` inside a `FirebaseAuth.authStateChanges()` listener.
- Calls `ChatRepository.updateOnlineStatus(userId, bool)` which writes to `users/{uid}/isOnline` and `lastSeen`.

---

## 6. Implementation Roadmap (Recommended)

Based on this analysis, here is the minimal integration surface:

| Step | File(s) | Action |
|---|---|---|
| **1. Initialize OneSignal** | `lib/data/services/service_locator.dart` | Call `OneSignal.initialize("APP_ID")` inside `setupServiceLocator()` after `Firebase.initializeApp()` |
| **2. Write token to Firestore** | `lib/logic/cubit/auth/auth_cubit.dart` | After `AuthStatus.authenticated` in `_init()`, `signIn()`, and `signUp()`, get the OneSignal player/subscription ID and write it to `users/{uid}/fcmToken` |
| **3. Clear token on logout** | `lib/logic/cubit/auth/auth_cubit.dart` | In `signOut()`, set `users/{uid}/fcmToken` to `null` |
| **4. Trigger notification on message send** | `lib/data/repositories/chat_repository.dart` → `sendMessage()` | After `batch.commit()`, look up `receiverId`'s token from Firestore and send notification via OneSignal REST API or a Cloud Function |
| **5. Trigger group notification** | `lib/data/repositories/group_repository.dart` → `sendGroupMessage()` | Same pattern, but fan out to all `members` minus `senderId` |
| **6. Implement `NotificationService`** | `lib/data/services/notification_service.dart` | Centralize OneSignal init, token management, and send logic |
| **7. Native config** | `AndroidManifest.xml`, `AppDelegate.swift` | Add OneSignal required metadata/capabilities |

---

*Document generated: 27 February 2026*
