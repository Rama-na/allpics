import 'package:allpics/core/errors/app_exception.dart';
import 'package:allpics/features/events/data/supabase_events_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// The two failure modes behind the historical "Something went wrong" on
/// create event must surface as actionable messages.
void main() {
  group('mapPlanLookupError', () {
    test('PGRST116 (no plan rows) → backend-not-provisioned', () {
      final mapped = mapPlanLookupError(
        const sb.PostgrestException(message: 'no rows', code: 'PGRST116'),
      );
      expect(mapped, isA<BackendNotProvisionedException>());
      expect(mapped.message, contains('plan catalog'));
    });

    test('other Postgrest errors stay generic', () {
      final mapped = mapPlanLookupError(
        const sb.PostgrestException(message: 'boom', code: '500'),
      );
      expect(mapped, isA<UnexpectedException>());
    });
  });

  group('mapCreateEventError', () {
    test('42501 (RLS: missing profile) → auth guidance', () {
      final mapped = mapCreateEventError(
        const sb.PostgrestException(message: 'rls', code: '42501'),
      );
      expect(mapped, isA<AuthException>());
      expect(mapped.message, contains('profile'));
    });

    test('other Postgrest errors stay generic', () {
      final mapped = mapCreateEventError(
        const sb.PostgrestException(message: 'boom', code: '23505'),
      );
      expect(mapped, isA<UnexpectedException>());
    });
  });
}
