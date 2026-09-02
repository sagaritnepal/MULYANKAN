import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../core/models/valuation_request.dart';

class DealContext extends StatelessWidget {
  final ValuationRequestDetail detail;
  const DealContext({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    if (detail.customerAskingPrice == null && detail.targetBikeDescription == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.customerAskingPrice != null) Text('Customer asking: Rs ${detail.customerAskingPrice}'),
          if (detail.targetBikeDescription != null) Text('Wants: ${detail.targetBikeDescription}'),
          Text('Urgency: ${detail.urgency == 'now' ? 'Customer waiting now' : 'Decides later'}'),
        ],
      ),
    );
  }
}
