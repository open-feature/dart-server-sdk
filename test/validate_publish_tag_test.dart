import 'package:test/test.dart';

import '../tool/validate_publish_tag.dart';

void main() {
  test('accepts an exact client prerelease tag and pubspec version', () {
    expect(
      () => validatePublishTag(
        tag: 'openfeature_dart_client_sdk-v0.0.1-beta.1',
        packageDirectory: clientPackageDirectory,
        pubspec: 'name: openfeature_dart_client_sdk\nversion: 0.0.1-beta.1\n',
      ),
      returnsNormally,
    );
  });

  test('accepts an exact server release tag and pubspec version', () {
    expect(
      () => validatePublishTag(
        tag: 'v1.2.3',
        packageDirectory: serverPackageDirectory,
        pubspec: 'name: openfeature_dart_server_sdk\nversion: 1.2.3\n',
      ),
      returnsNormally,
    );
  });

  test('accepts valid numeric prerelease and build identifiers', () {
    expect(
      () => validatePublishTag(
        tag: 'openfeature_dart_client_sdk-v1.2.3-0+build.01',
        packageDirectory: clientPackageDirectory,
        pubspec: 'version: 1.2.3-0+build.01\n',
      ),
      returnsNormally,
    );
  });

  test('rejects malformed versions', () {
    expect(
      () => validatePublishTag(
        tag: 'openfeature_dart_client_sdk-vnext',
        packageDirectory: clientPackageDirectory,
        pubspec: 'version: 0.0.1-beta.1\n',
      ),
      throwsFormatException,
    );
  });

  test('rejects leading zeroes in core numeric identifiers', () {
    expect(
      () => validatePublishTag(
        tag: 'v01.2.3',
        packageDirectory: serverPackageDirectory,
        pubspec: 'version: 01.2.3\n',
      ),
      throwsFormatException,
    );
  });

  test('rejects leading zeroes in numeric prerelease identifiers', () {
    expect(
      () => validatePublishTag(
        tag: 'v1.2.3-01',
        packageDirectory: serverPackageDirectory,
        pubspec: 'version: 1.2.3-01\n',
      ),
      throwsFormatException,
    );
  });

  test('rejects a tag that does not match the pubspec version', () {
    expect(
      () => validatePublishTag(
        tag: 'openfeature_dart_client_sdk-v0.0.2-beta.1',
        packageDirectory: clientPackageDirectory,
        pubspec: 'version: 0.0.1-beta.1\n',
      ),
      throwsFormatException,
    );
  });

  test('rejects a valid tag routed to the wrong package', () {
    expect(
      () => validatePublishTag(
        tag: 'v1.2.3',
        packageDirectory: clientPackageDirectory,
        pubspec: 'version: 1.2.3\n',
      ),
      throwsFormatException,
    );
  });
}
