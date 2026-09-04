import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/models/valuation_request.dart';
import '../../core/npr_formatter.dart';
import '../../widgets/deal_context.dart';
import '../../widgets/photo_carousel.dart';
import '../../widgets/spec_chip.dart';
import 'live_board_screen.dart';
import 'new_request_screen.dart';
import 'result_screen.dart';

/// Full read view of a request — reached by tapping any card on Poster
/// Home, regardless of status. A draft's "Start Valuation" here is the
/// only place its countdown begins.
class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  ValuationRequestDetail? _detail;
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiClient.instance.dio.get('/requests/${widget.requestId}/board');
    if (!mounted) return;
    setState(() => _detail = ValuationRequestDetail.fromJson(res.data));
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NewRequestScreen(editing: _detail)),
    );
    if (changed == true) _load();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      await ApiClient.instance.dio.post('/requests/${widget.requestId}/start');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LiveBoardScreen(requestId: widget.requestId)),
      );
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, fallback: 'Could not start this valuation'));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text('${detail.brand} ${detail.model} · ${detail.mfgYearAd}'),
        actions: [
          if (detail.status == 'draft')
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit, tooltip: 'Edit'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PhotoCarousel(photos: detail.photos),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SpecChip('${detail.mfgYearAd}'),
            SpecChip('${formatKm(detail.kmRun)} km'),
            if (detail.engineCc != null) SpecChip('${detail.engineCc} cc'),
            SpecChip(ordinalOwner(detail.ownerCount)),
            SpecChip(detail.billBookStatus.replaceAll('_', ' ')),
            SpecChip('Accident: ${detail.accidentHistory}'),
            SpecChip(detail.modifications),
            if (detail.colour != null) SpecChip(detail.colour!),
          ]),
          if (detail.conditionNotes != null && detail.conditionNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(detail.conditionNotes!),
          ],
          if (detail.maintenanceNotes != null && detail.maintenanceNotes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Repair needed', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(detail.maintenanceNotes!),
          ],
          const SizedBox(height: 16),
          DealContext(detail: detail),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: AppColors.urgent)),
            const SizedBox(height: 12),
          ],
          _ActionArea(detail: detail, starting: _starting, onStart: _start),
        ],
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  final ValuationRequestDetail detail;
  final bool starting;
  final VoidCallback onStart;
  const _ActionArea({required this.detail, required this.starting, required this.onStart});

  @override
  Widget build(BuildContext context) {
    switch (detail.status) {
      case 'draft':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${detail.brand} ${detail.model}',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (detail.customerAskingPrice != null) ...[
                  const SizedBox(width: 12),
                  Text("Asking: ${formatNpr(detail.customerAskingPrice)}",
                      style: AppTheme.moneyStyle(size: 16, color: AppColors.money)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: starting ? null : onStart,
              child: starting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Start Valuation'),
            ),
          ],
        );
      case 'live':
        return ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LiveBoardScreen(requestId: detail.id)),
          ),
          child: const Text('View live board'),
        );
      case 'closed':
      case 'expired':
        return ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ResultScreen(requestId: detail.id)),
          ),
          child: const Text('Pick a winner'),
        );
      case 'decided':
        final decision = detail.decision;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(decision?.outcome.replaceAll('_', ' ') ?? 'Decided'),
                  Text(formatNpr(decision?.offeredToCustomerNpr), style: AppTheme.moneyStyle(size: 16, color: AppColors.money)),
                ],
              ),
              if (decision?.winningValuerName != null) ...[
                const SizedBox(height: 4),
                Text('Winning quote: ${decision!.winningValuerName}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
