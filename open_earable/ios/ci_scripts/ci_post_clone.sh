#!/bin/sh

# Fail this script if any subcommand fails.
set -e

FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.0-stable.tar.xz"
FLUTTER_DIR="$HOME/flutter"

# by default, the execution directory of this script is the ci_scripts directory
# CI_WORKSPACE is the directory of your cloned repo
echo "🟩 Navigate from ($PWD) to ($CI_WORKSPACE_PATH)"
cd $CI_WORKSPACE_PATH

echo "🟩 Install Flutter"
mkdir -p $FLUTTER_DIR
time curl -L $FLUTTER_URL -o /tmp/flutter.tar.xz
time tar -xf /tmp/flutter.tar.xz -C $FLUTTER_DIR --strip-components=1
export PATH="$PATH:$HOME/flutter/bin"

echo "🟩 Flutter Precache"
time flutter precache --ios

echo "🟩 Install Flutter Dependencies"
cd repository/open_earable
time flutter clean
time flutter pub get
time flutter pub upgrade

echo "🟩 Install CocoaPods via Homebrew"
time HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

echo "🟩 build iOS"
time flutter build ios --release --no-codesign

echo "🟩 Install CocoaPods dependencies..."
time cd ios && pod install

exit 0