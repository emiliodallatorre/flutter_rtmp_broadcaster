// Tests for [CameraController] members not covered elsewhere: zoom level
// getters/setter, flash/exposure/focus mode setters, the iOS-only "prepare"
// no-ops, [CameraController.takePictureXFile], and the translation of a
// native [PlatformException] into a [CameraException].
//
// See also:
//  * camera_controller_guard_clauses_test.dart, which covers the
//    preconditions checked before these channel calls are made.
//  * camera_channel_arguments_test.dart, which asserts the exact channel
//    calls made by the other CameraController methods.

import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtmp_broadcaster/rtmp_broadcaster.dart';

const MethodChannel _cameraChannel = MethodChannel(
  'plugins.flutter.io/rtmp_publisher',
);
const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

const int _textureId = 1;

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
        case 'getMaxZoomLevel':
          return 8.0;
        case 'getMinZoomLevel':
          return 1.0;
        default:
          return null;
      }
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (MethodCall call) async {
      switch (call.method) {
        case 'getTemporaryDirectory':
          return '/tmp';
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_cameraChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
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

    test('getMaxZoomLevel throws', () {
      expect(
        () => controller.getMaxZoomLevel(),
        throwsA(isA<CameraException>()),
      );
    });

    test('getMinZoomLevel throws', () {
      expect(
        () => controller.getMinZoomLevel(),
        throwsA(isA<CameraException>()),
      );
    });

    test('setZoomLevel throws', () {
      expect(
        () => controller.setZoomLevel(2),
        throwsA(isA<CameraException>()),
      );
    });

    test('setFlashMode throws', () {
      expect(
        () => controller.setFlashMode(FlashMode.always),
        throwsA(isA<CameraException>()),
      );
    });

    test('setExposureMode throws', () {
      expect(
        () => controller.setExposureMode(ExposureMode.locked),
        throwsA(isA<CameraException>()),
      );
    });

    test('setFocusMode throws', () {
      expect(
        () => controller.setFocusMode(FocusMode.locked),
        throwsA(isA<CameraException>()),
      );
    });
  });

  test('getMaxZoomLevel sends textureId and returns the native value',
      () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    final double maxZoomLevel = await controller.getMaxZoomLevel();

    expect(log, <Matcher>[
      isMethodCall('getMaxZoomLevel', arguments: <String, dynamic>{
        'textureId': _textureId,
      }),
    ]);
    expect(maxZoomLevel, 8.0);
  });

  test('getMinZoomLevel sends textureId and returns the native value',
      () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    final double minZoomLevel = await controller.getMinZoomLevel();

    expect(log, <Matcher>[
      isMethodCall('getMinZoomLevel', arguments: <String, dynamic>{
        'textureId': _textureId,
      }),
    ]);
    expect(minZoomLevel, 1.0);
  });

  test('setZoomLevel sends textureId and zoom', () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    await controller.setZoomLevel(2.5);

    expect(log, <Matcher>[
      isMethodCall('setZoomLevel', arguments: <String, dynamic>{
        'textureId': _textureId,
        'zoom': 2.5,
      }),
    ]);
  });

  test('setFlashMode sends textureId and serialized mode, updates value',
      () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    await controller.setFlashMode(FlashMode.torch);

    expect(log, <Matcher>[
      isMethodCall('setFlashMode', arguments: <String, dynamic>{
        'textureId': _textureId,
        'mode': 'torch',
      }),
    ]);
    expect(controller.value.flashMode, FlashMode.torch);
  });

  test('setExposureMode sends textureId and serialized mode, updates value',
      () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    await controller.setExposureMode(ExposureMode.locked);

    expect(log, <Matcher>[
      isMethodCall('setExposureMode', arguments: <String, dynamic>{
        'textureId': _textureId,
        'mode': 'locked',
      }),
    ]);
    expect(controller.value.exposureMode, ExposureMode.locked);
  });

  test('setFocusMode sends textureId and serialized mode, updates value',
      () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    await controller.setFocusMode(FocusMode.locked);

    expect(log, <Matcher>[
      isMethodCall('setFocusMode', arguments: <String, dynamic>{
        'textureId': _textureId,
        'mode': 'locked',
      }),
    ]);
    expect(controller.value.focusMode, FocusMode.locked);
  });

  test('prepareForVideoRecording sends no arguments', () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    await controller.prepareForVideoRecording();

    expect(log, <Matcher>[
      isMethodCall('prepareForVideoRecording', arguments: null),
    ]);
  });

  test('prepareForVideoStreaming sends no arguments', () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    await controller.prepareForVideoStreaming();

    expect(log, <Matcher>[
      isMethodCall('prepareForVideoStreaming', arguments: null),
    ]);
  });

  test('takePictureXFile saves to a temporary path and returns it', () async {
    final CameraController controller = await _createInitializedController();
    log.clear();

    final XFile file = await controller.takePictureXFile();

    expect(log, hasLength(1));
    expect(log.single.method, 'takePicture');
    expect(
      (log.single.arguments as Map<dynamic, dynamic>)['path'],
      file.path,
    );
    expect(file.path, startsWith('/tmp/'));
    expect(file.path, endsWith('.jpg'));
  });

  group('PlatformException translation', () {
    test('initialize rethrows as CameraException', () {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_cameraChannel, (MethodCall call) async {
        throw PlatformException(code: 'init_error', message: 'boom');
      });

      final CameraController controller = CameraController(
        CameraDescription(
          name: 'test',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 0,
        ),
        ResolutionPreset.low,
      );

      expect(controller.initialize(), throwsA(isA<CameraException>()));
    });

    test('setZoomLevel rethrows as CameraException', () async {
      final CameraController controller = await _createInitializedController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_cameraChannel, (MethodCall call) async {
        throw PlatformException(code: 'zoom_error', message: 'unsupported');
      });

      expect(
        controller.setZoomLevel(100),
        throwsA(isA<CameraException>()),
      );
    });

    test('takePicture rethrows as CameraException and resets isTakingPicture',
        () async {
      final CameraController controller = await _createInitializedController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_cameraChannel, (MethodCall call) async {
        throw PlatformException(code: 'capture_error', message: 'failed');
      });

      await expectLater(
        controller.takePicture('/tmp/photo.jpg'),
        throwsA(isA<CameraException>()),
      );
      expect(controller.value.isTakingPicture, isFalse);
    });
  });
}
