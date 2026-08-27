import 'dart:io';

/// Returns whether [relativePath] must be omitted from the staged client SDK.
bool isExcludedClientPackagePath(String relativePath, {String? pathSeparator}) {
  const excludedSegments = <String>{'.dart_tool', 'build', 'coverage'};
  final segments = relativePath.split(pathSeparator ?? Platform.pathSeparator);
  return segments.any(excludedSegments.contains) ||
      segments.last == 'pubspec.lock';
}
