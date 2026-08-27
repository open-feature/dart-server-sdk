import 'package:test/test.dart';

import '../tool/stage_client_package_paths.dart';

void main() {
  test('client staging excludes generated directories at any depth', () {
    for (final path in <String>[
      '.dart_tool/package_config.json',
      'build/web_compile_smoke.js',
      'coverage/lcov.info',
      'test/coverage/stale.json',
      'example/build/output.js',
      'pubspec.lock',
      'example/pubspec.lock',
    ]) {
      expect(
        isExcludedClientPackagePath(path, pathSeparator: '/'),
        isTrue,
        reason: path,
      );
    }
  });

  test('client staging preserves package source and tests', () {
    for (final path in <String>[
      'lib/openfeature_dart_client_sdk.dart',
      'test/client_sdk_test.dart',
      'README.md',
      '.pubignore',
    ]) {
      expect(
        isExcludedClientPackagePath(path, pathSeparator: '/'),
        isFalse,
        reason: path,
      );
    }
  });
}
