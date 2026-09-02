import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_error.dart';
import '../../state/auth_provider.dart';
import '../../widgets/app_logo.dart';
import 'forgot_password_screen.dart';
import 'otp_request_screen.dart';

/// Email + password is the primary login path; phone OTP is the secondary
/// option (reachable via "Use phone number instead" below) — reversed
/// from the original phone-first spec at the product owner's request.
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
  String? _error;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter both email and password');
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
      setState(() => _error = apiErrorMessage(e, fallback: 'Could not sign in'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Center(child: AppLogoFull(width: 300)),
              const SizedBox(height: 32),
              Text(_isRegister ? 'Create account' : 'Log in', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (_isRegister) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name (optional)'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (!_isRegister) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                            ),
                    child: const Text('Forgot password?'),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isRegister ? 'Create account' : 'Log in'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _isRegister = !_isRegister),
                child: Text(_isRegister
                    ? 'Already have an account? Log in'
                    : 'New here? Create an account'),
              ),
              const Divider(height: 32),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const OtpRequestScreen()),
                        ),
                child: const Text('Use phone number instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
