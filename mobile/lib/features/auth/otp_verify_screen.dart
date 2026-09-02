import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../core/api_error.dart';
import '../../state/auth_provider.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String phone;
  /// Only ever set when the backend has no real SMS provider configured
  /// (dev/test) — see AuthService.requestOtp. Pre-fills the field so
  /// testing doesn't require reading the code off a server log.
  final String? devCode;

  const OtpVerifyScreen({super.key, required this.phone, this.devCode});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  late final _codeController = TextEditingController(text: widget.devCode ?? '');
  bool _verifying = false;
  String? _error;

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).verifyOtp(widget.phone, _codeController.text.trim());
      // AuthGate (root widget) reacts to auth state and swaps screens.
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, fallback: 'Incorrect or expired code'));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Code sent to ${widget.phone}'),
            if (widget.devCode != null) ...[
              const SizedBox(height: 4),
              const Text(
                'No SMS provider configured — code pre-filled for testing.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 8),
              decoration: const InputDecoration(counterText: ''),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _verifying ? null : _verify,
              child: _verifying
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
