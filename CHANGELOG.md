## 3.1.1

* iOS: fixed RTMP stream key/query string being truncated when constructing the connect URL, by parsing the URL with `URLComponents` instead of splitting on `/` (fixes [#38](https://github.com/emiliodallatorre/flutter_rtmp_broadcaster/issues/38)).

## 3.1.0

* **Breaking:** iOS minimum deployment target is now `13.0` (previously `10.0`) to support modern HaishinKit 1.x.
* Android: implemented `pauseVideoStreaming` / `resumeVideoStreaming` by pausing camera+audio input and restoring it on resume, with proper native method-channel success/error reporting (fixes [#29](https://github.com/emiliodallatorre/flutter_rtmp_broadcaster/issues/29)).
* iOS: upgraded `HaishinKit` to `~> 1.9.9` and updated Swift settings in the plugin podspec (`swift_version` `5.10`).
* iOS: migrated RTMP bridge code to the HaishinKit 1.9.9 API surface (`VideoCodecSettings`, `append(_:)`, `videoOrientation`, `sessionPreset`, `frameRate`).
* Fixed native handling for `prepareForVideoStreaming` so the Dart method is fully wired on iOS (and Android no-op parity).
* Fixed `getStreamStatistics` mapping typo for `droppedAudioFrames`.
* iOS: removed blocking reconnect sleeps, replaced with async backoff scheduling, and removed unsafe reconnect force-unwrapping.

## 3.0.1

* Fixed `startVideoStreaming`/`startVideoRecordingAndStreaming` hanging indefinitely on Android when called immediately after `initialize()`, by waiting for the native preview surface to be ready before starting the stream (fixes [#15](https://github.com/emiliodallatorre/flutter_rtmp_broadcaster/issues/15))
* Added a GitHub Actions workflow to close stale issues and pull requests
* The pub.dev/GitHub release workflow now waits for the Dart CI workflow to pass on the tagged commit before publishing
* Added a Docker Compose configuration for a local `mediamtx` RTMP test server
* Updated the API consistency test baseline reference to version 3.0.0

## 3.0.0

* Restarted active development of the plugin
* Gradle: bumped `compileSdkVersion`/`buildToolsVersion` to 37 and Android Gradle Plugin to 9.3.1
* Gradle: bumped Gradle wrapper to 9.5.1
* Gradle: opted out of AGP's built-in Kotlin and reapplied the classic `kotlin-android` plugin pinned to 2.3.21
* Gradle: increased Gradle JVM heap to prevent out-of-memory failures during Jetifier transforms
* Removed the unnecessary `project.clj` packaging exclusion from the example app
* Restructured `lib/` to match the upstream `camera` package layout
* Added camera-control and `XFile` capture APIs to `CameraController`
* Added test coverage tooling with CI reporting
* Split the example app's single `main.dart` into dedicated screens, widgets and utils
* Modernized the example app to current Flutter/Dart conventions, with explicit types and null safety
* Replaced the example app's watch icon with a settings icon
* Added a `.devcontainer` configuration for a ready-to-use Flutter/Android development environment
* Added a local RTMP test server (`server/`, via Docker Compose) with a dedicated README
* Added a GitHub Actions workflow to publish to pub.dev and create a GitHub release on tag push
* Modernized the CI workflow, running `dart analyze`, tests and example builds on every push
* **Breaking:** renamed the main library file from `lib/camera.dart` to `lib/rtmp_broadcaster.dart`, to satisfy pub.dev's package validation. Update your imports accordingly:

  ```sh
  grep -rl "package:rtmp_broadcaster/camera.dart" --include="*.dart" . | xargs sed -i "s#package:rtmp_broadcaster/camera.dart#package:rtmp_broadcaster/rtmp_broadcaster.dart#g"
  ```

## 2.3.4

* Updated Dependencies
* Bumped Flutter min Version to 3.22.0 and Dart SDK min Version to 3.4.0
* Gradle: Bumped compileSdkVersion to 33
* Gradle: Specified buildToolsVersion to 33.0.1
* Gradle: Replaced jcenter with mavenCentral
* Gradle: Specified source/targetCompatibility and jvmTarget to 1.8
* The credits for this version go to @OlJhonny, who called out [PR #27](https://github.com/emiliodallatorre/flutter_rtmp_broadcaster/pull/27) to fix Gradle 8 compatibility and old dependencies


## 2.2.6

* Fixed SDK contraints for Flutter 4.0.0

## 2.2.5

* Fixed old Flutter dependency usage

## 2.2.3

* Fixed video recording on Android

## 2.2.2

* Updated the license with the explicit permission of the original developer David Bennett

## 2.2.1

* Updated README.md

## 2.2.0

* Fixed a bitrate issue on iOS that was preventing the stream and recording of the video
* Removed outdated test suite

## 2.1.3

* Fixed some testing errors
* Updated Android embedding to v2 in example

## 2.1.2

* Reformatted some files

## 2.1.1

* Migrated the entire package to null safety

## 0.3.7

* Export full event info

## 0.3.6

* Update ios podspec

## 0.3.5

* Update example

## 0.3.4

* Update android, ios build
