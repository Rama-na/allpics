import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../auth/presentation/widgets/auth_sheet.dart';
import '../../auth/providers.dart';
import '../domain/event.dart';
import 'controllers/event_form_controller.dart';
import 'widgets/event_card.dart';

/// Create a new event, or edit an existing one when [existing] is provided.
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key, this.existing});

  final Event? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late EventType _type;
  DateTime? _date;
  Uint8List? _coverBytes;
  String _coverExtension = 'jpg';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _type = e?.type ?? EventType.wedding;
    _date = e?.eventDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickCover() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last.toLowerCase();
    setState(() {
      _coverBytes = bytes;
      _coverExtension = ['jpg', 'jpeg', 'png', 'webp'].contains(ext)
          ? ext
          : 'jpg';
    });
  }

  /// Try-first: the wizard is open to everyone; a host account is required
  /// only at the moment of publishing. The form survives under the modal.
  Future<bool> _ensureHostSession() async {
    final user = ref.read(currentUserProvider);
    if (user != null && user.isHost) return true;
    return showAuthSheet(context);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!widget.isEditing) {
      final ok = await _ensureHostSession();
      if (!ok || !mounted) return;
    }
    final draft = EventDraft(
      type: _type,
      title: _title.text,
      description: _description.text,
      eventDate: _date,
      location: _location.text,
    );
    final controller = ref.read(eventFormControllerProvider.notifier);
    final event = widget.isEditing
        ? await controller.update(
            widget.existing!.id,
            draft,
            coverBytes: _coverBytes,
            coverExtension: _coverExtension,
          )
        : await controller.create(
            draft,
            coverBytes: _coverBytes,
            coverExtension: _coverExtension,
          );
    if (event != null && mounted) {
      context.goNamed(
        AppRoute.eventDashboard,
        pathParameters: {'eventId': event.id},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(eventFormControllerProvider).isLoading;

    ref.listen(eventFormControllerProvider, (_, next) {
      final error = next.error;
      if (error is AppException) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit event' : 'Create event'),
        leading: BackButton(
          onPressed: () {
            if (widget.isEditing) {
              context.goNamed(
                AppRoute.eventDashboard,
                pathParameters: {'eventId': widget.existing!.id},
              );
              return;
            }
            // Signed-out visitors came from the landing page; hosts from home.
            final user = ref.read(currentUserProvider);
            context.goNamed(
              user != null && user.isHost ? AppRoute.home : AppRoute.landing,
            );
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Event type', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: EventType.values.map((type) {
                        final selected = type == _type;
                        return ChoiceChip(
                          avatar: Icon(
                            eventTypeIcon(type),
                            size: 18,
                            color: selected
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          label: Text(type.label),
                          selected: selected,
                          onSelected: isLoading
                              ? null
                              : (_) => setState(() => _type = type),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Title',
                      controller: _title,
                      hint: "e.g. Priya & Rahul's Wedding",
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Title is required.'
                          : (v.trim().length > 120
                                ? 'Title is too long.'
                                : null),
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Description (optional)',
                      controller: _description,
                      hint: 'Tell guests what to capture',
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Location (optional)',
                      controller: _location,
                      hint: 'e.g. Bengaluru',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.place_outlined,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Date (optional)', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(
                        _date == null
                            ? 'Pick a date'
                            : DateFormat.yMMMMd().format(_date!),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Cover image (optional)',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isLoading ? null : _pickCover,
                            icon: const Icon(Icons.image_outlined, size: 18),
                            label: Text(
                              _coverBytes == null
                                  ? 'Choose from gallery'
                                  : 'Cover selected',
                            ),
                          ),
                        ),
                        if (_coverBytes != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            tooltip: 'Remove cover',
                            onPressed: isLoading
                                ? null
                                : () => setState(() => _coverBytes = null),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ],
                    ),
                    if (_coverBytes != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        child: Image.memory(
                          _coverBytes!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: widget.isEditing ? 'Save changes' : 'Create event',
                      isLoading: isLoading,
                      onPressed: _submit,
                    ),
                    if (!widget.isEditing) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Starts on the Free plan (100 uploads, 7 days). '
                        'Upgrade anytime to keep the album longer.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
