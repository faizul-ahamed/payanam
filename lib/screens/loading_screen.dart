import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'logo_animation_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String _statusText = 'Initializing Payanam…';
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _timers.add(
      Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() => _statusText = 'Checking authentication…');

        _timers.add(
          Timer(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            setState(() => _statusText = 'Verifying permissions…');

            _timers.add(
              Timer(const Duration(milliseconds: 500), () {
                if (!mounted) return;
                setState(() => _statusText = 'Loading preferences…');

                _timers.add(
                  Timer(const Duration(milliseconds: 400), () {
                    if (!mounted) return;
                    setState(() => _statusText = 'Almost ready…');

                    _timers.add(
                      Timer(const Duration(milliseconds: 500), () {
                        if (!mounted) return;
                        Navigator.of(context).pushReplacement(
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const LogoAnimationScreen(),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                            transitionDuration: const Duration(
                              milliseconds: 800,
                            ),
                          ),
                        );
                      }),
                    );
                  }),
                );
              }),
            );
          }),
        );
      }),
    );
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();

    _pulseController.dispose();
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryPurple.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _statusText,
                  key: ValueKey<String>(_statusText),
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
