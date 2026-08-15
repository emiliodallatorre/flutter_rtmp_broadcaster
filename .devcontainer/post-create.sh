#!/usr/bin/env bash
set -euo pipefail

flutter config --android-sdk "${ANDROID_HOME}"
flutter precache --android
flutter doctor -v

# Fetch dependencies for the plugin and the example app.
flutter pub get
(cd example && flutter pub get)
