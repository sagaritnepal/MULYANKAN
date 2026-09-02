/// One card in the vehicle feed (`GET /requests/feed`).
///
/// [topBidNpr] is null for any vehicle still in blind mode — the server
/// withholds amounts until bidding goes live, so a null here means "not
/// disclosed", never "no bids". Use [bidCount] to tell those apart.
class FeedVehicle {
  final String id;
  final String brand;
  final String model;
  final int mfgYearAd;
  final int kmRun;
  final String? colour;
  final int? engineCc;
  final String status;
  final DateTime? closesAt;
  final String? coverPhotoUrl;
  final String showroomName;
  final String? showroomDistrict;
  final bool isMine;
  final String biddingMode;
  final int participantCount;
  final int bidCount;
  final int? topBidNpr;
  final bool iHaveBid;

  const FeedVehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.mfgYearAd,
    required this.kmRun,
    required this.colour,
    required this.engineCc,
    required this.status,
    required this.closesAt,
    required this.coverPhotoUrl,
    required this.showroomName,
    required this.showroomDistrict,
    required this.isMine,
    required this.biddingMode,
    required this.participantCount,
    required this.bidCount,
    required this.topBidNpr,
    required this.iHaveBid,
  });

  bool get isLive => biddingMode == 'live';
  bool get isOpenForBids => status == 'live';
  String get title => '$brand $model';

  factory FeedVehicle.fromJson(Map<String, dynamic> json) {
    return FeedVehicle(
      id: json['id'] as String,
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      mfgYearAd: json['mfgYearAd'] as int? ?? 0,
      kmRun: json['kmRun'] as int? ?? 0,
      colour: json['colour'] as String?,
      engineCc: json['engineCc'] as int?,
      status: json['status'] as String? ?? 'live',
      closesAt: json['closesAt'] == null ? null : DateTime.parse(json['closesAt'] as String),
      coverPhotoUrl: json['coverPhotoUrl'] as String?,
      showroomName: json['showroomName'] as String? ?? 'Unknown showroom',
      showroomDistrict: json['showroomDistrict'] as String?,
      isMine: json['isMine'] as bool? ?? false,
      biddingMode: json['biddingMode'] as String? ?? 'blind',
      participantCount: json['participantCount'] as int? ?? 0,
      bidCount: json['bidCount'] as int? ?? 0,
      topBidNpr: json['topBidNpr'] as int?,
      iHaveBid: json['iHaveBid'] as bool? ?? false,
    );
  }

  FeedVehicle copyWith({
    String? biddingMode,
    int? participantCount,
    int? bidCount,
    int? topBidNpr,
    bool? iHaveBid,
  }) {
    return FeedVehicle(
      id: id,
      brand: brand,
      model: model,
      mfgYearAd: mfgYearAd,
      kmRun: kmRun,
      colour: colour,
      engineCc: engineCc,
      status: status,
      closesAt: closesAt,
      coverPhotoUrl: coverPhotoUrl,
      showroomName: showroomName,
      showroomDistrict: showroomDistrict,
      isMine: isMine,
      biddingMode: biddingMode ?? this.biddingMode,
      participantCount: participantCount ?? this.participantCount,
      bidCount: bidCount ?? this.bidCount,
      topBidNpr: topBidNpr ?? this.topBidNpr,
      iHaveBid: iHaveBid ?? this.iHaveBid,
    );
  }
}

/// A single bid on the open board (`GET /requests/:id/live`, and the
/// `bid.placed` socket event).
class LiveBid {
  final String quoteId;
  final String valuerId;
  final String bidderLabel;
  final int? amountNpr;
  final DateTime at;

  const LiveBid({
    required this.quoteId,
    required this.valuerId,
    required this.bidderLabel,
    required this.amountNpr,
    required this.at,
  });

  factory LiveBid.fromJson(Map<String, dynamic> json) {
    return LiveBid(
      quoteId: json['quoteId'] as String,
      valuerId: json['valuerId'] as String? ?? '',
      bidderLabel: json['bidderLabel'] as String? ?? 'Valuer',
      amountNpr: json['amountNpr'] as int?,
      at: json['at'] == null ? DateTime.now() : DateTime.parse(json['at'] as String),
    );
  }
}
