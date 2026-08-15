// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Shows a dialog prompting the user for the RTMP URL to stream to.
///
/// Returns the URL entered by the user, or the unchanged text in
/// [urlController] if the dialog is dismissed without editing.
Future<String?> showStreamUrlDialog(
  BuildContext context,
  TextEditingController urlController,
) {
  String result = urlController.text;

  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Url to Stream to'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(hintText: 'Url to Stream to'),
          onChanged: (String value) => result = value,
        ),
        actions: <Widget>[
          TextButton(
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
            onPressed: () => Navigator.of(context).pop(result),
          ),
        ],
      );
    },
  );
}
