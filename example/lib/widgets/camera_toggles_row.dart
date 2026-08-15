// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:rtmp_broadcaster/camera.dart';

import '../utils/camera_utils.dart';

/// Displays a row of radio buttons to select the active camera, or a
/// message when no camera is available.
class CameraTogglesRow extends StatelessWidget {
  const CameraTogglesRow({
    super.key,
    required this.cameras,
    required this.selectedCamera,
    required this.isRecordingVideo,
    required this.onChanged,
  });

  final List<CameraDescription> cameras;
  final CameraDescription? selectedCamera;
  final bool isRecordingVideo;
  final ValueChanged<CameraDescription?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (cameras.isEmpty) {
      return const Text('No camera found');
    }

    return Row(
      children: <Widget>[
        for (final CameraDescription cameraDescription in cameras)
          SizedBox(
            width: 90.0,
            child: RadioListTile<CameraDescription>(
              title: Icon(getCameraLensIcon(cameraDescription.lensDirection)),
              groupValue: selectedCamera,
              value: cameraDescription,
              onChanged: isRecordingVideo ? null : onChanged,
            ),
          ),
      ],
    );
  }
}
