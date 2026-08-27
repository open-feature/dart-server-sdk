import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk_experimental.dart';
import 'package:test/test.dart';

void main() {
  test('client SDK evaluates a flag in a browser runtime', () async {
    final api = createIsolatedOpenFeatureAPI();
    addTearDown(api.shutdown);
    await api.setProviderAndWait(InMemoryProvider({'web-compatible': true}));

    expect(api.getClient().getBooleanValue('web-compatible', false), isTrue);
  });
}
