// Tests that [CameraController] methods invoke the platform channel with
// the exact method name and argument keys the native (Kotlin/Swift) side
// expects. These are not compile-checked across the platform boundary, so
// a rename/typo here would silently break native communication.
//
// See also:
//  * camera_controller_guard_clauses_test.dart, which covers the
//    preconditions checked before these channel calls are made.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtmp_broadcaster/rtmp_broadcaster.dart';

const MethodChannel _cameraChannel = MethodChannel(
  'plugins.flutter.io/rtmp_publisher',
);

const int _textureId = 42;

Future<CameraController> _createInitializedController() async {
  final CameraController controller = CameraController(
    CameraDescription(
      name: 'test',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 0,
    ),
    ResolutionPreset.low,
  );
  await controller.initialize();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraChannel, (MethodCall call) async {
      log.add(call);
      switch (call.method) {
        case 'initialize':
          return <String, dynamic>{
            'textureId': _textureId,
            'previewWidth': 1920.0,
            'previewHeight': 1080.0,
            'previewQuarterTurns': 0,
          };
        case 'getStreamStatistics':
          return <String, dynamic>{
            'cacheSize': 0,
            'sentAudioFrames': 0,
            'sentVideoFrames': 0,
            'droppedAudioFrames': 0,
            'droppedVideoFrames': 0,
            'isAudioMuted': false,
            'bitrate': 0,
            'width': 0,
            'height': 0,
          };
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraChannel, null);
  });

  test('initialize sends cameraName, resolutionPreset, streamingPreset, '
      'enableAudio and enableAndroidOpenGL', () async {
    final CameraController controller = CameraController(
      CameraDescription(
        name: 'back-camera',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 0,
      ),
      ResolutionPreset.medium,
      enableAudio: false,
      streamingPreset: ResolutionPreset.high,
      androidUseOpenGL: true,
    );

    await controller.initialize();

    expect(log, <Matcher>[
      isMethodCall('initialize', arguments: <String, dynamic>{
        'cameraName': 'back-camera',
        'resolutionPreset': 'medium',
        'streamingPreset': 'high',
        'enableAudio': false,
        'enableAndroidOpenGL': true,
      }),
    ]);
  });

  test('takePicture sends textureId and path', () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    await controller.takePicture('/tmp/photo.jpg');

    expect(log, <Matcher>[
      isMethodCall('takePicture', arguments: <String, dynamic>{
        'textureId': _textureId,
        'path': '/tmp/photo.jpg',
      }),
    ]);
  });

  test('startImageStream sends no arguments', () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    await controller.startImageStream((CameraImage image) {});

    expect(log, <Matcher>[isMethodCall('startImageStream', arguments: null)]);
  });

  test('stopImageStream sends no arguments', () async {
    final CameraController controller = await _createInitializedController();
    await controller.startImageStream((CameraImage image) {});
    log.clear();

    await controller.stopImageStream();

    expect(log, <Matcher>[isMethodCall('stopImageStream', arguments: null)]);
  });

  test('getStreamStatistics sends no arguments', () async {
    final CameraController controller = await _createInitializedController();
    await controller.startVideoStreaming('rtmp://example.com');
    log.clear();

    await controller.getStreamStatistics();

    expect(log, <Matcher>[
      isMethodCall('getStreamStatistics', arguments: null),
    ]);
  });

  test('startVideoRecording sends textureId and filePath', () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    await controller.startVideoRecording('/tmp/video.mp4');

    expect(log, <Matcher>[
      isMethodCall('startVideoRecording', arguments: <String, dynamic>{
        'textureId': _textureId,
        'filePath': '/tmp/video.mp4',
      }),
    ]);
  });

  test('stopVideoRecording sends stopRecordingOrStreaming with textureId', () async {
    final CameraController controller = await _createInitializedController();
    await controller.startVideoRecording('/tmp/video.mp4');
    log.clear();

    await controller.stopVideoRecording();

    expect(log, <Matcher>[
      isMethodCall('stopRecordingOrStreaming', arguments: <String, dynamic>{
        'textureId': _textureId,
      }),
    ]);
  });

  test('pauseVideoRecording sends textureId', () async {
    final CameraController controller = await _createInitializedController();
    await controller.startVideoRecording('/tmp/video.mp4');
    log.clear();

    await controller.pauseVideoRecording();

    expect(log, <Matcher>[
      isMethodCall('pauseVideoRecording', arguments: <String, dynamic>{
        'textureId': _textureId,
      }),
    ]);
  });

  test('resumeVideoRecording sends textureId', () async {
    final CameraController controller = await _createInitializedController();
    await controller.startVideoRecording('/tmp/video.mp4');
    await controller.pauseVideoRecording();
    log.clear();

    await controller.resumeVideoRecording();

    expect(log, <Matcher>[
      isMethodCall('resumeVideoRecording', arguments: <String, dynamic>{
        'textureId': _textureId,
      }),
    ]);
  });

  test('startVideoStreaming sends textureId, url and bitrate', () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    await controller.startVideoStreaming('rtmp://example.com', bitrate: 500);

    expect(log, <Matcher>[
      isMethodCall('startVideoStreaming', arguments: <String, dynamic>{
        'textureId': _textureId,
        'url': 'rtmp://example.com',
        'bitrate': 500,
      }),
    ]);
  });

  test('startVideoRecordingAndStreaming sends textureId, url, filePath '
      'and bitrate', () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    await controller.startVideoRecordingAndStreaming(
      '/tmp/video.mp4',
      'rtmp://example.com',
      bitrate: 500,
    );

    expect(log, <Matcher>[
      isMethodCall(
        'startVideoRecordingAndStreaming',
        arguments: <String, dynamic>{
          'textureId': _textureId,
          'url': 'rtmp://example.com',
          'filePath': '/tmp/video.mp4',
          'bitrate': 500,
        },
      ),
    ]);
  });

  test('stopVideoStreaming sends stopRecordingOrStreaming with textureId', () async {
    final CameraController controller = await _createInitializedController();
    await controller.startVideoStreaming('rtmp://example.com');
    log.clear();

    await controller.stopVideoStreaming();

    expect(log, <Matcher>[
      isMethodCall('stopRecordingOrStreaming', arguments: <String, dynamic>{
        'textureId': _textureId,
      }),
    ]);
  });

  test('pauseVideoStreaming sends textureId', () async {
    final CameraController controller = await _createInitializedController();
    await controller.startVideoStreaming('rtmp://example.com');
    log.clear();

    await controller.pauseVideoStreaming();

    expect(log, <Matcher>[
      isMethodCall('pauseVideoStreaming', arguments: <String, dynamic>{
        'textureId': _textureId,
      }),
    ]);
  });

  test('resumeVideoStreaming sends textureId', () async {
    final CameraController controller = await _createInitializedController();
    await controller.startVideoStreaming('rtmp://example.com');
    await controller.pauseVideoStreaming();
    log.clear();

    await controller.resumeVideoStreaming();

    expect(log, <Matcher>[
      isMethodCall('resumeVideoStreaming', arguments: <String, dynamic>{
        'textureId': _textureId,
      }),
    ]);
  });

  test('stopEverything sends stopRecordingOrStreaming when recording', () async {
    final CameraController controller = await _createInitializedController();
    await controller.startVideoRecording('/tmp/video.mp4');
    log.clear();

    await controller.stopEverything();

    expect(log, <Matcher>[
      isMethodCall('stopRecordingOrStreaming', arguments: <String, dynamic>{
        'textureId': _textureId,
      }),
    ]);
  });

  test('stopEverything sends stopImageStream when streaming images', () async {
    final CameraController controller = await _createInitializedController();
    await controller.startImageStream((CameraImage image) {});
    log.clear();

    await controller.stopEverything();

    expect(log, <Matcher>[isMethodCall('stopImageStream', arguments: null)]);
  });

  test('dispose sends textureId', () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    await controller.dispose();

    expect(log, <Matcher>[
      isMethodCall('dispose', arguments: <String, dynamic>{
        'textureId': _textureId,
      }),
    ]);
  });
}
