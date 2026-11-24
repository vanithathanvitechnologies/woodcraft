import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/customer_api_service.dart';
import 'customer_dashboard_screen.dart';
import 'mobile_login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _brass = Color(0xFFD4A037);

  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _progressCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoTilt;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.72, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _logoTilt = Tween<double>(begin: -0.05, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.42, 0.95, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.42, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _progressAnim = CurvedAnimation(
      parent: _progressCtrl,
      curve: Curves.easeInOutCubic,
    );

    _entryCtrl.forward();
    _progressCtrl.forward();
    _bootAndNavigate();
  }

  Future<void> _bootAndNavigate() async {
    await Future.wait([
      CustomerApiService.instance.init().catchError((_) {}),
      Future.delayed(const Duration(milliseconds: 2450)),
    ]);

    if (!mounted) return;
    final Widget next = CustomerApiService.instance.token != null
        ? const CustomerDashboardScreen()
        : const MobileLoginScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 480),
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  Widget _buildPulseRing(double phaseShift) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final t = (_pulseCtrl.value + phaseShift) % 1.0;
        final scale = 1.0 + (t * 0.72);
        final opacity = (1.0 - t) * 0.42;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 186,
            height: 94,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _brass.withValues(alpha: opacity),
                width: 2.0,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.18),
            radius: 1.15,
            colors: [
              Color(0xFF5C2E14),
              Color(0xFF3B1E0D),
              Color(0xFF221107),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Animated Logo Crest + Expanding Golden Pulse Rings + Glossy Sheen
              SizedBox(
                width: 280,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ambient golden glow
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) {
                        final breathe = 0.16 + 0.08 * math.sin(_pulseCtrl.value * 2 * math.pi);
                        return Container(
                          width: 210,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: _brass.withValues(alpha: breathe),
                                blurRadius: 48,
                                spreadRadius: 12,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    _buildPulseRing(0.0),
                    _buildPulseRing(0.5),

                    // Main Logo Card
                    AnimatedBuilder(
                      animation: Listenable.merge([_entryCtrl, _pulseCtrl]),
                      builder: (_, child) {
                        final floatY = -3.5 * math.sin(_pulseCtrl.value * 2 * math.pi);
                        return Opacity(
                          opacity: _logoOpacity.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, floatY),
                            child: Transform.rotate(
                              angle: _logoTilt.value,
                              child: Transform.scale(
                                scale: _logoScale.value,
                                child: child,
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 184,
                        height: 92,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _brass.withValues(alpha: 0.75),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.42),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Image.asset(
                                  'assets/images/app_logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              // Diagonal Light Sheen Sweep
                              AnimatedBuilder(
                                animation: _pulseCtrl,
                                builder: (_, __) {
                                  final sweep = (_pulseCtrl.value * 3.4) - 1.7;
                                  return Align(
                                    alignment: Alignment(sweep, 0),
                                    child: Transform.rotate(
                                      angle: 0.35,
                                      child: Container(
                                        width: 32,
                                        height: 160,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withValues(alpha: 0.0),
                                              Colors.white.withValues(alpha: 0.42),
                                              Colors.white.withValues(alpha: 0.0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Brand Title & Subtitle Reveal
              FadeTransition(
                opacity: _textOpacity,
                child: SlideTransition(
                  position: _textSlide,
                  child: Column(
                    children: [
                      const Text(
                        'Suresh Timbers',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: _brass.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _brass.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'SINCE 1983 • 25 YRS WRITTEN WARRANTY',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF3DEC0),
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Royal Main Entrance for Your Family',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.72),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // Animated Loading Progress Bar
              FadeTransition(
                opacity: _textOpacity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _progressAnim,
                          builder: (_, __) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _progressAnim.value,
                                minHeight: 4.5,
                                backgroundColor: Colors.white.withValues(alpha: 0.14),
                                valueColor: const AlwaysStoppedAnimation<Color>(_brass),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _brass.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              'Loading...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.65),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
