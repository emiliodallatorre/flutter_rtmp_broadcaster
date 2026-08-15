// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Displays a small thumbnail preview of the most recently captured photo
/// or video, if any.
class CaptureThumbnail extends StatelessWidget {
  const CaptureThumbnail({
    super.key,
    required this.imagePath,
    required this.videoController,
  });

  final String? imagePath;
  final VideoPlayerController? videoController;

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? videoController = this.videoController;
    final String? imagePath = this.imagePath;

    return Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (videoController == null && imagePath == null)
              const SizedBox.shrink()
            else
              SizedBox(
                width: 64.0,
                height: 64.0,
                child: videoController == null
                    ? Image.file(File(imagePath!))
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.pink),
                        ),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: videoController.value.aspectRatio,
                            child: VideoPlayer(videoController),
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
