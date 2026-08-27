import 'dart:io';

const String clientPackageDirectory = 'packages/openfeature_dart_client_sdk';
const String serverPackageDirectory = 'packages/openfeature_dart_server_sdk';

final RegExp _semanticVersion = RegExp(
  r'^[0-9]+\.[0-9]+\.[0-9]+'
  r'(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?'
  r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
);

void main(List<String> arguments) {
  try {
    final tag = _argumentValue(arguments, '--tag');
    final packageDirectory = _argumentValue(arguments, '--package');
    final pubspec = File('$packageDirectory/pubspec.yaml').readAsStringSync();
    validatePublishTag(
      tag: tag,
      packageDirectory: packageDirectory,
      pubspec: pubspec,
    );
    stdout.writeln('Validated $tag for $packageDirectory.');
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 64;
  }
}

void validatePublishTag({
  required String tag,
  required String packageDirectory,
  required String pubspec,
}) {
  final normalizedDirectory = packageDirectory.replaceAll('\\', '/');
  final (expectedDirectory, version) = _targetForTag(tag);
  if (normalizedDirectory != expectedDirectory) {
    throw FormatException(
      'Tag $tag selects $expectedDirectory, not $normalizedDirectory.',
    );
  }

  final versionMatch = RegExp(
    r'^version:\s*([^\s#]+)',
    multiLine: true,
  ).firstMatch(pubspec);
  if (versionMatch == null) {
    throw const FormatException('The selected pubspec has no version field.');
  }
  final pubspecVersion = versionMatch.group(1)!;
  if (version != pubspecVersion) {
    throw FormatException(
      'Tag version $version does not match pubspec version $pubspecVersion.',
    );
  }
}

(String, String) _targetForTag(String tag) {
  const clientPrefix = 'openfeature_dart_client_sdk-v';
  final String directory;
  final String version;
  if (tag.startsWith(clientPrefix)) {
    directory = clientPackageDirectory;
    version = tag.substring(clientPrefix.length);
  } else if (tag.startsWith('v')) {
    directory = serverPackageDirectory;
    version = tag.substring(1);
  } else {
    throw FormatException('Unsupported publication tag: $tag.');
  }
  if (!_semanticVersion.hasMatch(version)) {
    throw FormatException('Publication tag has an invalid version: $tag.');
  }
  return (directory, version);
}

String _argumentValue(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index == -1 || index + 1 >= arguments.length) {
    throw FormatException('Missing required argument $name.');
  }
  return arguments[index + 1];
}
