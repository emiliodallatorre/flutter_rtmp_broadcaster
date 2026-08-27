// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'camera_image.dart';
import 'types.dart';

final MethodChannel _channel =
    const MethodChannel('plugins.flutter.io/rtmp_publisher');

// ignore: inference_failure_on_function_return_type
typedef LatestImageCallback = Function(CameraImage image);

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

/// The state of a [CameraController].
class CameraValue {
  /// Creates a new camera controller state.
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

  /// Creates a new camera controller state for an uninitialized controller.
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

  /// True when the camera is recording video (not the same as previewing).
  final bool? isRecordingVideo;

  /// True when the camera is streaming video to an RTMP server (not the
  /// same as previewing).
  final bool? isStreamingVideoRtmp;

  /// True when images from the camera are being streamed.
  final bool? isStreamingImages;

  final bool? _isRecordingPaused;
  final bool? _isStreamingPaused;

  /// True when camera [isRecordingVideo] and recording is paused.
  bool get isRecordingPaused => isRecordingVideo! && _isRecordingPaused!;

  /// True when camera [isStreamingVideoRtmp] and streaming is paused.
  bool get isStreamingPaused => isStreamingVideoRtmp! && _isStreamingPaused!;

  /// Description of an error state.
  ///
  /// This is null while the controller is not in an error state.
  /// When [hasError] is true this contains the error description.
  final String? errorDescription;

  /// The size of the preview in pixels.
  ///
  /// Is `null` until [isInitialized] is `true`.
  final Size? previewSize;

  /// The amount to rotate the preview by in quarter turns.
  ///
  /// Is `null` until [isInitialized] is `true`.
  final int? previewQuarterTurns;

  /// Raw info about the last event received from the native plugin, as
  /// reported by [CameraController._listener].
  ///
  /// This carries RTMP connection/retry/stop notifications and rotation
  /// updates alongside the more specific [CameraValue] fields they also
  /// update.
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

  /// Whether the controller is in an error state.
  ///
  /// When true [errorDescription] describes the error.
  bool get hasError => errorDescription != null;

  /// Creates a modified copy of the object.
  ///
  /// Explicitly specified fields get the specified value, all other fields
  /// get the same value of the current object, except [errorDescription] and
  /// [event] which are always cleared unless explicitly specified.
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
        'isStreamingVideoRtmp: $isStreamingVideoRtmp, '
        'isInitialized: $isInitialized, '
        'errorDescription: $errorDescription, '
        'previewSize: $previewSize, '
        'previewQuarterTurns: $previewQuarterTurns, '
        'isStreamingImages: $isStreamingImages)';
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
  /// Creates a new camera controller in an uninitialized state.
  CameraController(
    this.description,
    this.resolutionPreset, {
    this.enableAudio = true,
    this.streamingPreset,
    this.androidUseOpenGL = false,
  }) : super(const CameraValue.uninitialized());

  /// The properties of the camera device controlled by this controller.
  final CameraDescription description;

  /// The resolution this controller is targeting for video recording and
  /// image capture.
  ///
  /// This resolution preset is not guaranteed to be available on the device,
  /// if unavailable a lower resolution will be used.
  ///
  /// See also: [ResolutionPreset].
  final ResolutionPreset resolutionPreset;

  /// The resolution this controller is targeting for RTMP streaming.
  ///
  /// Falls back to [resolutionPreset] when omitted.
  final ResolutionPreset? streamingPreset;

  /// Whether to include audio when recording a video.
  final bool enableAudio;

  int? _textureId;
  String? _videoRecordingPath;
  bool _isDisposed = false;
  StreamSubscription<dynamic>? _eventSubscription;
  StreamSubscription<dynamic>? _imageStreamSubscription;
  Completer<void>? _creatingCompleter;

  /// Completes once the native camera preview surface has been created.
  ///
  /// On Android, the preview surface is created asynchronously after
  /// [initialize] resolves and the [CameraPreview] widget is built, so
  /// starting RTMP streaming too early can hang indefinitely. See
  /// https://github.com/emiliodallatorre/flutter_rtmp_broadcaster/issues/15.
  Completer<void>? _surfaceReadyCompleter;

  /// Whether the Android platform view should be composed using OpenGL.
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
      _surfaceReadyCompleter = Completer<void>();
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
  /// A "camera_closing" event is sent when the camera is closed automatically
  /// by the system (for example when the app go to background). The plugin
  /// will try to reopen the camera automatically but any ongoing recording
  /// will end.
  ///
  /// RTMP-specific events ("rtmp_connected", "rtmp_retry", "rtmp_stopped")
  /// and "rotation_update" are also delivered through this listener and
  /// update [CameraValue] accordingly.
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
      case 'camera_ready':
        if (_surfaceReadyCompleter != null &&
            !_surfaceReadyCompleter!.isCompleted) {
          _surfaceReadyCompleter!.complete();
        }
        value = value.copyWith(event: uniEvent);
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
  /// The file is saved to a temporary directory managed by the plugin; use
  /// [takePicture] instead if a specific destination path is required.
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
        onAvailable(CameraImage.fromPlatformData(imageData));
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

  /// Get statistics about the RTMP stream: bitrate, dropped frames, and
  /// similar values reported by the native encoder.
  ///
  /// Throws a [CameraException] if RTMP streaming was not started.
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
        droppedAudioFrames: data["droppedAudioFrames"],
        droppedVideoFrames: data["droppedVideoFrames"],
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Start a video recording and save the file to [filePath].
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

  /// Start recording video and streaming it to [url] via RTMP, saving a copy
  /// of the recording to [filePath].
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

    // The Android preview surface is created asynchronously after
    // [initialize] resolves. Starting streaming before it exists can hang
    // indefinitely, so wait for it here.
    if (Platform.isAndroid) {
      await _surfaceReadyCompleter?.future;
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

  /// Start streaming video to [url] via RTMP.
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

    // The Android preview surface is created asynchronously after
    // [initialize] resolves. Starting streaming before it exists can hang
    // indefinitely, so wait for it here.
    if (Platform.isAndroid) {
      await _surfaceReadyCompleter?.future;
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

  /// Stop RTMP streaming.
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
      await _channel.invokeMethod<void>(
        'stopRecordingOrStreaming',
        <String, dynamic>{'textureId': _textureId},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Stop any ongoing recording and/or RTMP streaming and/or image
  /// streaming, whichever of those are currently active.
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

  /// Pause RTMP streaming.
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

  /// Resume RTMP streaming after pausing.
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

  /// Returns a widget showing a live camera preview.
  ///
  /// Used by [CameraPreview]; most callers should use that widget instead of
  /// calling this method directly.
  Widget buildPreview() {
    if (Platform.isAndroid) {
      return const AndroidView(
        viewType: 'hybrid-view-type',
        creationParamsCodec: StandardMessageCodec(),
      );
    }
    return Texture(textureId: _textureId!);
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
