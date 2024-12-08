// Tests for evaluation context logic.
// evaluation_context_test.dart
// Tests for evaluation context functionality

import 'package:test/test.dart';
import '../lib/evaluation_context.dart';

void main() {
  group('EvaluationContext Tests', () {
    late EvaluationContext baseContext;

    setUp(() {
      baseContext = EvaluationContext(
        attributes: {'userRole': 'admin', 'region': 'EU'},
      );
    });

    test('getAttribute retrieves correct value', () {
      expect(baseContext.getAttribute('userRole'), equals('admin'));
      expect(baseContext.getAttribute('region'), equals('EU'));
      expect(baseContext.getAttribute('nonexistent'), isNull);
    });

    test('parent context attribute resolution works', () {
      final parentContext = EvaluationContext(
        attributes: {'parentAttr': 'parent', 'shared': 'parent'},
      );

      final childContext = EvaluationContext(
        attributes: {'childAttr': 'child', 'shared': 'child'},
        parent: parentContext,
      );

      expect(childContext.getAttribute('parentAttr'), equals('parent'));
      expect(childContext.getAttribute('childAttr'), equals('child'));
      expect(childContext.getAttribute('shared'), equals('child'));
    });

    group('Context Merging', () {
      test('merge combines attributes correctly', () {
        final otherContext = EvaluationContext(
          attributes: {'region': 'US', 'environment': 'prod'},
        );

        final mergedContext = baseContext.merge(otherContext);

        expect(mergedContext.getAttribute('userRole'), equals('admin'));
        expect(mergedContext.getAttribute('region'), equals('US'));
        expect(mergedContext.getAttribute('environment'), equals('prod'));
      });

      test('merge combines rules correctly', () {
        final rule1 = TargetingRule('userRole', 'equals', 'admin');
        final rule2 = TargetingRule('region', 'equals', 'US');

        final context1 = EvaluationContext(
          attributes: {'userRole': 'admin'},
          rules: [rule1],
        );

        final context2 = EvaluationContext(
          attributes: {'region': 'US'},
          rules: [rule2],
        );

        final merged = context1.merge(context2);
        expect(merged.rules.length, equals(2));
      });
    });

    group('Targeting Rules', () {
      test('equals rule evaluates correctly', () {
        final rule = TargetingRule('userRole', 'equals', 'admin');
        final context = EvaluationContext(
          attributes: {'userRole': 'admin'},
          rules: [rule],
        );

        expect(context.evaluateRules(), isTrue);
      });

      test('contains rule evaluates correctly', () {
        final rule = TargetingRule('permissions', 'contains', 'read');
        final context = EvaluationContext(
          attributes: {
            'permissions': ['read', 'write']
          },
          rules: [rule],
        );

        expect(context.evaluateRules(), isTrue);
      });

      test('multiple rules use AND logic', () {
        final rules = [
          TargetingRule('userRole', 'equals', 'admin'),
          TargetingRule('region', 'equals', 'EU'),
        ];

        final context = EvaluationContext(
          attributes: {'userRole': 'admin', 'region': 'EU'},
          rules: rules,
        );

        expect(context.evaluateRules(), isTrue);
      });
    });

    test('child context maintains parent reference', () {
      final childContext = baseContext.createChild({'team': 'engineering'});

      expect(childContext.parent, equals(baseContext));
      expect(childContext.getAttribute('team'), equals('engineering'));
      expect(childContext.getAttribute('userRole'), equals('admin'));
    });
  });
}
