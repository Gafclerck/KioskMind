import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';

/// The screen the app shows while it finds out who the merchant is.
///
/// It deliberately navigates nowhere. Where a session belongs is decided in one
/// place, `AppRouterNotifier.redirect`, which reacts to the real state of
/// authentication and onboarding. This page used to decide it as well, on a fixed
/// three second timer, and hardcoded to `/onboarding`.
///
/// That was wrong twice over. A merchant who had already onboarded and signed in
/// watched the carousel for three seconds before the router corrected it, and a
/// widget test could not get past the splash without spending three seconds of fake
/// time first. The timer also outlived the widget that created it, so every test that
/// mounted the app failed with a pending timer even when it asserted nothing about
/// navigation. Deciding once, from the state that actually decides it, leaves the
/// splash free to be a splash.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.75,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF19786D),
                  AppColors.primary,
                ],
              ),
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    const Spacer(flex: 5),

                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: SvgPicture.asset(
                        'assets/images/KioskMind_logo.svg',
                        width: 110,
                        height: 110,
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 3),

                    const Text(
                      'KioskMind',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Votre copilote vocal',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondary,
                      ),
                    ),

                    const Spacer(flex: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
