// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:rtmp_broadcaster/rtmp_broadcaster.dart';

import 'screens/camera_example_home.dart';
import 'utils/camera_utils.dart';

/// The root widget of the example app.
class CameraApp extends StatelessWidget {
  const CameraApp({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraExampleHome(cameras: cameras),
    );
  }
}

Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  List<CameraDescription> cameras = <CameraDescription>[];
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logError(e.code, e.description ?? 'No description found');
  }
  runApp(CameraApp(cameras: cameras));
}
