# PocketPeers Flutter Frontend

Flutter frontend for the PocketPeers app, a group expense tracker based on Blockchain with gamification.

## Run

```sh
cd frontend-flutter
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

If platform folders are required, generate them without overwriting `lib`:

```sh
flutter create --platforms=android,ios,web .
```