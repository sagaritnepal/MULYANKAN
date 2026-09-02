import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/models/feed_vehicle.dart';
import '../../core/npr_formatter.dart';
import '../../core/photo_url.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/countdown_text.dart';
import 'live_bidding_screen.dart';

/// The browse surface: every showroom's newest vehicles as a single
/// scrolling feed, one card per vehicle.
///
/// Cards are deliberately image-first — a valuer decides whether a bike
/// is worth bidding on by looking at it, so the photo gets the space and
/// the specs sit under it as a caption.
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
        _error = apiErrorMessage(e, fallback: 'Could not load the feed');
        _loading = false;
      });
    }
  }

  /// Registering interest can be what tips a vehicle into live bidding,
  /// so the response's biddingMode is applied straight to the card rather
  /// than waiting for the next refresh.
  Future<void> _markInterested(FeedVehicle vehicle) async {
    try {
      final res = await ApiClient.instance.dio.post('/requests/${vehicle.id}/interest');
      final mode = res.data['biddingMode'] as String? ?? vehicle.biddingMode;
      if (!mounted) return;
      setState(() {
        _vehicles = _vehicles
            .map((v) => v.id == vehicle.id
                ? v.copyWith(
                    biddingMode: mode,
                    participantCount: v.participantCount + 1,
                  )
                : v)
            .toList();
      });
      if (mode == 'live') {
        _openLiveBidding(vehicle.id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as interested — you will be notified when bidding opens')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, fallback: 'Could not register interest'))),
      );
    }
  }

  void _openLiveBidding(String requestId) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => LiveBiddingScreen(requestId: requestId)))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppLogoFull(width: 150),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _vehicles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _vehicles.isEmpty) {
      return _CenteredMessage(
        icon: Icons.cloud_off,
        title: 'Could not load vehicles',
        detail: _error!,
        action: FilledButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    if (_vehicles.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.two_wheeler_outlined,
        title: 'No vehicles yet',
        detail: 'Vehicles posted by any showroom will appear here.',
      );
    }
    return ListView.separated(
      // Always scrollable so pull-to-refresh works even on a short list.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _vehicles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _VehicleCard(
        vehicle: _vehicles[i],
        onInterested: () => _markInterested(_vehicles[i]),
        onOpenLive: () => _openLiveBidding(_vehicles[i].id),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final FeedVehicle vehicle;
  final VoidCallback onInterested;
  final VoidCallback onOpenLive;

  const _VehicleCard({
    required this.vehicle,
    required this.onInterested,
    required this.onOpenLive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),
          _photo(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _actions(context),
                const SizedBox(height: 10),
                Text(vehicle.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(_specLine(), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 8),
                _biddingLine(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _specLine() {
    final parts = <String>[
      if (vehicle.mfgYearAd > 0) '${vehicle.mfgYearAd}',
      if (vehicle.engineCc != null) '${vehicle.engineCc} cc',
      '${_thousands(vehicle.kmRun)} km',
      if (vehicle.colour != null && vehicle.colour!.isNotEmpty) vehicle.colour!,
    ];
    return parts.join('  ·  ');
  }

  static String _thousands(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.accent.withValues(alpha: 0.2),
            child: const AppLogoMark(size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vehicle.showroomName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                if (vehicle.showroomDistrict != null)
                  Text(
                    vehicle.showroomDistrict!,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (vehicle.isLive) const _LiveBadge(),
          if (vehicle.isMine)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Yours', style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ),
        ],
      ),
    );
  }

  Widget _photo() {
    final url = vehicle.coverPhotoUrl;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: url == null
          ? Container(
              color: AppColors.background,
              child: const Center(
                child: Icon(Icons.photo_camera_outlined, color: AppColors.muted, size: 40),
              ),
            )
          : Image.network(
              photoDisplayUrl(url),
              fit: BoxFit.cover,
              width: double.infinity,
              // A dead photo URL must not blank the whole card — the specs
              // and bidding state below are still worth showing.
              errorBuilder: (_, _, _) => Container(
                color: AppColors.background,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined, color: AppColors.muted, size: 40),
                ),
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      color: AppColors.background,
                      child: const Center(
                        child: SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
            ),
    );
  }

  Widget _actions(BuildContext context) {
    // Your own showroom's vehicle can never be bid on (backend rule #8),
    // so it gets a countdown instead of dead buttons.
    if (vehicle.isMine || !vehicle.isOpenForBids) {
      return Row(
        children: [
          Icon(
            vehicle.isOpenForBids ? Icons.timer_outlined : Icons.lock_outline,
            size: 18,
            color: AppColors.muted,
          ),
          const SizedBox(width: 8),
          if (vehicle.isOpenForBids && vehicle.closesAt != null)
            CountdownText(
              closesAt: vehicle.closesAt!,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            )
          else
            Text(
              'Bidding ${vehicle.status}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
        ],
      );
    }

    return Row(
      children: [
        if (vehicle.isLive)
          Expanded(
            child: FilledButton.icon(
              onPressed: onOpenLive,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.urgent,
                minimumSize: const Size.fromHeight(40),
              ),
              icon: const Icon(Icons.gavel, size: 18),
              label: const Text('Join live bidding'),
            ),
          )
        else ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onInterested,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
              icon: const Icon(Icons.pan_tool_alt_outlined, size: 18),
              label: const Text('Interested'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: onOpenLive,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size.fromHeight(40),
              ),
              icon: const Icon(Icons.currency_rupee, size: 18),
              label: const Text('Bid'),
            ),
          ),
        ],
        if (vehicle.closesAt != null) ...[
          const SizedBox(width: 10),
          CountdownText(
            closesAt: vehicle.closesAt!,
            style: const TextStyle(color: AppColors.urgent, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }

  Widget _biddingLine(BuildContext context) {
    final people = vehicle.participantCount;
    final needed = 3 - people;

    if (vehicle.isLive) {
      return Row(
        children: [
          Text(
            vehicle.topBidNpr != null ? formatNpr(vehicle.topBidNpr) : 'No bids yet',
            style: AppTheme.moneyStyle(size: 20, color: AppColors.money),
          ),
          const SizedBox(width: 8),
          Text(
            '· top bid · ${vehicle.bidCount} ${vehicle.bidCount == 1 ? 'bid' : 'bids'}',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      );
    }

    // Blind mode: the count of interested parties is public, the numbers
    // are not. Showing how many more are needed is what makes the live
    // threshold feel like something worth joining.
    return Row(
      children: [
        const Icon(Icons.visibility_off_outlined, size: 15, color: AppColors.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            needed > 0
                ? '$people interested · $needed more to open live bidding'
                : '$people interested · sealed bids',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.urgent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: Colors.white),
          SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(
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
        Center(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
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
