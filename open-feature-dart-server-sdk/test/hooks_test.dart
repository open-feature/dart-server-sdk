import 'package:test/test.dart';
import '../lib/open_feature_api.dart';
import '../lib/hooks.dart';

void main() {
  group('Hooks Tests', () {
    late OpenFeatureAPI api;

    setUp(() {
      OpenFeatureAPI.resetInstance();
      api = OpenFeatureAPI();
    });

    test('Global hooks run before and after evaluation', () async {
      final hook = _MockHook();
      api.addHook(hook);

      await api
          .evaluateBooleanFlag('test-flag', context: {'user': 'test-user'});

      expect(hook.beforeCalled, isTrue,
          reason: 'Before hook should be called.');
      expect(hook.afterCalled, isTrue, reason: 'After hook should be called.');
    });
  });
}

class _MockHook implements Hook {
  bool beforeCalled = false;
  bool afterCalled = false;

  @override
  void beforeEvaluation(String flagKey, Map<String, dynamic>? context) {
    beforeCalled = true;
  }

  @override
  void afterEvaluation(
      String flagKey, dynamic result, Map<String, dynamic>? context) {
    afterCalled = true;
  }
}
