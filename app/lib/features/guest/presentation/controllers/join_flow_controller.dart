import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/join_repository.dart';
import '../../domain/joinable_event.dart';
import '../../providers.dart';

/// Guest join flow: code entry → event preview → name form → joined.
sealed class JoinFlowState {
  const JoinFlowState();
}

class JoinIdle extends JoinFlowState {
  const JoinIdle();
}

class JoinLookingUp extends JoinFlowState {
  const JoinLookingUp();
}

class JoinPreview extends JoinFlowState {
  const JoinPreview(this.event, {this.isJoining = false, this.error});

  final JoinableEvent event;
  final bool isJoining;
  final String? error;
}

class JoinFailed extends JoinFlowState {
  const JoinFailed(this.message);

  final String message;
}

class Joined extends JoinFlowState {
  const Joined(this.event, this.guest);

  final JoinableEvent event;
  final EventGuest guest;
}

class JoinFlowController extends Notifier<JoinFlowState> {
  @override
  JoinFlowState build() => const JoinIdle();

  JoinRepository get _repo => ref.read(joinRepositoryProvider);

  Future<void> lookup(String code) async {
    state = const JoinLookingUp();
    try {
      final event = await _repo.lookupEvent(code);
      // Returning guests skip the name form entirely.
      final existing = await _repo.existingMembership(event.id);
      if (existing != null) {
        state = Joined(event, existing);
      } else {
        state = JoinPreview(event);
      }
    } on AppException catch (e) {
      state = JoinFailed(e.message);
    }
  }

  Future<void> join({required String name, String? phone}) async {
    final current = state;
    if (current is! JoinPreview) return;
    state = JoinPreview(current.event, isJoining: true);
    try {
      final guest = await _repo.joinEvent(
        eventId: current.event.id,
        name: name,
        phone: phone,
      );
      state = Joined(current.event, guest);
    } on AppException catch (e) {
      state = JoinPreview(current.event, error: e.message);
    }
  }

  void reset() => state = const JoinIdle();
}

final joinFlowControllerProvider =
    NotifierProvider<JoinFlowController, JoinFlowState>(JoinFlowController.new);
