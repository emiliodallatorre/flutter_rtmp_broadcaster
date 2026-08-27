# Flutter RTMP broadcaster

[![codecov](https://codecov.io/gh/emiliodallatorre/flutter_rtmp_broadcaster/graph/badge.svg?branch=master)](https://codecov.io/gh/emiliodallatorre/flutter_rtmp_broadcaster)

> [!IMPORTANT]
> Development of version 3.0 is being restarted. Expect breaking changes to the API and Android/iOS build configuration while this work is in progress.

This plugin extends the Flutter [camera](https://pub.dev/packages/camera) plugin with RTMP streaming support for Android and iOS. Web is not supported.

It follows the same API structure as the camera plugin and adds a `startStreaming(url)` method to initiate real-time streaming to an RTMP endpoint.

Underlying implementation:

- Android: [rtmp-rtsp-stream-client-java](https://github.com/pedroSG94/rtmp-rtsp-stream-client-java)
- iOS: [HaishinKit.swift](https://github.com/shogo4405/HaishinKit.swift)

## Features

- Live camera preview embedded in a widget
- Snapshot capture to file
- Video recording
- Direct access to image streams from Dart

## Usage

The controller extends the camera plugin's API with the following methods:

| Function | Description |
|----------|-------------|
| `startVideoStreaming(String url, {int bitrate = 1200 * 1024, bool? androidUseOpenGL})` | Starts streaming to an RTMP endpoint |
| `startVideoRecordingAndStreaming(String filePath, String url, {int bitrate = 1200 * 1024, bool? androidUseOpenGL})` | Starts streaming to an RTMP endpoint while simultaneously recording to a local file |
| `pauseVideoStreaming()` | Pauses the active stream |
| `resumeVideoStreaming()` | Resumes a paused stream |
| `stopEverything()` | Stops any active streaming and recording |

## Getting started

### iOS

Add the following keys to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>App requires access to the camera for live streaming feature.</string>
<key>NSMicrophoneUsageDescription</key>
<string>App requires access to the microphone for live streaming feature.</string>
```

### Android

Set `minSdkVersion` to 21 or higher in `android/app/build.gradle`.

## Example

The [example app](https://github.com/emiliodallatorre/flutter_rtmp_broadcaster/tree/master/example) demonstrates camera preview, snapshot capture, video recording, and RTMP streaming. Clone the repository and run the app on an Android or iOS device to try it.

A local RTMP test server is available under [`server/`](server/README.md), set up via Docker Compose, for testing without a public endpoint.

## Troubleshooting & issues

Report bugs or unexpected behavior via [GitHub issues](https://github.com/emiliodallatorre/flutter_rtmp_broadcaster/issues). Availability for support is limited; for prioritized or paid support, contact [info@emiliodallatorre.it](mailto:info@emiliodallatorre.it).

## Contributing

1. Fork the repository and create a branch for your change
2. Make the change
3. Ensure the code is formatted and tested
4. Submit a pull request describing the change

## Support development

If this plugin is useful to you, consider supporting its development via [Buy Me a Coffee](https://www.buymeacoffee.com/emiliodallatorre).
