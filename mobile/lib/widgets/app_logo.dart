import 'package:flutter/material.dart';

/// The Mulyankan mark (icon only, no wordmark) — background already
/// removed from the source artwork, see mobile/assets/mulyankan_mark.png.
class AppLogoMark extends StatelessWidget {
  final double size;
  const AppLogoMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/mulyankan_mark.png', width: size, height: size, fit: BoxFit.contain);
  }
}

/// The full lockup — mark plus the "MULYANKAN / AUTO VEHICLES VALUATOR"
/// wordmark baked into the artwork itself, see mobile/assets/mulyankan_logo.png.
class AppLogoFull extends StatelessWidget {
  final double width;
  const AppLogoFull({super.key, this.width = 280});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/mulyankan_logo.png', width: width, fit: BoxFit.contain);
  }
}
