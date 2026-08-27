import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
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
