# بوابة المولدات - Generator Portal (Flutter)

A professional Flutter application for managing electrical generators, connecting owners (admins) with consumers (subscribers) using Firebase backend.

## Architecture

**MVC + Riverpod** pattern with clean separation:

```
lib/
├── config/          # App configuration, theme, colors, routing
├── models/          # Data models (UserProfile, Bill, AppAlert, Complaint)
├── providers/        # Riverpod state management (auth, theme, data)
├── services/         # Firebase service + Image compression service
├── views/
│   ├── screens/       # All UI screens (consumer + admin)
│   └── widgets/       # Reusable components
└── main.dart         # App entry point
```

## Stack

- **Flutter 3.32.0** + Dart 3.8
- **Firebase**: Phone Auth + Firestore (no Storage)
- **State**: Riverpod 2.x (reactive, auto-dispose)
- **Routing**: go_router (deep links + auth guards)
- **Animations**: flutter_animate + custom animations
- **Theme**: Light/Dark with SharedPreferences persistence
- **Images**: Base64 encoding via `image` package (no Firebase Storage)
- **RTL**: Full Arabic support via `Directionality`

## Features

| Feature | Consumer | Admin |
|---------|----------|-------|
| Phone Auth (OTP) | ✅ | ✅ |
| Demo Mode (bypass) | ✅ | ✅ |
| Generator Status | View | Toggle |
| Bills & Receipts | View + Upload | Approve/Reject |
| Usage Charts | Monthly breakdown | — |
| Alerts | Push-style | — |
| Complaints | File | View + Resolve |
| Subscriber Management | — | Add/Edit/Toggle |
| Theme Toggle | ✅ | ✅ |

## Demo Login Codes

| Code | Role | Phone |
|------|------|-------|
| `0000000000` | Consumer | 0500000000 |
| `9999999999` | Admin | 0599999999 |

## Build

```bash
# Web (for testing)
cd artifacts/flutter-mobile
flutter build web

# Android
flutter build apk

# iOS
flutter build ios
```

## Firestore Collections

- `users` - subscriber profiles
- `bills` - monthly bills with receiptBase64
- `alerts` - notification log
- `complaints` - support tickets
- `system/generator` - generator on/off state
