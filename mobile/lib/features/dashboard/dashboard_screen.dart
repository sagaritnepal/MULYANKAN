import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../core/api_client.dart';
import '../../core/npr_formatter.dart';
import '../../state/auth_provider.dart';
import '../../widgets/app_logo.dart';

/// Deliberately has no "best valuator" ranking yet — that needs quote
/// accuracy tracking (how close a valuer's number lands to the final
/// price), which the backend doesn't compute. Everything shown here comes
/// from data we actually have.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.get('/requests/dashboard');
      setState(() => _data = Map<String, dynamic>.from(res.data));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(padding: EdgeInsets.all(8), child: AppLogoMark(size: 28)),
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading || data == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _StatTile(label: 'Bikes uploaded', value: '${data['totalBikes']}'),
                      _StatTile(label: 'Valuations started', value: '${(data['totalBikes'] as int) - (data['draftCount'] as int)}'),
                      _StatTile(label: 'Live now', value: '${data['liveCount']}', color: AppColors.urgent),
                      _StatTile(label: 'Decided', value: '${data['decidedCount']}', color: AppColors.money),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Outcomes', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  _OutcomeBreakdown(counts: Map<String, dynamic>.from(data['outcomeCounts'] ?? {})),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Average quotes per valuation'),
                        Text('${data['avgQuotesPerValuation']}', style: AppTheme.moneyStyle(size: 18)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Quick selling', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  const Text('Fastest exchanges, broadcast to close.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...(data['quickestSales'] as List).map((s) => _QuickSaleTile(sale: Map<String, dynamic>.from(s))),
                  if ((data['quickestSales'] as List).isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No exchanges yet.', style: TextStyle(color: AppColors.muted)),
                    ),
                ],
              ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatTile({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          Text(value, style: AppTheme.moneyStyle(size: 26, color: color)),
        ],
      ),
    );
  }
}

const _outcomeLabels = {
  'exchanged': 'Exchanged',
  'declined': 'Declined',
  'negotiating': 'Negotiating',
  'no_deal': 'No deal',
};

class _OutcomeBreakdown extends StatelessWidget {
  final Map<String, dynamic> counts;
  const _OutcomeBreakdown({required this.counts});

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) {
      return const Text('No decisions recorded yet.', style: TextStyle(color: AppColors.muted));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _outcomeLabels.entries.where((e) => counts[e.key] != null).map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.divider)),
          child: Text('${e.value}: ${counts[e.key]}', style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
    );
  }
}

class _QuickSaleTile extends StatelessWidget {
  final Map<String, dynamic> sale;
  const _QuickSaleTile({required this.sale});

  @override
  Widget build(BuildContext context) {
    final minutes = sale['minutesToClose'] as int;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${sale['brand']} ${sale['model']}'),
        subtitle: Text('$minutes min from broadcast to close'),
        trailing: Text(formatNpr(sale['offeredNpr']), style: AppTheme.moneyStyle(size: 16, color: AppColors.money)),
      ),
    );
  }
}
