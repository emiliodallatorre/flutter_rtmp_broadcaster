// Regenerates api/api_baseline.json from the current package sources.
//
// Run this after intentionally changing the public API, to update the
// committed snapshot used for human review. It does not enforce anything
// itself; enforcement of breaking-change detection lives in
// test/api_surface_test.dart.
//
// Usage: dart run scripts/update_api_baseline.dart

import 'dart:convert';
import 'dart:io';

const String _outputPath = 'api/api_baseline.json';

void main() {
  final Directory tempDir = Directory.systemTemp.createTempSync(
    'rtmp_broadcaster_api_extract_',
  );
  final File extractedFile = File(
    '${tempDir.path}${Platform.pathSeparator}api_extracted.json',
  );

  try {
    final ProcessResult extractResult = Process.runSync(
      'dart',
      <String>[
        'run',
        'dart_apitool:main',
        'extract',
        '--input',
        '.',
        '--output',
        extractedFile.path,
      ],
    );

    if (extractResult.exitCode != 0) {
      stderr.writeln('Failed to extract API:');
      stderr.writeln(extractResult.stdout);
      stderr.writeln(extractResult.stderr);
      exitCode = 1;
      return;
    }

    final Map<String, dynamic> extracted = jsonDecode(
      extractedFile.readAsStringSync(),
    ) as Map<String, dynamic>;

    final Map<String, dynamic> packageApi =
        extracted['packageApi'] as Map<String, dynamic>;
    packageApi.remove('packagePath');

    final File outputFile = File(_outputPath);
    outputFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('    ').convert(extracted)}\n',
    );

    stdout.writeln('Wrote $_outputPath');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}
