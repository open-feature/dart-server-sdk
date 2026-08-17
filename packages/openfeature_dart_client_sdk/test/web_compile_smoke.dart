import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

void main() {
  final api = OpenFeatureAPI.createIsolated();
  api.setProvider(InMemoryProvider({'web-compatible': true}));
  api.getClient().getBooleanValue('web-compatible', false);
}
