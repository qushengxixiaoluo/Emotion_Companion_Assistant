import 'package:flutter/material.dart';
import 'dart:math';
import '../app/styles/app_styles.dart';
import '../app/styles/ui_style.dart';
import '../app/themes/app_colors.dart';
import '../models/emotion_models.dart';

class EmotionRadarChart extends StatelessWidget {
  final EmotionRecord record;
  final Color textColor;

  const EmotionRadarChart({super.key, required this.record, this.textColor = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      size: const Size(double.infinity, 120),
      painter: _RadarPainter(
        record,
        textColor: textColor,
        isDark: isDark,
        style: UiStyleScope.of(context),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final EmotionRecord record;
  final Color textColor;
  final bool isDark;
  final AppUiStyle style;

  _RadarPainter(
    this.record, {
    this.textColor = AppColors.textSecondary,
    required this.isDark,
    this.style = AppUiStyle.lowPoly,
  });

  bool get _watercolor => style == AppUiStyle.watercolor;

  /// 水彩：线宽收细 0.3 + 圆头圆角；lowPoly 原值原样
  double _sw(double w) => _watercolor && w > 0.6 ? w - 0.3 : w;

  /// 面片/语义色填充水彩下 alpha ×0.75（清透）
  double _fillA(double a) => _watercolor ? a * 0.75 : a;

  Paint _stroke(double width, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _sw(width);
    if (_watercolor) {
      p
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;

    final dimensions = [
      ('悲伤', record.sadness, AppColors.softPink),
      ('焦虑', record.anxiety, AppColors.softOrange),
      ('愤怒', record.anger, AppColors.angerRed),
      ('孤独', record.loneliness, AppColors.gentlePurple),
      ('开心', record.happiness, AppColors.calmGreen),
      ('平静', record.calmness, AppColors.lightCyan),
      ('压抑', record.suppression, AppColors.warmBeige),
    ];

    final n = dimensions.length;
    final angleStep = 2 * pi / n;
    final ink = AppStroke.ink(isDark: isDark, style: style);

    // 绘制网格：1px ink 描边（alpha 0.25）
    final gridPaint = _stroke(AppStroke.hairline, ink.withValues(alpha: 0.25));

    for (var i = 1; i <= 3; i++) {
      final path = Path();
      for (var j = 0; j < n; j++) {
        final angle = angleStep * j - pi / 2;
        final r = radius * i / 3;
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (j == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 中心轴线：中心 → 7 个外顶点，1px ink alpha 0.2
    final axisPaint = _stroke(1, ink.withValues(alpha: 0.2));
    for (var i = 0; i < n; i++) {
      final angle = angleStep * i - pi / 2;
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        ),
        axisPaint,
      );
    }

    // 数据区域：7 个三角扇区分面填充 + 每片独立 ink 描边（lowpoly 分面效果）
    final facetFillPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < n; i++) {
      final angleA = angleStep * i - pi / 2;
      final angleB = angleStep * ((i + 1) % n) - pi / 2;
      final rA = radius * dimensions[i].$2;
      final rB = radius * dimensions[(i + 1) % n].$2;
      final facet = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + rA * cos(angleA), center.dy + rA * sin(angleA))
        ..lineTo(center.dx + rB * cos(angleB), center.dy + rB * sin(angleB))
        ..close();

      facetFillPaint.color =
          dimensions[i].$3.withValues(alpha: _fillA(0.25));
      canvas.drawPath(facet, facetFillPaint);

      canvas.drawPath(facet, _stroke(AppStroke.standard, ink));
    }

    // 绘制数据点（r=4 菱形）和标签
    for (var i = 0; i < n; i++) {
      final angle = angleStep * i - pi / 2;
      final r = radius * dimensions[i].$2;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);

      const d = 4.0;
      final diamond = Path()
        ..moveTo(x, y - d)
        ..lineTo(x + d, y)
        ..lineTo(x, y + d)
        ..lineTo(x - d, y)
        ..close();
      canvas.drawPath(
        diamond,
        Paint()..color = dimensions[i].$3.withValues(alpha: _fillA(dimensions[i].$3.a)),
      );
      canvas.drawPath(diamond, _stroke(1.5, ink));

      // 标签
      final labelR = radius + 16;
      final lx = center.dx + labelR * cos(angle);
      final ly = center.dy + labelR * sin(angle);
      final textPainter = TextPainter(
        text: TextSpan(
          text: dimensions[i].$1,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(lx - textPainter.width / 2, ly - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.record != record ||
      oldDelegate.textColor != textColor ||
      oldDelegate.isDark != isDark ||
      oldDelegate.style != style;
}
