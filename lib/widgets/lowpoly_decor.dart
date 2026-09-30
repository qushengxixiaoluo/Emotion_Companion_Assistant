import 'dart:math';

import 'package:flutter/material.dart';

import '../app/styles/app_styles.dart';
import '../app/styles/ui_style.dart';
import '../app/themes/app_colors.dart';

/// 静态几何碎片（多边形色块 + 描边），
/// 替换 app_splash 漂浮圆、页面光晕圆等"柔光圆"装饰。
class GeometricShard extends StatelessWidget {
  const GeometricShard({
    super.key,
    required this.color,
    this.size = 60,
    this.sides = 3,
    this.rotation = 0,
    this.strokeWidth = AppStroke.thin,
    this.strokeColor,
    this.fillAlpha = 0.35,
    this.child,
  });

  final Color color;
  final double size;

  /// 3=三角 4=菱形 5/6=多边形
  final int sides;
  final double rotation;
  final double strokeWidth;
  final Color? strokeColor;
  final double fillAlpha;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ink = strokeColor ?? AppStroke.inkOf(context);
    return Transform.rotate(
      angle: rotation,
      child: CustomPaint(
        size: Size.square(size),
        painter: _ShardPainter(
          color: color.withValues(alpha: fillAlpha),
          ink: ink,
          strokeWidth: strokeWidth,
          sides: sides,
          style: UiStyleScope.of(context),
        ),
        child: child,
      ),
    );
  }
}

class _ShardPainter extends CustomPainter {
  _ShardPainter({
    required this.color,
    required this.ink,
    required this.strokeWidth,
    required this.sides,
    this.style = AppUiStyle.lowPoly,
  });

  final Color color;
  final Color ink;
  final double strokeWidth;
  final int sides;
  final AppUiStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    // 水彩天空：多边形 → 圆润有机软 blob（卵石轮廓），去硬边
    if (style == AppUiStyle.watercolor) {
      final blob = _blobPath(center, r, sides);
      canvas.drawPath(
          blob, Paint()..color = color.withValues(alpha: color.a * 0.75));
      canvas.drawPath(
        blob,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth =
              strokeWidth > 0.6 ? strokeWidth - 0.3 : strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          // 水彩不勾硬黑边：边缘墨色压到 0.35 以下
          ..color = ink.withValues(alpha: 0.35),
      );
      return;
    }

    final path = Path();
    for (int k = 0; k < sides; k++) {
      final a = -pi / 2 + 2 * pi * k / sides;
      final p = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = ink,
    );
  }

  /// 低频正弦起伏的闭合平滑曲线：软 blob / 圆角卵石轮廓（确定性，随 sides 换相位）
  static Path _blobPath(Offset c, double r, int sides) {
    const samples = 16;
    final phase = sides * 0.9;
    final pts = <Offset>[];
    for (var i = 0; i < samples; i++) {
      final a = -pi / 2 + 2 * pi * i / samples;
      final wob = 1 + 0.08 * sin(a * 2 + phase) + 0.05 * cos(a * 3 - phase);
      pts.add(Offset(c.dx + r * wob * cos(a), c.dy + r * wob * sin(a)));
    }
    Offset mid(int i, int j) =>
        Offset((pts[i].dx + pts[j].dx) / 2, (pts[i].dy + pts[j].dy) / 2);
    final path = Path()..moveTo(mid(samples - 1, 0).dx, mid(samples - 1, 0).dy);
    for (var i = 0; i < samples; i++) {
      final ctrl = pts[i];
      final end = mid(i, (i + 1) % samples);
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _ShardPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.ink != ink ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.sides != sides ||
      oldDelegate.style != style;
}

/// 心跳呼吸按钮的几何碎片粒子（替换软光点粒子：实色三角/四边形 + 1.5px 描边，无 blur）
///
/// 水彩天空风格下自动切换为「圆形光尘点」：圆点填充（alpha ×0.75）+ 极淡圆头描边。
class GeometricParticlesPainter extends CustomPainter {
  GeometricParticlesPainter({
    required this.progress,
    required this.breatheScale,
    required this.isDark,
    this.count = 10,
    this.seed = 42,
    this.style = AppUiStyle.lowPoly,
  });

  /// 0..1 动画进度
  final double progress;

  /// 呼吸缩放系数
  final double breatheScale;
  final bool isDark;
  final int count;
  final int seed;
  final AppUiStyle style;

  static const List<Color> _palette = [
    AppColors.hazeBlue,
    AppColors.softPink,
    AppColors.lightCyan,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ink = AppStroke.ink(isDark: isDark, style: style);
    final watercolor = style == AppUiStyle.watercolor;
    final rng = Random(seed); // 固定种子保持粒子分布稳定

    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi + (rng.nextDouble() - 0.5) * 0.3;
      // 轨道在主按钮（半径≈size*0.40）之外，粒子环绕不藏在圆后露残角
      final orbitRadius = size.width * 0.44 + rng.nextDouble() * 10;
      final speed = 0.15 + rng.nextDouble() * 0.25;
      final baseSize = 6.0 + rng.nextDouble() * 8.0;
      final baseOpacity = 0.25 + rng.nextDouble() * 0.35;
      final driftPhase = rng.nextDouble() * 2 * pi;

      final currentAngle = angle + progress * 2 * pi * speed;
      final drift = sin(progress * 2 * pi + driftPhase) * 12;
      final radius = orbitRadius + drift;
      final breatheBoost = (breatheScale - 1.0) * 8;
      final opacity =
          (baseOpacity + breatheBoost * 0.3).clamp(0.1, 0.75);

      final x = center.dx + cos(currentAngle) * radius;
      final y = center.dy + sin(currentAngle) * radius;
      final r = baseSize + breatheBoost;

      final fill = _palette[i % _palette.length];

      // 水彩：圆形光尘点，去硬边
      if (watercolor) {
        final pos = Offset(x, y);
        canvas.drawCircle(
            pos, r, Paint()..color = fill.withValues(alpha: opacity * 0.75));
        canvas.drawCircle(
          pos,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = AppStroke.hairline
            ..strokeCap = StrokeCap.round
            ..color = ink.withValues(alpha: (opacity * 0.35).clamp(0.0, 0.35)),
        );
        continue;
      }

      // 交替三角/四边形，旋转朝向随时间变化
      final sides = (i % 2 == 0) ? 3 : 4;
      final path = Path();
      for (int k = 0; k < sides; k++) {
        final a = -pi / 2 + 2 * pi * k / sides + currentAngle;
        final px = x + r * cos(a);
        final py = y + r * sin(a);
        k == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
      }
      path.close();

      canvas.drawPath(
          path, Paint()..color = fill.withValues(alpha: opacity));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppStroke.thin
          ..color = ink.withValues(alpha: (opacity + 0.15).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant GeometricParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.breatheScale != breatheScale ||
      oldDelegate.isDark != isDark ||
      oldDelegate.style != style;
}

/// 卡片顶部强调色条（底部 2px ink 分隔）
class AccentStripe extends StatelessWidget {
  const AccentStripe({super.key, required this.color, this.height = 4});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    // 水彩天空：实色硬条 + 2px 黑底线 → 渐变细条 + 淡墨发丝线
    if (UiStyleScope.isWatercolor(context)) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [color, color.withValues(alpha: 0.25)],
          ),
          border: Border(
            bottom: BorderSide(
              color: AppStroke.inkOf(context).withValues(alpha: 0.35),
              width: AppStroke.hairline,
            ),
          ),
        ),
      );
    }
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        border: Border(
          bottom: BorderSide(
            color: AppStroke.inkOf(context),
            width: AppStroke.standard,
          ),
        ),
      ),
    );
  }
}

/// 面片小徽标（章节标题左侧几何块，替换圆角竖条）
class FacetDot extends StatelessWidget {
  const FacetDot({
    super.key,
    required this.color,
    this.size = 10,
    this.strokeWidth = AppStroke.thin,
  });

  final Color color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return GeometricShard(
      color: color,
      size: size,
      sides: 4, // 菱形
      rotation: pi / 4,
      strokeWidth: strokeWidth,
      fillAlpha: 1.0,
    );
  }
}
