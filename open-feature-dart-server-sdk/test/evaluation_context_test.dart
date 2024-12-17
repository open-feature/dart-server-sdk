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

    group('Basic Context Operations', () {
      test('getAttribute retrieves correct value', () {
        expect(baseContext.getAttribute('userRole'), equals('admin'));
        expect(baseContext.getAttribute('region'), equals('EU'));
        expect(baseContext.getAttribute('nonexistent'), isNull);
      });

      test('context creation with empty rules works', () {
        final context = EvaluationContext(attributes: {'test': 'value'});
        expect(context.rules, isEmpty);
        expect(context.parent, isNull);
        expect(context.attributes['test'], equals('value'));
      });
    });

    group('Parent-Child Context Relationships', () {
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

      test('createChild maintains correct hierarchy', () {
        final childContext = baseContext.createChild(
          {'team': 'engineering'},
          childRules: [
            TargetingRule('team', TargetingOperator.EQUALS, 'engineering')
          ],
        );

        expect(childContext.parent, equals(baseContext));
        expect(childContext.getAttribute('team'), equals('engineering'));
        expect(childContext.getAttribute('userRole'), equals('admin'));
        expect(childContext.rules.length, equals(1));
      });

      test('multi-level parent resolution works', () {
        final grandparent = EvaluationContext(
          attributes: {'level': 'grandparent', 'shared': 'grandparent'},
        );
        final parent = EvaluationContext(
          attributes: {'level': 'parent', 'shared': 'parent'},
          parent: grandparent,
        );
        final child = EvaluationContext(
          attributes: {'level': 'child', 'parentOnly': 'visible'},
          parent: parent,
        );

        expect(child.getAttribute('level'), equals('child'));
        expect(child.getAttribute('parentOnly'), equals('visible'));
        expect(child.getAttribute('shared'), equals('parent'));
      });
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
        final rule1 =
            TargetingRule('userRole', TargetingOperator.EQUALS, 'admin');
        final rule2 = TargetingRule('region', TargetingOperator.EQUALS, 'US');

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
        expect(merged.rules, containsAll([rule1, rule2]));
      });

      test('merge with null parent attributes works', () {
        final context1 = EvaluationContext(
          attributes: {'attr1': 'value1'},
        );
        final context2 = EvaluationContext(
          attributes: {'attr2': 'value2'},
        );

        final merged = context1.merge(context2);
        expect(merged.attributes.length, equals(2));
        expect(merged.attributes['attr1'], equals('value1'));
        expect(merged.attributes['attr2'], equals('value2'));
      });
    });

    group('Targeting Rules', () {
      group('Basic Operators', () {
        test('EQUALS operator evaluates correctly', () {
          final rule =
              TargetingRule('userRole', TargetingOperator.EQUALS, 'admin');
          final context = EvaluationContext(
            attributes: {'userRole': 'admin'},
            rules: [rule],
          );

          expect(context.evaluateRules(), isTrue);
        });

        test('NOT_EQUALS operator evaluates correctly', () {
          final rule =
              TargetingRule('userRole', TargetingOperator.NOT_EQUALS, 'user');
          final context = EvaluationContext(
            attributes: {'userRole': 'admin'},
            rules: [rule],
          );

          expect(context.evaluateRules(), isTrue);
        });

        test('CONTAINS operator evaluates correctly', () {
          final rule =
              TargetingRule('description', TargetingOperator.CONTAINS, 'admin');
          final context = EvaluationContext(
            attributes: {'description': 'super admin user'},
            rules: [rule],
          );

          expect(context.evaluateRules(), isTrue);
        });
      });

      group('List Operators', () {
        test('IN_LIST operator evaluates correctly', () {
          final rule = TargetingRule(
            'userRole',
            TargetingOperator.IN_LIST,
            ['admin', 'superuser'],
          );
          final context = EvaluationContext(
            attributes: {'userRole': 'admin'},
            rules: [rule],
          );

          expect(context.evaluateRules(), isTrue);
        });

        test('NOT_IN_LIST operator evaluates correctly', () {
          final rule = TargetingRule(
            'userRole',
            TargetingOperator.NOT_IN_LIST,
            ['user', 'guest'],
          );
          final context = EvaluationContext(
            attributes: {'userRole': 'admin'},
            rules: [rule],
          );

          expect(context.evaluateRules(), isTrue);
        });
      });

      group('Comparison Operators', () {
        test('GREATER_THAN operator evaluates correctly', () {
          final rule = TargetingRule('age', TargetingOperator.GREATER_THAN, 18);
          final context = EvaluationContext(
            attributes: {'age': 21},
            rules: [rule],
          );

          expect(context.evaluateRules(), isTrue);
        });

        test('LESS_THAN operator evaluates correctly', () {
          final rule = TargetingRule('price', TargetingOperator.LESS_THAN, 100);
          final context = EvaluationContext(
            attributes: {'price': 99.99},
            rules: [rule],
          );

          expect(context.evaluateRules(), isTrue);
        });
      });

      test('multiple rules use AND logic', () {
        final rules = [
          TargetingRule('userRole', TargetingOperator.EQUALS, 'admin'),
          TargetingRule('region', TargetingOperator.EQUALS, 'EU'),
          TargetingRule('age', TargetingOperator.GREATER_THAN, 18),
        ];

        final context = EvaluationContext(
          attributes: {'userRole': 'admin', 'region': 'EU', 'age': 25},
          rules: rules,
        );

        expect(context.evaluateRules(), isTrue);
      });

      test('rule evaluation returns false if any rule fails', () {
        final rules = [
          TargetingRule('userRole', TargetingOperator.EQUALS, 'admin'),
          TargetingRule('age', TargetingOperator.GREATER_THAN, 18),
          TargetingRule(
              'region', TargetingOperator.EQUALS, 'US'), // This will fail
        ];

        final context = EvaluationContext(
          attributes: {'userRole': 'admin', 'region': 'EU', 'age': 25},
          rules: rules,
        );

        expect(context.evaluateRules(), isFalse);
      });
    });

    group('TargetingRuleBuilder', () {
      test('equals builder creates correct rule', () {
        final rule = TargetingRuleBuilder.equals('attr', 'value');
        expect(rule.operator, equals(TargetingOperator.EQUALS));
        expect(rule.attribute, equals('attr'));
        expect(rule.value, equals('value'));
      });

      test('notEquals builder creates correct rule', () {
        final rule = TargetingRuleBuilder.notEquals('attr', 'value');
        expect(rule.operator, equals(TargetingOperator.NOT_EQUALS));
        expect(rule.attribute, equals('attr'));
        expect(rule.value, equals('value'));
      });

      test('contains builder creates correct rule', () {
        final rule = TargetingRuleBuilder.contains('attr', 'value');
        expect(rule.operator, equals(TargetingOperator.CONTAINS));
        expect(rule.attribute, equals('attr'));
        expect(rule.value, equals('value'));
      });

      test('inList builder creates correct rule', () {
        final values = ['value1', 'value2'];
        final rule = TargetingRuleBuilder.inList('attr', values);
        expect(rule.operator, equals(TargetingOperator.IN_LIST));
        expect(rule.attribute, equals('attr'));
        expect(rule.value, equals(values));
      });
    });
  });
}
