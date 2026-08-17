/// Experimental OpenFeature Dart client APIs.
library;

import 'openfeature_dart_client_sdk.dart';

export 'openfeature_dart_client_sdk.dart';

/// Creates an API instance isolated from the process-wide singleton.
OpenFeatureAPI createIsolatedOpenFeatureAPI() =>
    OpenFeatureAPI.createIsolated();
