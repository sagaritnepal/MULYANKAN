import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../core/api_client.dart';
import '../../core/npr_formatter.dart';
import '../../core/photo_url.dart';
import '../../core/server_clock.dart';
import '../../state/auth_provider.dart';
import '../../widgets/countdown_text.dart';
import '../../widgets/app_logo.dart';
import 'new_request_screen.dart';
import 'live_board_screen.dart';
import 'request_detail_screen.dart';

class PosterHomeScreen extends ConsumerStatefulWidget {
  const PosterHomeScreen({super.key});

  @override
  ConsumerState<PosterHomeScreen> createState() => _PosterHomeScreenState();
}

class _PosterHomeScreenState extends ConsumerState<PosterHomeScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.get('/requests/mine');
      final items = List<Map<String, dynamic>>.from(res.data);
      if (items.isNotEmpty) ServerClock.sync(items.first['serverNow'] as int);
      setState(() => _items = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNew() async {
    final createdId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const NewRequestScreen()),
    );
    if (createdId != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LiveBoardScreen(requestId: createdId)),
      );
    }
    _load();
  }

  /// Every card opens the same full detail view regardless of status —
  /// that screen itself offers the right next action (start, view board,
  /// pick a winner, or just show the recorded outcome).
  void _openItem(Map<String, dynamic> item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RequestDetailScreen(requestId: item['id'])),
    );
    _load();
  }

  /// Starts a draft's countdown (see backend RequestsService.startValuation)
  /// — the only way a bulk-imported listing's window begins.
  Future<void> _startValuation(Map<String, dynamic> item) async {
    try {
      await ApiClient.instance.dio.post('/requests/${item['id']}/start');
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LiveBoardScreen(requestId: item['id'])),
      );
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start this valuation')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showroom = ref.watch(authProvider).showroom;
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(padding: EdgeInsets.all(8), child: AppLogoMark(size: 28)),
        title: Text(showroom?.name ?? 'Mulyankan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _openNew,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('New Valuation', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 24),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            if (!_loading && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('No requests yet — post your first bike above.')),
              ),
            ..._items.map((item) => _RequestCard(
                  item: item,
                  onTap: () => _openItem(item),
                  onStart: () => _startValuation(item),
                )),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onStart;
  const _RequestCard({required this.item, required this.onTap, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final status = item['status'] as String;
    final decision = item['decision'] as Map<String, dynamic>?;
    final coverPhotoUrl = item['coverPhotoUrl'] as String?;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(8)),
                child: coverPhotoUrl != null
                    ? Image.network(
                        photoDisplayUrl(coverPhotoUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.two_wheeler, color: AppColors.muted, size: 28),
                      )
                    : const Icon(Icons.two_wheeler, color: AppColors.muted, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['brand']} ${item['model']} · ${item['mfgYearAd']}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    decision != null
                        ? Text('${decision['outcome']} · ${formatNpr(decision['offeredToCustomerNpr'])}',
                            style: const TextStyle(fontSize: 13, color: AppColors.money, fontWeight: FontWeight.w500))
                        : Text(
                            status == 'draft' ? 'Not broadcast yet' : '${item['quoteCount'] ?? 0} quotes so far',
                            style: const TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (status == 'draft')
                OutlinedButton(
                  onPressed: onStart,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                  child: const Text('Start Valuation'),
                )
              else if (status == 'live')
                CountdownText(
                  closesAt: DateTime.parse(item['closesAt']),
                  style: AppTheme.moneyStyle(size: 18),
                )
              else
                _StatusChip(status: status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
    );
  }
}
