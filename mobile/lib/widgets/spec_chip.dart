import 'package:flutter/material.dart';

class SpecChip extends StatelessWidget {
  final String text;
  const SpecChip(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Chip(label: Text(text), visualDensity: VisualDensity.compact);
}

String ordinalOwner(int n) => switch (n) { 1 => '1st owner', 2 => '2nd owner', 3 => '3rd owner', _ => '4th+ owner' };
