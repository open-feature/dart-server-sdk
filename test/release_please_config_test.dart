import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('client releases use prerelease-safe generic version updates', () {
    final config =
        jsonDecode(File('release-please-config.json').readAsStringSync())
            as Map<String, Object?>;
    final packages = config['packages']! as Map<String, Object?>;
    final clientConfig =
        packages['packages/openfeature_dart_client_sdk']!
            as Map<String, Object?>;

    expect(clientConfig['release-type'], 'simple');
    expect(clientConfig['component'], 'openfeature_dart_client_sdk');
    expect(clientConfig['package-name'], 'openfeature_dart_client_sdk');
    expect(clientConfig['version-file'], '.release-please-version');
    expect(clientConfig['extra-files'], [
      {'type': 'generic', 'path': 'pubspec.yaml'},
    ]);
    expect(clientConfig['prerelease'], isTrue);
    expect(clientConfig['prerelease-type'], 'beta');
    expect(clientConfig['versioning'], 'prerelease');

    final versionFile = File(
      'packages/openfeature_dart_client_sdk/.release-please-version',
    ).readAsStringSync().trim();
    final pubspec = File(
      'packages/openfeature_dart_client_sdk/pubspec.yaml',
    ).readAsStringSync();
    expect(
      pubspec,
      contains('version: $versionFile # x-release-please-version'),
    );
  });

  test(
    'client release-as is limited to the unpublished bootstrap manifest',
    () {
      final config =
          jsonDecode(File('release-please-config.json').readAsStringSync())
              as Map<String, Object?>;
      final packages = config['packages']! as Map<String, Object?>;
      final clientConfig =
          packages['packages/openfeature_dart_client_sdk']!
              as Map<String, Object?>;
      final manifest =
          jsonDecode(File('.release-please-manifest.json').readAsStringSync())
              as Map<String, Object?>;
      final clientVersion =
          manifest['packages/openfeature_dart_client_sdk']! as String;

      expect(
        clientVersion == '0.0.0' || !clientConfig.containsKey('release-as'),
        isTrue,
        reason:
            'Remove the one-time client release-as override in the first '
            'release PR before merging it.',
      );
    },
  );
}
