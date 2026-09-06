import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/models/feed_vehicle.dart';
import '../../core/npr_formatter.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/photo_url.dart';
import '../../state/locale_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/countdown_text.dart';
import '../../widgets/motion.dart';
import 'live_bidding_screen.dart';

/// The browse surface: every showroom's newest vehicles, two across on a
/// phone and three from tablet up.
///
/// A grid rather than a column of full-width cards: a valuer scanning for
/// something worth bidding on wants to compare several bikes at once, and
/// one photo per screen made that impossible. Each cell keeps a 4:3 photo
/// large enough to judge a bike by, with the state and the interest
/// action moved onto the image so the body stays three legible lines even
/// at phone density.
class VehicleFeedScreen extends ConsumerStatefulWidget {
  const VehicleFeedScreen({super.key});

  @override
  ConsumerState<VehicleFeedScreen> createState() => _VehicleFeedScreenState();
}

class _VehicleFeedScreenState extends ConsumerState<VehicleFeedScreen> {
  List<FeedVehicle> _vehicles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.dio.get('/requests/feed');
      final list = (res.data['vehicles'] as List)
          .map((e) => FeedVehicle.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _vehicles = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          e,
          fallback: ref.read(stringsProvider).feedLoadFailed,
        );
        _loading = false;
      });
    }
  }

  /// Registering interest can be what tips a vehicle into live bidding,
  /// so the response's biddingMode is applied straight to the card rather
  /// than waiting for the next refresh.
  Future<void> _markInterested(FeedVehicle vehicle) async {
    try {
      final res = await ApiClient.instance.dio.post(
        '/requests/${vehicle.id}/interest',
      );
      final mode = res.data['biddingMode'] as String? ?? vehicle.biddingMode;
      if (!mounted) return;
      setState(() {
        _vehicles = _vehicles
            .map(
              (v) => v.id == vehicle.id
                  ? v.copyWith(
                      biddingMode: mode,
                      participantCount: v.participantCount + 1,
                    )
                  : v,
            )
            .toList();
      });
      if (mode == 'live') {
        _openLiveBidding(vehicle.id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(stringsProvider).interestRegistered)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(
              e,
              fallback: ref.read(stringsProvider).couldNotRegisterInterest,
            ),
          ),
        ),
      );
    }
  }

  void _openLiveBidding(String requestId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => LiveBiddingScreen(requestId: requestId),
          ),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const AppLogoFull(width: 150),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: s.refresh,
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(s)),
    );
  }

  Widget _buildBody(AppStrings s) {
    if (_loading && _vehicles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _vehicles.isEmpty) {
      return _CenteredMessage(
        icon: Icons.cloud_off,
        title: s.feedLoadFailed,
        detail: _error!,
        action: FilledButton(onPressed: _load, child: Text(s.tryAgain)),
      );
    }
    if (_vehicles.isEmpty) {
      return _CenteredMessage(
        icon: Icons.two_wheeler_outlined,
        title: s.feedEmptyTitle,
        detail: s.feedEmptyDetail,
      );
    }
    // Two across on a phone, three from tablet up. The grid is also capped
    // in width: three columns across a 2560px monitor would put the
    // imagery straight back to the size this replaced.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gutter = 10.0;
        const pad = 12.0;
        const maxGridWidth = 1180.0;

        final available = constraints.maxWidth < maxGridWidth
            ? constraints.maxWidth
            : maxGridWidth;
        final columns = constraints.maxWidth < 600 ? 2 : 3;
        final cellWidth =
            (available - pad * 2 - gutter * (columns - 1)) / columns;
        final compact = cellWidth < 220;

        // Height is computed rather than guessed at with an aspect ratio:
        // the photo is a fixed 4:3 of the cell and the body below it is a
        // known three lines plus padding.
        final cellHeight = cellWidth * 3 / 4 + (compact ? 82 : 92);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxGridWidth),
            child: GridView.builder(
              // Always scrollable so pull-to-refresh works on a short list.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(pad, pad, pad, 28),
              itemCount: _vehicles.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: gutter,
                mainAxisSpacing: gutter,
                mainAxisExtent: cellHeight,
              ),
              itemBuilder: (context, i) => _VehicleCard(
                s: s,
                vehicle: _vehicles[i],
                compact: compact,
                onInterested: () => _markInterested(_vehicles[i]),
                onOpenLive: () => _openLiveBidding(_vehicles[i].id),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final AppStrings s;
  final FeedVehicle vehicle;
  final bool compact;
  final VoidCallback onInterested;
  final VoidCallback onOpenLive;

  const _VehicleCard({
    required this.s,
    required this.vehicle,
    required this.compact,
    required this.onInterested,
    required this.onOpenLive,
  });

  /// Your own showroom's vehicle can never be bid on (backend rule #8),
  /// and a closed one is out of play — neither opens the bidding screen.
  bool get _tappable => !vehicle.isMine && vehicle.isOpenForBids;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _tappable ? onOpenLive : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The photo carries the state and the secondary action, which
            // is what buys the body enough room to stay legible at two
            // cards across a phone.
            AspectRatio(aspectRatio: 4 / 3, child: _photo(context)),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _photo(BuildContext context) {
    final url = vehicle.coverPhotoUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url == null)
          const ColoredBox(
            color: AppColors.background,
            child: Center(
              child: Icon(
                Icons.photo_camera_outlined,
                color: AppColors.muted,
                size: 30,
              ),
            ),
          )
        else
          Image.network(
            photoDisplayUrl(url),
            fit: BoxFit.cover,
            // A dead photo URL must not blank the card — the specs and
            // bidding state below are still worth showing.
            errorBuilder: (_, _, _) => const ColoredBox(
              color: AppColors.background,
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.muted,
                  size: 26,
                ),
              ),
            ),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const ColoredBox(
                    color: AppColors.background,
                    child: Center(
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
          ),
        // Scrims top and bottom, so a white pill and the countdown stay
        // readable over a bright photo.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x8C000000),
                  Color(0x00000000),
                  Color(0xA6000000),
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
        ),
        Positioned(top: 8, right: 8, child: _statePill()),
        if (_tappable && !vehicle.isLive)
          Positioned(top: 6, left: 6, child: _interestedButton()),
        Positioned(bottom: 7, left: 9, right: 9, child: _timeRow()),
      ],
    );
  }

  Widget _statePill() {
    if (vehicle.isLive) return _LiveBadge(label: s.live);
    if (vehicle.isMine) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          s.yours,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// Interest keeps its own affordance rather than being dropped for
  /// space: it is one of the two ways a vehicle reaches live bidding.
  Widget _interestedButton() {
    return Material(
      color: const Color(0x99000000),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onInterested,
        tooltip: s.interested,
        iconSize: 16,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.pan_tool_alt_outlined, color: Colors.white),
      ),
    );
  }

  Widget _timeRow() {
    if (vehicle.isOpenForBids && vehicle.closesAt != null) {
      return Row(
        children: [
          const Icon(Icons.timer_outlined, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          CountdownText(
            closesAt: vehicle.closesAt!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.lock_outline, size: 12, color: Colors.white70),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            s.biddingStatus(vehicle.status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(10, compact ? 7 : 9, 10, compact ? 8 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            vehicle.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: Theme.of(context).textTheme.titleLarge?.fontFamily,
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          Text(
            _specLine(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 11 : 12.5,
            ),
          ),
          _biddingLine(),
        ],
      ),
    );
  }

  /// Deliberately short at grid density: the showroom name and district
  /// moved to the bidding screen, where there is room for them.
  String _specLine() {
    final parts = <String>[
      if (vehicle.mfgYearAd > 0) '${vehicle.mfgYearAd}',
      '${formatKm(vehicle.kmRun)} ${s.km}',
      if (!compact && vehicle.engineCc != null) '${vehicle.engineCc} ${s.cc}',
    ];
    return parts.join('  ·  ');
  }

  Widget _biddingLine() {
    if (vehicle.isLive) {
      return Row(
        children: [
          Flexible(
            child: Text(
              vehicle.topBidNpr != null
                  ? formatNpr(vehicle.topBidNpr)
                  : s.noBidsYet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.moneyStyle(
                size: compact ? 14 : 17,
                color: AppColors.money,
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 6),
            Text(
              s.bidCount(vehicle.bidCount),
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
            ),
          ],
        ],
      );
    }

    // Blind mode: the number of interested parties is public, the amounts
    // are not.
    return Row(
      children: [
        const Icon(
          Icons.visibility_off_outlined,
          size: 13,
          color: AppColors.muted,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            s.interestedShort(vehicle.participantCount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 11 : 12.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final String label;
  const _LiveBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.urgent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LivePulse(color: Colors.white, size: 7),
          const SizedBox(width: 5),
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

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 48, color: AppColors.muted),
        const SizedBox(height: 16),
        Center(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 20),
          Center(child: action!),
        ],
      ],
    );
  }
}
