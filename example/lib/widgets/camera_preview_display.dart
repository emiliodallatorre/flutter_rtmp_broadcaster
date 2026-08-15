// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:rtmp_broadcaster/camera.dart';

/// Displays the live camera preview, or a placeholder message when no
/// camera has been selected/initialized yet.
class CameraPreviewDisplay extends StatelessWidget {
  const CameraPreviewDisplay({super.key, required this.controller});

  final CameraController? controller;

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = this.controller;

    if (!(controller?.value.isInitialized ?? false)) {
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
      child: CameraPreview(controller),
    );
  }
}
