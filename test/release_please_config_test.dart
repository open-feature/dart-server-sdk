import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('server releases are scoped to the nested server package', () {
    final config =
        jsonDecode(File('release-please-config.json').readAsStringSync())
            as Map<String, Object?>;
    final packages = config['packages']! as Map<String, Object?>;
    final serverConfig =
        packages['packages/openfeature_dart_server_sdk']!
            as Map<String, Object?>;
    final manifest =
        jsonDecode(File('.release-please-manifest.json').readAsStringSync())
            as Map<String, Object?>;

    expect(packages, isNot(contains('.')));
    expect(serverConfig['release-type'], 'dart');
    expect(serverConfig['component'], 'openfeature_dart_server_sdk');
    expect(serverConfig['package-name'], 'openfeature_dart_server_sdk');
    expect(serverConfig['include-component-in-tag'], isFalse);
    expect(manifest['packages/openfeature_dart_server_sdk'], '0.0.23');

    final serverPubspec = File(
      'packages/openfeature_dart_server_sdk/pubspec.yaml',
    ).readAsStringSync();
    expect(serverPubspec, contains('version: 0.0.23'));
    expect(serverPubspec, contains('name: openfeature_dart_server_sdk'));
  });

  test('repository root is tooling-only and publishing uses package paths', () {
    final rootPubspec = File('pubspec.yaml').readAsStringSync();
    final publishWorkflow = File(
      '.github/workflows/publish.yaml',
    ).readAsStringSync();

    expect(rootPubspec, contains('publish_to: none'));
    expect(Directory('lib').existsSync(), isFalse);
    expect(
      Directory('packages/openfeature_dart_server_sdk/lib').existsSync(),
      isTrue,
    );
    expect(
      publishWorkflow,
      contains('directory=packages/openfeature_dart_server_sdk'),
    );
    expect(
      publishWorkflow,
      contains('directory=packages/openfeature_dart_client_sdk'),
    );
    expect(publishWorkflow, contains('dart tool/validate_publish_tag.dart'));
    expect(
      publishWorkflow,
      contains(r'openfeature_dart_client_sdk-v[0-9]+.[0-9]+.[0-9]+\+*'),
    );
    expect(
      publishWorkflow,
      isNot(contains("'openfeature_dart_client_sdk-v*'")),
    );
  });

  test('the legacy stable check name aggregates the current test matrix', () {
    final testWorkflow = File(
      '.github/workflows/pr-test.yaml',
    ).readAsStringSync();

    expect(testWorkflow, contains('name: test (ubuntu-latest, stable)'));
    expect(testWorkflow, contains('needs: test'));
    expect(testWorkflow, contains('MATRIX_RESULT:'));
    expect(testWorkflow, contains('needs.test.result'));
  });

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
