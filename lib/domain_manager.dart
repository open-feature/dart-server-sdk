import 'dart:async';
import 'domain.dart';

class DomainValidationException implements Exception {
  final String message;
  DomainValidationException(this.message);
}

class DomainManager {
  final Map<String, Domain> _domains = {};
  final Map<String, String> _clientDomainBindings = {};
  final StreamController<Domain> _domainUpdates =
      StreamController<Domain>.broadcast();

  Stream<Domain> get domainUpdates => _domainUpdates.stream;

  void bindClientToProvider(
    String clientId,
    String providerName, {
    DomainConfiguration? config,
    String? parentDomainId,
  }) {
    final domainConfig = config ?? DomainConfiguration(name: clientId);

    if (!domainConfig.validate()) {
      throw DomainValidationException('Invalid domain configuration');
    }

    Domain? parentDomain;
    if (parentDomainId != null) {
      parentDomain = _domains[parentDomainId];
      if (parentDomain == null) {
        throw DomainValidationException('Parent domain not found');
      }
    }

    final domain = Domain(
      clientId,
      providerName,
      config: domainConfig,
      parent: parentDomain,
    );

    _domains[clientId] = domain;
    _clientDomainBindings[clientId] = providerName;
    _domainUpdates.add(domain);
  }

  String? getProviderForClient(String clientId) {
    final domain = _domains[clientId];
    if (domain == null) return _clientDomainBindings[clientId];

    // Check inheritance chain
    Domain? current = domain;
    while (current != null) {
      if (current.providerName.isNotEmpty) {
        return current.providerName;
      }
      current = current.parent;
    }
    return null;
  }

  Domain? getDomain(String clientId) => _domains[clientId];

  List<Domain> getChildDomains(String domainId) {
    final domain = _domains[domainId];
    if (domain == null) return [];
    return domain.children;
  }

  Map<String, dynamic> getDomainSettings(String clientId) {
    final domain = _domains[clientId];
    if (domain == null) return {};
    return domain.effectiveSettings;
  }

  void updateDomainSettings(String clientId, Map<String, dynamic> settings) {
    final domain = _domains[clientId];
    if (domain == null) return;

    final newConfig = DomainConfiguration(
      name: domain.config.name,
      settings: {...domain.config.settings, ...settings},
      parentDomain: domain.config.parentDomain,
      childDomains: domain.config.childDomains,
    );

    if (!newConfig.validate()) {
      throw DomainValidationException('Invalid settings update');
    }

    final updatedDomain = Domain(
      clientId,
      domain.providerName,
      config: newConfig,
      parent: domain.parent,
    );

    _domains[clientId] = updatedDomain;
    _domainUpdates.add(updatedDomain);
  }

  void dispose() {
    _domainUpdates.close();
  }
}
