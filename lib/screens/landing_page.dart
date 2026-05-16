import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'student_login_screen.dart';
import 'driver_login_screen.dart';
import 'admin_login_screen.dart';
import '../widgets/theme_toggle_button.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late AnimationController _contentController;
  late Animation<double> _headerFade;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _buttonsFade;
  late Animation<Offset> _buttonsSlide;

  @override
  void initState() {
    super.initState();

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _heroFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.1, 0.45, curve: Curves.easeOut),
      ),
    );

    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _contentController,
            curve: const Interval(0.1, 0.45, curve: Curves.easeOutCubic),
          ),
        );

    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );

    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _contentController,
            curve: const Interval(0.35, 0.65, curve: Curves.easeOutCubic),
          ),
        );

    _buttonsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _buttonsSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _contentController,
            curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _contentController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // ── Top Header Bar ──
              FadeTransition(opacity: _headerFade, child: _buildTopHeader()),

              const SizedBox(height: 20),

              // ── Scrollable content ──
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // ── Hero Bus Image Card ──
                      SlideTransition(
                        position: _heroSlide,
                        child: FadeTransition(
                          opacity: _heroFade,
                          child: _buildHeroCard(screenWidth),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Description Card ──
                      SlideTransition(
                        position: _cardSlide,
                        child: FadeTransition(
                          opacity: _cardFade,
                          child: _buildDescriptionCard(),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Buttons ──
                      SlideTransition(
                        position: _buttonsSlide,
                        child: FadeTransition(
                          opacity: _buttonsFade,
                          child: _buildButtons(),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        // Logo icon
        Container(
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              width: 28,
              height: 28,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // App name
        Text(
          'PAYANAM',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.getTextPrimary(context),
            letterSpacing: 2.0,
          ),
        ),
        const Spacer(),
        // Theme Toggle Button
        const ThemeToggleButton(),
        const SizedBox(width: 12),
        // Shield / Admin icon button
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
            );
          },
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
            child: const Icon(
              Icons.shield_outlined,
              color: AppColors.primaryPurple,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(double screenWidth) {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.getSurfaceCardColor(context),
        border: Border.all(
          color: AppColors.getBorderColor(context).withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background with bus illustration
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1A1A3E),
                    const Color(0xFF0D1B2A),
                    AppColors.primaryPurple.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            //Decorative circles
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryPurple.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Center bus image and live track badge
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 18,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/bus_image.png',
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppColors.primaryPurple.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'LIVE TRACK',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
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

  Widget _buildDescriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.getBorderColor(context).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Your Campus\n',
                  style: AppTextStyles.heading1(context).copyWith(
                    fontSize: 26,
                    height: 1.3,
                  ),
                ),
                TextSpan(
                  text: 'Commute,\nSimplified.',
                  style: AppTextStyles.heading1(context).copyWith(
                    fontSize: 26,
                    height: 1.3,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [
                          AppColors.primaryPurple,
                          AppColors.primaryBlue,
                        ],
                      ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Track your bus in real-time and\nnever miss a stop again with our\npremium campus utility.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium(context).copyWith(
              color: AppColors.textMutedDark,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 58,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StudentLoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Get Started',
                    style: AppTextStyles.buttonText,
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DriverLoginScreen()),
              );
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.getButtonDriverBg(context),
              side: BorderSide(
                color: AppColors.getBorderColor(context),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_bus_outlined,
                  color: AppColors.getTextPrimary(context).withValues(alpha: 0.8),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Driver Login',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
