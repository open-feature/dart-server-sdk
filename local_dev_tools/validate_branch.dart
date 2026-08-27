import 'dart:io';

void main(List<String> args) {
  print('Validating branch name...');

  // Retrieve the branch name
  final result = Process.runSync('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
  final branchName = result.stdout.toString().trim();

  if (branchName.isEmpty) {
    print('❌ Could not determine branch name.');
    exit(1);
  }

  print('Branch name: $branchName');

  final validBranches = RegExp(
    r'^(development|main|release-please--branches--main--components--(openfeature_dart_server_sdk|openfeature_dart_client_sdk))$',
  );
  final validFeatureBranch = RegExp(
    r'^(feat|fix|hotfix|chore|test|refactor|release|admin|docs|ci)/[a-z0-9._-]+$',
  );

  if (validBranches.hasMatch(branchName) ||
      validFeatureBranch.hasMatch(branchName)) {
    print('✅ Branch name is valid.');
  } else {
    print(
      '❌ Branch name does not follow the required convention: <type>/<branch-name>',
    );
    print(
      'Valid types: feat, fix, hotfix, chore, test, refactor, release, admin, docs, ci, development, main',
    );
    exit(1);
  }
}
