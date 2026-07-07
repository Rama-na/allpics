import 'package:allpics/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.email', () {
    test('accepts valid emails', () {
      expect(Validators.email('a@b.co'), isNull);
      expect(Validators.email('user.name+tag@example.co.in'), isNull);
    });
    test('rejects invalid emails', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('requires 8+ characters', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('longenough'), isNull);
    });
  });

  group('Validators.name', () {
    test('requires non-empty, caps at 80', () {
      expect(Validators.name(''), isNotNull);
      expect(Validators.name('  '), isNotNull);
      expect(Validators.name('Priya'), isNull);
      expect(Validators.name('x' * 81), isNotNull);
    });
  });

  group('Validators.optionalPhone', () {
    test('empty is valid', () {
      expect(Validators.optionalPhone(''), isNull);
      expect(Validators.optionalPhone(null), isNull);
    });
    test('validates format when provided', () {
      expect(Validators.optionalPhone('+91 98765 43210'), isNull);
      expect(Validators.optionalPhone('abc'), isNotNull);
    });
  });

  group('Validators.eventCode', () {
    test('requires 6+ characters', () {
      expect(Validators.eventCode(''), isNotNull);
      expect(Validators.eventCode('K3X'), isNotNull);
      expect(Validators.eventCode('K3XR7P'), isNull);
    });
  });
}
