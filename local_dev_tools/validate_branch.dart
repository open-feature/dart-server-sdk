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

<<<<<<< HEAD
  final validBranches = RegExp(r'^(qa|development|main)$');
  final validFeatureBranch = RegExp(
    r'^(feat|fix|hotfix|chore|test|refactor|release)/[a-z0-9_-]+$',
  );
=======
  final validBranches = RegExp(r'^(qa|beta|main)$');
<<<<<<< HEAD
<<<<<<< HEAD
  final validFeatureBranch =
      RegExp(r'^(feat|fix|hotfix|chore|test|refactor|release)/[a-z0-9_-]+$');
>>>>>>> 83b6438 (feat: release v.0.0.1-pre+1 (#25))
=======
  final validFeatureBranch = RegExp(
    r'^(feat|fix|hotfix|chore|test|refactor|release)/[a-z0-9_-]+$',
  );
>>>>>>> 5eb4a58 (chore: update validation workflow)
=======
  final validFeatureBranch = RegExp(
    r'^(feat|fix|hotfix|chore|test|refactor|release)/[a-z0-9_-]+$',
  );
>>>>>>> 9729726 (chore: update dartsdk minimum to latest version 3.7.2 (#44))

  if (validBranches.hasMatch(branchName) ||
      validFeatureBranch.hasMatch(branchName)) {
    print('✅ Branch name is valid.');
  } else {
    print(
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
      '❌ Branch name does not follow the required convention: <type>/<branch-name>',
    );
    print(
      'Valid types: feat, fix, hotfix, chore, test, refactor, release, qa, development, main',
    );
=======
        '❌ Branch name does not follow the required convention: <type>/<branch-name>');
    print(
        'Valid types: feat, fix, hotfix, chore, test, refactor, release, qa, beta, main');
>>>>>>> 83b6438 (feat: release v.0.0.1-pre+1 (#25))
=======
      '❌ Branch name does not follow the required convention: <type>/<branch-name>',
    );
    print(
      'Valid types: feat, fix, hotfix, chore, test, refactor, release, development, qa, main',
    );
>>>>>>> 5eb4a58 (chore: update validation workflow)
=======
      '❌ Branch name does not follow the required convention: <type>/<branch-name>',
    );
    print(
      'Valid types: feat, fix, hotfix, chore, test, refactor, release, development, qa, main',
    );
>>>>>>> 9729726 (chore: update dartsdk minimum to latest version 3.7.2 (#44))
    exit(1);
  }
}
