
# 📱 Chatzilla - Real-Time Flutter Chat App

A secure, scalable, and Firebase-backed chat application built using Flutter.

---

## 📁 Repository Structure

```
chatzilla/
│
├── android/                   # Android-specific files
├── ios/                       # iOS-specific files
├── lib/                       # Main source code folder
│   ├── main.dart              # Entry point
│   ├── core/                  # Core constants, helpers, and themes
│   │   ├── constants.dart
│   │   ├── themes.dart
│   │   └── utils.dart
│   ├── models/                # Data models
│   │   ├── user_model.dart
│   │   └── message_model.dart
│   ├── services/              # Firebase services (Auth, Messaging, Firestore)
│   │   ├── auth_service.dart
│   │   ├── chat_service.dart
│   │   └── notification_service.dart
│   ├── screens/               # UI screens
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   ├── chat_list_screen.dart
│   │   ├── chat_detail_screen.dart
│   │   └── profile_screen.dart
│   ├── widgets/               # Reusable UI widgets
│   │   ├── chat_bubble.dart
│   │   ├── message_input.dart
│   │   └── user_tile.dart
│   ├── controllers/           # Business logic (Riverpod/Bloc)
│   │   ├── auth_controller.dart
│   │   ├── chat_controller.dart
│   │   └── notification_controller.dart
│   └── routes/                # Navigation routes
│       └── app_routes.dart
│
├── assets/                    # Fonts, icons, images
│   └── logo.png
│
├── test/                      # Unit and widget tests
│   ├── auth_test.dart
│   ├── chat_test.dart
│   └── widget_test.dart
│
├── pubspec.yaml               # Flutter dependencies
├── README.md                  # Project overview
└── .gitignore                 # Ignore rules
```

---

## ✅ Use Case Mapping

| Use Case             | Related Files/Folder                             |
|----------------------|--------------------------------------------------|
| Register/Login       | `auth_service.dart`, `auth_controller.dart`, `login_screen.dart`, `register_screen.dart` |
| Send/Receive Message | `chat_service.dart`, `chat_controller.dart`, `chat_detail_screen.dart`, `chat_bubble.dart` |
| View Chat History    | `chat_list_screen.dart`, `chat_service.dart`     |
| Get Notifications    | `notification_service.dart`, `notification_controller.dart` |
| Logout               | `auth_controller.dart`, handled via `AppBar`, `Profile` |
