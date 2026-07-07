import 'dart:async';
import 'dart:typed_data';

import 'package:allpics/core/errors/app_exception.dart';
import 'package:allpics/features/auth/domain/auth_repository.dart';
import 'package:allpics/features/auth/domain/auth_user.dart';
import 'package:allpics/features/events/domain/event.dart';
import 'package:allpics/features/events/domain/events_repository.dart';
import 'package:allpics/features/guest/domain/join_repository.dart';
import 'package:allpics/features/guest/domain/joinable_event.dart';

/// In-memory [AuthRepository] for widget/unit tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? initialUser}) : _current = initialUser;

  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  bool failSignIn = false;
  bool needsEmailConfirmation = false;

  static const host = AuthUser(
    id: 'host-1',
    isAnonymous: false,
    email: 'host@example.com',
    fullName: 'Test Host',
  );

  void _emit(AuthUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (failSignIn) {
      throw const AuthException('Incorrect email or password.');
    }
    _emit(host);
    return host;
  }

  @override
  Future<SignUpResult> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (!needsEmailConfirmation) _emit(host);
    return SignUpResult(needsEmailConfirmation: needsEmailConfirmation);
  }

  @override
  Future<void> signInWithGoogle() async => _emit(host);

  @override
  Future<AuthUser> signInAnonymously() async {
    final existing = _current;
    if (existing != null) return existing;
    const anon = AuthUser(id: 'guest-1', isAnonymous: true);
    _emit(anon);
    return anon;
  }

  @override
  Future<void> signOut() async => _emit(null);

  void dispose() => _controller.close();
}

/// In-memory [JoinRepository]. Knows one event, code `K3XR7P`.
/// Mirrors production behavior: joining creates an anonymous session first.
class FakeJoinRepository implements JoinRepository {
  FakeJoinRepository({this.auth});

  final FakeAuthRepository? auth;

  static const knownCode = 'K3XR7P';

  static const event = JoinableEvent(
    id: 'event-1',
    title: 'Priya & Rahul\'s Wedding',
    description: 'Share your favorite moments!',
    type: 'wedding',
    location: 'Bengaluru',
    photoCount: 12,
    videoCount: 3,
    photoLimit: 500,
    isFull: false,
  );

  final joined = <String, EventGuest>{};

  @override
  Future<JoinableEvent> lookupEvent(String code) async {
    if (code.trim().toUpperCase() == knownCode) return event;
    throw const NotFoundException(
      'No active event found for that code. Check with your host.',
    );
  }

  @override
  Future<EventGuest> joinEvent({
    required String eventId,
    required String name,
    String? phone,
  }) async {
    await auth?.signInAnonymously();
    final guest = EventGuest(
      id: 'guest-row-1',
      eventId: eventId,
      name: name.trim(),
      phone: phone,
    );
    joined[eventId] = guest;
    return guest;
  }

  @override
  Future<EventGuest?> existingMembership(String eventId) async =>
      joined[eventId];
}

/// In-memory [EventsRepository] with live stream semantics.
class FakeEventsRepository implements EventsRepository {
  FakeEventsRepository({List<Event>? initial}) {
    if (initial != null) _events.addAll({for (final e in initial) e.id: e});
  }

  final _events = <String, Event>{};
  final _listController = StreamController<List<Event>>.broadcast();
  int _nextId = 1;
  bool failWrites = false;

  List<Event> get _visible => _events.values
      .where((e) => e.status != EventStatus.deleted)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  void _emit() => _listController.add(_visible);

  static Event buildEvent({
    String id = 'event-1',
    String title = 'Test Event',
    EventType type = EventType.wedding,
    EventStatus status = EventStatus.active,
    int guestCount = 0,
    int photoCount = 0,
    int videoCount = 0,
    int photoLimit = 10,
  }) =>
      Event(
        id: id,
        hostId: 'host-1',
        type: type,
        status: status,
        title: title,
        description: 'A test event',
        location: 'Bengaluru',
        eventCode: 'K3XR7P',
        shareSlug: 'k3xr7p-abcd1234',
        photoLimit: photoLimit,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        guestCount: guestCount,
        photoCount: photoCount,
        videoCount: videoCount,
        bytesUsed: 0,
        createdAt: DateTime.now(),
      );

  @override
  Stream<List<Event>> watchMyEvents() async* {
    yield _visible;
    yield* _listController.stream;
  }

  @override
  Stream<Event> watchEvent(String eventId) async* {
    final event = _events[eventId];
    if (event == null || event.status == EventStatus.deleted) {
      throw const NotFoundException('This event no longer exists.');
    }
    yield event;
    yield* _listController.stream
        .map((_) => _events[eventId])
        .where((e) => e != null && e.status != EventStatus.deleted)
        .cast<Event>();
  }

  @override
  Future<Event> getEvent(String eventId) async {
    final event = _events[eventId];
    if (event == null) {
      throw const NotFoundException('This event no longer exists.');
    }
    return event;
  }

  @override
  Future<Event> createEvent(EventDraft draft) async {
    if (failWrites) {
      throw const UnexpectedException(cause: 'write failure requested');
    }
    final id = 'event-${_nextId++}';
    final event = Event(
      id: id,
      hostId: 'host-1',
      type: draft.type,
      status: EventStatus.active,
      title: draft.title.trim(),
      description: draft.description.trim(),
      eventDate: draft.eventDate,
      location: draft.location.trim(),
      eventCode: 'CODE$_nextId'.padRight(6, 'X').substring(0, 6),
      shareSlug: 'code$_nextId-slug',
      photoLimit: 10,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      guestCount: 0,
      photoCount: 0,
      videoCount: 0,
      bytesUsed: 0,
      createdAt: DateTime.now(),
    );
    _events[id] = event;
    _emit();
    return event;
  }

  @override
  Future<Event> updateEvent(String eventId, EventDraft draft) async {
    final old = await getEvent(eventId);
    final updated = Event(
      id: old.id,
      hostId: old.hostId,
      type: draft.type,
      status: old.status,
      title: draft.title.trim(),
      description: draft.description.trim(),
      eventDate: draft.eventDate,
      location: draft.location.trim(),
      coverPath: old.coverPath,
      eventCode: old.eventCode,
      shareSlug: old.shareSlug,
      photoLimit: old.photoLimit,
      expiresAt: old.expiresAt,
      guestCount: old.guestCount,
      photoCount: old.photoCount,
      videoCount: old.videoCount,
      bytesUsed: old.bytesUsed,
      createdAt: old.createdAt,
    );
    _events[eventId] = updated;
    _emit();
    return updated;
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    final old = await getEvent(eventId);
    _events[eventId] = Event(
      id: old.id,
      hostId: old.hostId,
      type: old.type,
      status: EventStatus.deleted,
      title: old.title,
      description: old.description,
      eventDate: old.eventDate,
      location: old.location,
      coverPath: old.coverPath,
      eventCode: old.eventCode,
      shareSlug: old.shareSlug,
      photoLimit: old.photoLimit,
      expiresAt: old.expiresAt,
      guestCount: old.guestCount,
      photoCount: old.photoCount,
      videoCount: old.videoCount,
      bytesUsed: old.bytesUsed,
      createdAt: old.createdAt,
    );
    _emit();
  }

  @override
  Future<Event> uploadCover({
    required String eventId,
    required Uint8List bytes,
    required String fileExtension,
  }) async =>
      getEvent(eventId);

  @override
  Future<String> signedCoverUrl(String coverPath) async =>
      'https://example.com/$coverPath';

  void dispose() => _listController.close();
}
