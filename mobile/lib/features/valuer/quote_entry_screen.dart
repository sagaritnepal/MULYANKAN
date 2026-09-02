import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/api_client.dart';
import '../../core/models/valuation_request.dart';
import '../../core/socket_service.dart';
import '../../widgets/countdown_text.dart';
import '../../widgets/deal_context.dart';
import '../../widgets/photo_carousel.dart';
import '../../widgets/price_pad.dart';
import '../../widgets/spec_chip.dart';

/// A valuer's response API calls only ever return their own quote — never
/// anyone else's amount, count, or existence. See backend QuotesService and
/// RequestsService.findForRole for the blind-bidding enforcement this
/// screen relies on (rule #2: enforced in the API, not just the UI).
class QuoteEntryScreen extends StatefulWidget {
  final String requestId;
  const QuoteEntryScreen({super.key, required this.requestId});

  @override
  State<QuoteEntryScreen> createState() => _QuoteEntryScreenState();
}

class _QuoteEntryScreenState extends State<QuoteEntryScreen> {
  ValuationRequestDetail? _detail;
  final _socket = RequestSocket();
  int _amount = 0;
  final _noteController = TextEditingController();
  bool _submitting = false;
  bool _closed = false;
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    _load();
    _socket.connect(
      requestId: widget.requestId,
      onSnapshot: (snap) => setState(() => _closed = snap['status'] != 'live'),
      onClosed: (_) => setState(() => _closed = true),
    );
  }

  Future<void> _load() async {
    final res = await ApiClient.instance.dio.get('/requests/${widget.requestId}');
    final detail = ValuationRequestDetail.fromJson(res.data);
    setState(() {
      _detail = detail;
      _closed = detail.status != 'live';
      if (detail.myQuote != null) {
        _amount = detail.myQuote!['amountNpr'] ?? 0;
        _noteController.text = detail.myQuote!['note'] ?? '';
      }
    });
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  Future<void> _submitQuote() async {
    if (_amount <= 0) return;
    setState(() {
      _submitting = true;
      _resultMessage = null;
    });
    try {
      await ApiClient.instance.dio.post('/requests/${widget.requestId}/quote', data: {
        'amountNpr': _amount,
        'note': _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      });
      if (mounted) setState(() => _resultMessage = 'Quote submitted');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        setState(() {
          _closed = true;
          _resultMessage = e.response?.data['message'] ?? 'Window closed.';
        });
      } else {
        setState(() => _resultMessage = 'Could not submit — try again');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pass() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _PassReasonDialog(),
    );
    if (reason == null || reason.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ApiClient.instance.dio.post('/requests/${widget.requestId}/pass', data: {'reason': reason});
      if (mounted) setState(() => _resultMessage = 'Passed');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        setState(() {
          _closed = true;
          _resultMessage = e.response?.data['message'] ?? 'Window closed.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text('${detail.brand} ${detail.model}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _closed
                  ? const Text('CLOSED', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.muted))
                  : CountdownText(closesAt: detail.closesAt ?? DateTime.now(), onExpired: () => setState(() => _closed = true)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PhotoCarousel(photos: detail.photos),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SpecChip('${detail.mfgYearAd}'),
            SpecChip('${detail.kmRun} km'),
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
            const SizedBox(height: 12),
            Text('Repair needed: ${detail.maintenanceNotes!}', style: const TextStyle(color: AppColors.muted)),
          ],
          const SizedBox(height: 16),
          DealContext(detail: detail),
          const SizedBox(height: 24),
          if (_closed)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(10)),
              child: Text(_resultMessage ?? 'This window has closed.', textAlign: TextAlign.center),
            )
          else ...[
            Text('Your quote', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            PricePad(initialValue: _amount, onChanged: (v) => _amount = v),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(hintText: 'Note (optional)'),
              maxLength: 280,
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: 8),
              Text(_resultMessage!, style: const TextStyle(color: AppColors.money)),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : _pass,
                  child: const Text('Pass'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitQuote,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(detail.myQuote != null ? 'Update quote' : 'Submit quote'),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _PassReasonDialog extends StatefulWidget {
  @override
  State<_PassReasonDialog> createState() => _PassReasonDialogState();
}

class _PassReasonDialogState extends State<_PassReasonDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Why are you passing?'),
      content: TextField(controller: _controller, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. out of my price range')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Pass')),
      ],
    );
  }
}
