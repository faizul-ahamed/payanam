import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.change,
    required this.icon,
    this.color = AppColors.primaryPurple,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceCardColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.getBorderColor(context).withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Allow content to determine height better
          children: [
            Container(
              padding: const EdgeInsets.all(10), // Reduced from 12
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12), // Reduced from 14
              ),
              child: Icon(icon, color: color, size: 22), // Reduced from 24
            ),
            const SizedBox(height: 12), // Reduced from 20
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium(context).copyWith(
                color: AppColors.getTextSecondary(context),
                fontWeight: FontWeight.w500,
                fontSize: 13, // Slightly smaller
              ),
            ),
            const SizedBox(height: 4), // Reduced from 8
            FittedBox( // Use FittedBox to prevent horizontal overflow and help vertical fit
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: AppTextStyles.heading1(context).copyWith(
                      fontSize: 26, // Slightly smaller
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      change,
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12, // Slightly smaller
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
