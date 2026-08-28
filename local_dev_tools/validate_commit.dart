import 'dart:io';

void main(List<String> args) {
  print('Validating commit...');

  for (final packagePath in <String>[
    '.',
    'packages/openfeature_dart_server_sdk',
    'packages/openfeature_dart_client_sdk',
  ]) {
    final analyzeResult = Process.runSync('dart', [
      'analyze',
    ], workingDirectory: packagePath);
    if (analyzeResult.exitCode != 0) {
      print('❌ Dart analyze failed in $packagePath. Please fix the issues.');
      print(analyzeResult.stdout);
      print(analyzeResult.stderr);
      exit(1);
    }
  }

  final formatResult = Process.runSync('dart', [
    'format',
    '--set-exit-if-changed',
    'tool',
    'test',
    'local_dev_tools',
    'packages/openfeature_dart_server_sdk',
    'packages/openfeature_dart_client_sdk',
  ]);
  if (formatResult.exitCode != 0) {
    print('❌ Dart format failed. Please format your code.');
    exit(1);
  }

  print('✅ Commit passed all validations.');
}
