// Tests for the plain value types in lib/src/types.dart: the enum
// serializers, CameraDescription equality/toString, StreamStatistics and
// CameraException.

import 'package:flutter_test/flutter_test.dart';
import 'package:rtmp_broadcaster/rtmp_broadcaster.dart';

void main() {
  group('serializeFlashMode', () {
    test('returns the expected wire string for each value', () {
      expect(serializeFlashMode(FlashMode.off), 'off');
      expect(serializeFlashMode(FlashMode.auto), 'auto');
      expect(serializeFlashMode(FlashMode.always), 'always');
      expect(serializeFlashMode(FlashMode.torch), 'torch');
    });
  });

  group('serializeExposureMode', () {
    test('returns the expected wire string for each value', () {
      expect(serializeExposureMode(ExposureMode.auto), 'auto');
      expect(serializeExposureMode(ExposureMode.locked), 'locked');
    });
  });

  group('serializeFocusMode', () {
    test('returns the expected wire string for each value', () {
      expect(serializeFocusMode(FocusMode.auto), 'auto');
      expect(serializeFocusMode(FocusMode.locked), 'locked');
    });
  });

  group('serializeResolutionPreset', () {
    test('returns the expected wire string for each value', () {
      expect(serializeResolutionPreset(ResolutionPreset.low), 'low');
      expect(serializeResolutionPreset(ResolutionPreset.medium), 'medium');
      expect(serializeResolutionPreset(ResolutionPreset.high), 'high');
      expect(serializeResolutionPreset(ResolutionPreset.veryHigh), 'veryHigh');
      expect(serializeResolutionPreset(ResolutionPreset.ultraHigh), 'ultraHigh');
      expect(serializeResolutionPreset(ResolutionPreset.max), 'max');
    });
  });

  group('CameraDescription', () {
    test('two descriptions with the same name and lensDirection are equal', () {
      final CameraDescription a = CameraDescription(
        name: 'back',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 0,
      );
      final CameraDescription b = CameraDescription(
        name: 'back',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      );

      expect(a, equals(b));
    });

    test('descriptions with a different name or lensDirection are not equal', () {
      final CameraDescription back = CameraDescription(
        name: 'back',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 0,
      );
      final CameraDescription front = CameraDescription(
        name: 'front',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 0,
      );

      expect(back, isNot(equals(front)));
    });

    test('toString contains name, lensDirection and sensorOrientation', () {
      final CameraDescription description = CameraDescription(
        name: 'back',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      );

      expect(
        description.toString(),
        'CameraDescription(back, CameraLensDirection.back, 90)',
      );
    });
  });

  group('StreamStatistics', () {
    test('toString contains every field', () {
      final StreamStatistics stats = StreamStatistics(
        cacheSize: 1,
        sentAudioFrames: 2,
        sentVideoFrames: 3,
        droppedAudioFrames: 4,
        droppedVideoFrames: 5,
        bitrate: 6,
        width: 7,
        height: 8,
        isAudioMuted: true,
      );

      expect(
        stats.toString(),
        'StreamStatistics{cacheSize: 1, sentAudioFrames: 2, '
        'sentVideoFrames: 3, droppedAudioFrames: 4, droppedVideoFrames: 5, '
        'isAudioMuted: true, bitrate: 6, width: 7, height: 8}',
      );
    });
  });

  group('CameraException', () {
    test('toString contains the code and description', () {
      final CameraException exception = CameraException('code', 'description');

      expect(exception.toString(), 'CameraException(code, description)');
    });
  });
}
