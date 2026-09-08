# OpenWearables - App

The OpenWearables App is a mobile application for connecting to, configuring, and interacting with wearable devices. It is designed as a flexible companion app for research, development, and prototyping with sensor-rich wearable platforms.

The app supports live sensor control, data visualizations and example applications that demonstrate how wearable devices can be used in practice. [OpenEarable](https://openearable.com) is one example of a compatible OpenWearables device. It is a fully open-source platform for ear-based sensing applications with true wireless audio, high-precision sensors, and a modular, reconfigurable hardware design.

For more information about the OpenWearables ecosystem, visit [openwearables.com](https://openwearables.com).

## Project Structure

This repository is primarily the Flutter app in [`open_wearable/`](./open_wearable/).

High-level architecture and state-management docs live in [`open_wearable/docs/`](./open_wearable/docs/README.md).

- [App Setup and Architecture](./open_wearable/docs/app-setup.md)
- [State and Providers](./open_wearable/docs/state-and-providers.md)

## Features

- Connect to compatible devices from OpenWearables, such as OpenEarable
- Configure available device sensors
- Control audio features
- Show live data from wearable sensors
- Provide example applications, including:
  - Posture Tracker
  - Recorder

## Getting Started

To get started with the OpenWearables App, you need:

- A compatible OpenWearables device, such as an OpenEarable device with the latest firmware
- A working Flutter installation

## Development Quick Start

1. Install Flutter on the stable channel.
2. From the app module, fetch dependencies:

    ```bash
    cd open_wearable
    flutter pub get
    ```

3. Run on a connected device or emulator:

    ```bash
    cd open_wearable
    flutter run
    ```

To enter demo mode with simulated sensor values, start the app with the App Store preview flag:

```bash
cd open_wearable
flutter run --dart-define=APP_STORE_PREVIEW=true
```

This launches the preview shell used for screenshots and demo flows instead of the normal Bluetooth-connected app.

## Contributing

Contributor expectations and workflow rules are documented in [CONTRIBUTING.md](./CONTRIBUTING.md).

## Run the app

1. Clone this repository:

    ```bash
    git clone https://github.com/OpenEarable/app.git
    ```

2. Navigate to the project folder in your terminal.

3. Connect your phone to your computer.

4. Start the app on your phone:

    ```bash
    cd open_wearable
    flutter run
    ```

    Select your phone as the target device from the list of connected devices.

## Install the app

1. Navigate to the project folder in your terminal.

2. Connect your phone to your computer.

3. Run the app in release mode:

    ```bash
    cd open_wearable
    flutter run --release
    ```

    Select your phone as the target device from the list of connected devices.

## Notes

- Core app bootstrap is in [`open_wearable/lib/main.dart`](./open_wearable/lib/main.dart).
- Route definitions are in [`open_wearable/lib/router.dart`](./open_wearable/lib/router.dart).
- High-level feature state is primarily under [`open_wearable/lib/view_models/`](./open_wearable/lib/view_models/).
