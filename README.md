# OpenEarable - App v1.3.0

[OpenEarable](https://open-earable.teco.edu) is a new, open-source, Arduino-based platform for ear-based sensing applications. It provides a versatile prototyping platform with support for various sensors and actuators, making it suitable for earable research and development.

<kbd> [Get OpenEarable device now!](https://forms.gle/R3LMcqtyKwVH7PZB9) </kbd>

## Table of Contents
- [Introduction](#Introduction)
- [Features](#Features)
- [Getting Started](#getting-started)
    - [Run the app](#run-the-app)
    - [Install the app](#install-the-app)
- [Contribute your own example app](#contribute-your-own-example-app)

## Introduction

This App is designed to control the OpenEarable device and work as an example project.

## Features
- Connect to OpenEarable device
- Configure the sensors
- Control the audio 
- Control the built-in LED
- Show live data from the sensors
- Provide a number of example applications
    - Posture Tracker
    - Recorder

## Getting Started
To get started with the OpenEarable App, you need to have the following:
- An OpenEarable device with the newest firmware
- A working flutter installation

### Run the app
1. Clone this repository
    ```
    git clone https://github.com/OpenEarable/app.git
    ```
2. Navigate to the project folder in your terminal
3. Connect your Phone to your Computer
4. Start the app on your phone
    ```
    flutter run
    ```
    and select your phone as the target device from the list of connected devices.

### Install the app
1. Navigate to the project folder in your terminal
2. Connect your Phone to your Computer
3. Run the app in release mode
    ```
    flutter run --release
    ```
    and select your phone as the target device from the list of connected devices.

## Contribute your own example app
If you want to contribute your own example app, please follow the steps below:
1. Create a new folder in the `lib/apps` folder for your app
2. Develop your app in the new folder
3. Add an instance of the `AppInfo` class to `sampleApps` property in the `lib/apps/apps_tab.dart` file to include your app in the list of example apps
4. Create a pull request to this repository