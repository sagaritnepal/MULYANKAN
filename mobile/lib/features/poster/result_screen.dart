import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/api_client.dart';
import '../../core/models/quote.dart';
import '../../core/models/valuation_request.dart';
import '../../core/npr_formatter.dart';
import '../../widgets/price_pad.dart';

const _outcomes = {
  'exchanged': 'Exchanged',
  'declined': 'Customer declined',
  'negotiating': 'Still negotiating',
  'no_deal': 'No deal',
};

class ResultScreen extends StatefulWidget {
  final String requestId;
  const ResultScreen({super.key, required this.requestId});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  ValuationRequestDetail? _detail;
  String? _selectedQuoteId;
  int _offeredNpr = 0;
  String _outcome = 'exchanged';
  bool _submitting = false;
  bool _decided = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiClient.instance.dio.get('/requests/${widget.requestId}/board');
    final detail = ValuationRequestDetail.fromJson(res.data);
    setState(() {
      _detail = detail;
      _decided = detail.status == 'decided';
      if (detail.decision != null) {
        // Already decided — show what was actually recorded, not a guess.
        _selectedQuoteId = detail.decision!.winningQuoteId;
        _offeredNpr = detail.decision!.offeredToCustomerNpr;
        _outcome = detail.decision!.outcome;
        return;
      }
      final submitted = detail.quotes.where((q) => q.status == 'submitted').toList()
        ..sort((a, b) => (b.amountNpr ?? 0).compareTo(a.amountNpr ?? 0));
      if (submitted.isNotEmpty) {
        _selectedQuoteId = submitted.first.id;
        _offeredNpr = submitted.first.amountNpr ?? 0;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ApiClient.instance.dio.post('/requests/${widget.requestId}/decide', data: {
        'quoteId': _selectedQuoteId,
        'offeredNpr': _offeredNpr,
        'outcome': _outcome,
      });
      if (mounted) setState(() => _decided = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the decision')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final submitted = detail.quotes.where((q) => q.status == 'submitted').toList()
      ..sort((a, b) => (b.amountNpr ?? 0).compareTo(a.amountNpr ?? 0));
    final winning = submitted.where((q) => q.id == _selectedQuoteId).firstOrNull;
    final margin = (winning?.amountNpr ?? 0) - _offeredNpr;

    if (_decided) {
      return Scaffold(
        appBar: AppBar(title: const Text('Decision recorded')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.money, size: 64),
              const SizedBox(height: 16),
              Text('Offered ${formatNpr(_offeredNpr)}', style: AppTheme.moneyStyle(size: 24)),
              const SizedBox(height: 8),
              Text(_outcomes[_outcome] ?? _outcome),
              if (detail.decision?.winningValuerName != null) ...[
                const SizedBox(height: 8),
                Text('Winning quote: ${detail.decision!.winningValuerName}', style: const TextStyle(color: AppColors.muted)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('${detail.brand} ${detail.model} · Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (submitted.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No quotes came in for this request.'),
            )
          else ...[
            Text('Ranked quotes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...submitted.map((q) => _RankedQuoteTile(
                  quote: q,
                  selected: q.id == _selectedQuoteId,
                  onTap: () => setState(() {
                    _selectedQuoteId = q.id;
                    _offeredNpr = q.amountNpr ?? 0;
                  }),
                )),
            const SizedBox(height: 24),
          ],
          Text('Amount offered to customer', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          PricePad(initialValue: _offeredNpr, onChanged: (v) => setState(() => _offeredNpr = v)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Showroom margin'),
                Text(formatNpr(margin), style: AppTheme.moneyStyle(size: 18, color: margin >= 0 ? AppColors.money : AppColors.urgent)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Outcome', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ..._outcomes.entries.map((e) => RadioListTile<String>(
                value: e.key,
                groupValue: _outcome,
                title: Text(e.value),
                onChanged: (v) => setState(() => _outcome = v!),
              )),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Confirm decision'),
          ),
        ],
      ),
    );
  }
}

class _RankedQuoteTile extends StatelessWidget {
  final Quote quote;
  final bool selected;
  final VoidCallback onTap;
  const _RankedQuoteTile({required this.quote, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? AppColors.accent.withValues(alpha: 0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? AppColors.accent : AppColors.divider, width: selected ? 2 : 1),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Radio<String>(value: quote.id, groupValue: selected ? quote.id : null, onChanged: (_) => onTap()),
        title: Text(quote.valuerName + (quote.showroomName != null ? ' · ${quote.showroomName}' : '')),
        subtitle: quote.note != null && quote.note!.isNotEmpty ? Text(quote.note!) : null,
        trailing: Text(formatNpr(quote.amountNpr), style: AppTheme.moneyStyle(size: 18, color: AppColors.money)),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
