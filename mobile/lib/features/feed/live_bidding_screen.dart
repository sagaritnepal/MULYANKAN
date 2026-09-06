import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/models/feed_vehicle.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/npr_formatter.dart';
import '../../core/photo_url.dart';
import '../../core/socket_service.dart';
import '../../state/auth_provider.dart';
import '../../state/locale_provider.dart';
import '../../widgets/countdown_text.dart';
import '../../widgets/motion.dart';

/// The bidding screen for one vehicle, in either of two modes.
///
/// Blind: the vehicle has fewer than three engaged valuers, so bids stay
/// sealed. You can submit a number and see only your own.
///
/// Live: three or more valuers are engaged, the server has flipped the
/// request, and every bid is visible to every participant as it lands.
/// Bids must ascend from here on — the backend rejects anything at or
/// below the current top bid.
///
/// The screen opens on whichever mode the server reports and switches
/// itself when the `bidding.live` event arrives, so a valuer who was the
/// third to engage watches the board appear without touching anything.
class LiveBiddingScreen extends ConsumerStatefulWidget {
  final String requestId;
  const LiveBiddingScreen({super.key, required this.requestId});

  @override
  ConsumerState<LiveBiddingScreen> createState() => _LiveBiddingScreenState();
}

class _LiveBiddingScreenState extends ConsumerState<LiveBiddingScreen> {
  final _socket = RequestSocket();
  final _amountController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _submitError;

  // Populated in both modes.
  String _title = '';
  String? _coverPhotoUrl;
  String _showroomName = '';
  String _status = 'live';
  DateTime? _closesAt;
  int _participantCount = 0;

  // Live mode only.
  bool _isLive = false;
  List<LiveBid> _bids = [];
  int? _topBidNpr;
  bool _isMine = false;

  // Blind mode only.
  int? _myBidNpr;

  /// The bid that just arrived, lit for one beat so a valuer sees
  /// WHICH number moved rather than only that something did.
  String? _justLandedQuoteId;

  /// True for one rebuild after the flip, so the board plays its
  /// staggered reveal exactly once and not on every refresh.
  bool _unsealing = false;

  @override
  void initState() {
    super.initState();
    _load();
    _connect();
  }

  @override
  void dispose() {
    _socket.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    await _socket.connect(
      requestId: widget.requestId,
      onSnapshot: (snap) {
        if (!mounted) return;
        setState(() {
          _status = snap['status'] as String? ?? _status;
          final closes = snap['closesAt'] as int?;
          if (closes != null) _closesAt = DateTime.fromMillisecondsSinceEpoch(closes);
        });
      },
      onLiveActivated: (event) {
        if (!mounted) return;
        // Reload rather than patching state: the whole sealed board becomes
        // visible at this moment and there is no local copy of it.
        // The reveal is the one authored moment in the app, so it is
        // flagged here and consumed by the board's first build.
        setState(() {
          _participantCount =
              event['participantCount'] as int? ?? _participantCount;
          _unsealing = true;
        });
        _load();
      },
      onBidPlaced: (event) {
        if (!mounted) return;
        final bid = LiveBid.fromJson(Map<String, dynamic>.from(event['bid']));
        setState(() {
          // One bid per valuer: a raise replaces their previous row rather
          // than stacking, matching the server's unique constraint.
          _bids = [
            bid,
            ..._bids.where((b) => b.valuerId != bid.valuerId),
          ]..sort((a, b) => (b.amountNpr ?? 0).compareTo(a.amountNpr ?? 0));
          _topBidNpr = event['topBidNpr'] as int? ?? _topBidNpr;
          _justLandedQuoteId = bid.quoteId;
        });
        // Hold the highlight long enough to be read, then let it go.
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted && _justLandedQuoteId == bid.quoteId) {
            setState(() => _justLandedQuoteId = null);
          }
        });
      },
      onClosed: (_) {
        if (!mounted) return;
        setState(() => _status = 'closed');
      },
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.dio.get('/requests/${widget.requestId}/live');
      final data = Map<String, dynamic>.from(res.data);
      if (!mounted) return;
      setState(() {
        _isLive = true;
        _title = '${data['brand'] ?? ''} ${data['model'] ?? ''}'.trim();
        _coverPhotoUrl = data['coverPhotoUrl'] as String?;
        _showroomName = data['showroomName'] as String? ?? '';
        _status = data['status'] as String? ?? 'live';
        _closesAt = data['closesAt'] == null ? null : DateTime.parse(data['closesAt'] as String);
        _participantCount = data['participantCount'] as int? ?? 0;
        _topBidNpr = data['topBidNpr'] as int?;
        _isMine = data['isMine'] as bool? ?? false;
        _bids = (data['bids'] as List)
            .map((e) => LiveBid.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loading = false;
      });
    } on DioException catch (e) {
      // 409 is the documented "still blind" response, not a failure.
      if (e.response?.statusCode == 409) {
        await _loadBlind();
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, fallback: ref.read(stringsProvider).couldNotLoadBidding);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, fallback: ref.read(stringsProvider).couldNotLoadBidding);
        _loading = false;
      });
    }
  }

  Future<void> _loadBlind() async {
    try {
      final res = await ApiClient.instance.dio.get('/requests/${widget.requestId}');
      final data = Map<String, dynamic>.from(res.data);
      final myQuote = data['myQuote'] == null ? null : Map<String, dynamic>.from(data['myQuote']);
      if (!mounted) return;
      setState(() {
        _isLive = false;
        _title = '${data['brand'] ?? ''} ${data['model'] ?? ''}'.trim();
        final photos = (data['photos'] as List?) ?? const [];
        _coverPhotoUrl = photos.isEmpty ? null : photos.first['url'] as String?;
        _showroomName = data['showroom']?['name'] as String? ?? '';
        _status = data['status'] as String? ?? 'live';
        _closesAt = data['closesAt'] == null ? null : DateTime.parse(data['closesAt'] as String);
        _myBidNpr = myQuote?['amountNpr'] as int?;
        // Sent by the blind detail path so the "n more to open live
        // bidding" line is accurate without disclosing any amount.
        _participantCount = data['participantCount'] as int? ?? _participantCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, fallback: ref.read(stringsProvider).couldNotLoadBidding);
        _loading = false;
      });
    }
  }

  Future<void> _placeBid() async {
    final raw = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(raw);
    if (amount == null || amount <= 0) {
      setState(() => _submitError = ref.read(stringsProvider).enterBidAmount);
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final res = await ApiClient.instance.dio
          .post('/requests/${widget.requestId}/quote', data: {'amountNpr': amount});
      final mode = res.data['biddingMode'] as String?;
      if (!mounted) return;
      _amountController.clear();
      setState(() {
        _submitting = false;
        _myBidNpr = amount;
      });
      // Your own bid may be the one that opened live bidding.
      if (mode == 'live' && !_isLive) {
        await _load();
      } else if (!_isLive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(stringsProvider).sealedBidSubmitted)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = apiErrorMessage(e, fallback: ref.read(stringsProvider).couldNotPlaceBid);
      });
    }
  }

  bool get _isOpen => _status == 'live';

  @override
  Widget build(BuildContext context) {
    final myUserId = ref.watch(authProvider).user?.id;
    final s = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title.isEmpty ? s.biddingTitle : _title),
        actions: [
          if (_isLive)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: _LivePill(label: s.live)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load, retryLabel: s.tryAgain)
              : _buildContent(myUserId, s),
      bottomNavigationBar: _loading || _error != null || _isMine || !_isOpen
          ? null
          : _buildBidBar(s),
    );
  }

  Widget _buildContent(String? myUserId, AppStrings s) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (_coverPhotoUrl != null)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              photoDisplayUrl(_coverPhotoUrl!),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.surface,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_showroomName, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 12),
              _statusPanel(s),
              const SizedBox(height: 20),
              if (_isLive)
                _liveBoard(myUserId, s)
              else
                _blindPanel(s),
            ],
          ),
        ),
      ],
    );
  }

  /// The focal panel: top bid and remaining time, on the app's deepest
  /// surface so it outranks everything else on screen.
  Widget _statusPanel(AppStrings s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.spotlight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _isLive ? AppColors.urgent : AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isLive ? s.topBidLabel : s.yourSealedBidLabel,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          if (_isLive && _topBidNpr != null)
            CountUpMoney(
              value: _topBidNpr,
              format: formatNpr,
              style: AppTheme.moneyStyle(size: 32, color: AppColors.money),
            )
          else
            Text(
              _isLive
                  ? s.noBidsYet
                  : (_myBidNpr != null ? formatNpr(_myBidNpr) : s.notBidYet),
              style: AppTheme.moneyStyle(size: 32, color: _isLive ? AppColors.money : AppColors.ink),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: AppColors.urgent),
              const SizedBox(width: 6),
              if (_isOpen && _closesAt != null)
                CountdownText(
                  closesAt: _closesAt!,
                  style: const TextStyle(
                    color: AppColors.urgent,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Text(
                  s.biddingStatus(_status),
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              const Spacer(),
              Text(
                s.biddingCount(_participantCount),
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveBoard(String? myUserId, AppStrings s) {
    if (_unsealing) {
      // One reveal only: clear the flag after this build commits.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _unsealing) setState(() => _unsealing = false);
      });
    }
    if (_bids.isEmpty) {
      return Text(
        s.liveOpenNoBids,
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.openBids, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          s.openBidsNote,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < _bids.length; i++)
          Arrive(
            // Keyed by quote so a re-sort moves an existing row rather
            // than replaying its entrance.
            key: ValueKey(_bids[i].quoteId),
            delay: _unsealing ? Motion.stagger(i) : Duration.zero,
            child: _BidRow(
              bid: _bids[i],
              rank: i + 1,
              isMine: _bids[i].valuerId == myUserId,
              youLabel: s.you,
              justLanded: _bids[i].quoteId == _justLandedQuoteId,
            ),
          ),
      ],
    );
  }

  Widget _blindPanel(AppStrings s) {
    final needed = 3 - _participantCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_off_outlined, size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Text(s.sealedBiddingTitle, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.sealedExplanation(needed),
            style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBidBar(AppStrings s) {
    final mustBeat = _isLive ? _topBidNpr : null;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_submitError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _submitError!,
                  style: const TextStyle(color: AppColors.accent, fontSize: 12),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    enabled: !_submitting,
                    style: AppTheme.moneyStyle(size: 18),
                    decoration: InputDecoration(
                      prefixText: 'Rs  ',
                      hintText: mustBeat != null ? s.mustBeatAmount(formatNpr(mustBeat)) : s.yourBid,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _submitting ? null : _placeBid,
                  style: FilledButton.styleFrom(
                    backgroundColor: _isLive ? AppColors.urgent : AppColors.accent,
                    minimumSize: const Size(112, 48),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isLive ? s.raiseBid : s.placeBid),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BidRow extends StatelessWidget {
  final LiveBid bid;
  final int rank;
  final bool isMine;
  final String youLabel;
  final bool justLanded;

  const _BidRow({
    required this.bid,
    required this.rank,
    required this.isMine,
    required this.youLabel,
    this.justLanded = false,
  });

  @override
  Widget build(BuildContext context) {
    // A just-landed row borrows the money tone for a beat. Colour, not
    // movement, so it still reads under Reduce Motion.
    final borderColour = justLanded || rank == 1
        ? AppColors.money
        : (isMine ? AppColors.accent : AppColors.divider);

    return AnimatedContainer(
      duration: Motion.state,
      curve: Motion.arrive,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: justLanded
            ? AppColors.money.withValues(alpha: 0.14)
            : (isMine ? AppColors.accent.withValues(alpha: 0.12) : AppColors.surface),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColour, width: justLanded ? 1.5 : 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank == 1 ? AppColors.money : AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              isMine ? '${bid.bidderLabel} ($youLabel)' : bid.bidderLabel,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            formatNpr(bid.amountNpr),
            style: AppTheme.moneyStyle(
              size: 17,
              color: rank == 1 ? AppColors.money : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  final String label;
  const _LivePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.urgent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LivePulse(color: Colors.white, size: 6),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 44, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
