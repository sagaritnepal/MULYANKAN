import 'quote.dart';

class RequestPhoto {
  final String id;
  final String type;
  final String url;

  RequestPhoto({required this.id, required this.type, required this.url});

  factory RequestPhoto.fromJson(Map<String, dynamic> json) =>
      RequestPhoto(id: json['id'] ?? '', type: json['type'], url: json['url']);
}

/// Only ever present once RequestsService.decide() has run — lets a
/// re-opened request show the real recorded outcome instead of a guess.
class RequestDecision {
  final String? winningQuoteId;
  final String? winningValuerName;
  final int offeredToCustomerNpr;
  final int marginNpr;
  final String outcome;
  final String? outcomeNotes;

  RequestDecision({
    required this.winningQuoteId,
    required this.winningValuerName,
    required this.offeredToCustomerNpr,
    required this.marginNpr,
    required this.outcome,
    required this.outcomeNotes,
  });

  factory RequestDecision.fromJson(Map<String, dynamic> json) => RequestDecision(
        winningQuoteId: json['winningQuoteId'],
        winningValuerName: json['winningValuerName'],
        offeredToCustomerNpr: json['offeredToCustomerNpr'],
        marginNpr: json['marginNpr'],
        outcome: json['outcome'],
        outcomeNotes: json['outcomeNotes'],
      );
}

/// Full request detail. `quotes`/`stats`/`totalInvited` are only populated
/// when the API responds to the poster (blind bidding — see backend
/// RequestsService.findForRole); a valuer's response leaves them null.
class ValuationRequestDetail {
  final String id;
  final String brand;
  final String model;
  final int? engineCc;
  final int mfgYearAd;
  final String plateNumber;
  final String? regZone;
  final int kmRun;
  final int ownerCount;
  final String billBookStatus;
  final String accidentHistory;
  final String? accidentNotes;
  final String modifications;
  final String? modificationNotes;
  final String? colour;
  final String? conditionNotes;
  final String? maintenanceNotes;
  final int? customerAskingPrice;
  final String? targetBikeDescription;
  final int? targetBikePrice;
  final int? customerTopup;
  final String urgency;
  final int windowSeconds;
  final String status; // draft | live | closed | decided | expired | cancelled
  final DateTime? closesAt; // null while status == 'draft' — no countdown yet
  final int serverNow;
  final List<RequestPhoto> photos;
  final Map<String, dynamic>? myQuote;
  final int? totalInvited;
  final BoardStats? stats;
  final RequestDecision? decision;
  final List<Quote> quotes;

  ValuationRequestDetail({
    required this.id,
    required this.brand,
    required this.model,
    required this.engineCc,
    required this.mfgYearAd,
    required this.plateNumber,
    required this.regZone,
    required this.kmRun,
    required this.ownerCount,
    required this.billBookStatus,
    required this.accidentHistory,
    required this.accidentNotes,
    required this.modifications,
    required this.modificationNotes,
    required this.colour,
    required this.conditionNotes,
    required this.maintenanceNotes,
    required this.customerAskingPrice,
    required this.targetBikeDescription,
    required this.targetBikePrice,
    required this.customerTopup,
    required this.urgency,
    required this.windowSeconds,
    required this.status,
    required this.closesAt,
    required this.serverNow,
    required this.photos,
    required this.myQuote,
    required this.totalInvited,
    required this.stats,
    required this.decision,
    required this.quotes,
  });

  bool get isPosterView => stats != null;

  factory ValuationRequestDetail.fromJson(Map<String, dynamic> json) => ValuationRequestDetail(
        id: json['id'],
        brand: json['brand'],
        model: json['model'],
        engineCc: json['engineCc'],
        mfgYearAd: json['mfgYearAd'],
        plateNumber: json['plateNumber'],
        regZone: json['regZone'],
        kmRun: json['kmRun'],
        ownerCount: json['ownerCount'],
        billBookStatus: json['billBookStatus'],
        accidentHistory: json['accidentHistory'],
        accidentNotes: json['accidentNotes'],
        modifications: json['modifications'],
        modificationNotes: json['modificationNotes'],
        colour: json['colour'],
        conditionNotes: json['conditionNotes'],
        maintenanceNotes: json['maintenanceNotes'],
        customerAskingPrice: json['customerAskingPrice'],
        targetBikeDescription: json['targetBikeDescription'],
        targetBikePrice: json['targetBikePrice'],
        customerTopup: json['customerTopup'],
        urgency: json['urgency'],
        windowSeconds: json['windowSeconds'],
        status: json['status'],
        closesAt: json['closesAt'] != null ? DateTime.parse(json['closesAt']).toUtc() : null,
        serverNow: json['serverNow'] ?? DateTime.now().millisecondsSinceEpoch,
        photos: (json['photos'] as List<dynamic>? ?? [])
            .map((p) => RequestPhoto.fromJson(p))
            .toList(),
        myQuote: json['myQuote'],
        totalInvited: json['totalInvited'],
        stats: json['stats'] != null ? BoardStats.fromJson(json['stats']) : null,
        decision: json['decision'] != null ? RequestDecision.fromJson(json['decision']) : null,
        quotes: (json['quotes'] as List<dynamic>? ?? []).map((q) => Quote.fromJson(q)).toList(),
      );
}

/// Lightweight row for the valuer's Inbox list — never carries quote amounts.
class InboxItem {
  final String id;
  final String brand;
  final String model;
  final int mfgYearAd;
  final int kmRun;
  final String status;
  final DateTime closesAt;
  final int serverNow;
  final String? coverPhotoUrl;
  final String? myQuoteStatus;

  InboxItem({
    required this.id,
    required this.brand,
    required this.model,
    required this.mfgYearAd,
    required this.kmRun,
    required this.status,
    required this.closesAt,
    required this.serverNow,
    required this.coverPhotoUrl,
    required this.myQuoteStatus,
  });

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
        id: json['id'],
        brand: json['brand'],
        model: json['model'],
        mfgYearAd: json['mfgYearAd'],
        kmRun: json['kmRun'],
        status: json['status'],
        closesAt: DateTime.parse(json['closesAt']).toUtc(),
        serverNow: json['serverNow'] ?? DateTime.now().millisecondsSinceEpoch,
        coverPhotoUrl: json['coverPhotoUrl'],
        myQuoteStatus: json['myQuoteStatus'],
      );
}
