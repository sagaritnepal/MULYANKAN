import 'package:flutter/material.dart';
import '../app_theme.dart';

/// A single vehicle fact. Was a stock Material [Chip], which brought its
/// own light-theme fill and pill radius into an otherwise dark, squarer
/// app; this matches the surface/divider/radius vocabulary everything
/// else uses.
class SpecChip extends StatelessWidget {
  final String text;
  const SpecChip(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          color: AppColors.ink,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

String ordinalOwner(int n) => switch (n) {
  1 => '1st owner',
  2 => '2nd owner',
  3 => '3rd owner',
  _ => '4th+ owner',
};
