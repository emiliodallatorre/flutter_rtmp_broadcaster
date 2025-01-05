
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rtmp_broadcaster/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class CameraExampleHome extends StatefulWidget {
  @override
  _CameraExampleHomeState createState() {
    return _CameraExampleHomeState();
  }
}

/// Returns a suitable camera icon for [direction].
IconData getCameraLensIcon(CameraLensDirection? direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
    default:
      return Icons.camera;
  }
}

void logError(String code, String message) =>
    print('Error: $code\nError Message: $message');

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

  TextEditingController _textFieldController = TextEditingController(
      text: "rtmp://198.7.123.229:1935/live/bH627zFoWCC1gJVI");

  bool get isStreaming => controller?.value.isStreamingVideoRtmp ?? false;
  bool isVisible = true;
  bool get isControllerInitialized => controller?.value.isInitialized ?? false;
  bool get isStreamingVideoRtmp =>
      controller?.value.isStreamingVideoRtmp ?? false;
  bool get isRecordingVideo => controller?.value.isRecordingVideo ?? false;
  bool get isRecordingPaused => controller?.value.isRecordingPaused ?? false;
  bool get isStreamingPaused => controller?.value.isStreamingPaused ?? false;
  bool get isTakingPicture => controller?.value.isTakingPicture ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
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
      if (controller != null) {
        if (isStreaming) {
          await resumeVideoStreaming();
        } else {
          onNewCameraSelected(controller!.description);
        }
      }
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    if (controller != null) {
      if (controller!.value.isRecordingVideo ?? false) {
        color = Colors.redAccent;
      } else if (controller!.value.isStreamingVideoRtmp ?? false) {
        color = Colors.blueAccent;
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Camera example'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              child: Padding(
                padding: const EdgeInsets.all(1.0),
                child: Center(
                  child: _cameraPreviewWidget(),
                ),
              ),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(
                  color: color,
                  width: 3.0,
                ),
              ),
            ),
          ),
          _captureControlRowWidget(),
          _toggleAudioWidget(),
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                _cameraTogglesRowWidget(),
                _thumbnailWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    if (controller == null || !isControllerInitialized) {
      return const Text(
        'Tap a camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    return AspectRatio(
      aspectRatio: controller!.value.aspectRatio,
      child: CameraPreview(controller!),
    );
  }

  /// Toggle recording audio
  Widget _toggleAudioWidget() {
    return Padding(
      padding: const EdgeInsets.only(left: 25),
      child: Row(
        children: <Widget>[
          const Text('Enable Audio:'),
          Switch(
            value: enableAudio,
            onChanged: (bool value) {
              enableAudio = value;
              if (controller != null) {
                onNewCameraSelected(controller!.description);
              }
            },
          ),
        ],
      ),
    );
  }

  /// Display the thumbnail of the captured image or video.
  Widget _thumbnailWidget() {
    return Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            videoController == null && imagePath == null
                ? Container()
                : SizedBox(
                    child: (videoController == null)
                        ? Image.file(File(imagePath!))
                        : Container(
                            child: Center(
                              child: AspectRatio(
                                  aspectRatio:
                                      videoController!.value.aspectRatio,
                                  child: VideoPlayer(videoController!)),
                            ),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.pink)),
                          ),
                    width: 64.0,
                    height: 64.0,
                  ),
          ],
        ),
      ),
    );
  }

  /// Display the control bar with buttons to take pictures and record videos.
  Widget _captureControlRowWidget() {
    if (controller == null) return Container();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.camera_alt),
          color: Colors.blue,
          onPressed: controller != null && isControllerInitialized
              ? onTakePictureButtonPressed
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.videocam),
          color: Colors.blue,
          onPressed:
              controller != null && isControllerInitialized && !isRecordingVideo
                  ? onVideoRecordButtonPressed
                  : null,
        ),
        IconButton(
          icon: const Icon(Icons.watch),
          color: Colors.blue,
          onPressed: controller != null &&
                  isControllerInitialized &&
                  !isStreamingVideoRtmp
              ? onVideoStreamingButtonPressed
              : null,
        ),
        IconButton(
          icon: controller != null && (isRecordingPaused || isStreamingPaused)
              ? Icon(Icons.play_arrow)
              : Icon(Icons.pause),
          color: Colors.blue,
          onPressed: controller != null &&
                  isControllerInitialized &&
                  (isRecordingVideo || isStreamingVideoRtmp)
              ? (controller != null && (isRecordingPaused || isStreamingPaused)
                  ? onResumeButtonPressed
                  : onPauseButtonPressed)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.stop),
          color: Colors.red,
          onPressed: controller != null &&
                  isControllerInitialized &&
                  (isRecordingVideo || isStreamingVideoRtmp)
              ? onStopButtonPressed
              : null,
        )
      ],
    );
  }

  /// Display a row of toggle to select the camera (or a message if no camera is available).
  Widget _cameraTogglesRowWidget() {
    final List<Widget> toggles = <Widget>[];

    if (cameras.isEmpty) {
      return const Text('No camera found');
    } else {
      for (CameraDescription cameraDescription in cameras) {
        toggles.add(
          SizedBox(
            width: 90.0,
            child: RadioListTile<CameraDescription>(
              title: Icon(getCameraLensIcon(cameraDescription.lensDirection)),
              groupValue: controller?.description,
              value: cameraDescription,
              onChanged: (CameraDescription? cld) =>
                  isRecordingVideo ? null : onNewCameraSelected(cld),
            ),
          ),
        );
      }
    }

    return Row(children: toggles);
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// -------------------------------------------
  /// MAIN CAMERA SETUP: ADDED/EDITED
  /// -------------------------------------------
  void onNewCameraSelected(CameraDescription? cameraDescription) async {
    if (cameraDescription == null) return;

    if (controller != null) {
      await stopVideoStreaming();
      await controller?.dispose();
    }

    // ADDED/EDITED: Usa una resolución alta (por ejemplo ultraHigh o max).
    // Esto da mejor calidad en la preview y en la grabación/streaming
    // que "medium".
    controller = CameraController(
      cameraDescription,
      ResolutionPreset.veryHigh, //1920x1080
      // ResolutionPreset.ultraHigh, //3840X2160  <--- Usa ultraHigh o max
      enableAudio: enableAudio,
      androidUseOpenGL: useOpenGL,
    );

    controller!.addListener(() async {
      if (mounted) setState(() {});

      if (controller!.value.hasError) {
        showInSnackBar('Camera error ${controller!.value.errorDescription}');
        await stopVideoStreaming();
      } else {
        final dynamic event = controller!.value.event;
        if (event is Map) {
          final String eventType = event['eventType'] as String? ?? 'unknown';
          if (isVisible && isStreaming && eventType == 'rtmp_retry') {
            showInSnackBar('BadName received, endpoint in use.');
            await stopVideoStreaming();
          }
        }
      }
    });

    try {
      // Inicializa la cámara con la nueva resolución
      await controller!.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void onTakePictureButtonPressed() {
    takePicture().then((String? filePath) {
      if (mounted && filePath != null) {
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
      if (mounted && filePath != null) {
        setState(() {});
        showInSnackBar('Saving video to $filePath');
        WakelockPlus.enable();
      }
    });
  }

  void onVideoStreamingButtonPressed() {
    startVideoStreaming().then((String? url) {
      if (mounted && url != null) {
        setState(() {});
        showInSnackBar('Streaming video to $url');
        WakelockPlus.enable();
      }
    });
  }

  void onRecordingAndVideoStreamingButtonPressed() {
    startRecordingAndVideoStreaming().then((String? url) {
      if (mounted && url != null) {
        setState(() {});
        showInSnackBar('Recording streaming video to $url');
        WakelockPlus.enable();
      }
    });
  }

  void onStopButtonPressed() {
    if (this.isStreamingVideoRtmp) {
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
    if (!isControllerInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    // Checar plataforma
    Directory? extDir;
    if (Platform.isAndroid) {
      extDir = await getExternalStorageDirectory();
    } else {
      extDir = await getApplicationDocumentsDirectory();
    }
    if (extDir == null) return null;

    final String dirPath = '${extDir.path}/Movies/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.mp4';

    if (isRecordingVideo) {
      return null;
    }

    try {
      videoPath = filePath;
      await controller!.startVideoRecording(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  Future<void> stopVideoRecording() async {
    if (!isRecordingVideo) {
      return null;
    }

    try {
      await controller!.stopVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return;
    }

    await _startVideoPlayer();
  }

  Future<void> pauseVideoRecording() async {
    try {
      if (controller!.value.isRecordingVideo!) {
        await controller!.pauseVideoRecording();
      }
      if (controller!.value.isStreamingVideoRtmp!) {
        await controller!.pauseVideoStreaming();
      }
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    } catch (e) {
      print(e);
    }
  }

  Future<void> resumeVideoRecording() async {
    try {
      if (controller!.value.isRecordingVideo!) {
        await controller!.resumeVideoRecording();
      }
      if (controller!.value.isStreamingVideoRtmp!) {
        await controller!.resumeVideoStreaming();
      }
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    } catch (e) {
      print(e);
    }
  }

  Future<String> _getUrl() async {
    String result = _textFieldController.text;

    return await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Url to Stream to'),
          content: TextField(
            controller: _textFieldController,
            decoration: InputDecoration(hintText: "Url to Stream to"),
            onChanged: (String str) => result = str,
          ),
          actions: <Widget>[
            TextButton(
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
              onPressed: () {
                Navigator.pop(context, result);
              },
            )
          ],
        );
      },
    );
  }

  Future<String?> startRecordingAndVideoStreaming() async {
    if (!isControllerInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    if (controller!.value.isStreamingVideoRtmp == true ||
        controller!.value.isStreamingVideoRtmp == true) {
      return null;
    }

    String myUrl = await _getUrl();

    Directory extDir;
    if (Platform.isAndroid) {
      extDir = (await getExternalStorageDirectory())!;
    } else {
      extDir = await getApplicationDocumentsDirectory();
    }
    final String dirPath = '${extDir.path}/Movies/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.mp4';

    try {
      url = myUrl;
      videoPath = filePath;
      await controller!.startVideoRecordingAndStreaming(videoPath!, url!);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return url;
  }

  Future<String?> startVideoStreaming() async {
    await stopVideoStreaming();
    if (controller == null) return null;
    if (!isControllerInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }
    if (controller?.value.isStreamingVideoRtmp ?? false) {
      return null;
    }

    String myUrl = await _getUrl();

    try {
      url = myUrl;
      await controller!.startVideoStreaming(url!);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return url;
  }

  Future<void> stopVideoStreaming() async {
    if (controller == null || !isControllerInitialized) {
      return;
    }
    if (!isStreamingVideoRtmp) {
      return;
    }

    try {
      await controller!.stopVideoStreaming();
    } on CameraException catch (e) {
      _showCameraException(e);
      return;
    }
  }

  Future<void> pauseVideoStreaming() async {
    if (!isStreamingVideoRtmp) {
      return;
    }

    try {
      await controller!.pauseVideoStreaming();
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> resumeVideoStreaming() async {
    if (!isStreamingVideoRtmp) {
      return;
    }

    try {
      await controller!.resumeVideoStreaming();
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> _startVideoPlayer() async {
    final VideoPlayerController vcontroller =
        VideoPlayerController.file(File(videoPath!));
    videoPlayerListener = () {
      if (videoController != null) {
        if (mounted) setState(() {});
        videoController!.removeListener(videoPlayerListener ?? () {});
      }
    };
    vcontroller.addListener(videoPlayerListener ?? () {});
    await vcontroller.setLooping(true);
    await vcontroller.initialize();
    await videoController?.dispose();
    if (mounted) {
      setState(() {
        imagePath = null;
        videoController = vcontroller;
      });
    }
    await vcontroller.play();
  }

  Future<String?> takePicture() async {
    if (!isControllerInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }
    Directory? extDir;
    if (Platform.isAndroid) {
      extDir = await getExternalStorageDirectory();
    } else {
      extDir = await getApplicationDocumentsDirectory();
    }
    if (extDir == null) return null;

    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';

    if (isTakingPicture) {
      return null;
    }

    try {
      await controller!.takePicture(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description ?? "No description found");
    showInSnackBar(
        'Error: ${e.code}\n${e.description ?? "No description found"}');
  }
}

class CameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraExampleHome(),
    );
  }
}

List<CameraDescription> cameras = [];

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logError(e.code, e.description ?? "No description found");
  }
  runApp(CameraApp());
}




/*



import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rtmp_broadcaster/camera.dart'; // <-- plugin nativo o paquete
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class CameraExampleHome extends StatefulWidget {
  @override
  _CameraExampleHomeState createState() => _CameraExampleHomeState();
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

  TextEditingController _textFieldController =
      TextEditingController(text: "rtmp://198.7.123.229:1935/live/bH627zFoWCC1gJVI");

  // ------------------------------------------------
  // Getters resumidos
  // ------------------------------------------------
  bool get isControllerInitialized => controller?.value.isInitialized ?? false;
  bool get isStreaming => controller?.value.isStreamingVideoRtmp ?? false;
  bool get isStreamingPaused => controller?.value.isStreamingPaused ?? false;
  bool get isRecordingVideo => controller?.value.isRecordingVideo ?? false;
  bool get isRecordingPaused => controller?.value.isRecordingPaused ?? false;
  bool get isTakingPicture => controller?.value.isTakingPicture ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Podrías inicializar alguna cámara por defecto aquí si quieres.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    controller?.dispose(); 
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (controller == null || !isControllerInitialized) return;

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
        // Re-inicializa la cámara con la misma si gustas
        onNewCameraSelected(controller!.description);
      }
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ----------------------------------------------------------------
  // Build principal
  // ----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    if (controller != null) {
      if (isRecordingVideo) {
        color = Colors.redAccent;
      } else if (isStreaming) {
        color = Colors.blueAccent;
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: const Text('Camera example')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.black, border: Border.all(color: color, width: 3)),
              child: Padding(
                padding: const EdgeInsets.all(1.0),
                child: Center(child: _cameraPreviewWidget()),
              ),
            ),
          ),
          _captureControlRowWidget(),
          _toggleAudioWidget(),
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _cameraTogglesRowWidget(),
                _thumbnailWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // Vista de la cámara
  // ----------------------------------------------------------------
  Widget _cameraPreviewWidget() {
    if (controller == null || !isControllerInitialized) {
      return const Text('No camera selected', style: TextStyle(color: Colors.white, fontSize: 24));
    }
    return AspectRatio(
      aspectRatio: controller!.value.aspectRatio,
      child: CameraPreview(controller!),
    );
  }

  // ----------------------------------------------------------------
  // Botón toggle audio
  // ----------------------------------------------------------------
  Widget _toggleAudioWidget() {
    return Padding(
      padding: const EdgeInsets.only(left: 25),
      child: Row(
        children: [
          const Text('Enable Audio:'),
          Switch(
            value: enableAudio,
            onChanged: (bool val) async {
              enableAudio = val;
              if (controller != null) {
                // Reinstancia la cámara con audio on/off
                onNewCameraSelected(controller!.description);
              }
            },
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // Row de preview de foto/video
  // ----------------------------------------------------------------
  Widget _thumbnailWidget() {
    return Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          (videoController == null && imagePath == null)
              ? Container()
              : SizedBox(
                  width: 64, height: 64,
                  child: (videoController == null)
                      ? Image.file(File(imagePath!))
                      : Container(
                          decoration: BoxDecoration(border: Border.all(color: Colors.pink)),
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: videoController!.value.aspectRatio,
                              child: VideoPlayer(videoController!),
                            ),
                          ),
                        ),
                ),
        ]),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Row de botones: foto, grabar, start streaming, pause/resume, stop
  // ----------------------------------------------------------------
  Widget _captureControlRowWidget() {
    if (controller == null) return Container();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Take Picture
        IconButton(
          icon: const Icon(Icons.camera_alt, color: Colors.blue),
          onPressed: (isControllerInitialized) ? onTakePictureButtonPressed : null,
        ),

        // Record
        IconButton(
          icon: const Icon(Icons.videocam, color: Colors.blue),
          onPressed: (isControllerInitialized && !isRecordingVideo) ? onVideoRecordButtonPressed : null,
        ),

        // Stream
        IconButton(
          icon: const Icon(Icons.wifi_tethering, color: Colors.blue),
          onPressed: (isControllerInitialized && !isStreaming) ? onVideoStreamingButtonPressed : null,
        ),

        // Pause/Resume
        IconButton(
          icon: Icon((isRecordingPaused || isStreamingPaused) ? Icons.play_arrow : Icons.pause, color: Colors.blue),
          onPressed: (isControllerInitialized && (isRecordingVideo || isStreaming))
              ? ((isRecordingPaused || isStreamingPaused) ? onResumeButtonPressed : onPauseButtonPressed)
              : null,
        ),

        // Stop
        IconButton(
          icon: const Icon(Icons.stop, color: Colors.red),
          onPressed: (isControllerInitialized && (isRecordingVideo || isStreaming)) ? onStopButtonPressed : null,
        ),
      ],
    );
  }

  // ----------------------------------------------------------------
  // Row de toggles para elegir front/back camera
  // ----------------------------------------------------------------
  Widget _cameraTogglesRowWidget() {
    final toggles = <Widget>[];
    if (cameras.isEmpty) {
      return const Text('No camera found');
    } else {
      for (final camDesc in cameras) {
        toggles.add(SizedBox(
          width: 90,
          child: RadioListTile<CameraDescription>(
            title: Icon(getCameraLensIcon(camDesc.lensDirection)),
            groupValue: controller?.description,
            value: camDesc,
            onChanged: (desc) => (isRecordingVideo ? null : onNewCameraSelected(desc)),
          ),
        ));
      }
    }
    return Row(children: toggles);
  }

  // ----------------------------------------------------------------
  // Cambiar de cámara: si ya estás streameando, NO hagas stop
  // ----------------------------------------------------------------
  Future<void> onNewCameraSelected(CameraDescription? desc) async {
    if (desc == null) return;

    // OJO: si tu plugin es incapaz de “switchCamera” sin cortar stream,
    // esto forzará a parar y re-inicializar. 
    // PERO si lo admite, podemos usar una función “switchCameraInCode()” 
    // que no corte el stream.

    // EJEMPLO si tu plugin de android provee un method: “switchCameraHot()”
    // sin cortar stream:
    if (isStreaming) {
      // Llamamos un método nativo que cambie la cámara en caliente
      try {
        await controller?.switchCamera(); // <--- Asegúrate que tu plugin lo tenga
        showInSnackBar("Camera switched in hot. STILL streaming");
      } on CameraException catch (e) {
        _showCameraException(e);
      }
      return; // No hagas disposal, ni re-init
    }

    // Caso normal: si no estás streameando, paramos/descartamos la cámara
    if (controller != null) {
      await controller?.dispose();
      controller = null;
    }

    // Instancia un controller nuevo
    controller = CameraController(
      desc,
      ResolutionPreset.veryHigh, // o lo que quieras
      enableAudio: enableAudio,
      androidUseOpenGL: useOpenGL,
    );

    controller!.addListener(() async {
      if (mounted) setState(() {});
      if (controller!.value.hasError) {
        showInSnackBar("Camera error: ${controller!.value.errorDescription}");
      }
    });

    try {
      await controller!.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) setState(() {});
  }

  // ----------------------------------------------------------------
  // TOMA DE FOTO
  // ----------------------------------------------------------------
  void onTakePictureButtonPressed() {
    takePicture().then((filePath) {
      if (mounted && filePath != null) {
        setState(() {
          imagePath = filePath;
          videoController?.dispose();
          videoController = null;
        });
        showInSnackBar('Picture saved to $filePath');
      }
    });
  }

  // ----------------------------------------------------------------
  // RECORD
  // ----------------------------------------------------------------
  void onVideoRecordButtonPressed() {
    startVideoRecording().then((filePath) {
      if (mounted && filePath != null) {
        setState(() {});
        showInSnackBar('Saving video to $filePath');
        WakelockPlus.enable();
      }
    });
  }

  // ----------------------------------------------------------------
  // STREAM
  // ----------------------------------------------------------------
  void onVideoStreamingButtonPressed() {
    startVideoStreaming().then((u) {
      if (mounted && u != null) {
        setState(() {});
        showInSnackBar('Streaming video to $u');
        WakelockPlus.enable();
      }
    });
  }

  // ----------------------------------------------------------------
  // STOP
  // ----------------------------------------------------------------
  void onStopButtonPressed() {
    if (isStreaming) {
      stopVideoStreaming().then((_) {
        if (mounted) setState(() {});
        showInSnackBar('Streaming stopped: $url');
      });
    } else {
      stopVideoRecording().then((_) {
        if (mounted) setState(() {});
        showInSnackBar('Video recorded to $videoPath');
      });
    }
    WakelockPlus.disable();
  }

  // ----------------------------------------------------------------
  // PAUSE
  // ----------------------------------------------------------------
  void onPauseButtonPressed() async {
    await pauseVideoRecording();
    if (mounted) setState(() {});
    showInSnackBar('Video recording paused');
  }

  // ----------------------------------------------------------------
  // RESUME
  // ----------------------------------------------------------------
  void onResumeButtonPressed() async {
    await resumeVideoRecording();
    if (mounted) setState(() {});
    showInSnackBar('Video recording resumed');
  }

  // ----------------------------------------------------------------
  // 1) START RECORD
  // ----------------------------------------------------------------
  Future<String?> startVideoRecording() async {
    if (!isControllerInitialized) {
      showInSnackBar('No camera selected');
      return null;
    }
    Directory? extDir;
    if (Platform.isAndroid) {
      extDir = await getExternalStorageDirectory();
    } else {
      extDir = await getApplicationDocumentsDirectory();
    }
    if (extDir == null) return null;

    final dirPath = '${extDir.path}/Movies/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final filePath = '$dirPath/${DateTime.now().millisecondsSinceEpoch}.mp4';

    if (isRecordingVideo) return null;
    try {
      videoPath = filePath;
      await controller!.startVideoRecording(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  // ----------------------------------------------------------------
  // 2) STOP RECORD
  // ----------------------------------------------------------------
  Future<void> stopVideoRecording() async {
    if (!isRecordingVideo) return;
    try {
      await controller!.stopVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return;
    }
    await _startVideoPlayer();
  }

  // ----------------------------------------------------------------
  // PAUSE / RESUME RECORD
  // ----------------------------------------------------------------
  Future<void> pauseVideoRecording() async {
    try {
      if (controller!.value.isRecordingVideo!) {
        await controller!.pauseVideoRecording();
      }
      if (controller!.value.isStreamingVideoRtmp!) {
        await controller!.pauseVideoStreaming();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> resumeVideoRecording() async {
    try {
      if (controller!.value.isRecordingVideo!) {
        await controller!.resumeVideoRecording();
      }
      if (controller!.value.isStreamingVideoRtmp!) {
        await controller!.resumeVideoStreaming();
      }
    } catch (e) {
      print(e);
    }
  }

  // ----------------------------------------------------------------
  // 3) START STREAM
  // ----------------------------------------------------------------
  Future<String?> startVideoStreaming() async {
    // Cancela cualquier streaming anterior
    await stopVideoStreaming();

    if (!isControllerInitialized) {
      showInSnackBar('No camera selected');
      return null;
    }
    if (isStreaming) return null;

    final myUrl = await _askUserRtmpUrl();
    if (myUrl == null || myUrl.isEmpty) return null;

    try {
      url = myUrl;
      await controller!.startVideoStreaming(url!);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return url;
  }

  // ----------------------------------------------------------------
  // 4) STOP STREAM
  // ----------------------------------------------------------------
  Future<void> stopVideoStreaming() async {
    if (!isControllerInitialized) return;
    if (!isStreaming) return;
    try {
      await controller!.stopVideoStreaming();
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  // ----------------------------------------------------------------
  // PAUSE / RESUME STREAM
  // ----------------------------------------------------------------
  Future<void> pauseVideoStreaming() async {
    if (!isStreaming) return;
    try {
      await controller!.pauseVideoStreaming();
    } catch (e) {
      print(e);
    }
  }

  Future<void> resumeVideoStreaming() async {
    if (!isStreaming) return;
    try {
      await controller!.resumeVideoStreaming();
    } catch (e) {
      print(e);
    }
  }

  // ----------------------------------------------------------------
  // VIDEO PLAYER
  // ----------------------------------------------------------------
  Future<void> _startVideoPlayer() async {
    final vcontroller = VideoPlayerController.file(File(videoPath!));
    videoPlayerListener = () {
      if (videoController != null && mounted) setState(() {});
      videoController?.removeListener(videoPlayerListener ?? () {});
    };
    vcontroller.addListener(videoPlayerListener ?? () {});
    await vcontroller.setLooping(true);
    await vcontroller.initialize();
    await videoController?.dispose();
    if (mounted) {
      setState(() {
        imagePath = null;
        videoController = vcontroller;
      });
    }
    await vcontroller.play();
  }

  // ----------------------------------------------------------------
  // TAKE PICTURE
  // ----------------------------------------------------------------
  void onTakePictureButtonPressed() {
    takePicture().then((fp) {
      if (mounted && fp != null) {
        setState(() {
          imagePath = fp;
          videoController?.dispose();
          videoController = null;
        });
        showInSnackBar('Picture saved to $fp');
      }
    });
  }

  Future<String?> takePicture() async {
    if (!isControllerInitialized) {
      showInSnackBar('No camera selected');
      return null;
    }
    Directory? extDir;
    if (Platform.isAndroid) {
      extDir = await getExternalStorageDirectory();
    } else {
      extDir = await getApplicationDocumentsDirectory();
    }
    if (extDir == null) return null;

    final dirPath = '${extDir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final filePath = '$dirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (isTakingPicture) return null;
    try {
      await controller!.takePicture(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  // ----------------------------------------------------------------
  // Utils
  // ----------------------------------------------------------------
  void _showCameraException(CameraException e) {
    logError(e.code, e.description ?? "No description found");
    showInSnackBar('Error: ${e.code}\n${e.description ?? ""}');
  }

  Future<String?> _askUserRtmpUrl() async {
    String result = _textFieldController.text;
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Url to Stream to'),
        content: TextField(
          controller: _textFieldController,
          decoration: const InputDecoration(hintText: "Url to Stream to"),
          onChanged: (str) => result = str,
        ),
        actions: [
          TextButton(
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
            onPressed: () => Navigator.pop(ctx, result),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// MAIN (ejemplo de arranque normal)
// ----------------------------------------------------------------
class CameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(home: CameraExampleHome());
}

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logError(e.code, e.description ?? "");
  }
  runApp(CameraApp());
}






 */