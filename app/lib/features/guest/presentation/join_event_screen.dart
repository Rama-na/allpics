import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../domain/joinable_event.dart';
import 'controllers/join_flow_controller.dart';
import 'widgets/event_preview_card.dart';

/// Guest entry point: QR deep links land here with [initialCode] prefilled;
/// manual entry types the 6-char event code.
class JoinEventScreen extends ConsumerStatefulWidget {
  const JoinEventScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<JoinEventScreen> createState() => _JoinEventScreenState();
}

class _JoinEventScreenState extends ConsumerState<JoinEventScreen> {
  final _codeFormKey = GlobalKey<FormState>();
  final _joinFormKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.initialCode ?? '');
    // Deep link: look up immediately without requiring a tap.
    final initial = widget.initialCode;
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(joinFlowControllerProvider.notifier).lookup(initial);
      });
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _lookup() {
    if (!_codeFormKey.currentState!.validate()) return;
    ref.read(joinFlowControllerProvider.notifier).lookup(_code.text);
  }

  void _join() {
    if (!_joinFormKey.currentState!.validate()) return;
    ref
        .read(joinFlowControllerProvider.notifier)
        .join(name: _name.text, phone: _phone.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(joinFlowControllerProvider);

    ref.listen(joinFlowControllerProvider, (_, next) {
      if (next is Joined) {
        context.goNamed(
          AppRoute.guestEvent,
          pathParameters: {'eventId': next.event.id},
          extra: next,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join an event'),
        leading: BackButton(
          onPressed: () {
            ref.read(joinFlowControllerProvider.notifier).reset();
            context.goNamed(AppRoute.signIn);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: switch (state) {
                JoinIdle() || JoinFailed() => _codeStep(state),
                JoinLookingUp() => const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xxl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                JoinPreview() => _nameStep(state),
                Joined() => const SizedBox.shrink(), // navigating away
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _codeStep(JoinFlowState state) {
    final theme = Theme.of(context);
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enter the event code', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Scan the QR code or type the code shared by your host.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'Event code',
            controller: _code,
            hint: 'e.g. K3XR7P',
            validator: Validators.eventCode,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.qr_code_rounded,
            onFieldSubmitted: (_) => _lookup(),
          ),
          if (state is JoinFailed) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              state.message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Find event', onPressed: _lookup),
        ],
      ),
    );
  }

  Widget _nameStep(JoinPreview state) {
    final theme = Theme.of(context);
    final JoinableEvent event = state.event;
    return Form(
      key: _joinFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EventPreviewCard(event: event),
          const SizedBox(height: AppSpacing.lg),
          Text('Who\'s uploading?', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your name appears next to your photos. No account needed.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'Your name',
            controller: _name,
            hint: 'Rahul',
            validator: Validators.name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.person_outline_rounded,
            enabled: !state.isJoining,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Phone (optional)',
            controller: _phone,
            hint: '+91 98765 43210',
            validator: Validators.optionalPhone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.phone_outlined,
            onFieldSubmitted: (_) => _join(),
            enabled: !state.isJoining,
          ),
          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              state.error!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: event.isFull ? 'Album is full' : 'Join event',
            isLoading: state.isJoining,
            onPressed: event.isFull ? null : _join,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Different event? Change code',
            variant: AppButtonVariant.text,
            onPressed: state.isJoining
                ? null
                : () => ref.read(joinFlowControllerProvider.notifier).reset(),
          ),
        ],
      ),
    );
  }
}
