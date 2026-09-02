import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../core/npr_formatter.dart';
import '../core/server_clock.dart';

/// Renders a countdown from [ServerClock], never the device clock — ticks
/// locally every second between server re-syncs (see ServerClock docs).
class CountdownText extends StatefulWidget {
  final DateTime closesAt;
  final TextStyle? style;
  final VoidCallback? onExpired;

  const CountdownText({super.key, required this.closesAt, this.style, this.onExpired});

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  int _secondsLeft = 0;
  bool _expiredFired = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final left = ServerClock.secondsUntil(widget.closesAt);
    if (!mounted) return;
    setState(() => _secondsLeft = left);
    if (left <= 0 && !_expiredFired) {
      _expiredFired = true;
      widget.onExpired?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _secondsLeft <= 60 && _secondsLeft > 0;
    final expired = _secondsLeft <= 0;
    final color = expired ? AppColors.muted : (urgent ? AppColors.urgent : null);
    return Text(
      formatCountdown(_secondsLeft),
      style: (widget.style ?? const TextStyle()).copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
