

import 'domain.dart';

class DomainManager {
  final Map<String, Domain> _clientDomains = {};

  // Bind a client to a provider
  void bindClientToProvider(String clientId, String providerName) {
    _clientDomains[clientId] = Domain(clientId, providerName);
  }

  // Get the provider name associated with a client
  String? getProviderForClient(String clientId) {
    return _clientDomains[clientId]?.providerName;
  }
}
