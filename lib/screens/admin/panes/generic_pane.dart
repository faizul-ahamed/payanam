import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class GenericManagementPane extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const GenericManagementPane({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppColors.textMutedDark.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.heading1(context)),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTextStyles.bodyMedium(context)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: Text('Manage $title'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
