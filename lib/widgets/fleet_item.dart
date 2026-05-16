import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum BusStatus { running, delayed, breakdown, inactive }

class FleetItem extends StatelessWidget {
  final String routeName;
  final String currentStop;
  final String busNumber;
  final String? eta;
  final BusStatus status;
  final VoidCallback onTap;

  const FleetItem({
    super.key,
    required this.routeName,
    required this.currentStop,
    required this.busNumber,
    this.eta,
    required this.status,
    required this.onTap,
  });

  Color _getStatusColor() {
    switch (status) {
      case BusStatus.running:
        return AppColors.success;
      case BusStatus.delayed:
        return AppColors.warning;
      case BusStatus.breakdown:
        return AppColors.error;
      case BusStatus.inactive:
        return AppColors.textMutedDark;
    }
  }

  String _getStatusText() {
    switch (status) {
      case BusStatus.running:
        return 'Running';
      case BusStatus.delayed:
        return 'Delayed';
      case BusStatus.breakdown:
        return 'EMERGENCY';
      case BusStatus.inactive:
        return 'Inactive';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceCardColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: status == BusStatus.breakdown 
                ? AppColors.error.withOpacity(0.3) 
                : AppColors.getBorderColor(context).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                status == BusStatus.breakdown 
                    ? Icons.report_problem_outlined 
                    : status == BusStatus.delayed 
                        ? Icons.access_time 
                        : Icons.navigation_outlined,
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routeName,
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currentStop • Bus $busNumber',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.textMutedDark,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (eta != null || status == BusStatus.breakdown) ...[
                  const SizedBox(height: 6),
                  Text(
                    status == BusStatus.breakdown ? 'Immediate Action' : 'ETA $eta',
                    style: TextStyle(
                      color: status == BusStatus.breakdown ? AppColors.error : AppColors.textMutedDark,
                      fontSize: 11,
                      fontWeight: status == BusStatus.breakdown ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
