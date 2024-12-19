import 'package:open_feature_dart_server_sdk/domain_manager.dart';
import 'package:test/test.dart';
// Update with the correct path

void main() {
  group('DomainManager', () {
    DomainManager? domainManager;

    setUp(() {
      domainManager = DomainManager();
    });

    test('should bind a client to a provider', () {
      domainManager!.bindClientToProvider('client1', 'providerA');
      final providerName = domainManager!.getProviderForClient('client1');
      expect(providerName, equals('providerA'));
    });

    test('should return null for unbound client', () {
      final providerName = domainManager!.getProviderForClient('client2');
      expect(providerName, isNull);
    });

    test('should update provider binding for a client', () {
      domainManager!.bindClientToProvider('client1', 'providerA');
      domainManager!.bindClientToProvider('client1', 'providerB');
      final providerName = domainManager!.getProviderForClient('client1');
      expect(providerName, equals('providerB'));
    });
  });
}
