import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../providers.dart';
import '../controllers/auth_controller.dart';

/// Deferred sign-up: shown the moment an anonymous visitor publishes their
/// first event. Resolves `true` once a host session exists.
Future<bool> showAuthSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _AuthSheetBody(),
  );
  return result ?? false;
}

class _AuthSheetBody extends ConsumerStatefulWidget {
  const _AuthSheetBody();

  @override
  ConsumerState<_AuthSheetBody> createState() => _AuthSheetBodyState();
}

class _AuthSheetBodyState extends ConsumerState<_AuthSheetBody> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = true;
  bool _popped = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// The sheet can resolve from two paths (form submit and the auth-state
  /// listener for Google OAuth) — make sure it pops exactly once.
  void _popOnce(bool result) {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop(result);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(authControllerProvider.notifier);
    if (_isSignUp) {
      final result = await controller.signUp(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (result == null || !mounted) return;
      if (result.needsEmailConfirmation) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Almost there — confirm your email, then sign in.'),
        ));
        setState(() => _isSignUp = false);
        return;
      }
      _popOnce(true);
    } else {
      final ok = await controller.signIn(
        email: _email.text,
        password: _password.text,
      );
      if (ok) _popOnce(true);
    }
  }

  Future<void> _google() async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
    // Session lands via deep link; authStateProvider listener pops the sheet.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(authControllerProvider).isLoading;

    ref.listen(authControllerProvider, (_, next) {
      final error = next.error;
      if (error is AppException) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    });

    // Google OAuth completes out-of-band — close the sheet when a host
    // session appears.
    ref.listen(authStateProvider, (_, next) {
      final user = next.value;
      if (user != null && user.isHost) _popOnce(true);
    });

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isSignUp ? 'Save your event' : 'Welcome back',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _isSignUp
                    ? 'Create a free account to publish your event. '
                        'Free plan included — 100 uploads, 7 days, no card.'
                    : 'Sign in to publish your event.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Sign up')),
                  ButtonSegment(value: false, label: Text('Sign in')),
                ],
                selected: {_isSignUp},
                onSelectionChanged: isLoading
                    ? null
                    : (selection) =>
                        setState(() => _isSignUp = selection.first),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_isSignUp) ...[
                AppTextField(
                  label: 'Full name',
                  controller: _name,
                  hint: 'Priya Sharma',
                  validator: Validators.name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.person_outline_rounded,
                  enabled: !isLoading,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                label: 'Email',
                controller: _email,
                hint: 'you@example.com',
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.mail_outline_rounded,
                enabled: !isLoading,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Password',
                controller: _password,
                hint: _isSignUp ? 'At least 8 characters' : null,
                validator: Validators.password,
                obscureText: true,
                autofillHints: [
                  if (_isSignUp)
                    AutofillHints.newPassword
                  else
                    AutofillHints.password,
                ],
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_outline_rounded,
                onFieldSubmitted: (_) => _submit(),
                enabled: !isLoading,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: _isSignUp ? 'Create account & publish' : 'Sign in',
                isLoading: isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: isLoading ? null : _google,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
