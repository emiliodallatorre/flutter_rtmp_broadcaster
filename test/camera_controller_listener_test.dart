// Tests for [CameraController]'s handling of native camera events
// (CameraController._listener), which is otherwise untested. Native camera
// events arrive with slightly different shapes on Android (`eventType` key)
// and iOS (`event` key), so each case is exercised with both shapes.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtmp_broadcaster/rtmp_broadcaster.dart';

const int _textureId = 7;
const MethodChannel _cameraChannel = MethodChannel(
  'plugins.flutter.io/rtmp_publisher',
);
final EventChannel _eventChannel = EventChannel(
  'plugins.flutter.io/rtmp_publisher/cameraEvents$_textureId',
);

/// Creates an initialized [CameraController] whose event channel emits
/// exactly the given [events], one after another, once listened to.
Future<CameraController> _createControllerReceivingEvents(
  List<Map<String, dynamic>> events,
) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_cameraChannel, (MethodCall call) async {
    if (call.method == 'initialize') {
      return <String, dynamic>{
        'textureId': _textureId,
        'previewWidth': 1920.0,
        'previewHeight': 1080.0,
        'previewQuarterTurns': 0,
      };
    }
    return null;
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockStreamHandler(
    _eventChannel,
    MockStreamHandler.inline(
      onListen: (Object? arguments, MockStreamHandlerEventSink events0) {
        for (final Map<String, dynamic> event in events) {
          events0.success(event);
        }
      },
    ),
  );

  final CameraController controller = CameraController(
    CameraDescription(
      name: 'test',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 0,
    ),
    ResolutionPreset.low,
  );
  await controller.initialize();
  await pumpEventQueue();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(_eventChannel, null);
  });

  group('error event', () {
    test('sets errorDescription (Android shape)', () async {
      final CameraController controller = await _createControllerReceivingEvents(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'eventType': 'error',
            'errorDescription': 'boom',
          },
        ],
      );

      expect(controller.value.errorDescription, 'boom');
      expect(controller.value.hasError, isTrue);
    });

    test('sets errorDescription (iOS shape)', () async {
      final CameraController controller = await _createControllerReceivingEvents(
        <Map<String, dynamic>>[
          <String, dynamic>{'event': 'error', 'errorDescription': 'boom'},
        ],
      );

      expect(controller.value.errorDescription, 'boom');
      expect(controller.value.hasError, isTrue);
    });
  });

  group('camera_closing event', () {
    test('clears isRecordingVideo and isStreamingVideoRtmp', () async {
      final CameraController controller = await _createControllerReceivingEvents(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'eventType': 'camera_closing',
            'errorDescription': null,
          },
        ],
      );

      expect(controller.value.isRecordingVideo, isFalse);
      expect(controller.value.isStreamingVideoRtmp, isFalse);
    });
  });

  group('rtmp_connected event', () {
    test('records the event without changing streaming flags', () async {
      final CameraController controller = await _createControllerReceivingEvents(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'eventType': 'rtmp_connected',
            'errorDescription': null,
          },
        ],
      );

      expect(controller.value.event, <String, dynamic>{
        'eventType': 'rtmp_connected',
        'errorDescription': null,
      });
      expect(controller.value.isStreamingVideoRtmp, isFalse);
    });
  });

  group('rtmp_retry event', () {
    test('records the event without changing streaming flags', () async {
      final CameraController controller = await _createControllerReceivingEvents(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'eventType': 'rtmp_retry',
            'errorDescription': 'BadName received',
          },
        ],
      );

      expect(controller.value.event, <String, dynamic>{
        'eventType': 'rtmp_retry',
        'errorDescription': 'BadName received',
      });
      expect(controller.value.isStreamingVideoRtmp, isFalse);
    });
  });

  group('rtmp_stopped event', () {
    test('clears isStreamingVideoRtmp', () async {
      final CameraController controller = await _createControllerReceivingEvents(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'eventType': 'rtmp_stopped',
            'errorDescription': null,
          },
        ],
      );

      expect(controller.value.isStreamingVideoRtmp, isFalse);
    });
  });

  group('rotation_update event', () {
    test('parses errorDescription as the new previewQuarterTurns', () async {
      final CameraController controller = await _createControllerReceivingEvents(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'eventType': 'rotation_update',
            'errorDescription': '2',
          },
        ],
      );

      expect(controller.value.previewQuarterTurns, 2);
    });
  });

  group('unrecognized event type', () {
    test('records the raw event without changing known flags', () async {
      final CameraController controller = await _createControllerReceivingEvents(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'eventType': 'something_new',
            'errorDescription': null,
          },
        ],
      );

      expect(controller.value.event, <String, dynamic>{
        'eventType': 'something_new',
        'errorDescription': null,
      });
      expect(controller.value.hasError, isFalse);
    });
  });

  group('multiple events', () {
    test('are applied in order', () async {
      final CameraController controller = await _createControllerReceivingEvents(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'eventType': 'rtmp_connected',
            'errorDescription': null,
          },
          <String, dynamic>{
            'eventType': 'rtmp_stopped',
            'errorDescription': null,
          },
        ],
      );

      expect(controller.value.event, <String, dynamic>{
        'eventType': 'rtmp_stopped',
        'errorDescription': null,
      });
      expect(controller.value.isStreamingVideoRtmp, isFalse);
    });
  });
}
