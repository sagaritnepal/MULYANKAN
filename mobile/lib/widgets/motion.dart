import 'package:flutter/material.dart';

/// One motion vocabulary for the whole app, so timing means something.
///
/// Durations express distance and consequence rather than taste:
/// acknowledgement is near-instant, a state change is quick, a view
/// change is allowed to be seen, and exactly one authored moment — the
/// blind-to-live unseal — is allowed to take its time.
class Motion {
  const Motion._();

  /// Acknowledging a tap. Anything longer reads as latency.
  static const feedback = Duration(milliseconds: 140);

  /// A routine state change: a colour, a badge, a value.
  static const state = Duration(milliseconds: 240);

  /// Layout or overlay change the eye should be able to follow.
  static const view = Duration(milliseconds: 380);

  /// The one authored entrance: sealed bidding giving way to the open
  /// board. Deliberately the slowest thing in the app.
  static const focal = Duration(milliseconds: 640);

  /// Exponential deceleration — a confident arrival, not a bounce.
  /// Matches cubic-bezier(0.16, 1, 0.3, 1).
  static const arrive = Cubic(0.16, 1, 0.3, 1);

  /// Leaving is faster than arriving.
  static const depart = Curves.easeOutCubic;

  /// Per-item delay when a list genuinely appears as a list. Capped by
  /// [stagger] so a long board never crawls.
  static Duration stagger(int index, {int cap = 6}) =>
      Duration(milliseconds: 55 * (index > cap ? cap : index));

  /// Movement is dropped under Reduce Motion; colour and opacity changes
  /// stay, because they carry state that a valuer needs to see.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Slides and fades a child in once, on first build.
///
/// Used where something genuinely arrives — a bid landing on the board —
/// never as a blanket entrance for static content.
class Arrive extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double offsetY;

  const Arrive({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 14,
  });

  @override
  State<Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<Arrive> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: Motion.view,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduce Motion keeps the fade and drops the travel.
    final travel = Motion.reduced(context) ? 0.0 : widget.offsetY;
    final curved = CurvedAnimation(parent: _c, curve: Motion.arrive);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, travel * (1 - curved.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Counts a money figure up to its new value instead of swapping it.
///
/// A bid that jumps silently is just a different string; a bid that
/// travels is a bid you watched arrive. Only ever counts forward — the
/// board is ascending — and lands instantly under Reduce Motion.
class CountUpMoney extends StatefulWidget {
  final int? value;
  final TextStyle style;
  final String Function(int?) format;

  const CountUpMoney({
    super.key,
    required this.value,
    required this.style,
    required this.format,
  });

  @override
  State<CountUpMoney> createState() => _CountUpMoneyState();
}

class _CountUpMoneyState extends State<CountUpMoney>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: Motion.view,
    vsync: this,
  );

  // The figure travels from the last one shown, so the previous value has
  // to be held here — TweenAnimationBuilder cannot do it, since a tween
  // built in build() has begin == end and never moves.
  int _from = 0;
  int _to = 0;

  @override
  void initState() {
    super.initState();
    _from = widget.value ?? 0;
    _to = _from;
  }

  @override
  void didUpdateWidget(CountUpMoney old) {
    super.didUpdateWidget(old);
    final next = widget.value;
    if (next == null || next == _to) return;
    _from = _to;
    _to = next;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value == null || Motion.reduced(context)) {
      return Text(widget.format(widget.value), style: widget.style);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Motion.arrive.transform(_c.isAnimating ? _c.value : 1);
        final shown = _from + ((_to - _from) * t).round();
        return Text(widget.format(shown), style: widget.style);
      },
    );
  }
}

/// A slow breathing dot for something that is genuinely happening right
/// now. Stops with the widget, so it never runs off-screen.
class LivePulse extends StatefulWidget {
  final Color color;
  final double size;

  const LivePulse({super.key, required this.color, this.size = 7});

  @override
  State<LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<LivePulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 1400),
    vsync: this,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) {
      return Icon(Icons.circle, size: widget.size, color: widget.color);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.55 + 0.45 * t),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.35 * t),
                blurRadius: 4 + 4 * t,
                spreadRadius: 0.5 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}
