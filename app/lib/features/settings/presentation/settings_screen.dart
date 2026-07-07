import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/profile.dart';
import '../providers.dart';

/// Host settings: profile, appearance, notifications, legal, account.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, Profile profile) async {
    final controller = TextEditingController(text: profile.fullName);
    final formKey = GlobalKey<FormState>();
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            validator: Validators.name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName == profile.fullName) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(fullName: newName);
      ref.invalidate(profileProvider);
    } on AppException catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  Future<void> _setTheme(
      BuildContext context, WidgetRef ref, ThemeMode mode) async {
    ref.read(themeModeProvider.notifier).set(mode); // instant, local-first
    try {
      await ref.read(profileRepositoryProvider).updateProfile(theme: mode.name);
    } on AppException {
      // Server sync is best-effort; the local choice already applied.
    }
  }

  Future<void> _toggleNotification(
    BuildContext context,
    WidgetRef ref, {
    bool? guestJoined,
    bool? newUploads,
    bool? expiry,
  }) async {
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            notifyGuestJoined: guestJoined,
            notifyNewUploads: newUploads,
            notifyExpiry: expiry,
          );
      ref.invalidate(profileProvider);
    } on AppException catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'Your profile, all your events, and every photo in them will be '
          'permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(profileRepositoryProvider).deleteAccount();
      await ref.read(authControllerProvider.notifier).signOut();
      if (context.mounted) context.goNamed(AppRoute.signIn);
    } on AppException catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profileAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is AppException
              ? error.message
              : 'Could not load your profile.',
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // ---- Profile ----
            Text('Profile', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(
                    profile.fullName.isEmpty ? '(no name)' : profile.fullName),
                subtitle:
                    profile.email == null ? null : Text(profile.email!),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () => _editName(context, ref, profile),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ---- Appearance ----
            Text('Appearance', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded),
                        label: Text('System')),
                    ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded),
                        label: Text('Light')),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded),
                        label: Text('Dark')),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (selection) =>
                      _setTheme(context, ref, selection.first),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ---- Notifications ----
            Text('Notifications', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Guest joined'),
                    value: profile.notifyGuestJoined,
                    onChanged: (v) =>
                        _toggleNotification(context, ref, guestJoined: v),
                  ),
                  SwitchListTile(
                    title: const Text('New uploads'),
                    value: profile.notifyNewUploads,
                    onChanged: (v) =>
                        _toggleNotification(context, ref, newUploads: v),
                  ),
                  SwitchListTile(
                    title: const Text('Album expiring'),
                    value: profile.notifyExpiry,
                    onChanged: (v) =>
                        _toggleNotification(context, ref, expiry: v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ---- Payments & legal ----
            Text('More', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('Payment history'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.pushNamed(AppRoute.paymentHistory),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy policy'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.pushNamed(AppRoute.privacy),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ---- Account ----
            Text('Account', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('Sign out'),
                    onTap: () async {
                      await ref
                          .read(authControllerProvider.notifier)
                          .signOut();
                      if (context.mounted) {
                        context.goNamed(AppRoute.signIn);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.delete_forever_rounded,
                        color: theme.colorScheme.error),
                    title: Text('Delete account',
                        style: TextStyle(color: theme.colorScheme.error)),
                    onTap: () => _deleteAccount(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
