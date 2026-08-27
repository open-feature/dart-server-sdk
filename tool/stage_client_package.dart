import 'dart:io';

import 'stage_client_package_paths.dart';

Future<void> main(List<String> arguments) async {
  final publish = arguments.contains('--publish');
  final unknownArguments = arguments
      .where((argument) => argument != '--publish' && argument != '--dry-run')
      .toList(growable: false);
  if (unknownArguments.isNotEmpty) {
    stderr.writeln('Unknown arguments: ${unknownArguments.join(', ')}');
    exitCode = 64;
    return;
  }

  final script = File.fromUri(Platform.script);
  final repositoryRoot = script.parent.parent;
  final source = Directory(
    _join(repositoryRoot.path, 'packages', 'openfeature_dart_client_sdk'),
  );
  final stagingRoot = await Directory.systemTemp.createTemp(
    'openfeature_dart_client_sdk-',
  );

  try {
    await _copyPackage(source, stagingRoot);
    final commandArguments = <String>[
      'pub',
      'publish',
      publish ? '--force' : '--dry-run',
    ];
    final process = await Process.start(
      Platform.resolvedExecutable,
      commandArguments,
      workingDirectory: stagingRoot.path,
      mode: ProcessStartMode.inheritStdio,
    );
    exitCode = await process.exitCode;
  } finally {
    if (stagingRoot.existsSync()) {
      await stagingRoot.delete(recursive: true);
    }
  }
}

Future<void> _copyPackage(Directory source, Directory destination) async {
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final relativePath = entity.path.substring(source.path.length + 1);
    if (isExcludedClientPackagePath(relativePath)) {
      continue;
    }
    final targetPath = _join(destination.path, relativePath);
    if (entity is Directory) {
      await Directory(targetPath).create(recursive: true);
    } else if (entity is File) {
      await File(targetPath).parent.create(recursive: true);
      await entity.copy(targetPath);
    } else if (entity is Link) {
      throw FileSystemException(
        'Package staging does not support symbolic links.',
        entity.path,
      );
    }
  }
}

String _join(String first, String second, [String? third]) {
  return [first, second, if (third != null) third].join(Platform.pathSeparator);
}
