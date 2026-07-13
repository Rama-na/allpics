import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import 'controllers/join_flow_controller.dart';
import 'widgets/join_event_body.dart';

/// Guest entry point: QR deep links land here with [initialCode] prefilled;
/// manual entry types the 6-char event code. The home shell embeds the same
/// [JoinEventBody] on its Join page.
class JoinEventScreen extends ConsumerWidget {
  const JoinEventScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join an event'),
        leading: BackButton(
          onPressed: () {
            ref.read(joinFlowControllerProvider.notifier).reset();
            context.goNamed(AppRoute.home);
          },
        ),
      ),
      body: SafeArea(
        child: JoinEventBody(
          initialCode: initialCode,
          onJoined: (joined) => context.goNamed(
            AppRoute.guestEvent,
            pathParameters: {'eventId': joined.event.id},
            extra: joined,
          ),
        ),
      ),
    );
  }
}
