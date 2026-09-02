import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/api_client.dart';
import '../../core/models/quote.dart';
import '../../core/models/valuation_request.dart';
import '../../core/npr_formatter.dart';
import '../../core/socket_service.dart';
import '../../widgets/countdown_text.dart';
import 'result_screen.dart';

/// The most important screen in the product: readable at arm's length in
/// daylight, updates without a refresh. Quote data only ever reaches this
/// screen because the viewer is the poster — see backend RequestsGateway
/// (board room) and RequestsService.findForRole (blind-bidding rule #2).
class LiveBoardScreen extends StatefulWidget {
  final String requestId;
  const LiveBoardScreen({super.key, required this.requestId});

  @override
  State<LiveBoardScreen> createState() => _LiveBoardScreenState();
}

class _LiveBoardScreenState extends State<LiveBoardScreen> {
  ValuationRequestDetail? _detail;
  final Map<String, Quote> _quotesById = {};
  final _socket = RequestSocket();
  bool _closed = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _load();
    _socket.connect(
      requestId: widget.requestId,
      onSnapshot: (_) {},
      onQuoteCreated: (data) => setState(() => _quotesById[data['id']] = Quote.fromJson(data)),
      onQuoteUpdated: (data) => setState(() => _quotesById[data['id']] = Quote.fromJson(data)),
      onClosed: (_) => setState(() => _closed = true),
    );
  }

  Future<void> _load() async {
    final res = await ApiClient.instance.dio.get('/requests/${widget.requestId}/board');
    final detail = ValuationRequestDetail.fromJson(res.data);
    setState(() {
      _detail = detail;
      _quotesById
        ..clear()
        ..addEntries(detail.quotes.map((q) => MapEntry(q.id, q)));
      _closed = detail.status != 'live';
    });
  }

  Future<void> _stop() async {
    if (_liveStats.count == 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Stop valuation?'),
          content: const Text('No valuer has quoted yet. Stopping now closes this request with no winner — you can rebroadcast it later.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep waiting')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Stop now')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _closing = true);
    try {
      await ApiClient.instance.dio.post('/requests/${widget.requestId}/close');
      setState(() => _closed = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not stop the valuation — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  List<Quote> get _sortedQuotes =>
      _quotesById.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  BoardStats get _liveStats {
    final submitted = _sortedQuotes.where((q) => q.status == 'submitted' && q.amountNpr != null).toList();
    final amounts = submitted.map((q) => q.amountNpr!).toList()..sort();
    final passedCount = _sortedQuotes.where((q) => q.status == 'passed').length;
    if (amounts.isEmpty) {
      return BoardStats(count: 0, passedCount: passedCount, highest: null, lowest: null, average: null, median: null);
    }
    final avg = (amounts.reduce((a, b) => a + b) / amounts.length).round();
    final mid = amounts.length ~/ 2;
    final median = amounts.length % 2 == 0 ? ((amounts[mid - 1] + amounts[mid]) / 2).round() : amounts[mid];
    return BoardStats(
      count: amounts.length,
      passedCount: passedCount,
      highest: amounts.last,
      lowest: amounts.first,
      average: avg,
      median: median,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final stats = _liveStats;
    final responded = stats.count + stats.passedCount;
    final total = detail.totalInvited ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text('${detail.brand} ${detail.model} · ${detail.mfgYearAd}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(color: AppColors.spotlight, borderRadius: BorderRadius.circular(14)),
              child: Center(
                child: _closed
                    ? const Text('CLOSED', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))
                    : CountdownText(
                        // Live Board is only ever opened for a live/closed request, never
                        // a draft, so closesAt is always set here — the fallback is just
                        // to satisfy the nullable type (drafts have no countdown yet).
                        closesAt: detail.closesAt ?? DateTime.now(),
                        style: AppTheme.moneyStyle(size: 48, color: Colors.white),
                        onExpired: () => setState(() => _closed = true),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text('$responded of $total responded · ${stats.passedCount} passed',
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatBox(label: 'Highest', value: formatNpr(stats.highest), color: AppColors.money),
                _StatBox(label: 'Average', value: formatNpr(stats.average)),
                _StatBox(label: 'Median', value: formatNpr(stats.median)),
                _StatBox(label: 'Lowest', value: formatNpr(stats.lowest)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _sortedQuotes.isEmpty
                  ? const Center(child: Text('Waiting for the first quote…'))
                  : ListView.separated(
                      itemCount: _sortedQuotes.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => _QuoteRow(quote: _sortedQuotes[i]),
                    ),
            ),
            const SizedBox(height: 12),
            if (!_closed)
              OutlinedButton(
                onPressed: _closing ? null : _stop,
                child: Text(stats.count == 0 ? 'Stop valuation' : 'Stop and close early'),
              )
            else
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => ResultScreen(requestId: widget.requestId)),
                ),
                child: const Text('Pick a winner'),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatBox({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: AppTheme.moneyStyle(size: 16, color: color))),
        ],
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  final Quote quote;
  const _QuoteRow({required this.quote});

  @override
  Widget build(BuildContext context) {
    final passed = quote.status == 'passed';
    return Opacity(
      opacity: passed ? 0.55 : 1,
      child: ListTile(
        title: Text(quote.valuerName + (quote.showroomName != null ? ' · ${quote.showroomName}' : '')),
        subtitle: Text(passed ? 'Passed: ${quote.passReason ?? '—'}' : (quote.note ?? '')),
        trailing: passed
            ? const Text('PASS', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.bold))
            : Text(formatNpr(quote.amountNpr), style: AppTheme.moneyStyle(size: 18, color: AppColors.money)),
      ),
    );
  }
}
