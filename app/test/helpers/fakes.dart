import 'dart:async';
import 'dart:typed_data';

import 'package:allpics/core/errors/app_exception.dart';
import 'package:allpics/features/album/domain/album_item.dart';
import 'package:allpics/features/album/domain/album_repository.dart';
import 'package:allpics/features/auth/domain/auth_repository.dart';
import 'package:allpics/features/auth/domain/auth_user.dart';
import 'package:allpics/features/events/domain/event.dart';
import 'package:allpics/features/events/domain/events_repository.dart';
import 'package:allpics/features/guest/domain/join_repository.dart';
import 'package:allpics/features/guest/domain/joinable_event.dart';
import 'package:allpics/features/notifications/domain/app_notification.dart';
import 'package:allpics/features/notifications/domain/notifications_repository.dart';
import 'package:allpics/features/payments/domain/payment_models.dart';
import 'package:allpics/features/payments/domain/payments_repository.dart';
import 'package:allpics/features/uploads/domain/uploads_repository.dart';

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

/// In-memory [UploadsRepository] with scriptable failures.
class FakeUploadsRepository implements UploadsRepository {
  /// File names that should fail this many times before succeeding.
  final failuresByFileName = <String, int>{};

  /// When set, every slot request throws quota-exceeded.
  bool quotaFull = false;

  final confirmed = <String>[];
  int slotCounter = 0;

  @override
  Future<UploadSlot> requestSlot({
    required String eventId,
    required String fileName,
    required String mimeType,
    required int bytes,
  }) async {
    if (quotaFull) throw const QuotaExceededException();
    final remaining = failuresByFileName[fileName] ?? 0;
    if (remaining > 0) {
      failuresByFileName[fileName] = remaining - 1;
      throw const NetworkException();
    }
    slotCounter++;
    return UploadSlot(
      uploadId: 'upload-$slotCounter',
      storagePath: 'media/$eventId/upload-$slotCounter',
      signedUrl: 'https://example.com/signed/$slotCounter',
      token: 'token-$slotCounter',
    );
  }

  @override
  Future<void> uploadBytes({
    required UploadSlot slot,
    required Uint8List bytes,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    await Future<void>.delayed(Duration.zero);
    onProgress?.call(1.0);
  }

  @override
  Future<void> confirmUploaded(String uploadId) async {
    confirmed.add(uploadId);
  }
}

/// In-memory [AlbumRepository] with live favorite toggling.
class FakeAlbumRepository implements AlbumRepository {
  FakeAlbumRepository({List<AlbumItem>? items}) : _items = items ?? [];

  final List<AlbumItem> _items;
  final _itemsController = StreamController<List<AlbumItem>>.broadcast();
  final _favorites = <String>{};
  final _favController = StreamController<Set<String>>.broadcast();

  static AlbumItem buildItem({
    required String id,
    String eventId = 'event-1',
    String guestName = 'Anita',
    bool isVideo = false,
    String caption = '',
    DateTime? createdAt,
  }) =>
      AlbumItem(
        id: id,
        eventId: eventId,
        guestId: 'guest-$guestName',
        guestName: guestName,
        isVideo: isVideo,
        storagePath: 'media/$eventId/$id.jpg',
        caption: caption,
        createdAt: createdAt ?? DateTime(2026, 7, 1),
      );

  void addItem(AlbumItem item) {
    _items.add(item);
    _itemsController.add(List.of(_items));
  }

  @override
  Stream<List<AlbumItem>> watchAlbum(String eventId) async* {
    yield _items.where((i) => i.eventId == eventId).toList();
    yield* _itemsController.stream
        .map((all) => all.where((i) => i.eventId == eventId).toList());
  }

  @override
  Stream<Set<String>> watchFavoriteIds() async* {
    yield Set.of(_favorites);
    yield* _favController.stream;
  }

  @override
  Future<void> setFavorite(String uploadId, bool favorite) async {
    favorite ? _favorites.add(uploadId) : _favorites.remove(uploadId);
    _favController.add(Set.of(_favorites));
  }

  @override
  Future<String> signedMediaUrl(String path) async =>
      'https://example.com/$path';

  @override
  Future<Uint8List> downloadBytes(String path) async =>
      Uint8List.fromList(List.filled(64, 1));

  void dispose() {
    _itemsController.close();
    _favController.close();
  }
}

/// In-memory [PaymentsRepository].
class FakePaymentsRepository implements PaymentsRepository {
  bool failOrders = false;
  final orders = <(String eventId, String planCode)>[];
  List<Payment> history = [];

  static const plans = [
    Plan(id: 'p0', code: 'free', name: 'Free', priceInr: 0, photoLimit: 10, storageDays: 30, sortOrder: 0),
    Plan(id: 'p1', code: 'basic', name: 'Basic', priceInr: 15900, photoLimit: 100, storageDays: 30, sortOrder: 1),
    Plan(id: 'p2', code: 'plus', name: 'Plus', priceInr: 29900, photoLimit: 500, storageDays: 30, sortOrder: 2),
    Plan(id: 'p3', code: 'premium', name: 'Premium', priceInr: 59900, photoLimit: 1000, storageDays: 180, sortOrder: 3),
  ];

  @override
  Future<List<Plan>> fetchPlans() async => plans;

  @override
  Future<RazorpayOrder> createOrder({
    required String eventId,
    required String planCode,
  }) async {
    if (failOrders) {
      throw const ValidationException('Could not start the payment.');
    }
    orders.add((eventId, planCode));
    final plan = plans.firstWhere((p) => p.code == planCode);
    return RazorpayOrder(
      orderId: 'order_${orders.length}',
      amountInr: plan.priceInr,
      currency: 'INR',
      keyId: 'rzp_test_key',
      planName: plan.name,
      eventTitle: 'Goa Trip',
    );
  }

  @override
  Future<List<Payment>> fetchPayments() async => history;
}

/// Scriptable [CheckoutGateway] — succeeds, fails, or cancels on demand.
class FakeCheckoutGateway implements CheckoutGateway {
  CheckoutResult next = const CheckoutResult.success('pay_1');
  final opened = <RazorpayOrder>[];

  @override
  Future<CheckoutResult> openCheckout({
    required RazorpayOrder order,
    String? prefillEmail,
  }) async {
    opened.add(order);
    return next;
  }
}

/// In-memory [NotificationsRepository] with live read/delete semantics.
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({List<AppNotification>? initial})
      : _items = initial ?? [];

  final List<AppNotification> _items;
  final _controller = StreamController<List<AppNotification>>.broadcast();
  final registeredTokens = <String>[];

  static AppNotification build({
    required String id,
    AppNotificationType type = AppNotificationType.guestJoined,
    String title = 'Anita joined Goa Trip',
    String body = 'They can now add photos to the album.',
    String? eventId = 'event-1',
    bool read = false,
  }) =>
      AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        data: eventId == null ? const {} : {'event_id': eventId},
        createdAt: DateTime(2026, 7, 1, 12),
        readAt: read ? DateTime(2026, 7, 1, 13) : null,
      );

  void _emit() => _controller.add(List.of(_items));

  @override
  Stream<List<AppNotification>> watchNotifications() async* {
    yield List.of(_items);
    yield* _controller.stream;
  }

  AppNotification _copyRead(AppNotification n) => AppNotification(
        id: n.id,
        type: n.type,
        title: n.title,
        body: n.body,
        data: n.data,
        createdAt: n.createdAt,
        readAt: DateTime.now(),
      );

  @override
  Future<void> markRead(String notificationId) async {
    final index = _items.indexWhere((n) => n.id == notificationId);
    if (index >= 0) {
      _items[index] = _copyRead(_items[index]);
      _emit();
    }
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) _items[i] = _copyRead(_items[i]);
    }
    _emit();
  }

  @override
  Future<void> delete(String notificationId) async {
    _items.removeWhere((n) => n.id == notificationId);
    _emit();
  }

  @override
  Future<void> registerPushToken(String token) async {
    registeredTokens.add(token);
  }

  void dispose() => _controller.close();
}

/// Scriptable [PushGateway].
class FakePushGateway implements PushGateway {
  FakePushGateway({this.token});

  final String? token;
  final _refreshController = StreamController<String>.broadcast();

  @override
  Future<String?> obtainToken() async => token;

  @override
  Stream<String> get onTokenRefresh => _refreshController.stream;

  void refresh(String newToken) => _refreshController.add(newToken);

  void dispose() => _refreshController.close();
}
