import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/auth_provider.dart';

/// Every user belongs to a showroom — it's how the backend knows which
/// requests are "yours" (rule #8: can't quote your own showroom's bike)
/// and who owns a live request's board. Shown once, right after login.
class ShowroomSetupScreen extends ConsumerStatefulWidget {
  const ShowroomSetupScreen({super.key});

  @override
  ConsumerState<ShowroomSetupScreen> createState() => _ShowroomSetupScreenState();
}

class _ShowroomSetupScreenState extends ConsumerState<ShowroomSetupScreen> {
  final _nameController = TextEditingController();
  final _joinCodeController = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).createShowroom(_nameController.text.trim());
    } catch (e) {
      setState(() => _error = 'Could not create showroom');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    if (_joinCodeController.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).joinShowroom(_joinCodeController.text.trim());
    } catch (e) {
      setState(() => _error = 'Invalid join code');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your showroom')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Create your showroom', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Showroom name')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _busy ? null : _create, child: const Text('Create')),
            const SizedBox(height: 32),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('OR')),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 32),
            const Text('Join an existing showroom', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _joinCodeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'Join code'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _busy ? null : _join, child: const Text('Join')),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
