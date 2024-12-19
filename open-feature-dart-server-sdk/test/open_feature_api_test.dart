import 'package:open_feature_dart_server_sdk/transaction_context.dart';
import 'package:test/test.dart';
import '../lib/open_feature_api.dart';

import 'package:mockito/mockito.dart';
import 'package:logging/logging.dart';

// Mock classes
class MockFeatureProvider extends Mock implements OpenFeatureProvider {}

class MockOpenFeatureHook extends Mock implements OpenFeatureHook {}

class MockTransactionContext extends Mock implements TransactionContext {}

void main() {
  group('OpenFeatureAPI', () {
    late OpenFeatureAPI api;
    late MockFeatureProvider mockProvider;
    late MockOpenFeatureHook mockHook;
    late MockTransactionContext mockTransactionContext;

    setUp(() {
      // Initialize logging
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((record) {
        print(
            '${record.time} [${record.level.name}] ${record.loggerName}: ${record.message}');
      });

      // Create mock instances
      mockProvider = MockFeatureProvider();
      mockHook = MockOpenFeatureHook();
      mockTransactionContext = MockTransactionContext();

      // Initialize the API with a mock provider
      api = OpenFeatureAPI();
      api.setProvider(mockProvider);
    });

    tearDown(() {
      // Clean up after each test
      OpenFeatureAPI.resetInstance();
    });

    test('set and get provider', () {
      expect(api.provider, equals(mockProvider));
    });

    test('set and get global context', () {
      final context = OpenFeatureEvaluationContext({'key': 'value'});
      api.setGlobalContext(context);

      expect(api.globalContext, equals(context));
    });

    test('add and run hooks', () {
      api.addHooks([mockHook]);

      final flagKey = 'testFlag';
      final context = {'key': 'value'};
      final result = true;

      api.evaluateBooleanFlag(flagKey, 'testClient', context: context);

      verify(mockHook.beforeEvaluation(flagKey, context)).called(1);
      verify(mockHook.afterEvaluation(flagKey, result, context)).called(1);
    });

    test('evaluate boolean flag with hooks and emit events', () async {
      when(mockProvider.getFlag('testFlag', context: anyNamed('context')))
          .thenAnswer((_) async => true);

      final flagKey = 'testFlag';
      final clientId = 'testClient';
      final context = {'key': 'value'};

      final result =
          await api.evaluateBooleanFlag(flagKey, clientId, context: context);

      expect(result, equals(true));

      await expectLater(api.events, emits(isA<OpenFeatureEvent>()));
      verify(mockProvider.getFlag(flagKey, context: context)).called(1);
    });

    test('handle error during flag evaluation', () async {
      when(mockProvider.getFlag('testFlag', context: anyNamed('context')))
          .thenThrow(Exception('Error'));

      final flagKey = 'testFlag';
      final clientId = 'testClient';
      final context = {'key': 'value'};

      final result =
          await api.evaluateBooleanFlag(flagKey, clientId, context: context);

      expect(result, equals(false));

      await expectLater(api.events, emits(isA<OpenFeatureEvent>()));
      verify(mockProvider.getFlag(flagKey, context: context)).called(1);
    });

    test('manage transaction contexts', () {
      api.pushTransactionContext(mockTransactionContext);
      expect(api.currentTransactionContext, equals(mockTransactionContext));

      final poppedContext = api.popTransactionContext();
      expect(poppedContext, equals(mockTransactionContext));
      expect(api.currentTransactionContext, isNull);
    });

    test('register and unregister extensions', () async {
      final extensionId = 'testExtension';
      final config = ExtensionConfig(id: extensionId);

      await api.registerExtension(extensionId, config);
      expect(api.getRegisteredExtensions(), contains(extensionId));

      await api.unregisterExtension(extensionId);
      expect(api.getRegisteredExtensions(), isNot(contains(extensionId)));
    });

    test('shutdown API', () async {
      await api.shutdown();
      verify(mockProvider.shutdown()).called(1);
    });
  });
}
