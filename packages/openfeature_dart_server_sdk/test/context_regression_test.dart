import 'package:test/test.dart';
import '../lib/evaluation_context.dart';
import '../lib/open_feature_api.dart';
import '../lib/transaction_context.dart';

void main() {
  test('global adapter snapshots nested caller data', () {
    final nested = {'tier': 'standard'};
    final context = OpenFeatureEvaluationContext({'account': nested});
    nested['tier'] = 'premium';
    expect(context.attributes['account']['tier'], 'standard');
  });

  test('transaction snapshots nested caller data', () {
    final groups = ['first'];
    final context = TransactionContext(
      transactionId: 'request',
      attributes: {'groups': groups},
    );
    groups.add('second');
    expect(context.effectiveAttributes['groups'], ['first']);
  });

  test('merge preserves both complete parent chains', () {
    const left = EvaluationContext(
      attributes: {},
      parent: EvaluationContext(
        attributes: {},
        parent: EvaluationContext(attributes: {'left': true}),
      ),
    );
    const right = EvaluationContext(
      attributes: {},
      parent: EvaluationContext(
        targetingKey: 'right',
        attributes: {'right': true},
      ),
    );
    expect(left.merge(right).toProviderContext(), {
      'left': true,
      'right': true,
      'targetingKey': 'right',
    });
  });
}
