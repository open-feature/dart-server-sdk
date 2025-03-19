import 'dart:async';
import 'package:test/test.dart';
import '../lib/hooks.dart';

class TestHook implements Hook {
  final List<String> executionOrder = [];
  final HookPriority _priority;
  bool receivedEvaluationDetails = false;

  TestHook([this._priority = HookPriority.NORMAL]);

  @override
  HookMetadata get metadata =>
      HookMetadata(name: 'TestHook', priority: _priority);

  @override
  Future<void> before(HookContext context) async {
    executionOrder.add('before');
  }

  @override
  Future<void> after(HookContext context) async {
    executionOrder.add('after');
  }

  @override
  Future<void> error(HookContext context) async {
    executionOrder.add('error');
  }

  @override
  Future<void> finally_(
    HookContext context,
    EvaluationDetails? evaluationDetails, [
    HookHints? hints,
  ]) async {
    executionOrder.add('finally');
    if (evaluationDetails != null) {
      receivedEvaluationDetails = true;
    }
    if (hints != null) {
      executionOrder.add('with_hints');
    }
  }
}

class OTelTestHook extends OpenTelemetryHook {
  final List<Map<String, dynamic>> capturedAttributes = [];

  OTelTestHook({required String providerName})
    : super(
        providerName: providerName,
        telemetryCallback: null, // We'll override the finally_ method
      );

  @override
  Future<void> finally_(
    HookContext context,
    EvaluationDetails? evaluationDetails, [
    HookHints? hints,
  ]) async {
    final otelAttributes =
        evaluationDetails != null
            ? OpenTelemetryUtil.fromEvaluationDetails(
              evaluationDetails,
              providerName: providerName,
            )
            : OpenTelemetryUtil.fromHookContext(
              context,
              providerName: providerName,
            );

    capturedAttributes.add(otelAttributes.toJson());
  }
}

void main() {
  group('HookManager', () {
    late HookManager manager;
    late TestHook testHook;

    setUp(() {
      manager = HookManager();
      testHook = TestHook();
      manager.addHook(testHook);
    });

    test('executes hooks in correct order', () async {
      await manager.executeHooks(HookStage.BEFORE, 'test-flag', {
        'user': 'test',
      });

      await manager.executeHooks(HookStage.AFTER, 'test-flag', {
        'user': 'test',
      }, result: true);

      await manager.executeHooks(HookStage.FINALLY, 'test-flag', {
        'user': 'test',
      });

      expect(testHook.executionOrder, ['before', 'after', 'finally']);
    });

    test('passes evaluation details to finally hook', () async {
      final evaluationDetails = EvaluationDetails(
        flagKey: 'test-flag',
        value: true,
        evaluationTime: DateTime.now(),
        reason: 'TARGETING_MATCH',
        variant: 'control',
      );

      await manager.executeHooks(HookStage.FINALLY, 'test-flag', {
        'user': 'test',
      }, evaluationDetails: evaluationDetails);

      expect(testHook.receivedEvaluationDetails, isTrue);
    });

    test('passes hook hints to finally hook', () async {
      final hints = HookHints(hints: {'source': 'test'});

      await manager.executeHooks(HookStage.FINALLY, 'test-flag', {
        'user': 'test',
      }, hints: hints);

      expect(testHook.executionOrder, contains('with_hints'));
    });
  });

  group('OpenTelemetryUtil', () {
    test('creates attributes for boolean flag', () {
      final attributes = OpenTelemetryUtil.createOTelAttributes(
        flagKey: 'test-flag',
        value: true,
        providerName: 'test-provider',
      );

      final jsonMap = attributes.toJson();

      expect(jsonMap[OTelFeatureFlagConstants.FLAG_KEY], equals('test-flag'));
      expect(
        jsonMap[OTelFeatureFlagConstants.FLAG_PROVIDER_NAME],
        equals('test-provider'),
      );
      expect(jsonMap[OTelFeatureFlagConstants.FLAG_EVALUATED], isTrue);
      expect(
        jsonMap[OTelFeatureFlagConstants.FLAG_VALUE_TYPE],
        equals(OTelFeatureFlagConstants.TYPE_BOOLEAN),
      );
      expect(jsonMap[OTelFeatureFlagConstants.FLAG_VALUE_BOOLEAN], isTrue);
      expect(
        jsonMap[OTelFeatureFlagConstants.REASON],
        equals(OTelFeatureFlagConstants.REASON_DEFAULT),
      );
    });

    test('creates attributes for string flag', () {
      final attributes = OpenTelemetryUtil.createOTelAttributes(
        flagKey: 'test-flag',
        value: 'test-value',
        providerName: 'test-provider',
        variant: 'control',
        reason: OTelFeatureFlagConstants.REASON_TARGETING_MATCH,
      );

      final jsonMap = attributes.toJson();

      expect(jsonMap[OTelFeatureFlagConstants.FLAG_VARIANT], equals('control'));
      expect(
        jsonMap[OTelFeatureFlagConstants.FLAG_VALUE_TYPE],
        equals(OTelFeatureFlagConstants.TYPE_STRING),
      );
      expect(
        jsonMap[OTelFeatureFlagConstants.FLAG_VALUE_STRING],
        equals('test-value'),
      );
      expect(
        jsonMap[OTelFeatureFlagConstants.REASON],
        equals(OTelFeatureFlagConstants.REASON_TARGETING_MATCH),
      );
    });

    test('creates attributes for numeric flags', () {
      final intAttributes = OpenTelemetryUtil.createOTelAttributes(
        flagKey: 'int-flag',
        value: 42,
        providerName: 'test-provider',
      );

      final doubleAttributes = OpenTelemetryUtil.createOTelAttributes(
        flagKey: 'double-flag',
        value: 3.14,
        providerName: 'test-provider',
      );

      expect(
        intAttributes.toJson()[OTelFeatureFlagConstants.FLAG_VALUE_TYPE],
        equals(OTelFeatureFlagConstants.TYPE_INT),
      );
      expect(
        intAttributes.toJson()[OTelFeatureFlagConstants.FLAG_VALUE_INT],
        equals(42),
      );

      expect(
        doubleAttributes.toJson()[OTelFeatureFlagConstants.FLAG_VALUE_TYPE],
        equals(OTelFeatureFlagConstants.TYPE_DOUBLE),
      );
      expect(
        doubleAttributes.toJson()[OTelFeatureFlagConstants.FLAG_VALUE_FLOAT],
        equals(3.14),
      );
    });
  });

  group('OpenTelemetryHook', () {
    test('generates telemetry from evaluation details', () async {
      final otelHook = OTelTestHook(providerName: 'test-provider');

      final evaluationDetails = EvaluationDetails(
        flagKey: 'test-flag',
        value: true,
        evaluationTime: DateTime.now(),
        variant: 'control',
      );

      await otelHook.finally_(
        HookContext(flagKey: 'test-flag', result: true),
        evaluationDetails,
      );

      expect(otelHook.capturedAttributes.length, equals(1));
      expect(
        otelHook.capturedAttributes[0][OTelFeatureFlagConstants.FLAG_KEY],
        equals('test-flag'),
      );
      expect(
        otelHook.capturedAttributes[0][OTelFeatureFlagConstants
            .FLAG_VALUE_BOOLEAN],
        isTrue,
      );
      expect(
        otelHook.capturedAttributes[0][OTelFeatureFlagConstants.FLAG_VARIANT],
        equals('control'),
      );
    });

    test(
      'generates telemetry from context when details not available',
      () async {
        final otelHook = OTelTestHook(providerName: 'test-provider');

        await otelHook.finally_(
          HookContext(flagKey: 'test-flag', result: 'test-value'),
          null,
        );

        expect(otelHook.capturedAttributes.length, equals(1));
        expect(
          otelHook.capturedAttributes[0][OTelFeatureFlagConstants.FLAG_KEY],
          equals('test-flag'),
        );
        expect(
          otelHook.capturedAttributes[0][OTelFeatureFlagConstants
              .FLAG_VALUE_STRING],
          equals('test-value'),
        );
      },
    );

    test('includes error reason when appropriate', () async {
      final otelHook = OTelTestHook(providerName: 'test-provider');

      await otelHook.finally_(
        HookContext(
          flagKey: 'test-flag',
          result: null,
          error: Exception('Test error'),
        ),
        null,
      );

      expect(
        otelHook.capturedAttributes[0][OTelFeatureFlagConstants.REASON],
        equals(OTelFeatureFlagConstants.REASON_ERROR),
      );
    });
  });
}
