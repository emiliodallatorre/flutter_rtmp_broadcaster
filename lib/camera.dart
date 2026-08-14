// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

part 'camera_image.dart';

final MethodChannel _channel =
    const MethodChannel('plugins.flutter.io/rtmp_publisher');

enum CameraLensDirection { front, back, external }

/// Affect the quality of video recording and image capture:
///
/// If a preset is not available on the camera being used a preset of lower quality will be selected automatically.
enum ResolutionPreset {
  /// 352x288 on iOS, 240p (320x240) on Android
  low,

  /// 480p (640x480 on iOS, 720x480 on Android)
  medium,

  /// 720p (1280x720)
  high,

  /// 1080p (1920x1080)
  veryHigh,

  /// 2160p (3840x2160)
  ultraHigh,

  /// The highest resolution available.
  max,
}

// ignore: inference_failure_on_function_return_type
typedef LatestImageCallback = Function(CameraImage image);

/// The possible flash modes that can be set for a camera.
enum FlashMode {
  /// Do not use the flash when taking a picture.
  off,

  /// Let the device decide whether to flash the camera when taking a picture.
  auto,

  /// Always use the flash when taking a picture.
  always,

  /// Turns on the flash light and keeps it on until switched off.
  torch,
}

/// Returns the flash mode as a String.
String serializeFlashMode(FlashMode flashMode) {
  switch (flashMode) {
    case FlashMode.off:
      return 'off';
    case FlashMode.auto:
      return 'auto';
    case FlashMode.always:
      return 'always';
    case FlashMode.torch:
      return 'torch';
  }
}

/// The possible exposure modes that can be set for a camera.
enum ExposureMode {
  /// Automatically determine exposure settings.
  auto,

  /// Lock the currently determined exposure settings.
  locked,
}

/// Returns the exposure mode as a String.
String serializeExposureMode(ExposureMode exposureMode) {
  switch (exposureMode) {
    case ExposureMode.auto:
      return 'auto';
    case ExposureMode.locked:
      return 'locked';
  }
}

/// The possible focus modes that can be set for a camera.
enum FocusMode {
  /// Automatically determine focus settings.
  auto,

  /// Lock the currently determined focus settings.
  locked,
}

/// Returns the focus mode as a String.
String serializeFocusMode(FocusMode focusMode) {
  switch (focusMode) {
    case FocusMode.auto:
      return 'auto';
    case FocusMode.locked:
      return 'locked';
  }
}

/// Returns the resolution preset as a String.
String serializeResolutionPreset(ResolutionPreset resolutionPreset) {
  switch (resolutionPreset) {
    case ResolutionPreset.max:
      return 'max';
    case ResolutionPreset.ultraHigh:
      return 'ultraHigh';
    case ResolutionPreset.veryHigh:
      return 'veryHigh';
    case ResolutionPreset.high:
      return 'high';
    case ResolutionPreset.medium:
      return 'medium';
    case ResolutionPreset.low:
      return 'low';
  }
}

CameraLensDirection _parseCameraLensDirection(String? string) {
  switch (string) {
    case 'front':
      return CameraLensDirection.front;
    case 'back':
      return CameraLensDirection.back;
    case 'external':
      return CameraLensDirection.external;
  }
  throw ArgumentError('Unknown CameraLensDirection value');
}

/// Completes with a list of available cameras.
///
/// May throw a [CameraException].
Future<List<CameraDescription>> availableCameras() async {
  try {
    final List<Map<dynamic, dynamic>> cameras = (await _channel
        .invokeListMethod<Map<dynamic, dynamic>>('availableCameras'))!;
    return cameras.map((Map<dynamic, dynamic> camera) {
      return CameraDescription(
        name: camera['name'],
        lensDirection: _parseCameraLensDirection(camera['lensFacing']),
        sensorOrientation: camera['sensorOrientation'],
      );
    }).toList();
  } on PlatformException catch (e) {
    throw CameraException(e.code, e.message);
  }
}

class CameraDescription {
  CameraDescription({this.name, this.lensDirection, this.sensorOrientation});

  final String? name;
  final CameraLensDirection? lensDirection;

  /// Clockwise angle through which the output image needs to be rotated to be upright on the device screen in its native orientation.
  ///
  /// **Range of valid values:**
  /// 0, 90, 180, 270
  ///
  /// On Android, also defines the direction of rolling shutter readout, which
  /// is from top to bottom in the sensor's coordinate system.
  final int? sensorOrientation;

  @override
  bool operator ==(Object o) {
    return o is CameraDescription &&
        o.name == name &&
        o.lensDirection == lensDirection;
  }

  @override
  int get hashCode {
    return [name, lensDirection].hashCode;
  }

  @override
  String toString() {
    return '$runtimeType($name, $lensDirection, $sensorOrientation)';
  }
}

/// Statistics about the streaming, bitrate, errors, drops etc.
///
class StreamStatistics {
  final int? cacheSize;
  final int? sentAudioFrames;
  final int? sentVideoFrames;
  final int? droppedAudioFrames;
  final int? droppedVideoFrames;
  final bool? isAudioMuted;
  final int? bitrate;
  final int? width;
  final int? height;

  StreamStatistics({
    required this.cacheSize,
    required this.sentAudioFrames,
    required this.sentVideoFrames,
    required this.droppedAudioFrames,
    required this.droppedVideoFrames,
    required this.bitrate,
    required this.width,
    required this.height,
    required this.isAudioMuted,
  });

  @override
  String toString() {
    return 'StreamStatistics{cacheSize: $cacheSize, sentAudioFrames: $sentAudioFrames, sentVideoFrames: $sentVideoFrames, droppedAudioFrames: $droppedAudioFrames, droppedVideoFrames: $droppedVideoFrames, isAudioMuted: $isAudioMuted, bitrate: $bitrate, width: $width, height: $height}';
  }
}

/// This is thrown when the plugin reports an error.
class CameraException implements Exception {
  CameraException(this.code, this.description);

  String code;
  String? description;

  @override
  String toString() => '$runtimeType($code, $description)';
}

// Build the UI texture view of the video data with textureId.
class CameraPreview extends StatelessWidget {
  const CameraPreview(this.controller);

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.value.isInitialized!) {
      Widget childView;
      if (Platform.isAndroid) {
        childView = AndroidView(
          viewType: 'hybrid-view-type',
          creationParamsCodec: const StandardMessageCodec(),
        );
      } else {
        childView = Texture(textureId: controller._textureId!);
      }

      if (controller.value.previewSize!.width <
          controller.value.previewSize!.height) {
        return RotatedBox(
            quarterTurns: controller.value.previewQuarterTurns!,
            child: childView);
      } else {
        return childView;
      }
    } else {
      return Container();
    }
  }
}

/// The state of a [CameraController].
class CameraValue {
  const CameraValue({
    this.isInitialized,
    this.errorDescription,
    this.previewSize,
    this.previewQuarterTurns,
    this.isRecordingVideo,
    this.isTakingPicture,
    this.isStreamingImages,
    this.isStreamingVideoRtmp,
    this.event,
    this.flashMode = FlashMode.auto,
    this.exposureMode = ExposureMode.auto,
    this.focusMode = FocusMode.auto,
    bool? isRecordingPaused,
    bool? isStreamingPaused,
  })  : _isRecordingPaused = isRecordingPaused,
        _isStreamingPaused = isStreamingPaused;

  const CameraValue.uninitialized()
      : this(
          isInitialized: false,
          isRecordingVideo: false,
          isTakingPicture: false,
          isStreamingImages: false,
          isStreamingVideoRtmp: false,
          isRecordingPaused: false,
          isStreamingPaused: false,
          previewQuarterTurns: 0,
          event: null,
        );

  /// True after [CameraController.initialize] has completed successfully.
  final bool? isInitialized;

  /// True when a picture capture request has been sent but as not yet returned.
  final bool? isTakingPicture;

  /// True when the camera is recording (not the same as previewing).
  final bool? isRecordingVideo;

  /// True when the camera is recording (not the same as previewing).
  final bool? isStreamingVideoRtmp;

  /// True when images from the camera are being streamed.
  final bool? isStreamingImages;

  final bool? _isRecordingPaused;
  final bool? _isStreamingPaused;

  /// True when camera [isRecordingVideo] and recording is paused.
  bool get isRecordingPaused => isRecordingVideo! && _isRecordingPaused!;

  /// True when camera [isRecordingVideo] and streaming is paused.
  bool get isStreamingPaused => isStreamingVideoRtmp! && _isStreamingPaused!;

  final String? errorDescription;

  /// The size of the preview in pixels.
  ///
  /// Is `null` until  [isInitialized] is `true`.
  final Size? previewSize;

  /// The amount to rotate the preview by in quarter turns.
  ///
  /// Is `null` until  [isInitialized] is `true`.
  final int? previewQuarterTurns;

  /// Raw event info
  final dynamic event;

  /// The flash mode the camera is currently set to.
  final FlashMode flashMode;

  /// The exposure mode the camera is currently set to.
  final ExposureMode exposureMode;

  /// The focus mode the camera is currently set to.
  final FocusMode focusMode;

  /// Convenience getter for `previewSize.height / previewSize.width`.
  ///
  /// Can only be called when [initialize] is done.
  double get aspectRatio => previewSize!.height / previewSize!.width;

  bool get hasError => errorDescription != null;

  CameraValue copyWith({
    bool? isInitialized,
    bool? isRecordingVideo,
    bool? isStreamingVideoRtmp,
    bool? isTakingPicture,
    bool? isStreamingImages,
    String? errorDescription,
    Size? previewSize,
    int? previewQuarterTurns,
    bool? isRecordingPaused,
    bool? isStreamingPaused,
    dynamic event,
    FlashMode? flashMode,
    ExposureMode? exposureMode,
    FocusMode? focusMode,
  }) {
    return CameraValue(
      isInitialized: isInitialized ?? this.isInitialized,
      errorDescription: errorDescription,
      previewSize: previewSize ?? this.previewSize,
      previewQuarterTurns: previewQuarterTurns ?? this.previewQuarterTurns,
      isRecordingVideo: isRecordingVideo ?? this.isRecordingVideo,
      isStreamingVideoRtmp: isStreamingVideoRtmp ?? this.isStreamingVideoRtmp,
      isTakingPicture: isTakingPicture ?? this.isTakingPicture,
      isStreamingImages: isStreamingImages ?? this.isStreamingImages,
      isRecordingPaused: isRecordingPaused ?? _isRecordingPaused,
      isStreamingPaused: isStreamingPaused ?? _isStreamingPaused,
      event: event,
      flashMode: flashMode ?? this.flashMode,
      exposureMode: exposureMode ?? this.exposureMode,
      focusMode: focusMode ?? this.focusMode,
    );
  }

  @override
  String toString() {
    return '$runtimeType('
        'isRecordingVideo: $isRecordingVideo, '
        'isRecordingVideo: $isRecordingVideo, '
        'isInitialized: $isInitialized, '
        'errorDescription: $errorDescription, '
        'previewSize: $previewSize, '
        'previewQuarterTurns: $previewQuarterTurns, '
        'isStreamingImages: $isStreamingImages, '
        'isStreamingVideoRtmp: $isStreamingVideoRtmp)';
  }
}

/// Controls a device camera.
///
/// Use [availableCameras] to get a list of available cameras.
///
/// Before using a [CameraController] a call to [initialize] must complete.
///
/// To show the camera preview on the screen use a [CameraPreview] widget.
class CameraController extends ValueNotifier<CameraValue> {
  CameraController(
    this.description,
    this.resolutionPreset, {
    this.enableAudio = true,
    this.streamingPreset,
    this.androidUseOpenGL = false,
  }) : super(const CameraValue.uninitialized());

  final CameraDescription description;
  final ResolutionPreset resolutionPreset;
  final ResolutionPreset? streamingPreset;

  /// Whether to include audio when recording a video.
  final bool enableAudio;

  int? _textureId;
  String? _videoRecordingPath;
  bool _isDisposed = false;
  StreamSubscription<dynamic>? _eventSubscription;
  StreamSubscription<dynamic>? _imageStreamSubscription;
  Completer<void>? _creatingCompleter;
  final bool androidUseOpenGL;

  /// Initializes the camera on the device.
  ///
  /// Throws a [CameraException] if the initialization fails.
  Future<void> initialize() async {
    if (_isDisposed) {
      return Future<void>.value();
    }
    try {
      _creatingCompleter = Completer<void>();
      final Map<String, dynamic> reply =
          (await _channel.invokeMapMethod<String, dynamic>(
        'initialize',
        <String, dynamic>{
          'cameraName': description.name,
          'resolutionPreset': serializeResolutionPreset(resolutionPreset),
          'streamingPreset':
              serializeResolutionPreset(streamingPreset ?? resolutionPreset),
          'enableAudio': enableAudio,
          'enableAndroidOpenGL': androidUseOpenGL
        },
      ))!;
      _textureId = reply['textureId'];
      value = value.copyWith(
        isInitialized: true,
        previewSize: Size(
          reply['previewWidth'].toDouble(),
          reply['previewHeight'].toDouble(),
        ),
        previewQuarterTurns: reply['previewQuarterTurns'],
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
    _eventSubscription = EventChannel(
            'plugins.flutter.io/rtmp_publisher/cameraEvents$_textureId')
        .receiveBroadcastStream()
        .listen(_listener);
    _creatingCompleter!.complete();
    return _creatingCompleter!.future;
  }

  /// Prepare the capture session for video recording.
  ///
  /// Use of this method is optional, but it may be called for performance
  /// reasons on iOS.
  ///
  /// Preparing audio can cause a minor delay in the CameraPreview view on iOS.
  /// If video recording is intended, calling this early eliminates this delay
  /// that would otherwise be experienced when video recording is started.
  /// This operation is a no-op on Android.
  ///
  /// Throws a [CameraException] if the prepare fails.
  Future<void> prepareForVideoRecording() async {
    await _channel.invokeMethod<void>('prepareForVideoRecording');
  }

  /// Prepare the capture session for video streaming.
  ///
  /// Use of this method is optional, but it may be called for performance
  /// reasons on iOS.
  ///
  /// Preparing audio can cause a minor delay in the CameraPreview view on iOS.
  /// If video streaming is intended, calling this early eliminates this delay
  /// that would otherwise be experienced when video streaming is started.
  /// This operation is a no-op on Android.
  ///
  /// Throws a [CameraException] if the prepare fails.
  Future<void> prepareForVideoStreaming() async {
    await _channel.invokeMethod<void>('prepareForVideoStreaming');
  }

  /// Listen to events from the native plugins.
  ///
  /// A "cameraClosing" event is sent when the camera is closed automatically by the system (for example when the app go to background). The plugin will try to reopen the camera automatically but any ongoing recording will end.
  void _listener(dynamic event) {
    final Map<dynamic, dynamic>? map = event;
    if (_isDisposed || event == null) {
      return;
    }

    // Android: Event {eventType: rtmp_retry, errorDescription: BadName received}
    // iOS: Event {event: rtmp_retry, errorDescription: connection failed rtmpStatus}
    final String? eventType =
        map!['eventType'] as String? ?? map['event'] as String?;
    final String? errorDescription = map['errorDescription'];
    final Map<String, dynamic> uniEvent = <String, dynamic>{
      'eventType': eventType,
      'errorDescription': errorDescription
    };
    switch (eventType) {
      case 'error':
        value =
            value.copyWith(errorDescription: errorDescription, event: uniEvent);
        break;
      case 'camera_closing':
        value = value.copyWith(
            isRecordingVideo: false,
            isStreamingVideoRtmp: false,
            event: uniEvent);
        break;
      case 'rtmp_connected':
        value = value.copyWith(event: uniEvent);
        break;
      case 'rtmp_retry':
        value = value.copyWith(event: uniEvent);
        break;
      case 'rtmp_stopped':
        value = value.copyWith(isStreamingVideoRtmp: false, event: uniEvent);
        break;
      case 'rotation_update':
        value = value.copyWith(
            previewQuarterTurns: int.parse(errorDescription!), event: uniEvent);
        break;
      default:
        value = value.copyWith(event: uniEvent);
        break;
    }
  }

  /// Captures an image and saves it to [path].
  ///
  /// A path can for example be obtained using
  /// [path_provider](https://pub.dartlang.org/packages/path_provider).
  ///
  /// If a file already exists at the provided path an error will be thrown.
  /// The file can be read as this function returns.
  ///
  /// Throws a [CameraException] if the capture fails.
  Future<void> takePicture(String path) async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController.',
        'takePicture was called on uninitialized CameraController',
      );
    }
    if (value.isTakingPicture!) {
      throw CameraException(
        'Previous capture has not returned yet.',
        'takePicture was called before the previous capture returned.',
      );
    }
    try {
      value = value.copyWith(isTakingPicture: true);
      await _channel.invokeMethod<void>(
        'takePicture',
        <String, dynamic>{'textureId': _textureId, 'path': path},
      );
      value = value.copyWith(isTakingPicture: false);
    } on PlatformException catch (e) {
      value = value.copyWith(isTakingPicture: false);
      throw CameraException(e.code, e.message);
    }
  }

  /// Captures an image and returns the file where it was saved.
  ///
  /// The file is saved to a temporary directory managed by the plugin;
  /// use [takePicture] instead if a specific destination path is required.
  ///
  /// Throws a [CameraException] if the capture fails.
  Future<XFile> takePictureXFile() async {
    final Directory tempDir = await getTemporaryDirectory();
    final String path =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await takePicture(path);
    return XFile(path);
  }

  /// Start streaming images from platform camera.
  ///
  /// Settings for capturing images on iOS and Android is set to always use the
  /// latest image available from the camera and will drop all other images.
  ///
  /// When running continuously with [CameraPreview] widget, this function runs
  /// best with [ResolutionPreset.low]. Running on [ResolutionPreset.high] can
  /// have significant frame rate drops for [CameraPreview] on lower end
  /// devices.
  ///
  /// Throws a [CameraException] if image streaming or video recording has
  /// already started.
  // TODO(bmparr): Add settings for resolution and fps.
  Future<void> startImageStream(LatestImageCallback onAvailable) async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'startImageStream was called on uninitialized CameraController.',
      );
    }
    if (value.isRecordingVideo!) {
      throw CameraException(
        'A video recording is already started.',
        'startImageStream was called while a video is being recorded.',
      );
    }
    if (value.isStreamingVideoRtmp!) {
      throw CameraException(
        'A video recording is already started.',
        'startImageStream was called while a video is being recorded.',
      );
    }
    if (value.isStreamingImages!) {
      throw CameraException(
        'A camera has started streaming images.',
        'startImageStream was called while a camera was streaming images.',
      );
    }

    try {
      await _channel.invokeMethod<void>('startImageStream');
      value = value.copyWith(isStreamingImages: true);
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
    const EventChannel cameraEventChannel =
        EventChannel('plugins.flutter.io/rtmp_publisher/imageStream');
    _imageStreamSubscription =
        cameraEventChannel.receiveBroadcastStream().listen(
      (dynamic imageData) {
        onAvailable(CameraImage._fromPlatformData(imageData));
      },
    );
  }

  /// Stop streaming images from platform camera.
  ///
  /// Throws a [CameraException] if image streaming was not started or video
  /// recording was started.
  Future<void> stopImageStream() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'stopImageStream was called on uninitialized CameraController.',
      );
    }
    if (!value.isStreamingImages!) {
      throw CameraException(
        'No camera is streaming images',
        'stopImageStream was called when no camera is streaming images.',
      );
    }

    try {
      value = value.copyWith(isStreamingImages: false);
      await _channel.invokeMethod<void>('stopImageStream');
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }

    await _imageStreamSubscription!.cancel();
    _imageStreamSubscription = null;
  }

  /// Get statistics about the rtmp stream.
  ///
  /// Throws a [CameraException] if image streaming was not started.
  Future<StreamStatistics> getStreamStatistics() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'stopImageStream was called on uninitialized CameraController.',
      );
    }
    if (!value.isStreamingVideoRtmp!) {
      throw CameraException(
        'No camera is streaming images',
        'stopImageStream was called when no camera is streaming images.',
      );
    }

    try {
      var data = (await _channel
          .invokeMapMethod<String, dynamic>('getStreamStatistics'))!;
      return StreamStatistics(
        sentAudioFrames: data["sentAudioFrames"],
        sentVideoFrames: data["sentVideoFrames"],
        height: data["height"],
        width: data["width"],
        bitrate: data["bitrate"],
        isAudioMuted: data["isAudioMuted"],
        cacheSize: data["cacheSize"],
        droppedAudioFrames: data["drpppedAudioFrames"],
        droppedVideoFrames: data["droppedVideoFrames"],
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Start a video recording and save the file to [path].
  ///
  /// A path can for example be obtained using
  /// [path_provider](https://pub.dartlang.org/packages/path_provider).
  ///
  /// The file is written on the flight as the video is being recorded.
  /// If a file already exists at the provided path an error will be thrown.
  /// The file can be read as soon as [stopVideoRecording] returns.
  ///
  /// Throws a [CameraException] if the capture fails.
  Future<void> startVideoRecording(String filePath) async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'startVideoRecording was called on uninitialized CameraController',
      );
    }
    if (value.isRecordingVideo!) {
      throw CameraException(
        'A video recording is already started.',
        'startVideoRecording was called when a recording is already started.',
      );
    }
    if (value.isStreamingImages!) {
      throw CameraException(
        'A camera has started streaming images.',
        'startVideoRecording was called while a camera was streaming images.',
      );
    }

    try {
      await _channel.invokeMethod<void>(
        'startVideoRecording',
        <String, dynamic>{'textureId': _textureId, 'filePath': filePath},
      );
      _videoRecordingPath = filePath;
      value = value.copyWith(isRecordingVideo: true, isRecordingPaused: false);
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Stop recording.
  Future<void> stopVideoRecording() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'stopVideoRecording was called on uninitialized CameraController',
      );
    }
    if (!value.isRecordingVideo!) {
      throw CameraException(
        'No video is recording',
        'stopVideoRecording was called when no video is recording.',
      );
    }
    try {
      value =
          value.copyWith(isRecordingVideo: false, isStreamingVideoRtmp: false);
      await _channel.invokeMethod<void>(
        'stopRecordingOrStreaming',
        <String, dynamic>{'textureId': _textureId},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Stops the video recording and returns the file where it was saved.
  ///
  /// Throws a [CameraException] if the capture failed, or if
  /// [startVideoRecording] was never called before this recording.
  Future<XFile> stopVideoRecordingXFile() async {
    final String? path = _videoRecordingPath;
    if (path == null) {
      throw CameraException(
        'No recording path available',
        'stopVideoRecordingXFile was called without a prior '
            'startVideoRecording call.',
      );
    }
    await stopVideoRecording();
    _videoRecordingPath = null;
    return XFile(path);
  }

  /// Pause video recording.
  ///
  /// This feature is only available on iOS and Android sdk 24+.
  Future<void> pauseVideoRecording() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'pauseVideoRecording was called on uninitialized CameraController',
      );
    }
    if (!value.isRecordingVideo!) {
      throw CameraException(
        'No video is recording',
        'pauseVideoRecording was called when no video is recording.',
      );
    }
    try {
      value = value.copyWith(isRecordingPaused: true);
      await _channel.invokeMethod<void>(
        'pauseVideoRecording',
        <String, dynamic>{'textureId': _textureId},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Resume video recording after pausing.
  ///
  /// This feature is only available on iOS and Android sdk 24+.
  Future<void> resumeVideoRecording() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'resumeVideoRecording was called on uninitialized CameraController',
      );
    }
    if (!value.isRecordingVideo!) {
      throw CameraException(
        'No video is recording',
        'resumeVideoRecording was called when no video is recording.',
      );
    }
    try {
      value = value.copyWith(isRecordingPaused: false);
      await _channel.invokeMethod<void>(
        'resumeVideoRecording',
        <String, dynamic>{'textureId': _textureId},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Start a video streaming to the url in [url`].
  ///
  /// This uses rtmp to do the sending the remote side.
  ///
  /// Throws a [CameraException] if the capture fails.
  Future<void> startVideoRecordingAndStreaming(String filePath, String url,
      {int bitrate = 1200 * 1024, bool? androidUseOpenGL}) async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'startVideoStreaming was called on uninitialized CameraController',
      );
    }

    if (value.isRecordingVideo!) {
      throw CameraException(
        'A video recording is already started.',
        'startVideoStreaming was called when a recording is already started.',
      );
    }
    if (value.isStreamingVideoRtmp!) {
      throw CameraException(
        'A video streaming is already started.',
        'startVideoStreaming was called when a recording is already started.',
      );
    }
    if (value.isStreamingImages!) {
      throw CameraException(
        'A camera has started streaming images.',
        'startVideoStreaming was called while a camera was streaming images.',
      );
    }

    try {
      await _channel.invokeMethod<void>(
          'startVideoRecordingAndStreaming', <String, dynamic>{
        'textureId': _textureId,
        'url': url,
        'filePath': filePath,
        'bitrate': bitrate,
      });
      value =
          value.copyWith(isStreamingVideoRtmp: true, isStreamingPaused: false, isRecordingVideo: true, isRecordingPaused: false);
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Start a video streaming to the url in [url`].
  ///
  /// This uses rtmp to do the sending the remote side.
  ///
  /// Throws a [CameraException] if the capture fails.
  Future<void> startVideoStreaming(String url,
      {int bitrate = 1200 * 1024, bool? androidUseOpenGL}) async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'startVideoStreaming was called on uninitialized CameraController',
      );
    }
    if (value.isRecordingVideo!) {
      throw CameraException(
        'A video recording is already started.',
        'startVideoStreaming was called when a recording is already started.',
      );
    }
    if (value.isStreamingVideoRtmp!) {
      throw CameraException(
        'A video streaming is already started.',
        'startVideoStreaming was called when a recording is already started.',
      );
    }
    if (value.isStreamingImages!) {
      throw CameraException(
        'A camera has started streaming images.',
        'startVideoStreaming was called while a camera was streaming images.',
      );
    }

    try {
      await _channel
          .invokeMethod<void>('startVideoStreaming', <String, dynamic>{
        'textureId': _textureId,
        'url': url,
        'bitrate': bitrate,
      });
      value =
          value.copyWith(isStreamingVideoRtmp: true, isStreamingPaused: false);
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Stop streaming.
  Future<void> stopVideoStreaming() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'stopVideoStreaming was called on uninitialized CameraController',
      );
    }
    if (!value.isStreamingVideoRtmp!) {
      throw CameraException(
        'No video is recording',
        'stopVideoStreaming was called when no video is streaming.',
      );
    }
    try {
      value =
          value.copyWith(isStreamingVideoRtmp: false, isRecordingVideo: false);
      print("Stop video streaming call");
      await _channel.invokeMethod<void>(
        'stopRecordingOrStreaming',
        <String, dynamic>{'textureId': _textureId},
      );
    } on PlatformException catch (e) {
      print("Got exception " + e.toString());
      throw CameraException(e.code, e.message);
    }
  }

  /// Stop streaming.
  Future<void> stopEverything() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'stopVideoStreaming was called on uninitialized CameraController',
      );
    }
    try {
      value = value.copyWith(isStreamingVideoRtmp: false);
      if (value.isRecordingVideo! || value.isStreamingVideoRtmp!) {
        value = value.copyWith(
            isRecordingVideo: false, isStreamingVideoRtmp: false);
        await _channel.invokeMethod<void>(
          'stopRecordingOrStreaming',
          <String, dynamic>{'textureId': _textureId},
        );
      }
      if (value.isStreamingImages!) {
        value = value.copyWith(isStreamingImages: false);
        await _channel.invokeMethod<void>('stopImageStream');
      }
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Pause video recording.
  ///
  /// This feature is only available on iOS and Android sdk 24+.
  Future<void> pauseVideoStreaming() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'pauseVideoStreaming was called on uninitialized CameraController',
      );
    }
    if (!value.isStreamingVideoRtmp!) {
      throw CameraException(
        'No video is recording',
        'pauseVideoStreaming was called when no video is streaming.',
      );
    }
    try {
      value = value.copyWith(isStreamingPaused: true);
      await _channel.invokeMethod<void>(
        'pauseVideoStreaming',
        <String, dynamic>{'textureId': _textureId},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Resume video streaming after pausing.
  ///
  /// This feature is only available on iOS and Android sdk 24+.
  Future<void> resumeVideoStreaming() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'resumeVideoStreaming was called on uninitialized CameraController',
      );
    }
    if (!value.isStreamingVideoRtmp!) {
      throw CameraException(
        'No video is recording',
        'resumeVideoStreaming was called when no video is streaming.',
      );
    }
    try {
      value = value.copyWith(isStreamingPaused: false);
      await _channel.invokeMethod<void>(
        'resumeVideoStreaming',
        <String, dynamic>{'textureId': _textureId},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Gets the maximum supported zoom level for the selected camera.
  Future<double> getMaxZoomLevel() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'getMaxZoomLevel was called on uninitialized CameraController.',
      );
    }
    try {
      final double maxZoomLevel = (await _channel.invokeMethod<double>(
        'getMaxZoomLevel',
        <String, dynamic>{'textureId': _textureId},
      ))!;
      return maxZoomLevel;
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Gets the minimum supported zoom level for the selected camera.
  Future<double> getMinZoomLevel() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'getMinZoomLevel was called on uninitialized CameraController.',
      );
    }
    try {
      final double minZoomLevel = (await _channel.invokeMethod<double>(
        'getMinZoomLevel',
        <String, dynamic>{'textureId': _textureId},
      ))!;
      return minZoomLevel;
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Set the zoom level for the selected camera.
  ///
  /// The supplied [zoom] value should be between 1.0 and the maximum
  /// supported zoom level returned by [getMaxZoomLevel]. Throws a
  /// [CameraException] when an illegal zoom level is supplied.
  Future<void> setZoomLevel(double zoom) async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'setZoomLevel was called on uninitialized CameraController.',
      );
    }
    try {
      await _channel.invokeMethod<void>(
        'setZoomLevel',
        <String, dynamic>{'textureId': _textureId, 'zoom': zoom},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Sets the flash mode for taking pictures.
  Future<void> setFlashMode(FlashMode mode) async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'setFlashMode was called on uninitialized CameraController.',
      );
    }
    try {
      await _channel.invokeMethod<void>(
        'setFlashMode',
        <String, dynamic>{
          'textureId': _textureId,
          'mode': serializeFlashMode(mode),
        },
      );
      value = value.copyWith(flashMode: mode);
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Sets the exposure mode for taking pictures.
  Future<void> setExposureMode(ExposureMode mode) async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'setExposureMode was called on uninitialized CameraController.',
      );
    }
    try {
      await _channel.invokeMethod<void>(
        'setExposureMode',
        <String, dynamic>{
          'textureId': _textureId,
          'mode': serializeExposureMode(mode),
        },
      );
      value = value.copyWith(exposureMode: mode);
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Sets the focus mode for taking pictures.
  Future<void> setFocusMode(FocusMode mode) async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'setFocusMode was called on uninitialized CameraController.',
      );
    }
    try {
      await _channel.invokeMethod<void>(
        'setFocusMode',
        <String, dynamic>{
          'textureId': _textureId,
          'mode': serializeFocusMode(mode),
        },
      );
      value = value.copyWith(focusMode: mode);
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Releases the resources of this camera.
  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    super.dispose();
    if (_creatingCompleter != null) {
      await _creatingCompleter!.future;
      await _channel.invokeMethod<void>(
        'dispose',
        <String, dynamic>{'textureId': _textureId},
      );
      await _eventSubscription?.cancel();
    }
  }
}
