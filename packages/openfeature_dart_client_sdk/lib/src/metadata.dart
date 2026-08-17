import 'immutable.dart';

/// Immutable client metadata.
final class ClientMetadata {
  const ClientMetadata({this.domain});

  /// The domain used to bind this client to a provider.
  final String? domain;

  /// Alias retained for SDKs and applications that use the earlier term.
  String? get name => domain;
}

/// Immutable provider metadata.
final class ProviderMetadata {
  const ProviderMetadata({required this.name});

  final String name;
}

/// Creates an immutable OpenFeature flag metadata record.
Map<String, Object> flagMetadata([Map<String, Object> values = const {}]) =>
    immutableMetadata(values, path: 'flagMetadata');
