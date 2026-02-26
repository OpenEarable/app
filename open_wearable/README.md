# OpenWearable App Module

Flutter application module for the OpenEarable app.

## Documentation

High-level architecture and state-management docs live in [`docs/`](./docs/README.md).

- [App Setup and Architecture](./docs/app-setup.md)
- [State and Providers](./docs/state-and-providers.md)

## Development Quick Start

1. Install Flutter (stable channel).
2. From this folder (`open_wearable/`), fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run on a connected device/emulator:
   ```bash
   flutter run
   ```

## Notes

- Core app bootstrap is in `lib/main.dart`.
- Route definitions are in `lib/router.dart`.
- High-level feature state is primarily under `lib/view_models/`.
