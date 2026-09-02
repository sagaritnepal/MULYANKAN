/// Formats an integer NPR amount using Nepali lakh/crore digit grouping:
/// 450000 -> "Rs 4,50,000", never "Rs 450,000". Use this everywhere money
/// is displayed — there must be exactly one formatter in the app.
String formatNpr(num? amount) {
  if (amount == null) return 'Rs —';
  final negative = amount < 0;
  final digits = amount.abs().truncate().toString();

  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final last3 = digits.substring(digits.length - 3);
    final rest = digits.substring(0, digits.length - 3);
    final buffer = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      final posFromEnd = rest.length - i;
      buffer.write(rest[i]);
      if (posFromEnd > 1 && posFromEnd % 2 == 1) buffer.write(',');
    }
    grouped = '$buffer,$last3';
  }
  return 'Rs ${negative ? '-' : ''}$grouped';
}

String formatCountdown(int secondsLeft) {
  final s = secondsLeft < 0 ? 0 : secondsLeft;
  final m = s ~/ 60;
  final rem = s % 60;
  return '$m:${rem.toString().padLeft(2, '0')}';
}
