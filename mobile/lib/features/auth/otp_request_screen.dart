import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_error.dart';
import '../../state/auth_provider.dart';
import 'otp_verify_screen.dart';

/// Secondary login path, reached via "Use phone number instead" on
/// EmailAuthScreen (the primary/entry screen) — so this is always pushed
/// with a back button, never the app's root.
class OtpRequestScreen extends ConsumerStatefulWidget {
  const OtpRequestScreen({super.key});

  @override
  ConsumerState<OtpRequestScreen> createState() => _OtpRequestScreenState();
}

class _OtpRequestScreenState extends ConsumerState<OtpRequestScreen> {
  final _phoneController = TextEditingController();
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    final digits = _phoneController.text.trim();
    if (digits.length < 9) {
      setState(() => _error = 'Enter a valid 10-digit Nepali number');
      return;
    }
    final phone = '+977$digits';
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final devCode = await ref.read(authProvider.notifier).requestOtp(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpVerifyScreen(phone: phone, devCode: devCode)),
      );
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, fallback: 'Could not send code. Try again.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log in with phone')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Your phone number'),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(prefixText: '+977  ', hintText: '98XXXXXXXX'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send code'),
            ),
          ],
        ),
      ),
    );
  }
}
