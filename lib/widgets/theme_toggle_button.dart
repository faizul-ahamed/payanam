import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

class ThemeToggleButton extends StatelessWidget {
  final Color? color;
  const ThemeToggleButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return GestureDetector(
      onTap: () => themeProvider.toggleTheme(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.getSurfaceCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.getBorderColor(context).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          color: color ?? AppColors.primaryPurple,
          size: 22,
        ),
      ),
    );
  }
}
