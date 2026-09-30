import 'dart:math';

import 'package:flutter/material.dart';
import '../app/styles/app_styles.dart';
import '../app/styles/ui_style.dart';
import '../app/themes/app_colors.dart';
import 'lowpoly_decor.dart';

class AppSplash extends StatefulWidget {
  final Future<void> appInit;
  final VoidCallback onFinished;
  final bool isDarkMode;

  const AppSplash({
    super.key,
    required this.appInit,
    required this.onFinished,
    required this.isDarkMode,
  });

  @override
  State<AppSplash> createState() => _AppSplashState();
}

class _AppSplashState extends State<AppSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;
  late final Animation<double> _float;

  bool _initDone = false;
  bool _animDone = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );

    _float = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animDone = true;
        _tryFinish();
      }
    });

    widget.appInit.then((_) {
      if (mounted) {
        _initDone = true;
        _tryFinish();
      }
    });
  }

  void _tryFinish() {
    if (_animDone && _initDone) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) widget.onFinished();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const [
                      AppColors.splashTopDark,
                      AppColors.splashMidDark,
                      AppColors.splashBotDark,
                    ]
                  : const [
                      AppColors.splashTopLight,
                      AppColors.splashMidLight,
                      AppColors.splashBotLight,
                    ],
            ),
          ),
          child: Stack(
            children: [
              _buildFloatingCircles(dark),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: _scale.value,
                      child: Opacity(
                        opacity: _fadeIn.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: (dark ? AppColors.darkCard : Colors.white).withValues(alpha: 0.9),
                            boxShadow: AppShadow.hard(context, dy: 4, alpha: 0.25),
                          ),
                          // 描边用 foreground：logo 图铺满 100x100，
                          // 放 decoration 会被图片盖住
                          foregroundDecoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: dark
                                  ? AppColors.inkDark
                                  : AppColors.inkLight,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              dark
                                  ? 'assets/images/app_icon_night.png'
                                  : 'assets/images/app_icon_day.png',
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Opacity(
                      opacity: _fadeIn.value,
                      child: Transform.translate(
                        offset: Offset(0, 4 * (1 - _float.value)),
                        child: Text(
                          '抱抱情绪云',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: _fadeIn.value * 0.7,
                      child: Text(
                        '用温暖抱抱你的每一种情绪',
                        style: TextStyle(
                          fontSize: 14,
                          color: dark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Opacity(
                      opacity: _fadeIn.value * 0.6,
                      child: _LoadingDots(isDarkMode: dark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingCircles(bool dark) {
    return Positioned.fill(
      child: Opacity(
        opacity: _fadeIn.value * 0.4,
        child: _FloatingDecorations(isDarkMode: dark),
      ),
    );
  }
}

class _FloatingDecorations extends StatelessWidget {
  final bool isDarkMode;
  const _FloatingDecorations({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final alpha = isDarkMode ? 0.25 : 0.15;
    return Stack(
      children: [
        Align(
          alignment: const Alignment(-0.7, -0.6),
          child: _DecoCircle(color: AppColors.softPink.withValues(alpha: alpha), size: 60, delay: 0.0),
        ),
        Align(
          alignment: const Alignment(0.75, -0.4),
          child: _DecoCircle(color: AppColors.lightCyan.withValues(alpha: alpha), size: 80, delay: 0.3),
        ),
        Align(
          alignment: const Alignment(-0.6, 0.2),
          child: _DecoCircle(color: AppColors.gentlePurple.withValues(alpha: alpha), size: 50, delay: 0.6),
        ),
        Align(
          alignment: const Alignment(0.65, 0.1),
          child: _DecoCircle(color: AppColors.calmGreen.withValues(alpha: alpha), size: 70, delay: 0.9),
        ),
        Align(
          alignment: const Alignment(-0.3, 0.5),
          child: _DecoCircle(color: AppColors.softOrange.withValues(alpha: alpha), size: 40, delay: 1.2),
        ),
      ],
    );
  }
}

class _DecoCircle extends StatefulWidget {
  final Color color;
  final double size;
  final double delay;

  const _DecoCircle({
    required this.color,
    required this.size,
    required this.delay,
  });

  @override
  State<_DecoCircle> createState() => _DecoCircleState();
}

class _DecoCircleState extends State<_DecoCircle>
    with SingleTickerProviderStateMixin {
  /// 5 个装饰按 delay 轮换 3/4/5/6 边
  static const List<int> _shardSides = [3, 4, 5, 6];

  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).round()), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // delay 步进 0.3（0 / 0.3 / 0.6 / 0.9 / 1.2）→ 0..4 → 轮换 3/4/5/6 边
    final sideIndex = (widget.delay / 0.3).round() % _shardSides.length;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -8 * _ctrl.value),
          child: GeometricShard(
            color: widget.color,
            size: widget.size,
            sides: _shardSides[sideIndex],
            // color 已带原透明度（亮 0.15 / 暗 0.25），
            // GeometricShard 会用 fillAlpha 覆盖，故回传原 alpha
            fillAlpha: widget.color.a,
          ),
        );
      },
    );
  }
}

class _LoadingDots extends StatefulWidget {
  final bool isDarkMode;
  const _LoadingDots({required this.isDarkMode});

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.isDarkMode
        ? AppColors.splashDotDark
        : AppColors.hazeBlue;
    final ink = AppStroke.ink(
        isDark: widget.isDarkMode, style: UiStyleScope.of(context));
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = ((_ctrl.value - delay + 1.0) % 1.0);
            final opacity = 0.3 + 0.5 * (1 - (t - 0.5).abs() * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              // 8px 圆点 → 8px 菱形（45° 旋转的方块）
              child: Transform.rotate(
                angle: pi / 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: opacity),
                    border: Border.all(
                      color: ink.withValues(alpha: opacity),
                      width: 1,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
