import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/theme_toggle_button.dart';

class AuthTemplate extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget form;
  final VoidCallback onBack;
  final Color accentColor;
  final IconData headerIcon;

  const AuthTemplate({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.onBack,
    this.accentColor = AppColors.primaryPurple,
    this.headerIcon = Icons.lock_outline,
  });

  @override
  State<AuthTemplate> createState() => _AuthTemplateState();
}

class _AuthTemplateState extends State<AuthTemplate>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.backgroundGradientDark : AppColors.backgroundGradientLight,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Top Bar: Back Button & Theme Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: widget.onBack,
                        icon: Icon(
                          Icons.arrow_back_ios, 
                          color: AppColors.getTextPrimary(context)
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const ThemeToggleButton(),
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  // Header Section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: widget.accentColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Icon(
                              widget.headerIcon,
                              color: widget.accentColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            widget.title,
                            style: AppTextStyles.heading1(context).copyWith(
                              fontSize: 32,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.subtitle,
                            style: AppTextStyles.bodyLarge(context).copyWith(
                              color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Form Section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: widget.form,
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
