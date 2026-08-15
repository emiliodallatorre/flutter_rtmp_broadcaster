// Tests for [CameraController]'s guard clauses: the preconditions each
// public method checks before invoking the platform channel.
//
// See also:
//  * camera_channel_arguments_test.dart, which asserts the exact channel
//    calls made once a guard clause passes.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtmp_broadcaster/camera.dart';

const MethodChannel _cameraChannel = MethodChannel(
  'plugins.flutter.io/rtmp_publisher',
);

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

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraChannel, (MethodCall call) async {
      switch (call.method) {
        case 'initialize':
          return <String, dynamic>{
            'textureId': 1,
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

  group('operations on an uninitialized controller', () {
    late CameraController controller;

    setUp(() {
      controller = CameraController(
        CameraDescription(
          name: 'test',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 0,
        ),
        ResolutionPreset.low,
      );
    });

    test('takePicture throws', () {
      expect(
        () => controller.takePicture('path'),
        throwsA(isA<CameraException>()),
      );
    });

    test('startImageStream throws', () {
      expect(
        () => controller.startImageStream((CameraImage image) {}),
        throwsA(isA<CameraException>()),
      );
    });

    test('stopImageStream throws', () {
      expect(
        () => controller.stopImageStream(),
        throwsA(isA<CameraException>()),
      );
    });

    test('getStreamStatistics throws', () {
      expect(
        () => controller.getStreamStatistics(),
        throwsA(isA<CameraException>()),
      );
    });

    test('startVideoRecording throws', () {
      expect(
        () => controller.startVideoRecording('path'),
        throwsA(isA<CameraException>()),
      );
    });

    test('stopVideoRecording throws', () {
      expect(
        () => controller.stopVideoRecording(),
        throwsA(isA<CameraException>()),
      );
    });

    test('pauseVideoRecording throws', () {
      expect(
        () => controller.pauseVideoRecording(),
        throwsA(isA<CameraException>()),
      );
    });

    test('resumeVideoRecording throws', () {
      expect(
        () => controller.resumeVideoRecording(),
        throwsA(isA<CameraException>()),
      );
    });

    test('startVideoStreaming throws', () {
      expect(
        () => controller.startVideoStreaming('rtmp://example.com'),
        throwsA(isA<CameraException>()),
      );
    });

    test('startVideoRecordingAndStreaming throws', () {
      expect(
        () => controller.startVideoRecordingAndStreaming(
          'path',
          'rtmp://example.com',
        ),
        throwsA(isA<CameraException>()),
      );
    });

    test('stopVideoStreaming throws', () {
      expect(
        () => controller.stopVideoStreaming(),
        throwsA(isA<CameraException>()),
      );
    });

    test('stopEverything throws', () {
      expect(
        () => controller.stopEverything(),
        throwsA(isA<CameraException>()),
      );
    });

    test('pauseVideoStreaming throws', () {
      expect(
        () => controller.pauseVideoStreaming(),
        throwsA(isA<CameraException>()),
      );
    });

    test('resumeVideoStreaming throws', () {
      expect(
        () => controller.resumeVideoStreaming(),
        throwsA(isA<CameraException>()),
      );
    });
  });

  group('takePicture', () {
    test('throws when a capture is already in flight', () async {
      final CameraController controller = await _createInitializedController();
      final Future<void> firstCapture = controller.takePicture('path1');

      expect(
        () => controller.takePicture('path2'),
        throwsA(isA<CameraException>()),
      );

      await firstCapture;
    });
  });

  group('startImageStream', () {
    test('throws while a video recording is in progress', () async {
      final CameraController controller = await _createInitializedController();
      await controller.startVideoRecording('path');

      expect(
        () => controller.startImageStream((CameraImage image) {}),
        throwsA(isA<CameraException>()),
      );
    });

    test('throws while streaming to RTMP', () async {
      final CameraController controller = await _createInitializedController();
      await controller.startVideoStreaming('rtmp://example.com');

      expect(
        () => controller.startImageStream((CameraImage image) {}),
        throwsA(isA<CameraException>()),
      );
    });

    test('throws when image streaming has already started', () async {
      final CameraController controller = await _createInitializedController();
      await controller.startImageStream((CameraImage image) {});

      expect(
        () => controller.startImageStream((CameraImage image) {}),
        throwsA(isA<CameraException>()),
      );
    });
  });

  group('stopImageStream', () {
    test('throws when image streaming was never started', () async {
      final CameraController controller = await _createInitializedController();

      expect(
        () => controller.stopImageStream(),
        throwsA(isA<CameraException>()),
      );
    });
  });

  group('getStreamStatistics', () {
    test('throws when not streaming to RTMP', () async {
      final CameraController controller = await _createInitializedController();

      expect(
        () => controller.getStreamStatistics(),
        throwsA(isA<CameraException>()),
      );
    });
  });

  group('startVideoRecording', () {
    test('throws when a recording is already started', () async {
      final CameraController controller = await _createInitializedController();
      await controller.startVideoRecording('path');

      expect(
        () => controller.startVideoRecording('path2'),
        throwsA(isA<CameraException>()),
      );
    });

    test('throws while image streaming is in progress', () async {
      final CameraController controller = await _createInitializedController();
      await controller.startImageStream((CameraImage image) {});

      expect(
        () => controller.startVideoRecording('path'),
        throwsA(isA<CameraException>()),
      );
    });
  });

  group('stopVideoRecording', () {
    test('throws when no recording is in progress', () async {
      final CameraController controller = await _createInitializedController();

      expect(
        () => controller.stopVideoRecording(),
        throwsA(isA<CameraException>()),
      );
    });
  });

  group('pauseVideoRecording', () {
    test('throws when no recording is in progress', () async {
      final CameraController controller = await _createInitializedController();

      expect(
        () => controller.pauseVideoRecording(),
        throwsA(isA<CameraException>()),
      );
    });
  });

  group('resumeVideoRecording', () {
    test('throws when no recording is in progress', () async {
      final CameraController controller = await _createInitializedController();

      expect(
        () => controller.resumeVideoRecording(),
        throwsA(isA<CameraException>()),
      );
    });
  });

  group('startVideoStreaming', () {
    test('throws when a recording is already started', () async {
      final CameraController controller = await _createInitializedController();
      await controller.startVideoRecording('path');

      expect(
        () => controller.startVideoStreaming('rtmp://example.com'),
        throwsA(isA<CameraException>()),
      );
    });

    test('throws when streaming is already started', () async {
      final CameraController controller = await _createInitializedController();
      await controller.startVideoStreaming('rtmp://example.com');

      expect(
        () => controller.startVideoStreaming('rtmp://example.com'),
        throwsA(isA<CameraException>()),
      );
    });

    test('throws while image streaming is in progress', () async {
      final CameraController controller = await _createInitializedController();
      await controller.startImageStream((CameraImage image) {});

      expect(
        () => controller.startVideoStreaming('rtmp://example.com'),
        throwsA(isA<CameraException>()),
      );
    });
  });

  group('startVideoRecordingAndStreaming', () {
    test('throws when a recording is already started', () async {
      final CameraController controller = await _createInitializedController();
      await controller.startVideoRecording('path');

      expect(
        () => controller.startVideoRecordingAndStreaming(
          'path2',
          'rtmp://example.com',
        ),
        throwsA(isA<CameraException>()),
      );
    });

    test('throws when streaming is already started', () async {
      final CameraController controller = await _createInitializedController();
      await controller.startVideoStreaming('rtmp://example.com');

      expect(
        () => controller.startVideoRecordingAndStreaming(
          'path',
          'rtmp://example.com',
        ),
        throwsA(isA<CameraException>()),
      );
    });

    test('throws while image streaming is in progress', () async {
      final CameraController controller = await _createInitializedController();
      await controller.startImageStream((CameraImage image) {});

      expect(
        () => controller.startVideoRecordingAndStreaming(
          'path',
          'rtmp://example.com',
        ),
        throwsA(isA<CameraException>()),
      );
    });
  });

  group('stopVideoStreaming', () {
    test('throws when not streaming to RTMP', () async {
      final CameraController controller = await _createInitializedController();

      expect(
        () => controller.stopVideoStreaming(),
        throwsA(isA<CameraException>()),
      );
    });
  });

  group('pauseVideoStreaming', () {
    test('throws when not streaming to RTMP', () async {
      final CameraController controller = await _createInitializedController();

      expect(
        () => controller.pauseVideoStreaming(),
        throwsA(isA<CameraException>()),
      );
    });
  });

  group('resumeVideoStreaming', () {
    test('throws when not streaming to RTMP', () async {
      final CameraController controller = await _createInitializedController();

      expect(
        () => controller.resumeVideoStreaming(),
        throwsA(isA<CameraException>()),
      );
    });
  });
}
