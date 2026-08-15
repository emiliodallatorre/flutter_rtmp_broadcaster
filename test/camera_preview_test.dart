// Tests for the [CameraPreview] widget: it should show a Texture (or
// AndroidView, on Android) sized according to the controller's preview,
// rotated via [CameraValue.previewQuarterTurns] when the preview is in
// portrait orientation.
//
// A fake CameraController is used instead of a real, channel-backed one so
// these tests don't need to drive initialize()/dispose() through mocked
// platform channels.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtmp_broadcaster/rtmp_broadcaster.dart';

const int _textureId = 1;
const MethodChannel _cameraChannel = MethodChannel(
  'plugins.flutter.io/rtmp_publisher',
);
final EventChannel _eventChannel = EventChannel(
  'plugins.flutter.io/rtmp_publisher/cameraEvents$_textureId',
);

/// Creates a controller with a real (mocked) textureId, for exercising
/// [CameraController.buildPreview] directly. Deliberately not disposed —
/// disposing a real, channel-backed controller inside a `test()` created
/// alongside `testWidgets()` cases in the same file has been observed to
/// hang the test runner's teardown.
Future<CameraController> _initializedController() async {
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
    MockStreamHandler.inline(onListen: (Object? arguments, MockStreamHandlerEventSink events) {}),
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
  return controller;
}

class _FakeCameraController extends CameraController {
  _FakeCameraController()
      : super(
          CameraDescription(
            name: 'test',
            lensDirection: CameraLensDirection.back,
            sensorOrientation: 0,
          ),
          ResolutionPreset.low,
        );

  @override
  Widget buildPreview() => const Placeholder();
}

void main() {
  testWidgets('shows an empty Container before the controller is initialized', (
    WidgetTester tester,
  ) async {
    final CameraController controller = _FakeCameraController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(CameraPreview(controller));

    expect(find.byType(Placeholder), findsNothing);
    expect(find.byType(Container), findsOneWidget);
  });

  testWidgets('wraps the preview in a RotatedBox when the preview is portrait', (
    WidgetTester tester,
  ) async {
    final CameraController controller = _FakeCameraController();
    addTearDown(controller.dispose);
    controller.value = controller.value.copyWith(
      isInitialized: true,
      previewSize: const Size(1080, 1920),
      previewQuarterTurns: 3,
    );

    await tester.pumpWidget(CameraPreview(controller));

    expect(find.byType(RotatedBox), findsOneWidget);
    final RotatedBox rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox));
    expect(rotatedBox.quarterTurns, 3);
  });

  testWidgets('does not wrap the preview in a RotatedBox when the preview is landscape', (
    WidgetTester tester,
  ) async {
    final CameraController controller = _FakeCameraController();
    addTearDown(controller.dispose);
    controller.value = controller.value.copyWith(
      isInitialized: true,
      previewSize: const Size(1920, 1080),
      previewQuarterTurns: 0,
    );

    await tester.pumpWidget(CameraPreview(controller));

    expect(find.byType(RotatedBox), findsNothing);
    expect(find.byType(Placeholder), findsOneWidget);
  });

  testWidgets('CameraController.buildPreview shows a Texture', (WidgetTester tester) async {
    // buildPreview() branches on dart:io's Platform.isAndroid, which
    // reflects the actual host OS rather than debugDefaultTargetPlatformOverride,
    // so only the non-Android (Texture) branch is exercisable here; this
    // also matches the test/CI environment, which never runs on real Android.
    final CameraController controller = await _initializedController();

    final Widget preview = controller.buildPreview();

    expect(preview, isA<Texture>());
  });
}
