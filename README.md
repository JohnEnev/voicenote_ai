# Note Taking AI

Local-first voice notes with on-device speech-to-text and optional AI summarization.

## Features

- 🎤 On-device voice recording
- 🤖 Local STT using Parakeet via MLC.ai
- 📝 Automatic transcription and tagging
- 🔒 Privacy-first (local-only by default)
- ☁️ Optional cloud sync via Firebase
- 🌙 Dark mode support
- 📱 Cross-platform (Android & iOS)

## Architecture

- **Frontend**: Flutter + Riverpod
- **Database**: SQLite (Drift)
- **STT**: Parakeet (MLC.ai runtime)
- **Optional LLM**: phi-3-mini for summarization
- **Backend**: Firebase (Auth, Firestore, Storage)

## Project Structure

```
note_taking_ai/
├── lib/
│   ├── data/
│   │   ├── database/        # Drift schema & DAOs
│   │   └── models/          # Data models
│   ├── domain/
│   │   └── repositories/    # Repository interfaces
│   ├── presentation/
│   │   ├── screens/         # UI screens
│   │   ├── widgets/         # Reusable widgets
│   │   └── router/          # Navigation
│   ├── services/            # Business logic
│   └── mlc_bridge/          # FFI bindings for MLC.ai
├── android/                 # Android config
├── ios/                     # iOS config
├── assets/
│   ├── models/parakeet/     # STT models
│   └── prompts/             # AI prompts
└── test/                    # Tests
```

## Setup

### Prerequisites

- Flutter SDK >= 3.5.0
- Android SDK (minSdk 24)
- Xcode (for iOS)

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd note_taking_ai

# Install dependencies
flutter pub get

# Generate Drift code
dart run build_runner build --delete-conflicting-outputs

# Setup Firebase (optional - only needed for cloud sync)
flutterfire configure

# Run on Android
flutter run -d android

# Run on iOS
flutter run -d ios
```

### Firebase Setup (Optional)

Only needed if you want cloud sync features:

1. Install FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

2. Configure Firebase for your project:
```bash
flutterfire configure
```

This will:
- Create a Firebase project (or select existing)
- Generate `firebase_options.dart`
- Add config files for Android/iOS

## Development Status

This project is currently under active development. See Linear project for current tasks and progress.

### Completed (JOH-39)
- ✅ Flutter project scaffold
- ✅ Riverpod state management setup
- ✅ Drift database schema
- ✅ Android configuration (minSdk 24, permissions)
- ✅ iOS configuration (permissions)
- ✅ Basic routing with go_router
- ✅ Initial screens structure

### Next Steps (JOH-40+)
- Audio recording with flutter_sound
- MLC.ai FFI bridge for Parakeet
- Recording → STT → save note flow
- UI screens implementation
- Firebase backend setup

## License

[To be determined]

## Contributing

Contributions welcome! See issues on Linear for current work items.
