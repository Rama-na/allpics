import 'package:allpics/features/events/domain/event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> row({int photos = 3, int videos = 1, int limit = 10}) =>
      {
        'id': 'e1',
        'host_id': 'h1',
        'type': 'wedding',
        'status': 'active',
        'title': 'Test',
        'description': '',
        'event_date': '2026-08-01',
        'location': 'Pune',
        'cover_url': null,
        'event_code': 'ABC234',
        'share_slug': 'abc234-xyz',
        'photo_limit': limit,
        'expires_at':
            DateTime.now().add(const Duration(days: 10)).toIso8601String(),
        'guest_count': 2,
        'photo_count': photos,
        'video_count': videos,
        'bytes_used': 1024,
        'created_at': DateTime.now().toIso8601String(),
      };

  test('fromMap parses a full row', () {
    final event = Event.fromMap(row());
    expect(event.type, EventType.wedding);
    expect(event.status, EventStatus.active);
    expect(event.eventDate, DateTime(2026, 8, 1));
    expect(event.uploadsUsed, 4);
    expect(event.uploadsRemaining, 6);
    expect(event.isFull, isFalse);
    expect(event.daysUntilExpiry, inInclusiveRange(9, 10));
  });

  test('quota helpers: full event', () {
    final event = Event.fromMap(row(photos: 9, videos: 1));
    expect(event.isFull, isTrue);
    expect(event.uploadsRemaining, 0);
  });

  test('share link uses the slug', () {
    final event = Event.fromMap(row());
    expect(event.shareLink('https://allpics.app'),
        'https://allpics.app/j/abc234-xyz');
  });

  test('unknown enum values fall back safely', () {
    expect(EventType.fromDb('weird'), EventType.custom);
    expect(EventStatus.fromDb(null), EventStatus.active);
  });
}
