import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/state_views.dart';
import '../../events/presentation/widgets/stat_tile.dart';
import '../domain/admin_models.dart';
import '../providers.dart';

/// Role-gated admin panel (built primarily for the Flutter Web target).
/// Tabs: Overview · Users · Events · Flags.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);

    return isAdminAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: ErrorView(
          message: 'Could not verify admin access.',
          onRetry: () => ref.invalidate(isAdminProvider),
        ),
      ),
      data: (isAdmin) {
        if (!isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin')),
            body: const ErrorView(
              icon: Icons.lock_outline_rounded,
              message: 'Admin access required.',
            ),
          );
        }
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Admin'),
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Users'),
                  Tab(text: 'Events'),
                  Tab(text: 'Flags'),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                _OverviewTab(),
                _UsersTab(),
                _EventsTab(),
                _FlagsTab(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================ Overview

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    return statsAsync.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        message: error is AppException ? error.message : 'Could not load stats.',
        onRetry: () => ref.invalidate(adminStatsProvider),
      ),
      data: (stats) => RefreshIndicator(
        onRefresh: () async => ref.refresh(adminStatsProvider.future),
        child: GridView.count(
          padding: const EdgeInsets.all(AppSpacing.md),
          crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.8,
          children: [
            StatTile(
                icon: Icons.people_outline_rounded,
                label: 'Hosts',
                value: '${stats.hosts}'),
            StatTile(
                icon: Icons.celebration_rounded,
                label: 'Active events',
                value: '${stats.eventsActive}/${stats.eventsTotal}'),
            StatTile(
                icon: Icons.group_add_rounded,
                label: 'Guests',
                value: '${stats.guests}'),
            StatTile(
                icon: Icons.photo_library_outlined,
                label: 'Uploads',
                value: '${stats.uploads}'),
            StatTile(
                icon: Icons.cloud_outlined,
                label: 'Storage',
                value: stats.storageLabel),
            StatTile(
                icon: Icons.currency_rupee_rounded,
                label: 'Revenue',
                value: stats.revenueLabel),
            StatTile(
                icon: Icons.receipt_long_outlined,
                label: 'Payments',
                value: '${stats.paymentsCaptured}'),
            StatTile(
                icon: Icons.memory_rounded,
                label: 'Jobs queued / failed',
                value: '${stats.jobsQueued} / ${stats.jobsFailed}',
                emphasize: stats.jobsFailed > 0),
          ],
        ),
      ),
    );
  }
}

// ============================================================ Users

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  String _search = '';

  Future<void> _toggleBan(AdminUser user) async {
    try {
      await ref
          .read(adminRepositoryProvider)
          .setUserBanned(user.id, !user.isBanned);
      ref.invalidate(adminUsersProvider);
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider(_search));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search name or email',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
            onSubmitted: (q) => setState(() => _search = q),
          ),
        ),
        Expanded(
          child: usersAsync.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: error is AppException
                  ? error.message
                  : 'Could not load users.',
              onRetry: () => ref.invalidate(adminUsersProvider(_search)),
            ),
            data: (users) => users.isEmpty
                ? const EmptyView(
                    icon: Icons.person_search_rounded,
                    title: 'No users found',
                    subtitle: 'Try a different search.')
                : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: Icon(
                          user.isAdmin
                              ? Icons.shield_rounded
                              : Icons.person_outline_rounded,
                          color: user.isBanned
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                        title: Text(
                            user.fullName.isEmpty ? '(no name)' : user.fullName),
                        subtitle: Text(
                            '${user.email} · ${user.eventCount} events'
                            '${user.isBanned ? ' · BANNED' : ''}'),
                        trailing: user.isAdmin
                            ? const Text('admin')
                            : TextButton(
                                onPressed: () => _toggleBan(user),
                                child:
                                    Text(user.isBanned ? 'Unban' : 'Ban'),
                              ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

// ============================================================ Events

class _EventsTab extends ConsumerStatefulWidget {
  const _EventsTab();

  @override
  ConsumerState<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends ConsumerState<_EventsTab> {
  String _search = '';

  Future<void> _delete(AdminEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('"${event.title}" by ${event.hostName} will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteEvent(event.id);
      ref.invalidate(adminEventsProvider);
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(adminEventsProvider(_search));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search event titles',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
            onSubmitted: (q) => setState(() => _search = q),
          ),
        ),
        Expanded(
          child: eventsAsync.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: error is AppException
                  ? error.message
                  : 'Could not load events.',
              onRetry: () => ref.invalidate(adminEventsProvider(_search)),
            ),
            data: (events) => events.isEmpty
                ? const EmptyView(
                    icon: Icons.event_busy_rounded,
                    title: 'No events found',
                    subtitle: 'Try a different search.')
                : ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return ListTile(
                        leading: Icon(
                          event.status == 'active'
                              ? Icons.event_available_rounded
                              : Icons.event_busy_rounded,
                        ),
                        title: Text(event.title),
                        subtitle: Text(
                          '${event.hostName} · ${event.uploadsUsed}/${event.photoLimit} uploads · '
                          '${event.guestCount} guests · expires '
                          '${DateFormat.yMMMd().format(event.expiresAt)}',
                        ),
                        trailing: event.status == 'deleted'
                            ? const Text('deleted')
                            : IconButton(
                                tooltip: 'Delete event',
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () => _delete(event),
                              ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

// ============================================================ Flags

class _FlagsTab extends ConsumerWidget {
  const _FlagsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagsAsync = ref.watch(adminFlagsProvider);
    return flagsAsync.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        message:
            error is AppException ? error.message : 'Could not load flags.',
        onRetry: () => ref.invalidate(adminFlagsProvider),
      ),
      data: (flags) => flags.isEmpty
          ? const EmptyView(
              icon: Icons.flag_outlined,
              title: 'No feature flags',
              subtitle: 'Flags from the seed migration appear here.')
          : ListView.builder(
              itemCount: flags.length,
              itemBuilder: (context, index) {
                final flag = flags[index];
                return SwitchListTile(
                  title: Text(flag.key),
                  value: flag.enabled,
                  onChanged: (enabled) async {
                    try {
                      await ref
                          .read(adminRepositoryProvider)
                          .setFlag(flag.key, enabled);
                      ref.invalidate(adminFlagsProvider);
                    } on AppException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                );
              },
            ),
    );
  }
}
