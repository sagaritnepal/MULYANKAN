class Quote {
  final String id;
  final String valuerId;
  final String valuerName;
  final String? showroomName;
  final int? amountNpr;
  final String? note;
  final String status; // submitted | passed | withdrawn
  final String? passReason;
  final int? respondedInMs;
  final DateTime updatedAt;

  Quote({
    required this.id,
    required this.valuerId,
    required this.valuerName,
    required this.showroomName,
    required this.amountNpr,
    required this.note,
    required this.status,
    required this.passReason,
    required this.respondedInMs,
    required this.updatedAt,
  });

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        id: json['id'],
        valuerId: json['valuerId'],
        valuerName: json['valuerName'] ?? 'Unnamed valuer',
        showroomName: json['showroomName'],
        amountNpr: json['amountNpr'],
        note: json['note'],
        status: json['status'],
        passReason: json['passReason'],
        respondedInMs: json['respondedInMs'],
        updatedAt: DateTime.parse(json['updatedAt']),
      );
}

class BoardStats {
  final int count;
  final int passedCount;
  final int? highest;
  final int? lowest;
  final int? average;
  final int? median;

  BoardStats({
    required this.count,
    required this.passedCount,
    required this.highest,
    required this.lowest,
    required this.average,
    required this.median,
  });

  factory BoardStats.fromJson(Map<String, dynamic> json) => BoardStats(
        count: json['count'] ?? 0,
        passedCount: json['passedCount'] ?? 0,
        highest: json['highest'],
        lowest: json['lowest'],
        average: json['average'],
        median: json['median'],
      );
}
