import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/styles/app_styles.dart';
import '../app/styles/ui_style.dart';
import '../app/themes/app_colors.dart';

/// 全站共享的低多边形页面背景（drop-in 替换原 LinearGradient Container）
///
/// 结构 = 底层渐变（复刻原 gradientColors 视觉）+ 淡色三角网格面片 + 1px 淡描边。
/// 网格采用「确定性抖动」：每个格子独立取样 Random(seed ^ cellHash)，
/// 视口变化时已有格子结果不变，固定 seed 截图可复现。
class LowPolyBackground extends StatelessWidget {
  const LowPolyBackground({
    super.key,
    this.tint,
    this.tintAlpha,
    this.tintAlphaDark,
    this.seed = 0x4C4F5750,
    this.cellSize = 150,
    this.meshAlpha = 0.45,
    this.strokeAlpha,
    this.topFade = 96,
    required this.child,
  });

  /// 页面强调色（渐变顶部色 + 面片取色基准），默认雾蓝
  final Color? tint;

  /// 浅色渐变顶部透明度（默认 0.05）
  final double? tintAlpha;

  /// 深色渐变顶部透明度（默认 0.12；页面有单独深色值时传入）
  final double? tintAlphaDark;

  final int seed;
  final double cellSize;
  final double meshAlpha;
  final double? strokeAlpha;
  final double topFade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = UiStyleScope.of(context);

    // 双风格分流：水彩天空走 _SkyWashPainter，lowpoly 走原三角面片画笔
    if (style == AppUiStyle.watercolor) {
      return Container(
        decoration: SkyWashDecoration(
          tint: tint ?? AppColors.hazeBlue,
          tintAlpha:
              isDark ? (tintAlphaDark ?? tintAlpha ?? 0.12) : (tintAlpha ?? 0.05),
          isDark: isDark,
          seed: seed,
        ),
        child: child,
      );
    }

    return Container(
      decoration: LowPolyDecoration(
        tint: tint ?? AppColors.hazeBlue,
        tintAlpha: isDark ? (tintAlphaDark ?? tintAlpha ?? 0.12) : (tintAlpha ?? 0.05),
        isDark: isDark,
        seed: seed,
        cellSize: cellSize,
        meshAlpha: meshAlpha,
        // 默认不描线：横线/蜘蛛网感都来自网格描边，
        // lowpoly 身份完全由相邻面片的微色差呈现（需要线时可显式传 strokeAlpha）
        strokeAlpha: strokeAlpha ?? 0,
        topFade: topFade,
      ),
      child: child,
    );
  }
}

/// 与 BoxDecoration(gradient:) 同构的 Decoration：零布局风险，
/// ==/hashCode 按字段比较 → 装饰不变时不会触发重绘。
class LowPolyDecoration extends Decoration {
  const LowPolyDecoration({
    required this.tint,
    required this.tintAlpha,
    required this.isDark,
    required this.seed,
    required this.cellSize,
    required this.meshAlpha,
    required this.strokeAlpha,
    required this.topFade,
  });

  final Color tint;
  final double tintAlpha;
  final bool isDark;
  final int seed;
  final double cellSize;
  final double meshAlpha;
  final double strokeAlpha;
  final double topFade;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _LowPolyPainter(this, onChanged);

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) =>
      false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LowPolyDecoration &&
          other.tint == tint &&
          other.tintAlpha == tintAlpha &&
          other.isDark == isDark &&
          other.seed == seed &&
          other.cellSize == cellSize &&
          other.meshAlpha == meshAlpha &&
          other.strokeAlpha == strokeAlpha &&
          other.topFade == topFade);

  @override
  int get hashCode => Object.hash(tint, tintAlpha, isDark, seed, cellSize,
      meshAlpha, strokeAlpha, topFade);
}

class _LowPolyPainter extends BoxPainter {
  _LowPolyPainter(this.decoration, [VoidCallback? onChanged])
      : super(onChanged);

  final LowPolyDecoration decoration;

  ui.Picture? _picture;
  Size? _pictureSize;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    // Picture 缓存：尺寸与装饰不变时直接重放
    final cached = _picture;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    if (cached != null && _pictureSize == size) {
      canvas.drawPicture(cached);
      canvas.restore();
      return;
    }
    cached?.dispose();
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    _paintScene(c, size);
    _picture = recorder.endRecording();
    _pictureSize = size;
    canvas.drawPicture(_picture!);
    canvas.restore();
  }

  void _paintScene(Canvas canvas, Size size) {
    final d = decoration;
    final rect = Offset.zero & size;

    // 1) 底层渐变（复刻原 gradientColors）
    final bg =
        d.isDark ? AppColors.darkBackground : AppColors.background;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [d.tint.withValues(alpha: d.tintAlpha), bg],
    );
    canvas.drawRect(
        rect, Paint()..shader = gradient.createShader(rect));

    // 2) 抖动网格三角剖分
    final cell = d.cellSize;
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;

    Offset vertex(int i, int j) {
      // 边界顶点钉死，避免边缘漏出渐变底
      if (i == 0 || j == 0 || i >= cols || j >= rows) {
        return Offset(
          i == 0 ? 0.0 : (i >= cols ? size.width : i * cell),
          j == 0 ? 0.0 : (j >= rows ? size.height : j * cell),
        );
      }
      final r = Random(_cellHash(d.seed, i, j));
      // 轻微抖动（0.06）：保留手工分面的味道，但整体保持规整不乱
      return Offset(
        i * cell + (r.nextDouble() - 0.5) * 0.06 * cell,
        j * cell + (r.nextDouble() - 0.5) * 0.06 * cell,
      );
    }

    double fadeAt(double y) {
      if (d.topFade <= 0 || y >= d.topFade) return 1.0;
      return (y / d.topFade).clamp(0.0, 1.0);
    }

    final ink = d.isDark ? AppColors.inkDark : AppColors.inkLight;
    final palette =
        d.isDark ? AppColors.lowPolyDark : AppColors.lowPolyLight;
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.hairline;

    for (int j = 0; j < rows; j++) {
      for (int i = 0; i < cols; i++) {
        final v00 = vertex(i, j);
        final v10 = vertex(i + 1, j);
        final v01 = vertex(i, j + 1);
        final v11 = vertex(i + 1, j + 1);
        // 交替对角线方向，避免网格方向感
        final flip = (i + j).isOdd;
        final tris = flip
            ? [
                [v00, v10, v11],
                [v00, v11, v01],
              ]
            : [
                [v00, v10, v01],
                [v10, v11, v01],
              ];

        final h = _cellHash(d.seed, i, j);
        for (final tri in tris) {
          final path = Path()
            ..moveTo(tri[0].dx, tri[0].dy)
            ..lineTo(tri[1].dx, tri[1].dy)
            ..lineTo(tri[2].dx, tri[2].dy)
            ..close();

          final cy = (tri[0].dy + tri[1].dy + tri[2].dy) / 3;
          final fade = fadeAt(cy);

          // 靠相邻面片的微色差呈现 lowpoly（块面主导），强调面片极少且很淡
          final accent = (h % 12) == 0;
          final color = accent
              ? palette[h % palette.length]
              : Color.lerp(bg, d.tint, 0.03 + (h % 4) * 0.02)!;
          final baseAlpha = accent ? 0.26 : 0.30 + (h % 4) * 0.05;
          fillPaint.color =
              color.withValues(alpha: baseAlpha * d.meshAlpha * fade);
          canvas.drawPath(path, fillPaint);

          strokePaint.color = ink.withValues(
              alpha: d.strokeAlpha * fade);
          canvas.drawPath(path, strokePaint);
        }
      }
    }
  }

  /// 与坐标无关的格子哈希：固定 seed 下结果稳定
  static int _cellHash(int seed, int i, int j) {
    var h = seed ^ (i * 73856093) ^ (j * 19349663);
    h ^= (h >> 13);
    h *= 1274126177;
    h ^= (h >> 16);
    return h & 0x7FFFFFFF;
  }
}

// =============================================================================
// 水彩天空背景（AppUiStyle.watercolor）
// =============================================================================

/// 水彩天空 Decoration：与 LowPolyDecoration 同构（==/hashCode 按字段比较，
/// 装饰不变不触发重绘；画笔内部 Picture 缓存）。
class SkyWashDecoration extends Decoration {
  const SkyWashDecoration({
    required this.tint,
    required this.tintAlpha,
    required this.isDark,
    required this.seed,
  });

  final Color tint;
  final double tintAlpha;
  final bool isDark;
  final int seed;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _SkyWashPainter(this, onChanged);

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) =>
      false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SkyWashDecoration &&
          other.tint == tint &&
          other.tintAlpha == tintAlpha &&
          other.isDark == isDark &&
          other.seed == seed);

  @override
  int get hashCode => Object.hash(tint, tintAlpha, isDark, seed);
}

/// 水彩天空画笔：垂直渐变 + 蓬松云影 + 丁达尔光线 + 光尘/星点。
/// 全部由 seed 驱动的确定性随机生成；Picture 缓存，尺寸不变不重绘。
class _SkyWashPainter extends BoxPainter {
  _SkyWashPainter(this.decoration, [VoidCallback? onChanged])
      : super(onChanged);

  final SkyWashDecoration decoration;

  ui.Picture? _picture;
  Size? _pictureSize;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final cached = _picture;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    if (cached != null && _pictureSize == size) {
      canvas.drawPicture(cached);
      canvas.restore();
      return;
    }
    cached?.dispose();
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    _paintScene(c, size);
    _picture = recorder.endRecording();
    _pictureSize = size;
    canvas.drawPicture(_picture!);
    canvas.restore();
  }

  void _paintScene(Canvas canvas, Size size) {
    final d = decoration;
    final rect = Offset.zero & size;
    final r = Random(d.seed);

    // 1) 垂直渐变：light 淡天蓝 → 雾白 → cream（tint 弱化并入底部）；
    //    dark 深靛 → 夜空蓝（tint 同样 lerp ≤ 0.15，不喧宾夺主）
    final tintLerp = d.tintAlpha.clamp(0.0, 0.15);
    final List<Color> colors;
    if (d.isDark) {
      final bottom = Color.lerp(AppColors.waterDarkBg, d.tint, tintLerp)!;
      colors = [AppColors.waterWashTopDark, AppColors.waterDarkBg, bottom];
    } else {
      final bottom = Color.lerp(AppColors.waterCreamBg, d.tint, tintLerp)!;
      colors = [AppColors.waterWashTopLight, AppColors.waterMistLight, bottom];
    }
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // 2) 云：3~5 簇，每簇 3~6 个重叠圆合成一朵蓬松云（单次 drawPath
    //    非零环绕填充 → 簇内 alpha 均匀不叠深），轻度模糊出水彩边缘
    final clusterCount = 3 + r.nextInt(3); // 3..5
    for (var i = 0; i < clusterCount; i++) {
      _paintCloud(canvas, size, r, d.isDark);
    }

    // 3) 丁达尔光线：2~3 条从顶部斜下的半透明白带（新海诚签名）
    final beamCount = 2 + r.nextInt(2); // 2..3
    for (var i = 0; i < beamCount; i++) {
      _paintBeam(canvas, size, r);
    }

    // 4) 光尘/星点：~10 个小圆点
    for (var i = 0; i < 10; i++) {
      final pos = Offset(
        size.width * r.nextDouble(),
        size.height * r.nextDouble(),
      );
      final radius = 1.0 + r.nextDouble() * 1.6;
      final alpha = 0.12 + r.nextDouble() * (d.isDark ? 0.38 : 0.28);
      final dotColor = d.isDark
          ? Colors.white
          : Color.lerp(Colors.white, AppColors.waterSunset, 0.45)!;
      canvas.drawCircle(
        pos,
        radius,
        Paint()..color = dotColor.withValues(alpha: alpha),
      );
    }
  }

  void _paintCloud(Canvas canvas, Size size, Random r, bool isDark) {
    final cx = size.width * (0.06 + 0.88 * r.nextDouble());
    final cy = size.height * (0.05 + 0.40 * r.nextDouble());
    final baseR = size.shortestSide * (0.05 + 0.05 * r.nextDouble());
    final circleCount = 3 + r.nextInt(4); // 3..6
    // light 白 alpha 0.4~0.55 / dark 白 alpha 0.08~0.14
    final alpha = isDark
        ? 0.08 + r.nextDouble() * 0.06
        : 0.40 + r.nextDouble() * 0.15;

    final path = Path();
    for (var i = 0; i < circleCount; i++) {
      final dx = (r.nextDouble() - 0.5) * baseR * 2.6;
      final dy = (r.nextDouble() - 0.5) * baseR * 1.0;
      final cr = baseR * (0.45 + r.nextDouble() * 0.55);
      path.addOval(Rect.fromCircle(
        center: Offset(cx + dx, cy + dy),
        radius: cr,
      ));
    }
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, paint);
  }

  void _paintBeam(Canvas canvas, Size size, Random r) {
    final topX = size.width * (0.05 + 0.75 * r.nextDouble());
    final width = size.width * (0.04 + 0.08 * r.nextDouble());
    final slant = size.width * (0.12 + 0.22 * r.nextDouble());
    final height = size.height * 0.9;
    final alpha = 0.05 + r.nextDouble() * 0.05; // 0.05~0.10

    final path = Path()
      ..moveTo(topX, 0)
      ..lineTo(topX + width, 0)
      ..lineTo(topX + width + slant, height)
      ..lineTo(topX + slant, height)
      ..close();

    // 沿光带方向淡出：顶亮底隐
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: alpha),
        Colors.white.withValues(alpha: 0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, height));
    canvas.drawPath(path, Paint()..shader = shader);
  }
}
