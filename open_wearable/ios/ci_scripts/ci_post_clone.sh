#!/bin/bash

# Fail this script if any subcommand fails.
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
time flutter precache --ios

# by default, the execution directory of this script is the ci_scripts directory
# CI_WORKSPACE is the directory of your cloned repo
echo "🟩 Navigate from ($PWD) to ($CI_WORKSPACE_PATH)"
cd $CI_WORKSPACE_PATH

echo "🟩 Install Flutter Dependencies"
cd repository/open_wearable
time flutter clean
time flutter pub get

echo "🟩 Install CocoaPods via Homebrew"
time HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

echo "🟩 Install CocoaPods dependencies..."
time cd ios && pod install
cd ../

echo "🟩 build iOS"
time flutter build ios --release --no-codesign

exit 0
