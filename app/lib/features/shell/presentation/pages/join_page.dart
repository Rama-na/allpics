import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../guest/presentation/widgets/join_event_body.dart';

/// Shell page 2: join an event by code (QR deep links use the standalone
/// /join route; this page covers in-app joining).
class JoinPage extends StatelessWidget {
  const JoinPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // Clears the shell's floating top overlay.
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 72, AppSpacing.md, 0),
            child: Text('Join an event', style: theme.textTheme.headlineSmall),
          ),
          Expanded(
            child: JoinEventBody(
              onJoined: (joined) => context.pushNamed(
                AppRoute.guestEvent,
                pathParameters: {'eventId': joined.event.id},
                extra: joined,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
