import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../core/api_client.dart';
import '../../core/models/valuation_request.dart';
import '../../core/npr_formatter.dart';
import '../../core/photo_url.dart';
import '../../core/server_clock.dart';
import '../../state/auth_provider.dart';
import '../../widgets/countdown_text.dart';
import 'quote_entry_screen.dart';

/// The valuer's working surface: what is open for a number right now.
///
/// Rebuilt image-forward to match the vehicle feed, because a valuer
/// decides whether a bike is worth a number by looking at it. The
/// countdown is the loudest element on each card — a five-minute window
/// is the whole premise, and the previous 16px trailing label gave no
/// sense of it running out.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  List<InboxItem> _items = [];
  bool _loading = true;
  String? _error;
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
    try {
      final res = await ApiClient.instance.dio.get('/inbox');
      final items = (res.data as List)
          .map((j) => InboxItem.fromJson(j))
          .toList();
      if (items.isNotEmpty) ServerClock.sync(items.first.serverNow);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      // A failed poll must not throw every ten seconds. Keep whatever is
      // already on screen and surface the failure only if there is
      // nothing to show.
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_items.isEmpty) _error = 'Could not reach the server';
      });
    }
  }

  void _open(InboxItem item) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => QuoteEntryScreen(requestId: item.id),
          ),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final live = _items.where((i) => i.status == 'live').toList();
    final past = _items.where((i) => i.status != 'live').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 28),
                children: [
                  const _AvailabilityStrip(),
                  if (live.isEmpty && past.isEmpty) _EmptyState(error: _error),
                  if (live.isNotEmpty) ...[
                    _SectionHeader(
                      label: 'Open now',
                      count: live.length,
                      accent: AppColors.urgent,
                    ),
                    ...live.map(
                      (item) =>
                          _RequestCard(item: item, onTap: () => _open(item)),
                    ),
                  ],
                  if (past.isNotEmpty) ...[
                    _SectionHeader(
                      label: 'Recently closed',
                      count: past.length,
                    ),
                    ...past.map(
                      (item) => _RequestCard(item: item, onTap: null),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Availability is status, not an action — it belongs in the body with a
/// line explaining what it does, not squeezed into the app bar where it
/// read as a stray unlabelled switch.
class _AvailabilityStrip extends ConsumerWidget {
  const _AvailabilityStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(authProvider).user?.isAvailable ?? true;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: available
              ? AppColors.money.withValues(alpha: 0.45)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: available ? AppColors.money : AppColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  available
                      ? 'Available for requests'
                      : 'Not receiving requests',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  available
                      ? 'New broadcasts will reach you'
                      : 'You will be skipped when a bike goes out',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: available,
            activeThumbColor: AppColors.money,
            onChanged: (v) => ref.read(authProvider.notifier).setAvailable(v),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color? accent;

  const _SectionHeader({required this.label, required this.count, this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: accent ?? AppColors.muted,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: AppColors.divider)),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final InboxItem item;
  final VoidCallback? onTap;

  const _RequestCard({required this.item, this.onTap});

  bool get _isLive => item.status == 'live';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            // A closed request stays readable but visibly out of play,
            // rather than being greyed into illegibility by ListTile's
            // disabled state.
            opacity: _isLive ? 1 : 0.62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _photo(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.brand} ${item.model}',
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${item.mfgYearAd}  ·  ${formatKm(item.kmRun)} km',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _footer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photo(BuildContext context) {
    final url = item.coverPhotoUrl;
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: url == null
              ? Container(
                  color: AppColors.background,
                  child: const Center(
                    child: Icon(
                      Icons.two_wheeler_outlined,
                      color: AppColors.muted,
                      size: 42,
                    ),
                  ),
                )
              : Image.network(
                  // Routed through the media proxy: the seeded inventory is
                  // hosted somewhere that sends no CORS headers, so a raw
                  // NetworkImage here was blank on the web build.
                  photoDisplayUrl(url),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.background,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.muted,
                        size: 36,
                      ),
                    ),
                  ),
                ),
        ),
        // Scrim so an overlaid countdown stays legible on a bright photo.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
                stops: const [0, 0.55],
              ),
            ),
          ),
        ),
        Positioned(top: 10, right: 10, child: _statusPill()),
        if (item.myQuoteStatus != null)
          Positioned(top: 10, left: 10, child: _myQuoteBadge()),
      ],
    );
  }

  Widget _statusPill() {
    if (!_isLive) {
      return _Pill(
        background: Colors.black.withValues(alpha: 0.6),
        child: Text(
          _statusLabel(item.status),
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return _Pill(
      background: AppColors.urgent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          // CountdownText already shifts to the urgent tone inside the
          // last minute and greys out on expiry.
          CountdownText(
            closesAt: item.closesAt,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _myQuoteBadge() {
    final quoted = item.myQuoteStatus == 'submitted';
    return _Pill(
      background: (quoted ? AppColors.money : AppColors.muted).withValues(
        alpha: 0.9,
      ),
      child: Text(
        quoted ? 'You quoted' : 'You passed',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _footer() {
    if (!_isLive) {
      return Row(
        children: [
          const Icon(Icons.lock_outline, size: 15, color: AppColors.muted),
          const SizedBox(width: 7),
          Text(
            'Closed — no longer accepting numbers',
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ],
      );
    }
    final quoted = item.myQuoteStatus == 'submitted';
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: quoted ? AppColors.surface : AppColors.accent,
              foregroundColor: quoted ? AppColors.ink : Colors.white,
              side: quoted ? const BorderSide(color: AppColors.divider) : null,
              minimumSize: const Size.fromHeight(42),
            ),
            icon: Icon(
              quoted ? Icons.edit_outlined : Icons.currency_rupee,
              size: 17,
            ),
            label: Text(quoted ? 'Revise your number' : 'Give your number'),
          ),
        ),
      ],
    );
  }

  /// The API returns raw enum values; "expired" and "decided" are database
  /// vocabulary, not something to show a valuer.
  static String _statusLabel(String status) => switch (status) {
    'closed' => 'CLOSED',
    'decided' => 'AWARDED',
    'expired' => 'NO BIDS',
    'cancelled' => 'WITHDRAWN',
    _ => status.toUpperCase(),
  };
}

class _Pill extends StatelessWidget {
  final Widget child;
  final Color background;

  const _Pill({required this.child, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? error;
  const _EmptyState({this.error});

  @override
  Widget build(BuildContext context) {
    final failed = error != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 80, 40, 40),
      child: Column(
        children: [
          Icon(
            failed ? Icons.cloud_off : Icons.inbox_outlined,
            size: 46,
            color: AppColors.muted,
          ),
          const SizedBox(height: 18),
          Text(
            failed ? error! : 'Nothing open right now',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            failed
                ? 'Pull down to try again.'
                : 'The moment a showroom broadcasts a bike, it lands here with its countdown running.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
