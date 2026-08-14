// Verifies the package's public API has not introduced breaking changes
// relative to the `2.3.4` release published on pub.dev, using dart_apitool.
//
// Shells out to `dart run dart_apitool:main diff`, comparing against
// pub://rtmp_broadcaster/2.3.4, so it requires network access to pub.dev.
@Tags(<String>['api-consistency'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _baselineRef = 'pub://rtmp_broadcaster/2.3.4';

void main() {
  test('public API has no breaking changes since $_baselineRef', () async {
    final Directory packageRoot = Directory.current;
    final Directory reportDir = await Directory.systemTemp.createTemp(
      'rtmp_broadcaster_api_diff_',
    );
    final File reportFile = File(
      '${reportDir.path}${Platform.pathSeparator}diff_report.json',
    );

    try {
      final ProcessResult diffResult = await Process.run(
        'dart',
        <String>[
          'run',
          'dart_apitool:main',
          'diff',
          '--old',
          _baselineRef,
          '--new',
          packageRoot.path,
          '--version-check-mode',
          'onlyBreakingChanges',
          '--report-format',
          'json',
          '--report-file-path',
          reportFile.path,
        ],
        workingDirectory: packageRoot.path,
      );

      expect(
        reportFile.existsSync(),
        isTrue,
        reason: 'dart_apitool did not produce a report:\n'
            '${diffResult.stdout}\n${diffResult.stderr}',
      );

      final Map<String, dynamic> report = jsonDecode(
        reportFile.readAsStringSync(),
      ) as Map<String, dynamic>;

      expect(
        diffResult.exitCode,
        0,
        reason: 'Breaking API changes detected against $_baselineRef:\n'
            '${const JsonEncoder.withIndent('  ').convert(report)}',
      );
    } finally {
      await reportDir.delete(recursive: true);
    }
  });
}
