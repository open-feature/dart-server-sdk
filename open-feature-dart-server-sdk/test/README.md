## TEST USE CASE Protocols

To keep production code clean and focused on functionality, there are no Test-Only Methods in Production Code: 

In order to keep production code clean, we recommend using the following test method:

1.  Dependency Injection for the Singleton Instance

```class OpenFeatureAPI {
  static final OpenFeatureAPI _instance = OpenFeatureAPI._internal();

  OpenFeatureAPI._internal(); // Private constructor

  factory OpenFeatureAPI() {
    return _instance;
  }

  // Singleton logic...
}
```

Encapsulation of Test Logic: Test-specific behavior is isolated, making your production code less error-prone.
Extensible Testing: Mocking or dependency injection allows you to simulate various scenarios without altering production logic.