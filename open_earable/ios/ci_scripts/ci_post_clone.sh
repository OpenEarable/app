#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# by default, the execution directory of this script is the ci_scripts directory
# CI_WORKSPACE is the directory of your cloned repo
echo "🟩 Navigate from ($PWD) to ($CI_WORKSPACE_PATH)"
cd $CI_WORKSPACE_PATH

echo "🟩 Install Flutter"
time git clone https://github.com/flutter/flutter.git -b flutter-3.16-candidate.22 $HOME/flutter
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
flutter build ios --release --no-codesign

echo "🟩 Install CocoaPods dependencies..."
time cd ios && pod install

exit 0