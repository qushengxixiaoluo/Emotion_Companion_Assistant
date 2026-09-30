import 'dart:math';
import 'package:flutter/material.dart';
import '../app/styles/app_styles.dart';
import '../app/styles/ui_style.dart';
import '../app/themes/app_colors.dart';
import 'lowpoly_decor.dart';

class HeartbeatBreathButton extends StatefulWidget {
  final VoidCallback onTap;

  const HeartbeatBreathButton({super.key, required this.onTap});

  @override
  State<HeartbeatBreathButton> createState() => _HeartbeatBreathButtonState();
}

class _HeartbeatBreathButtonState extends State<HeartbeatBreathButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = 220.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          // 呼吸脉冲：正弦波，3-4秒一个周期
          final breathe = 1.0 + sin(t * 2 * pi) * 0.06;

          return SizedBox(
            width: size + 56,
            height: size + 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 粒子层
                CustomPaint(
                  size: Size(size + 56, size + 56),
                  painter: GeometricParticlesPainter(
                    progress: t,
                    breatheScale: breathe,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                    seed: 42,
                    style: UiStyleScope.of(context),
                  ),
                ),
                // 主按钮
                Transform.scale(
                  scale: breathe,
                  child: child,
                ),
              ],
            ),
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // lowpoly 平涂：全饱和贴纸色 + 2px 黑描边，醒目不发虚
            color: AppColors.softPink,
            border: AppStroke.all(context),
            boxShadow: AppShadow.hard(context, dy: 5, alpha: 0.35),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 白色爱心：按钮底为深粉贴纸色，同色系图标会撞色看不见
              const Icon(Icons.favorite, color: Colors.white, size: 56),
              const SizedBox(height: 10),
              Text(
                '开始情绪倾诉',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
