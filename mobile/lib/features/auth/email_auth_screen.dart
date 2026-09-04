import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../core/api_error.dart';
import '../../core/i18n/app_strings.dart';
import '../../state/auth_provider.dart';
import '../../state/locale_provider.dart';
import '../../widgets/app_logo.dart';
import 'forgot_password_screen.dart';
import 'otp_request_screen.dart';

/// Email + password is the primary login path; phone OTP is the secondary
/// option (reachable via "Log in with phone number" below) — reversed
/// from the original phone-first spec at the product owner's request.
///
/// Laid out in Instagram's login pattern at the product owner's request:
/// one tall centred column (logo, two stacked fields, primary action,
/// "OR" rule, secondary action) with the sign-up prompt pinned to the
/// bottom edge behind a hairline. The palette stays Mulyankan's dark red
/// rather than Instagram's blue — the structure was the ask, and a blue
/// primary button would be the only blue in the app.
class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  bool _isRegister = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Instagram keeps its primary button disabled until both fields have
  /// content, which is a clearer signal than validating on submit.
  bool get _canSubmit =>
      _emailController.text.trim().isNotEmpty && _passwordController.text.isNotEmpty;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = ref.read(stringsProvider).enterBothFields);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isRegister) {
        await ref.read(authProvider.notifier).registerWithEmail(email, password, _nameController.text.trim());
      } else {
        await ref.read(authProvider.notifier).loginWithEmail(email, password);
      }
      // AuthGate (root widget) reacts to auth state and swaps screens.
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, fallback: ref.read(stringsProvider).couldNotSignIn));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: ConstrainedBox(
                    // The web build runs full-width on a desktop browser;
                    // without this the fields stretch across the monitor.
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(alignment: Alignment.centerRight, child: _LanguageSwitch()),
                        const SizedBox(height: 12),
                        const Center(child: AppLogoFull(width: 240)),
                        const SizedBox(height: 44),
                        if (_isRegister) ...[
                          _AuthField(
                            controller: _nameController,
                            hint: s.fullNameOptional,
                            enabled: !_busy,
                          ),
                          const SizedBox(height: 10),
                        ],
                        _AuthField(
                          controller: _emailController,
                          hint: s.emailAddress,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_busy,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        _AuthField(
                          controller: _passwordController,
                          hint: s.password,
                          obscure: _obscure,
                          enabled: !_busy,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: _canSubmit && !_busy ? (_) => _submit() : null,
                          suffix: TextButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.muted,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              minimumSize: Size.zero,
                            ),
                            child: Text(
                              _obscure ? s.show : s.hide,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                        if (!_isRegister)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                      ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                minimumSize: Size.zero,
                              ),
                              child: Text(
                                s.forgotPassword,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _ErrorBanner(message: _error!),
                        ],
                        SizedBox(height: _isRegister ? 20 : 8),
                        _PrimaryButton(
                          label: _isRegister ? s.signUp : s.logIn,
                          busy: _busy,
                          onPressed: _canSubmit && !_busy ? _submit : null,
                        ),
                        const SizedBox(height: 24),
                        _OrDivider(label: s.or),
                        const SizedBox(height: 20),
                        TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const OtpRequestScreen()),
                                  ),
                          icon: const Icon(Icons.phone_iphone, size: 18),
                          label: Text(
                            s.logInWithPhone,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isRegister ? s.haveAccountPrompt : s.noAccountPrompt,
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: _busy
                        ? null
                        : () => setState(() {
                              _isRegister = !_isRegister;
                              _error = null;
                            }),
                    child: Text(
                      _isRegister ? s.logIn : s.signUp,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

/// Instagram's fields are shorter and flatter than the app's default
/// InputDecorationTheme, so the geometry is set locally rather than by
/// changing the theme every other screen depends on.
class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _AuthField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      autocorrect: false,
      textInputAction: onSubmitted != null ? TextInputAction.go : TextInputAction.next,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  const _PrimaryButton({required this.label, required this.busy, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        // Instagram dims rather than greys out its disabled button, which
        // reads as "not yet" instead of "broken".
        backgroundColor: disabled ? AppColors.accent.withValues(alpha: 0.4) : AppColors.accent,
        disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.4),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white70,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      child: busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    );
  }
}

class _OrDivider extends StatelessWidget {
  final String label;
  const _OrDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Expanded(child: Divider(height: 1)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.ink)),
          ),
        ],
      ),
    );
  }
}

/// Reachable before sign-in on purpose: a valuer who does not read
/// English needs the choice before the first field, not buried in
/// settings behind a login they cannot read.
class _LanguageSwitch extends ConsumerWidget {
  const _LanguageSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final locale in AppLocale.values)
          GestureDetector(
            onTap: () => ref.read(localeProvider.notifier).set(locale),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                // Each language is named in its own script, never translated.
                locale.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: locale == current ? FontWeight.w700 : FontWeight.w500,
                  color: locale == current ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
