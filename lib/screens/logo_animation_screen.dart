import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'landing_page.dart';
import 'student/student_dashboard.dart';
import 'driver_dashboard.dart';
import 'admin_dashboard.dart';

class LogoAnimationScreen extends StatefulWidget {
  const LogoAnimationScreen({super.key});

  @override
  State<LogoAnimationScreen> createState() => _LogoAnimationScreenState();
}

class _LogoAnimationScreenState extends State<LogoAnimationScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _taglineController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<Offset> _logoSlide;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _taglineFade;
  late Animation<Offset> _taglineSlide;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _taglineController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOut),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOutCubic),
    );

    _startAnimationSequence();
  }

  Future<void> _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    _taglineController.forward();

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      final user = FirebaseAuth.instance.currentUser;
      Widget nextScreen = const LandingPage();

      if (user != null) {
        final String? savedRole = await AuthService().getSavedRole();
        if (savedRole != null) {
          if (savedRole == 'student') {
            nextScreen = const StudentDashboard();
          } else if (savedRole == 'driver') {
            nextScreen = const DriverDashboard();
          } else if (savedRole == 'admin') {
            nextScreen = const AdminDashboard();
          }
        }
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            final tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: Curves.easeInOutCubic),
            );
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _taglineController.dispose();
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
              SlideTransition(
                position: _logoSlide,
                child: FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryPurple.withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textFade,
                  child: Text(
                    'PAYANAM',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                      letterSpacing: 6,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [
                            AppColors.primaryPurple,
                            AppColors.primaryBlue,
                            Color(0xFF8B9CF7),
                          ],
                        ).createShader(
                          const Rect.fromLTWH(0, 0, 250, 40),
                        ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              SlideTransition(
                position: _taglineSlide,
                child: FadeTransition(
                  opacity: _taglineFade,
                  child: Text(
                    'Track Smart. Travel Safe.',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      fontSize: 15,
                      letterSpacing: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
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
