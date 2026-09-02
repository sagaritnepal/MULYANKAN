import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../core/api_client.dart';
import '../../core/models/valuation_request.dart';
import '../../core/server_clock.dart';
import '../../state/auth_provider.dart';
import '../../widgets/countdown_text.dart';
import '../../widgets/app_logo.dart';
import 'quote_entry_screen.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  List<InboxItem> _items = [];
  bool _loading = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // No push notifications wired up without a Firebase project (see
    // core/push_service.dart); polling keeps the inbox usable for testing.
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await ApiClient.instance.dio.get('/inbox');
    final items = (res.data as List).map((j) => InboxItem.fromJson(j)).toList();
    if (items.isNotEmpty) ServerClock.sync(items.first.serverNow);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final live = _items.where((i) => i.status == 'live').toList();
    final past = _items.where((i) => i.status != 'live').toList();

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(padding: EdgeInsets.all(8), child: AppLogoMark(size: 28)),
        title: const Text('Inbox'),
        actions: [
          Row(children: [
            const Text('Available', style: TextStyle(fontSize: 13)),
            Switch(
              value: user?.isAvailable ?? true,
              onChanged: (v) => ref.read(authProvider.notifier).setAvailable(v),
            ),
          ]),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (live.isEmpty && past.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('No requests yet. New ones will show up here the moment they broadcast.')),
                    ),
                  ...live.map((item) => _InboxTile(item: item)),
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Recent', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...past.map((item) => _InboxTile(item: item)),
                  ],
                ],
              ),
            ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  final InboxItem item;
  const _InboxTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isLive = item.status == 'live';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        enabled: isLive,
        onTap: isLive
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => QuoteEntryScreen(requestId: item.id)),
                )
            : null,
        leading: CircleAvatar(
          backgroundColor: AppColors.divider,
          backgroundImage: item.coverPhotoUrl != null ? NetworkImage(item.coverPhotoUrl!) : null,
          child: item.coverPhotoUrl == null ? const Icon(Icons.motorcycle) : null,
        ),
        title: Text('${item.brand} ${item.model} · ${item.mfgYearAd}'),
        subtitle: Text('${item.kmRun} km${item.myQuoteStatus != null ? ' · you: ${item.myQuoteStatus}' : ''}'),
        trailing: isLive
            ? CountdownText(closesAt: item.closesAt, style: AppTheme.moneyStyle(size: 16, color: AppColors.urgent))
            : Text(item.status, style: const TextStyle(color: AppColors.muted)),
      ),
    );
  }
}
