import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../core/npr_formatter.dart';

/// Big-number price entry with quick ±5,000 / ±10,000 adjusters — built for
/// one-thumb use in a workshop, not careful typing.
class PricePad extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onChanged;

  const PricePad({super.key, this.initialValue = 0, required this.onChanged});

  @override
  State<PricePad> createState() => _PricePadState();
}

class _PricePadState extends State<PricePad> {
  late int _value = widget.initialValue;
  late final _controller = TextEditingController(text: _value == 0 ? '' : _value.toString());

  void _adjust(int delta) {
    setState(() {
      _value = (_value + delta).clamp(0, 999999999);
      _controller.text = _value.toString();
    });
    widget.onChanged(_value);
  }

  void _onTyped(String text) {
    final parsed = int.tryParse(text.replaceAll(',', '')) ?? 0;
    _value = parsed;
    widget.onChanged(_value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Center(
            child: Text(formatNpr(_value), style: AppTheme.moneyStyle(size: 40, color: AppColors.money)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: AppTheme.moneyStyle(size: 22),
          decoration: const InputDecoration(hintText: 'Type an amount'),
          onChanged: _onTyped,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _AdjustButton(label: '-10,000', onTap: () => _adjust(-10000)),
            const SizedBox(width: 8),
            _AdjustButton(label: '-5,000', onTap: () => _adjust(-5000)),
            const SizedBox(width: 8),
            _AdjustButton(label: '+5,000', onTap: () => _adjust(5000)),
            const SizedBox(width: 8),
            _AdjustButton(label: '+10,000', onTap: () => _adjust(10000)),
          ],
        ),
      ],
    );
  }
}

class _AdjustButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AdjustButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), padding: EdgeInsets.zero),
        child: FittedBox(child: Text(label)),
      ),
    );
  }
}
