// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// The row of controls used to take pictures, record video, start/stop
/// streaming, and pause/resume/stop the active recording or stream.
class CaptureControlRow extends StatelessWidget {
  const CaptureControlRow({
    super.key,
    required this.isControllerInitialized,
    required this.isRecordingVideo,
    required this.isStreamingVideoRtmp,
    required this.isRecordingOrStreamingPaused,
    required this.onTakePicture,
    required this.onRecordVideo,
    required this.onStartStreaming,
    required this.onPauseOrResume,
    required this.onStop,
  });

  final bool isControllerInitialized;
  final bool isRecordingVideo;
  final bool isStreamingVideoRtmp;
  final bool isRecordingOrStreamingPaused;
  final VoidCallback? onTakePicture;
  final VoidCallback? onRecordVideo;
  final VoidCallback? onStartStreaming;
  final VoidCallback? onPauseOrResume;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final bool isRecordingOrStreaming =
        isRecordingVideo || isStreamingVideoRtmp;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.camera_alt),
          color: Colors.blue,
          onPressed: isControllerInitialized ? onTakePicture : null,
        ),
        IconButton(
          icon: const Icon(Icons.videocam),
          color: Colors.blue,
          onPressed: isControllerInitialized && !isRecordingVideo
              ? onRecordVideo
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          color: Colors.blue,
          onPressed: isControllerInitialized && !isStreamingVideoRtmp
              ? onStartStreaming
              : null,
        ),
        IconButton(
          icon: Icon(
            isRecordingOrStreamingPaused ? Icons.play_arrow : Icons.pause,
          ),
          color: Colors.blue,
          onPressed: isControllerInitialized && isRecordingOrStreaming
              ? onPauseOrResume
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.stop),
          color: Colors.red,
          onPressed:
              isControllerInitialized && isRecordingOrStreaming ? onStop : null,
        ),
      ],
    );
  }
}
