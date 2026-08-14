// Tests for [CameraImage] and its helpers (Plane, ImageFormat,
// ImageFormatGroup), mirroring the coverage the upstream camera package
// has for its equivalent classes.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtmp_broadcaster/camera.dart';

Map<dynamic, dynamic> _rawImage({required dynamic format}) {
  return <dynamic, dynamic>{
    'format': format,
    'height': 1,
    'width': 4,
    'planes': <dynamic>[
      <dynamic, dynamic>{
        'bytes': Uint8List.fromList(<int>[1, 2, 3, 4]),
        'bytesPerPixel': 1,
        'bytesPerRow': 4,
        'height': 1,
        'width': 4,
      },
    ],
  };
}

void main() {
  test('CameraImage.fromPlatformData translates height, width and planes', () {
    final CameraImage image = CameraImage.fromPlatformData(_rawImage(format: null));

    expect(image.height, 1);
    expect(image.width, 4);
    expect(image.planes.length, 1);
    expect(image.planes.single.bytes, Uint8List.fromList(<int>[1, 2, 3, 4]));
    expect(image.planes.single.bytesPerPixel, 1);
    expect(image.planes.single.bytesPerRow, 4);
    expect(image.planes.single.height, 1);
    expect(image.planes.single.width, 4);
  });

  group('ImageFormatGroup detection', () {
    test('is yuv420 for Android YUV_420_888', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final CameraImage image = CameraImage.fromPlatformData(_rawImage(format: 35));

      expect(image.format.group, ImageFormatGroup.yuv420);
      expect(image.format.raw, 35);

      debugDefaultTargetPlatformOverride = null;
    });

    test('is unknown for an unrecognized Android format', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final CameraImage image = CameraImage.fromPlatformData(_rawImage(format: 17));

      expect(image.format.group, ImageFormatGroup.unknown);

      debugDefaultTargetPlatformOverride = null;
    });

    test('is yuv420 for iOS kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final CameraImage image = CameraImage.fromPlatformData(_rawImage(format: 875704438));

      expect(image.format.group, ImageFormatGroup.yuv420);

      debugDefaultTargetPlatformOverride = null;
    });

    test('is bgra8888 for iOS kCVPixelFormatType_32BGRA', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final CameraImage image = CameraImage.fromPlatformData(_rawImage(format: 1111970369));

      expect(image.format.group, ImageFormatGroup.bgra8888);

      debugDefaultTargetPlatformOverride = null;
    });

    test('is unknown when running on a platform other than Android or iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final CameraImage image = CameraImage.fromPlatformData(_rawImage(format: 35));

      expect(image.format.group, ImageFormatGroup.unknown);

      debugDefaultTargetPlatformOverride = null;
    });
  });
}
