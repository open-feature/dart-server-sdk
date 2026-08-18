import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk_experimental.dart';

void main() {
  final api = createIsolatedOpenFeatureAPI();
  api.setProvider(InMemoryProvider({'web-compatible': true}));
  api.getClient().getBooleanValue('web-compatible', false);
}
