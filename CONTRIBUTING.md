# **Welcome to Open Feature!**

Thank you for contributing to this project. We value your input, and any issues or pull requests adhering to these guidelines are welcome.



## **Code of Conduct**

Please read and follow our [Code of Conduct](https://github.com/open-feature/.github/blob/main/CODE_OF_CONDUCT.md).  
**TL;DR**: Be respectful and professional.


## **Vendor Specific Details**

Vendor specific details are intentionally not included in this module in order to be lightweight and agnostic.
If there are changes needed to enable vendor specific behaviour in code or other extension points, check out [the spec](https://github.com/open-feature/spec).

Here’s the updated **README** tailored for **Open Feature** and GitHub:

## **Development**

### **Installation and Dependencies**

Install dependencies with:
```bash
dart pub get
```

We aim to minimize runtime dependencies. Please review new dependencies carefully and follow Dart's best practices when proposing additions.

### **Testing**

We use an extensive suite of automated tests to ensure quality and reliability. Contributors must include appropriate tests for new features or bug fixes. Automated GitHub workflows will validate changes during pull requests.

#### **Testing Overview**

| **Test Type**            | **Description**                                                                                             | **Command**                     |
|--------------------------|-----------------------------------------------------------------------------------------------------------|----------------------------------|
| **Unit Tests**           | Validates individual components in isolation using mocks and fakes.                                       | `dart test`                     |
| **Integration Tests**    | Validates interactions between components and external systems like Firebase.                            | `make integration-test`         |
| **End-to-End Tests**     | Simulates real-world workflows across the system using Gherkin-based test harness.                       | `make e2e-test`                 |
| **Mutation Tests**       | Ensures robustness of test coverage by introducing controlled code mutations.                            | `dart run mutest`               |
| **Static Analysis**      | Ensures code adheres to guidelines and highlights potential bugs.                                        | `dart analyze`                  |
| **Code Coverage**        | Ensures critical paths are covered with tests, generates LCOV reports.                                  | `dart test --coverage=coverage` |

#### **Unit Tests**

Run unit tests with:
```bash
dart test
```

#### **End-to-End Tests**

Our CI pipeline executes Gherkin-based end-to-end tests. To run them locally:

1. Pull the `test-harness` git submodule:
   ```bash
   git submodule update --init --recursive
   ```
2. Execute the tests:
   ```bash
   make e2e-test
   ```

#### **Mutation Testing**

Validate the robustness of your test suite using mutation tests:
```bash
dart run mutest
```

---

Here's the updated **Branching and Commit Guidelines** section with the adjustment to use **`feat` for features** and other refinements to align with your conventions:

---

## **Branching and Commit Guidelines**

### **Branch Naming Conventions**

Follow these conventions when creating branches for pull requests:
```
<type>/<branch-name>
```

| **Branch Type** | **Purpose**                                                                                         |
|-----------------|-----------------------------------------------------------------------------------------------------|
| `feat`          | For new features under development. Example: `feat/add-auth-module`.                                |
| `fix`           | For bug fixes. Example: `fix/login-error`.                                                          |
| `hotfix`        | For urgent production fixes requiring immediate attention. Example: `hotfix/critical-db-error`.     |
| `chore`         | For maintenance tasks, such as dependency updates or refactoring. Example: `chore/update-dependencies`. |
| `release`       | For preparing release branches with versioned changes. Example: `release/v1.2.0`.                   |
| `test`          | For testing-related changes, such as adding or modifying test cases. Example: `test/add-unit-tests`.|

---

### **Examples**

| **Type**          | **Example Branch Name**            |
|-------------------|------------------------------------|
| `feat`            | `feat/add-user-auth`               |
| `fix`             | `fix/payment-gateway-bug`          |
| `hotfix`          | `hotfix/critical-db-error`         |
| `chore`           | `chore/upgrade-dependencies`       |
| `test`            | `test/add-integration-tests`       |
| `release`         | `release/v1.2.0`                   |

---

### **Commit Message Format**

We follow [Conventional Commits](https://www.conventionalcommits.org) to ensure clear and consistent commit history.  

**Commit types are aligned with branch naming conventions** to maintain consistency across the workflow.

#### **Commit Structure**

```
<type>(<scope>): <short summary>
<BLANK LINE>
[optional body]
<BLANK LINE>
[optional footer(s)]
```

| **Type**      | **Branch Equivalent**  | **Description**                                                                 |
|---------------|-------------------------|---------------------------------------------------------------------------------|
| `feat`        | `feat`                 | Adds a new feature. Example: `feat(auth): add OAuth 2.0 support`.              |
| `fix`         | `fix`                  | Fixes a bug. Example: `fix(payment): resolve rounding error`.                  |
| `hotfix`      | `hotfix`               | Urgent fixes for production. Example: `hotfix(db): resolve connection issue`.  |
| `chore`       | `chore`                | Maintenance tasks or refactoring. Example: `chore(deps): update dependencies`. |
| `test`        | `test`                 | Adds or updates tests. Example: `test(api): add integration tests`.            |
| `refactor`    | `refactor`             | Code restructuring without functional changes. Example: `refactor(ui): improve layout`. |
| `release`     | `release`              | Prepares a versioned release. Example: `release: v1.2.0`.                      |

---

#### **Best Practices**

1. **Align Commit Type with Branch Type**:
   - A branch like `feat/add-auth-module` should include commits starting with `feat:`.
   - A branch like `fix/login-error` should include commits starting with `fix:`.

2. **Use Scope (Optional)**:
   - Add a scope in parentheses to specify the module or component affected.
   - Examples: `feat(auth)`, `fix(payment)`, `test(ui)`.

3. **Write a Clear Summary**:
   - Use the imperative mood for the summary (e.g., "add", "fix", not "added" or "fixed").

4. **Add Context in the Body (Optional)**:
   - Provide additional details or reasoning for the change.

5. **Reference Issues or PRs in the Footer**:
   - Use the footer for links to related issues or PRs and to indicate breaking changes.
   - Examples:
     ```plaintext
     Fixes #123
     BREAKING CHANGE: Deprecated legacy login endpoints.
     ```

---

### **Branching Rules and Protection**

To maintain consistency and ensure stability, we enforce the following **branch protection rules**:

#### **Protected Branches**
- **Branches**: `main`, `qa`, `beta`
- **Rules**:
  - Direct **pushes** are not allowed.
  - Changes must go through a **pull request** and pass all required checks before merging.
  - At least **1 reviewer** must approve pull requests.
  - Status checks:
    - **Branch name validation** must pass.
    - **Commit message validation** must pass.
    - Relevant workflows (e.g., `main-workflow`, `qa-workflow`) must pass.

#### **Unprotected Branches**
- Feature and other short-lived branches (e.g., `feat/add-auth`, `fix/login-error`) are not protected.
- Contributors can push directly to these branches.

#### **Branch Lifecycle**
- **Feature, Fix, Hotfix, Test Branches**:
  - Created by developers for specific tasks.
  - Merged into `main`, `qa`, or `beta` branches through pull requests.
  - Deleted after merging.

---

### **How It Works**

1. **Contributors Create Feature Branches**:
   - Example: `feat/add-user-auth`.
   - Pushes to these branches are allowed without restrictions.

2. **Pull Requests into Protected Branches**:
   - Protected branches (`main`, `qa`, `beta`) require pull requests.
   - Pull requests trigger workflows for testing and validation.

3. **Validation on Push and Pull Requests**:
   - Branch name and commit message validations are run on all branches during pushes.
   - Protected branches also enforce workflow checks and reviews.

---

### **Examples**

| **Branch Name**               | **Commit Message**                                              |
|--------------------------------|---------------------------------------------------------------|
| `feat/add-auth-module`        | `feat(auth): add OAuth 2.0 support`                            |
| `fix/payment-bug`             | `fix(payment): resolve rounding error in total calculation`   |
| `hotfix/db-connection-issue`  | `hotfix(db): resolve connection timeout in production`        |
| `chore/update-dependencies`   | `chore(deps): upgrade Dart SDK to 3.0`                        |
| `test/add-integration-tests`  | `test(auth): add integration tests for login functionality`   |
| `refactor/improve-logging`    | `refactor(logging): standardize log format`                  |
| `release/v1.2.0`              | `release: prepare for v1.2.0`                                 |


## **Releases**

This repository uses [Release Please](https://github.com/googleapis/release-please) for automated versioning and changelogs.  

Merges into the main branch trigger a new version release if changes are detected.

For versioning standards, follow [Dart's semantic versioning](https://dart.dev/tools/pub/versioning).

Here’s your updated **Submitting a Pull Request** section with improved formatting and alignment for clarity and readability:



## **Submitting a Pull Request**

Contributing to the project is highly encouraged! Please follow these steps to submit a well-structured pull request (PR):


### **Steps to Submit a Pull Request**

1. **Create a New Branch**:
   - Use the appropriate branch naming convention:
     ```bash
     git checkout -b feat/new-feature
     ```
   - Ensure your branch is based on the latest `development` branch:
     ```bash
     git fetch origin
     git checkout development
     git rebase origin/development
     ```

2. **Implement Changes**:
   - Write clean, modular code following the project's coding standards.
   - Add appropriate unit and integration tests to ensure coverage.

3. **Run Tests Locally**:
   - Validate your changes locally to ensure they don't break existing functionality:
     ```bash
     dart analyze
     dart test
     ```

4. **Commit Your Changes**:
   - Use meaningful commit messages following the [Conventional Commits](https://www.conventionalcommits.org) format:
     ```bash
     git commit -s -m "feat(sdk): implement new feature"
     ```

---

### **How to Sign Off Commits**

To certify your contribution, you must add a `Signed-off-by` line to your commit message. This is required to comply with the [Developer Certificate of Origin (DCO)](https://developercertificate.org/).

1. **Sign Off When Committing**:
   - Use the `-s` or `--signoff` flag when creating a commit:
     ```bash
     git commit -s -m "feat: add authentication module"
     ```
   - This will add a `Signed-off-by` line to your commit message:
     ```
     feat: add authentication module

     Signed-off-by: Your Name <your.email@example.com>
     ```

2. **Ensure Git User Configuration**:
   - Make sure your Git username and email are correctly configured:
     ```bash
     git config --global user.name "Your Name"
     git config --global user.email "your.email@example.com"
     ```

3. **Forgot to Sign Off?**:
   - If you forgot to sign off a commit, you can fix it by amending the commit:
     ```bash
     git commit --amend --signoff
     git push --force-with-lease
     ```

   - For multiple commits, rebase with `--signoff`:
     ```bash
     git rebase --signoff HEAD~<number-of-commits>
     git push --force-with-lease
     ```

---

5. **Push Your Branch**:
   - Push your changes to the remote repository:
     ```bash
     git push origin feat/new-feature
     ```

6. **Open a Pull Request**:
   - Navigate to the repository on GitHub.
   - Open a pull request targeting the `qa` branch.
   - Provide a clear title and description summarizing your changes, including:
     - The problem your changes solve.
     - The approach you used.
     - Links to relevant issues or discussions (e.g., `Closes #123`).



### **Notes**:

- Ensure your branch passes all tests and validations before creating a PR.
- If you encounter issues during the sign-off process, check your DCO compliance or consult the contributing guidelines.

---

### **Addressing Review Feedback**

Pull requests often receive feedback. Follow these steps to address requested changes:

1. **Use Fixup Commits for Small Changes**:
   - For minor fixes or changes requested during the review:
     ```bash
     git commit --all --fixup HEAD
     git push
     ```

2. **Amend Commit Messages if Needed**:
   - Update commit messages to clarify or provide additional details:
     ```bash
     git commit --amend
     git push --force-with-lease
     ```

3. **Rebase and Squash Commits**:
   - If your branch has multiple commits and needs to be cleaned up:
     ```bash
     git rebase -i origin/qa
     git push --force-with-lease
     ```

4. **Run Tests Again**:
   - Ensure all tests pass after making changes:
     ```bash
     dart analyze
     dart test
     ```

5. **Update the Pull Request**:
   - Add a comment to the PR describing what was updated in response to the feedback.

---

### **Best Practices for Pull Requests**

- **Keep Pull Requests Small**:
  - Submit changes in manageable chunks to make reviews easier.
- **Follow Coding Standards**:
  - Adhere to the project's coding style and guidelines.
- **Document Changes**:
  - Update relevant documentation, if applicable, to reflect your changes.
- **Add Tests**:
  - Ensure new features or bug fixes are thoroughly tested.
- **Reference Issues**:
  - Use `Fixes #<issue-number>` or `Closes #<issue-number>` in the PR description to auto-close related issues.

---

### **Example Workflow**

```bash
# Create a new branch
git checkout -b feat/add-auth

# Implement changes
# ...

# Run tests
dart analyze
dart test

# Commit changes
git commit -m "feat(auth): add OAuth 2.0 authentication"

# Push changes
git push origin feat/add-auth

# Open a pull request on GitHub
# Provide a clear description linking the related issue (e.g., Fixes #45)
```

## **Versioning Standards**

We follow Dart's [semantic versioning](https://semver.org) conventions:
- `x.y.z+1`: For patch releases during pre-1.0 development.
- `x.y.z`: For stable, production-ready versions.

## **Contacting Us**

- Join our regular meetings [here](https://github.com/open-feature/community/#meetings-and-events).
- Chat with us in the `#openfeature` channel on [CNCF Slack](https://slack.cncf.io/).