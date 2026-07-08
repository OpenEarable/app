#!/bin/bash


set -e

FLUTTER_VERSION=$(cat "$CI_WORKSPACE_PATH/repository/open_wearable/.flutter_version")
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_${FLUTTER_VERSION}-stable.zip"

echo "🟩 Install Flutter $FLUTTER_VERSION"
cd $HOME
time curl -L $FLUTTER_URL -o flutter.zip
unzip flutter.zip
export PATH="$PATH:$HOME/flutter/bin"

echo "🟩 Verify Flutter Installation"
flutter --version

echo "🟩 Flutter Precache"
time flutter precache --macos

echo "🟩 Navigate from ($PWD) to ($CI_WORKSPACE_PATH)"
cd $CI_WORKSPACE_PATH

echo "🟩 Install Flutter Dependencies"
cd repository/open_wearable
time flutter clean
time flutter pub get

echo "🟩 Install CocoaPods via Homebrew"
time HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

echo "🟩 Install CocoaPods dependencies..."
time cd macos && pod install
cd ../

echo "🟩 Prepare macOS Flutter/Xcode project"
# Generate Flutter ephemeral files and Xcode config.
# The actual signed archive/build is performed later by Xcode Cloud.
time flutter build macos --release --config-only

exit 0
