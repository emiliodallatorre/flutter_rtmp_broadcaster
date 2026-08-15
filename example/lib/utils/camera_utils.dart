// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:rtmp_broadcaster/rtmp_broadcaster.dart';

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

/// Logs a camera-related error to the console.
void logError(String code, String message) =>
    debugPrint('Error: $code\nError Message: $message');

/// Generates a millisecond-precision timestamp suitable for use as a
/// unique file name suffix.
String generateTimestamp() => DateTime.now().millisecondsSinceEpoch.toString();
