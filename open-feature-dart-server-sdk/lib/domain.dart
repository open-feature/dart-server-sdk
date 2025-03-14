class DomainConfiguration {
  final String name;
  final Map<String, dynamic> settings;
  final String? parentDomain;
  final List<String> childDomains;

  DomainConfiguration({
    required this.name,
    this.settings = const {},
    this.parentDomain,
    this.childDomains = const [],
  });

  bool validate() {
    if (name.isEmpty) return false;
    if (parentDomain?.isEmpty ?? false) return false;
    return true;
  }
}

class Domain {
  final String clientId;
  final String providerName;
  final DomainConfiguration config;
  final Domain? parent;
  final List<Domain> children = [];

  Domain(
    this.clientId,
    this.providerName, {
    required this.config,
    this.parent,
  }) {
    if (parent != null) {
      parent!.children.add(this);
    }
  }

  Map<String, dynamic> get effectiveSettings {
    final parentSettings = parent?.effectiveSettings ?? {};
    return {
      ...parentSettings,
      ...config.settings,
    };
  }

  bool isChildOf(Domain other) {
    var current = parent;
    while (current != null) {
      if (current == other) return true;
      current = current.parent;
    }
    return false;
  }
}
