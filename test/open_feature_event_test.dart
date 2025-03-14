import 'package:test/test.dart';
import '../lib/open_feature_event.dart';

void main() {
  group('OpenFeatureEvent', () {
    test('constructs correctly', () {
      final event = OpenFeatureEvent(
        OpenFeatureEventType.flagUpdated,
        'Flag updated',
        data: {'flagKey': 'test-flag'},
      );

      expect(event.type, equals(OpenFeatureEventType.flagUpdated));
      expect(event.message, equals('Flag updated'));
      expect(event.data['flagKey'], equals('test-flag'));
    });

    test('constructs without data', () {
      final event = OpenFeatureEvent(
        OpenFeatureEventType.error,
        'Error occurred',
      );

      expect(event.type, equals(OpenFeatureEventType.error));
      expect(event.message, equals('Error occurred'));
      expect(event.data, isNull);
    });
  });
}
