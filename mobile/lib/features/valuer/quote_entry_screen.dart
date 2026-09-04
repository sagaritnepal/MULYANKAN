import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/api_client.dart';
import '../../core/models/valuation_request.dart';
import '../../core/npr_formatter.dart';
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
///
/// Laid out so every fact precedes the number: photos, then the facts that
/// move a price most (year, odometer, engine, owners) as a stat row, then
/// the paperwork and condition, and only then the entry panel. A valuer who
/// commits a figure above the accident history prices worse, so the panel
/// is deliberately last and made loud instead of moved up.
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
  bool _resultIsError = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
    _socket.connect(
      requestId: widget.requestId,
      onSnapshot: (snap) {
        if (mounted) setState(() => _closed = snap['status'] != 'live');
      },
      onClosed: (_) {
        if (mounted) setState(() => _closed = true);
      },
    );
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.dio.get(
        '/requests/${widget.requestId}',
      );
      final detail = ValuationRequestDetail.fromJson(res.data);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loadError = null;
        _closed = detail.status != 'live';
        if (detail.myQuote != null) {
          _amount = detail.myQuote!['amountNpr'] ?? 0;
          _noteController.text = detail.myQuote!['note'] ?? '';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load this vehicle');
    }
  }

  @override
  void dispose() {
    _socket.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _setResult(String message, {bool isError = false}) {
    setState(() {
      _resultMessage = message;
      _resultIsError = isError;
    });
  }

  Future<void> _submitQuote() async {
    if (_amount <= 0) {
      _setResult('Enter an amount first', isError: true);
      return;
    }
    setState(() {
      _submitting = true;
      _resultMessage = null;
    });
    try {
      await ApiClient.instance.dio.post(
        '/requests/${widget.requestId}/quote',
        data: {
          'amountNpr': _amount,
          'note': _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        },
      );
      if (mounted) _setResult('Your number is in — ${formatNpr(_amount)}');
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 409) {
        setState(() => _closed = true);
        _setResult(
          e.response?.data['message'] ?? 'Window closed.',
          isError: true,
        );
      } else {
        _setResult('Could not submit — try again', isError: true);
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
      await ApiClient.instance.dio.post(
        '/requests/${widget.requestId}/pass',
        data: {'reason': reason},
      );
      if (mounted) _setResult('Passed on this one');
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 409) {
        setState(() => _closed = true);
        _setResult(
          e.response?.data['message'] ?? 'Window closed.',
          isError: true,
        );
      } else {
        _setResult('Could not pass — try again', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    if (_loadError != null && detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 44, color: AppColors.muted),
                const SizedBox(height: 16),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      );
    }

    if (detail == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${detail.brand} ${detail.model}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(child: _countdownChip(detail)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: PhotoCarousel(photos: detail.photos),
          ),
          const SizedBox(height: 18),
          _KeyFacts(detail: detail),
          const SizedBox(height: 20),
          _Section(
            title: 'Paperwork & condition',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SpecChip(_billBookLabel(detail.billBookStatus)),
                SpecChip(_accidentLabel(detail.accidentHistory)),
                SpecChip(_modificationsLabel(detail.modifications)),
                if (detail.colour != null && detail.colour!.isNotEmpty)
                  SpecChip(detail.colour!),
              ],
            ),
          ),
          if (_hasText(detail.conditionNotes) ||
              _hasText(detail.maintenanceNotes))
            _Section(
              title: 'Seller notes',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_hasText(detail.conditionNotes))
                    Text(
                      detail.conditionNotes!,
                      style: const TextStyle(fontSize: 13.5, height: 1.55),
                    ),
                  if (_hasText(detail.maintenanceNotes)) ...[
                    if (_hasText(detail.conditionNotes))
                      const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.urgent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.urgent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.build_outlined,
                            size: 16,
                            color: AppColors.urgent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              detail.maintenanceNotes!,
                              style: const TextStyle(fontSize: 13, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          _Section(
            title: 'The deal',
            child: DealContext(detail: detail),
          ),
          const SizedBox(height: 8),
          if (_closed) _closedPanel() else _numberPanel(detail),
        ],
      ),
    );
  }

  Widget _countdownChip(ValuationRequestDetail detail) {
    final closesAt = detail.closesAt;
    // A live request always carries closesAt; falling back to "now" here
    // used to render an instantly-expired 0:00 for anything that did not.
    if (_closed || closesAt == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'CLOSED',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.muted,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.urgent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          CountdownText(
            closesAt: closesAt,
            onExpired: () {
              if (mounted) setState(() => _closed = true);
            },
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _closedPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 20, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _resultMessage ?? 'This window has closed.',
              style: const TextStyle(fontSize: 13.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  /// The focal block, on the app's deepest surface — the one panel per
  /// screen that must outrank everything else.
  Widget _numberPanel(ValuationRequestDetail detail) {
    final isUpdate = detail.myQuote != null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.spotlight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                isUpdate ? 'YOUR NUMBER' : 'WHAT IS IT WORTH TO YOU?',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.visibility_off_outlined,
                size: 14,
                color: AppColors.muted,
              ),
              const SizedBox(width: 6),
              const Text(
                'Sealed',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PricePad(initialValue: _amount, onChanged: (v) => _amount = v),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            maxLength: 280,
            style: const TextStyle(fontSize: 13.5),
            decoration: const InputDecoration(
              hintText: 'Note for the seller (optional)',
              isDense: true,
              counterText: '',
            ),
          ),
          if (_resultMessage != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _resultIsError
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  size: 16,
                  // Every outcome used to print in money green, including
                  // "Could not submit — try again".
                  color: _resultIsError ? AppColors.accent : AppColors.money,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _resultMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _resultIsError
                          ? AppColors.accent
                          : AppColors.money,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : _pass,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Pass'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitQuote,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isUpdate ? 'Update my number' : 'Submit my number',
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static bool _hasText(String? s) => s != null && s.trim().isNotEmpty;

  // The API hands back raw enum values; these are database vocabulary.
  static String _billBookLabel(String v) => switch (v) {
    'original' => 'Original bill book',
    'copy' => 'Bill book copy',
    'blue_book_only' => 'Blue book only',
    'missing' => 'No bill book',
    _ => v.replaceAll('_', ' '),
  };

  static String _accidentLabel(String v) => switch (v) {
    'none' => 'No accident history',
    'minor' => 'Minor accident',
    'major' => 'Major accident',
    _ => v,
  };

  static String _modificationsLabel(String v) => switch (v) {
    'stock' => 'Stock',
    'modified' => 'Modified',
    _ => v,
  };
}

/// The facts that move a price most, given the most room.
class _KeyFacts extends StatelessWidget {
  final ValuationRequestDetail detail;
  const _KeyFacts({required this.detail});

  @override
  Widget build(BuildContext context) {
    final facts = <List<String>>[
      ['YEAR', '${detail.mfgYearAd}'],
      ['ODOMETER', '${formatKm(detail.kmRun)} km'],
      if (detail.engineCc != null) ['ENGINE', '${detail.engineCc} cc'],
      ['OWNERS', ordinalOwner(detail.ownerCount)],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            for (int i = 0; i < facts.length; i++) ...[
              if (i > 0)
                Container(width: 1, height: 44, color: AppColors.divider),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 8,
                  ),
                  child: Column(
                    children: [
                      Text(
                        facts[i][0],
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        child: Text(
                          facts[i][1],
                          style: AppTheme.moneyStyle(size: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 1, color: AppColors.divider)),
            ],
          ),
          const SizedBox(height: 12),
          child,
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Why are you passing?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The seller sees this instead of a number.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. out of my price range',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          child: const Text('Pass'),
        ),
      ],
    );
  }
}
