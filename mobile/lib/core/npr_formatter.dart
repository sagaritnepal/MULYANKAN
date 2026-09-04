/// Nepali lakh/crore digit grouping: 450000 -> "4,50,000", never
/// "450,000". Shared by money and odometer readings so a reader parses
/// every number in the app the same way.
String _groupNepali(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  final rest = digits.substring(0, digits.length - 3);
  final buffer = StringBuffer();
  for (int i = 0; i < rest.length; i++) {
    final posFromEnd = rest.length - i;
    buffer.write(rest[i]);
    if (posFromEnd > 1 && posFromEnd % 2 == 1) buffer.write(',');
  }
  return '$buffer,$last3';
}

/// Formats an integer NPR amount using Nepali grouping:
/// 450000 -> "Rs 4,50,000". Use this everywhere money is displayed —
/// there must be exactly one formatter in the app.
String formatNpr(num? amount) {
  if (amount == null) return 'Rs —';
  final negative = amount < 0;
  final digits = amount.abs().truncate().toString();
  return 'Rs ${negative ? '-' : ''}${_groupNepali(digits)}';
}

/// An odometer reading, grouped but with no currency prefix and no unit —
/// callers add the localised "km". Replaces three separate places that
/// interpolated the raw integer and printed "45000 km".
String formatKm(int? km) {
  if (km == null) return '—';
  return _groupNepali(km.abs().toString());
}

String formatCountdown(int secondsLeft) {
  final s = secondsLeft < 0 ? 0 : secondsLeft;
  final m = s ~/ 60;
  final rem = s % 60;
  return '$m:${rem.toString().padLeft(2, '0')}';
}
