// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'camera_controller.dart';

/// A widget showing a live camera preview.
class CameraPreview extends StatelessWidget {
  /// Creates a preview widget for the given camera controller.
  const CameraPreview(this.controller);

  /// The controller for the camera that the preview is shown for.
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.value.isInitialized!) {
      Widget childView = controller.buildPreview();

      if (controller.value.previewSize!.width <
          controller.value.previewSize!.height) {
        return RotatedBox(
          quarterTurns: controller.value.previewQuarterTurns!,
          child: childView,
        );
      } else {
        return childView;
      }
    } else {
      return Container();
    }
  }
}
