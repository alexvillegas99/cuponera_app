#!/bin/sh

# Xcode Cloud post-clone script for Flutter
# Runs after Xcode Cloud clones the repo, before the build starts.
# Installs Flutter SDK, fetches pub packages and installs CocoaPods,
# so the generated files (Generated.xcconfig, Pods/Target Support Files/...)
# exist before xcodebuild runs.

set -e

echo "==> [ci_post_clone] Starting Flutter setup for Xcode Cloud"

# Clone Flutter SDK (stable channel) to a writable location
FLUTTER_DIR="$HOME/flutter"
if [ ! -d "$FLUTTER_DIR" ]; then
  echo "==> Cloning Flutter stable into $FLUTTER_DIR"
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "==> flutter --version"
flutter --version

echo "==> flutter precache --ios"
flutter precache --ios

# Move to the Flutter project root (one level up from ios/ci_scripts/)
cd "$CI_WORKSPACE"

echo "==> flutter pub get"
flutter pub get

echo "==> pod install"
cd ios
pod install --repo-update

echo "==> [ci_post_clone] Done"
