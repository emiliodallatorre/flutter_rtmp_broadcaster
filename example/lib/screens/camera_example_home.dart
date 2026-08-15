// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rtmp_broadcaster/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../utils/camera_utils.dart';
import '../widgets/audio_toggle_switch.dart';
import '../widgets/camera_preview_display.dart';
import '../widgets/camera_toggles_row.dart';
import '../widgets/capture_control_row.dart';
import '../widgets/capture_thumbnail.dart';
import '../widgets/stream_url_dialog.dart';

/// The example app's home screen: shows a live camera preview together
/// with controls to take pictures, record video, and stream over RTMP.
class CameraExampleHome extends StatefulWidget {
  const CameraExampleHome({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<CameraExampleHome> createState() => _CameraExampleHomeState();
}

class _CameraExampleHomeState extends State<CameraExampleHome>
    with WidgetsBindingObserver {
  CameraController? controller;
  String? imagePath;
  String? videoPath;
  String? url;
  VideoPlayerController? videoController;
  VoidCallback? videoPlayerListener;
  bool enableAudio = true;
  bool useOpenGL = true;
  bool isVisible = true;
  final TextEditingController _urlController = TextEditingController(
    text: 'rtmp://192.168.68.116/live/your_stream',
  );

  bool get isControllerInitialized => controller?.value.isInitialized ?? false;
  bool get isStreamingVideoRtmp =>
      controller?.value.isStreamingVideoRtmp ?? false;
  bool get isRecordingVideo => controller?.value.isRecordingVideo ?? false;
  bool get isRecordingPaused => controller?.value.isRecordingPaused ?? false;
  bool get isStreamingPaused => controller?.value.isStreamingPaused ?? false;
  bool get isTakingPicture => controller?.value.isTakingPicture ?? false;
  bool get isStreaming => isStreamingVideoRtmp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    final CameraController? controller = this.controller;
    // App state changed before we got the chance to initialize.
    if (controller == null || !isControllerInitialized) {
      return;
    }
    if (state == AppLifecycleState.paused) {
      isVisible = false;
      if (isStreaming) {
        await pauseVideoStreaming();
      }
    } else if (state == AppLifecycleState.resumed) {
      isVisible = true;
      if (isStreaming) {
        await resumeVideoStreaming();
      } else {
        await onNewCameraSelected(controller.description);
      }
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;

    if (isRecordingVideo) {
      color = Colors.redAccent;
    } else if (isStreamingVideoRtmp) {
      color = Colors.blueAccent;
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Camera example'),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(
                    color: color,
                    width: 3.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: Center(
                    child: CameraPreviewDisplay(controller: controller),
                  ),
                ),
              ),
            ),
            CaptureControlRow(
              isControllerInitialized: isControllerInitialized,
              isRecordingVideo: isRecordingVideo,
              isStreamingVideoRtmp: isStreamingVideoRtmp,
              isRecordingOrStreamingPaused:
                  isRecordingPaused || isStreamingPaused,
              onTakePicture: onTakePictureButtonPressed,
              onRecordVideo: onVideoRecordButtonPressed,
              onStartStreaming: onVideoStreamingButtonPressed,
              onPauseOrResume: isRecordingPaused || isStreamingPaused
                  ? onResumeButtonPressed
                  : onPauseButtonPressed,
              onStop: onStopButtonPressed,
            ),
            AudioToggleSwitch(
              enabled: enableAudio,
              onChanged: (bool value) {
                enableAudio = value;
                final CameraController? controller = this.controller;
                if (controller != null) {
                  onNewCameraSelected(controller.description);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.all(5.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  CameraTogglesRow(
                    cameras: widget.cameras,
                    selectedCamera: controller?.description,
                    isRecordingVideo: isRecordingVideo,
                    onChanged: (CameraDescription? description) {
                      if (!isRecordingVideo) {
                        onNewCameraSelected(description);
                      }
                    },
                  ),
                  CaptureThumbnail(
                    imagePath: imagePath,
                    videoController: videoController,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> onNewCameraSelected(CameraDescription? cameraDescription) async {
    if (cameraDescription == null) return;

    final CameraController? previousController = controller;
    if (previousController != null) {
      await stopVideoStreaming();
      await previousController.dispose();
    }

    final CameraController newController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: enableAudio,
      androidUseOpenGL: useOpenGL,
    );
    controller = newController;

    // If the controller is updated then update the UI.
    newController.addListener(() async {
      if (mounted) setState(() {});

      if (newController.value.hasError) {
        showInSnackBar('Camera error ${newController.value.errorDescription}');
        await stopVideoStreaming();
      } else {
        try {
          final Map<dynamic, dynamic> event =
              newController.value.event as Map<dynamic, dynamic>;
          debugPrint('Event $event');
          final String eventType = event['eventType'] as String;
          if (isVisible && isStreaming && eventType == 'rtmp_retry') {
            showInSnackBar('BadName received, endpoint in use.');
            await stopVideoStreaming();
          }
        } catch (e) {
          debugPrint('$e');
        }
      }
    });

    try {
      await newController.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void onTakePictureButtonPressed() {
    takePicture().then((String? filePath) {
      if (mounted) {
        setState(() {
          imagePath = filePath;
          videoController?.dispose();
          videoController = null;
        });
        showInSnackBar('Picture saved to $filePath');
      }
    });
  }

  void onVideoRecordButtonPressed() {
    startVideoRecording().then((String? filePath) {
      if (mounted) setState(() {});
      showInSnackBar('Saving video to $filePath');
      WakelockPlus.enable();
    });
  }

  void onVideoStreamingButtonPressed() {
    startVideoStreaming().then((String? url) {
      if (mounted) setState(() {});
      showInSnackBar('Streaming video to $url');
      WakelockPlus.enable();
    });
  }

  void onRecordingAndVideoStreamingButtonPressed() {
    startRecordingAndVideoStreaming().then((String? url) {
      if (mounted) setState(() {});
      showInSnackBar('Recording streaming video to $url');
      WakelockPlus.enable();
    });
  }

  void onStopButtonPressed() {
    if (isStreamingVideoRtmp) {
      stopVideoStreaming().then((_) {
        if (mounted) setState(() {});
        showInSnackBar('Video streamed to: $url');
      });
    } else {
      stopVideoRecording().then((_) {
        if (mounted) setState(() {});
        showInSnackBar('Video recorded to: $videoPath');
      });
    }
    WakelockPlus.disable();
  }

  void onPauseButtonPressed() {
    pauseVideoRecording().then((_) {
      if (mounted) setState(() {});
      showInSnackBar('Video recording paused');
    });
  }

  void onResumeButtonPressed() {
    resumeVideoRecording().then((_) {
      if (mounted) setState(() {});
      showInSnackBar('Video recording resumed');
    });
  }

  void onStopStreamingButtonPressed() {
    stopVideoStreaming().then((_) {
      if (mounted) setState(() {});
      showInSnackBar('Video not streaming to: $url');
    });
  }

  void onPauseStreamingButtonPressed() {
    pauseVideoStreaming().then((_) {
      if (mounted) setState(() {});
      showInSnackBar('Video streaming paused');
    });
  }

  void onResumeStreamingButtonPressed() {
    resumeVideoStreaming().then((_) {
      if (mounted) setState(() {});
      showInSnackBar('Video streaming resumed');
    });
  }

  Future<String?> startVideoRecording() async {
    final CameraController? controller = this.controller;
    if (controller == null || !isControllerInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    if (isRecordingVideo) {
      // A recording is already started, do nothing.
      return null;
    }

    final Directory? extDir = await getExternalStorageDirectory();
    if (extDir == null) return null;

    final String dirPath = '${extDir.path}/Movies/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${generateTimestamp()}.mp4';

    try {
      videoPath = filePath;
      await controller.startVideoRecording(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  Future<void> stopVideoRecording() async {
    final CameraController? controller = this.controller;
    if (controller == null || !isRecordingVideo) {
      return;
    }

    try {
      await controller.stopVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return;
    }

    await _startVideoPlayer();
  }

  Future<void> pauseVideoRecording() async {
    final CameraController? controller = this.controller;
    if (controller == null) return;

    try {
      if (isRecordingVideo) {
        await controller.pauseVideoRecording();
      }
      if (isStreamingVideoRtmp) {
        await controller.pauseVideoStreaming();
      }
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    } catch (e) {
      debugPrint('$e');
    }
  }

  Future<void> resumeVideoRecording() async {
    final CameraController? controller = this.controller;
    if (controller == null) return;

    try {
      if (isRecordingVideo) {
        await controller.resumeVideoRecording();
      }
      if (isStreamingVideoRtmp) {
        await controller.resumeVideoStreaming();
      }
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    } catch (e) {
      debugPrint('$e');
    }
  }

  Future<String?> startRecordingAndVideoStreaming() async {
    final CameraController? controller = this.controller;
    if (controller == null || !isControllerInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    if (isStreamingVideoRtmp) {
      return null;
    }

    final String? myUrl = await showStreamUrlDialog(context, _urlController);
    if (myUrl == null) return null;

    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Movies/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${generateTimestamp()}.mp4';

    try {
      url = myUrl;
      videoPath = filePath;
      await controller.startVideoRecordingAndStreaming(videoPath!, url!);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return url;
  }

  Future<String?> startVideoStreaming() async {
    await stopVideoStreaming();
    final CameraController? controller = this.controller;
    if (controller == null || !isControllerInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    if (isStreamingVideoRtmp) {
      return null;
    }

    final String? myUrl = await showStreamUrlDialog(context, _urlController);
    if (myUrl == null) return null;

    try {
      url = myUrl;
      await controller.startVideoStreaming(myUrl);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return url;
  }

  Future<void> stopVideoStreaming() async {
    final CameraController? controller = this.controller;
    if (controller == null || !isControllerInitialized || !isStreamingVideoRtmp) {
      return;
    }

    try {
      await controller.stopVideoStreaming();
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  Future<void> pauseVideoStreaming() async {
    final CameraController? controller = this.controller;
    if (controller == null || !isStreamingVideoRtmp) {
      return;
    }

    try {
      await controller.pauseVideoStreaming();
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> resumeVideoStreaming() async {
    final CameraController? controller = this.controller;
    if (controller == null || !isStreamingVideoRtmp) {
      return;
    }

    try {
      await controller.resumeVideoStreaming();
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> _startVideoPlayer() async {
    final String? videoPath = this.videoPath;
    if (videoPath == null) return;

    final VideoPlayerController newController =
        VideoPlayerController.file(File(videoPath));
    void listener() {
      final VideoPlayerController? videoController = this.videoController;
      if (videoController != null) {
        // Refreshing the state to update video player with the correct ratio.
        if (mounted) setState(() {});
        videoController.removeListener(listener);
      }
    }

    videoPlayerListener = listener;
    newController.addListener(listener);
    await newController.setLooping(true);
    await newController.initialize();
    await videoController?.dispose();
    if (mounted) {
      setState(() {
        imagePath = null;
        videoController = newController;
      });
    }
    await newController.play();
  }

  Future<String?> takePicture() async {
    final CameraController? controller = this.controller;
    if (controller == null || !isControllerInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    if (isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    final Directory? extDir = await getExternalStorageDirectory();
    final String dirPath = '${extDir?.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${generateTimestamp()}.jpg';

    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description ?? 'No description found');
    showInSnackBar(
      'Error: ${e.code}\n${e.description ?? "No description found"}',
    );
  }
}
