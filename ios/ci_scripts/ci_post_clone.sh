#!/bin/sh

# Xcode Cloud post-clone script for Flutter
# Runs after Xcode Cloud clones the repo, before the build starts.
# Installs Flutter SDK, fetches pub packages and installs CocoaPods,
# so the generated files (Generated.xcconfig, Pods/Target Support Files/...)
# exist before xcodebuild runs.

set -e

echo "==> [ci_post_clone] Starting Flutter setup for Xcode Cloud"

# Resolve repo root relative to this script (script lives at ios/ci_scripts/).
# Avoids relying on $CI_WORKSPACE / $CI_PRIMARY_REPOSITORY_PATH which can vary.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
echo "==> SCRIPT_DIR=$SCRIPT_DIR"
echo "==> REPO_ROOT=$REPO_ROOT"

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

echo "==> cd $REPO_ROOT && flutter pub get"
cd "$REPO_ROOT"
flutter pub get

echo "==> cd $REPO_ROOT/ios && pod install --repo-update"
cd "$REPO_ROOT/ios"
pod install --repo-update

echo "==> [ci_post_clone] Done"
