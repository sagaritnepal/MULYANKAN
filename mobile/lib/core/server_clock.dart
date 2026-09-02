/// Tracks the offset between server time and device time so every
/// countdown renders from the server's clock, never the device's — the
/// device clock is untrusted per the app's core business rule.
///
/// Call [sync] whenever a response or socket message carries a
/// `serverNow` (epoch ms) field, then use [secondsUntil] to compute a
/// countdown against a `closesAt` also expressed as epoch ms / DateTime.
class ServerClock {
  static int _offsetMs = 0;

  static void sync(int serverNowMs) {
    _offsetMs = serverNowMs - DateTime.now().millisecondsSinceEpoch;
  }

  static DateTime now() =>
      DateTime.now().add(Duration(milliseconds: _offsetMs));

  static int secondsUntil(DateTime closesAt) {
    final diff = closesAt.difference(now()).inMilliseconds;
    return (diff / 1000).ceil();
  }
}
