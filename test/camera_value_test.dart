// Tests for [CameraValue] and its [CameraValue.copyWith] method.
//
// copyWith has a notable asymmetry worth pinning down: most fields fall
// back to the current value when omitted (`x ?? this.x`), but
// `errorDescription` and `event` do not — omitting them always clears the
// value to null. Whether or not that's intentional, a test locks down the
// current behavior so it can't change silently during a refactor.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtmp_broadcaster/rtmp_broadcaster.dart';

void main() {
  group('CameraValue.uninitialized', () {
    test('has all flags false and a zero rotation', () {
      const CameraValue value = CameraValue.uninitialized();

      expect(value.isInitialized, isFalse);
      expect(value.isRecordingVideo, isFalse);
      expect(value.isTakingPicture, isFalse);
      expect(value.isStreamingImages, isFalse);
      expect(value.isStreamingVideoRtmp, isFalse);
      expect(value.isRecordingPaused, isFalse);
      expect(value.isStreamingPaused, isFalse);
      expect(value.previewQuarterTurns, 0);
      expect(value.event, isNull);
      expect(value.hasError, isFalse);
    });
  });

  group('CameraValue.hasError', () {
    test('is false when errorDescription is null', () {
      const CameraValue value = CameraValue.uninitialized();

      expect(value.hasError, isFalse);
    });

    test('is true when errorDescription is set', () {
      final CameraValue value = const CameraValue.uninitialized().copyWith(
        errorDescription: 'boom',
      );

      expect(value.hasError, isTrue);
    });
  });

  group('CameraValue.aspectRatio', () {
    test('divides preview height by preview width', () {
      final CameraValue value = const CameraValue.uninitialized().copyWith(
        previewSize: const Size(1920, 1080),
      );

      expect(value.aspectRatio, 1080 / 1920);
    });
  });

  group('CameraValue.isRecordingPaused', () {
    test('is true only when recording and paused', () {
      final CameraValue recordingAndPaused = const CameraValue.uninitialized()
          .copyWith(isRecordingVideo: true, isRecordingPaused: true);
      final CameraValue recordingNotPaused = const CameraValue.uninitialized()
          .copyWith(isRecordingVideo: true, isRecordingPaused: false);
      final CameraValue notRecording = const CameraValue.uninitialized()
          .copyWith(isRecordingVideo: false, isRecordingPaused: true);

      expect(recordingAndPaused.isRecordingPaused, isTrue);
      expect(recordingNotPaused.isRecordingPaused, isFalse);
      expect(notRecording.isRecordingPaused, isFalse);
    });
  });

  group('CameraValue.isStreamingPaused', () {
    test('is true only when streaming and paused', () {
      final CameraValue streamingAndPaused = const CameraValue.uninitialized()
          .copyWith(isStreamingVideoRtmp: true, isStreamingPaused: true);
      final CameraValue streamingNotPaused = const CameraValue.uninitialized()
          .copyWith(isStreamingVideoRtmp: true, isStreamingPaused: false);
      final CameraValue notStreaming = const CameraValue.uninitialized()
          .copyWith(isStreamingVideoRtmp: false, isStreamingPaused: true);

      expect(streamingAndPaused.isStreamingPaused, isTrue);
      expect(streamingNotPaused.isStreamingPaused, isFalse);
      expect(notStreaming.isStreamingPaused, isFalse);
    });
  });

  group('CameraValue.copyWith', () {
    test('keeps fields that fall back to the current value when omitted', () {
      final CameraValue initial = const CameraValue.uninitialized().copyWith(
        isInitialized: true,
        previewSize: const Size(1920, 1080),
        previewQuarterTurns: 1,
        isRecordingVideo: true,
        isStreamingVideoRtmp: true,
        isTakingPicture: true,
        isStreamingImages: true,
        isRecordingPaused: true,
        isStreamingPaused: true,
      );

      final CameraValue unchanged = initial.copyWith();

      expect(unchanged.isInitialized, initial.isInitialized);
      expect(unchanged.previewSize, initial.previewSize);
      expect(unchanged.previewQuarterTurns, initial.previewQuarterTurns);
      expect(unchanged.isRecordingVideo, initial.isRecordingVideo);
      expect(unchanged.isStreamingVideoRtmp, initial.isStreamingVideoRtmp);
      expect(unchanged.isTakingPicture, initial.isTakingPicture);
      expect(unchanged.isStreamingImages, initial.isStreamingImages);
      expect(unchanged.isRecordingPaused, initial.isRecordingPaused);
      expect(unchanged.isStreamingPaused, initial.isStreamingPaused);
    });

    test('overrides only the fields explicitly passed', () {
      final CameraValue initial = const CameraValue.uninitialized().copyWith(
        isInitialized: true,
        isRecordingVideo: true,
      );

      final CameraValue updated = initial.copyWith(isRecordingVideo: false);

      expect(updated.isInitialized, isTrue);
      expect(updated.isRecordingVideo, isFalse);
    });

    test('always clears errorDescription when omitted, unlike other fields', () {
      final CameraValue withError = const CameraValue.uninitialized().copyWith(
        errorDescription: 'boom',
      );

      final CameraValue afterUnrelatedUpdate = withError.copyWith(
        isRecordingVideo: true,
      );

      expect(withError.errorDescription, 'boom');
      expect(afterUnrelatedUpdate.errorDescription, isNull);
    });

    test('always clears event when omitted, unlike other fields', () {
      final CameraValue withEvent = const CameraValue.uninitialized().copyWith(
        event: <String, dynamic>{'eventType': 'rtmp_connected'},
      );

      final CameraValue afterUnrelatedUpdate = withEvent.copyWith(
        isRecordingVideo: true,
      );

      expect(withEvent.event, <String, dynamic>{'eventType': 'rtmp_connected'});
      expect(afterUnrelatedUpdate.event, isNull);
    });
  });

  group('CameraValue.toString', () {
    test('contains every field it reports', () {
      final CameraValue value = const CameraValue.uninitialized().copyWith(
        isInitialized: true,
        isRecordingVideo: true,
        isStreamingVideoRtmp: true,
        errorDescription: 'boom',
        previewSize: const Size(1920, 1080),
        previewQuarterTurns: 1,
        isStreamingImages: true,
      );

      expect(
        value.toString(),
        'CameraValue('
        'isRecordingVideo: true, '
        'isStreamingVideoRtmp: true, '
        'isInitialized: true, '
        'errorDescription: boom, '
        'previewSize: Size(1920.0, 1080.0), '
        'previewQuarterTurns: 1, '
        'isStreamingImages: true)',
      );
    });
  });
}
