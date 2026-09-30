import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/styles/app_styles.dart';
import '../app/styles/ui_style.dart';

/// 删除飞行动画（lowpoly 手绘风，零依赖）：
///   垃圾桶从屏幕下方蹦出 → 起点卡片"变身"成纸飞机沿弧线旋转飞入 → 桶身一颤 → 收场。
///
/// 返回的 Future 在整段动画结束后才完成；调用方应在 await 之后再执行真正的删除，
/// 动画期间可先把待删卡片置为透明（布局不动），营造"卡片变成纸飞机"的接力效果。
Future<void> showFlyToTrash(BuildContext context, {required Rect fromRect}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyToTrashScene(
      fromRect: fromRect,
      onFinished: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _FlyToTrashScene extends StatefulWidget {
  final Rect fromRect;
  final VoidCallback onFinished;
  const _FlyToTrashScene({required this.fromRect, required this.onFinished});

  @override
  State<_FlyToTrashScene> createState() => _FlyToTrashSceneState();
}

class _FlyToTrashSceneState extends State<_FlyToTrashScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onFinished();
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned.fill(
      // 吞掉动画期间的点击，防止连点重复删除
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: CustomPaint(
          painter: _FlyToTrashPainter(
            t: _ctrl,
            fromRect: widget.fromRect,
            isDark: isDark,
            surfaceColor: Theme.of(context).colorScheme.surface,
            bottomInset: bottomInset,
            style: UiStyleScope.of(context),
            repaint: _ctrl,
          ),
        ),
      ),
    );
  }
}

/// 纯函数式绘制：所有相位/几何都由 t（0→1）推导，repaint 由 controller 驱动。
///
/// 时间轴（1050ms）：
///   0.00–0.30 垃圾桶 elasticOut 弹出
///   0.12–0.72 纸飞机沿二次贝塞尔飞行（easeInOutCubic，机头对准切线方向）
///   0.66–0.74 飞机没入桶中（淡出 + 微缩）
///   0.70–0.88 桶身"吞咽"挤压颤动 + 桶盖微抬
///   0.88–1.00 整体缩放淡出收场
class _FlyToTrashPainter extends CustomPainter {
  final Animation<double> t;
  final Rect fromRect;
  final bool isDark;
  final Color surfaceColor;
  final double bottomInset;
  final AppUiStyle style;

  _FlyToTrashPainter({
    required this.t,
    required this.fromRect,
    required this.isDark,
    required this.surfaceColor,
    required this.bottomInset,
    this.style = AppUiStyle.lowPoly,
    super.repaint,
  });

  bool get _watercolor => style == AppUiStyle.watercolor;

  /// 桶/飞机填充：lowPoly = surface 平涂（原样）；水彩 = 天蓝→白微渐变
  Paint _fill(double alpha, Rect area) {
    if (!_watercolor) {
      return Paint()..color = surfaceColor.withValues(alpha: alpha);
    }
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFBFE0F5).withValues(alpha: alpha),
          Colors.white.withValues(alpha: alpha),
        ],
      ).createShader(area);
  }

  /// 水彩描边：略细 + 圆头圆角（lowPoly 分支原值原样）
  double _sw(double w) => _watercolor && w > 0.7 ? w - 0.3 : w;

  Paint _stroke(double width, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _sw(width)
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    if (_watercolor) p.strokeCap = StrokeCap.round;
    return p;
  }

  static const double _trashW = 58;
  static const double _trashH = 64;

  double _phase(double start, double end) =>
      ((t.value - start) / (end - start)).clamp(0.0, 1.0);

  Offset _bezier(Offset p0, Offset p1, Offset p2, double u) {
    final v = 1 - u;
    return Offset(
      v * v * p0.dx + 2 * v * u * p1.dx + u * u * p2.dx,
      v * v * p0.dy + 2 * v * u * p1.dy + u * u * p2.dy,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ink = AppStroke.ink(isDark: isDark, style: style);
    // 水彩航迹点：天蓝 × 暖棕同色系（与桶/机描边一家），lowPoly 仍是纯 ink
    final trailInk = _watercolor
        ? Color.lerp(const Color(0xFF8FBFE8), ink, 0.55)!
        : ink;

    // 垃圾桶目标位：屏幕底部居中、浮在底部导航之上
    final trashCenter = Offset(
      size.width / 2,
      math.max(size.height * 0.45, size.height - bottomInset - 150),
    );

    // 飞行起点：卡片中心（钳进屏幕内，防列表滚动后跑到屏外）
    final p0 = Offset(
      fromRect.center.dx.clamp(12.0, math.max(12.0, size.width - 12)),
      fromRect.center.dy.clamp(12.0, math.max(12.0, size.height - 12)),
    );
    // 落点：桶身内部（桶盖下方），飞机后画桶所以会"没入"桶里
    final p2 = Offset(trashCenter.dx, trashCenter.dy - _trashH * 0.18);
    // 控制点：中点上方拱起，形成抛物弧
    final p1 = Offset(
      (p0.dx + p2.dx) / 2,
      math.min(p0.dy, p2.dy) - math.min(180.0, (p0 - p2).distance * 0.42),
    );

    // ---- 相位 ----
    final popP = _phase(0, 0.30);
    final flyP = Curves.easeInOutCubic.transform(_phase(0.12, 0.72));
    final chompP = _phase(0.70, 0.88);
    final exitP = Curves.easeIn.transform(_phase(0.88, 1.0));

    final popScale = Curves.elasticOut.transform(popP);
    final popAlpha = _phase(0, 0.10);

    // ---- 航迹（点状虚线，越靠近飞机越亮）----
    final spawnFade = _phase(0.12, 0.20);
    if (flyP > 0.01) {
      const dots = 14;
      final trailPaint = Paint()..color = trailInk;
      for (var i = 0; i < dots; i++) {
        final u = flyP * i / (dots - 1);
        final pos = _bezier(p0, p1, p2, u);
        final k = i / (dots - 1); // 0=机尾远端, 1=贴近飞机
        trailPaint.color =
            trailInk.withValues(alpha: (0.10 + 0.32 * k) * spawnFade);
        canvas.drawCircle(pos, 1.2 + 1.5 * k, trailPaint);
      }
    }

    // ---- 纸飞机 ----
    final planeAlpha =
        spawnFade * (1 - _phase(0.66, 0.74));
    if (planeAlpha > 0.01) {
      final pos = _bezier(p0, p1, p2, flyP);
      // 切线角：B'(u) = 2(1-u)(P1-P0) + 2u(P2-P1)
      final du = 1 - flyP;
      final tangent = Offset(
        2 * du * (p1.dx - p0.dx) + 2 * flyP * (p2.dx - p1.dx),
        2 * du * (p1.dy - p0.dy) + 2 * flyP * (p2.dy - p1.dy),
      );
      final angle = tangent == Offset.zero ? 0.0 : math.atan2(tangent.dy, tangent.dx);
      final planeScale = 1.35 - 0.35 * flyP;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);
      canvas.scale(planeScale);
      final body = Path()
        ..moveTo(14, 0)
        ..lineTo(-10, -9)
        ..lineTo(-4, 0)
        ..lineTo(-10, 9)
        ..close();
      final fold = Path()
        ..moveTo(14, 0)
        ..lineTo(-4, 0);
      canvas.save();
      canvas.scale(planeAlpha); // 淡出时同时收缩
      canvas.drawPath(
        body,
        _fill(planeAlpha, const Rect.fromLTWH(-14, -10, 30, 20)),
      );
      canvas.drawPath(
        body,
        _stroke(1.8, ink.withValues(alpha: planeAlpha)),
      );
      canvas.drawPath(
        fold,
        _stroke(1.2, ink.withValues(alpha: 0.6 * planeAlpha)),
      );
      canvas.restore();
      canvas.restore();
    }

    // ---- 垃圾桶 ----
    final exitScale = 1 - exitP;
    final trashScale = popScale * exitScale;
    if (trashScale <= 0.01) return;

    // 吞咽挤压：中段压扁再回弹
    final squish = math.sin(chompP * math.pi);
    final sx = trashScale * (1 + 0.10 * squish);
    final sy = trashScale * (1 - 0.16 * squish);
    final lidLift = -7.0 * squish;
    final trashAlpha = popAlpha * (1 - exitP);

    canvas.save();
    canvas.translate(trashCenter.dx, trashCenter.dy);
    canvas.scale(sx, sy);

    final bodyPath = Path()
      ..moveTo(-_trashW / 2, -_trashH / 2 + 12)
      ..lineTo(_trashW / 2, -_trashH / 2 + 12)
      ..lineTo(_trashW * 0.34, _trashH / 2)
      ..lineTo(-_trashW * 0.34, _trashH / 2)
      ..close();
    final bucketArea =
        Rect.fromLTWH(-_trashW / 2 - 5, -_trashH / 2 - 10, _trashW + 10, _trashH + 14);
    canvas.drawPath(bodyPath, _fill(trashAlpha, bucketArea));

    // 两条竖向棱线（lowpoly 简化纹理）
    final ribPaint = _stroke(1.4, ink.withValues(alpha: 0.45 * trashAlpha));
    canvas.drawLine(Offset(-8, -_trashH / 2 + 18), Offset(-6, _trashH / 2 - 6), ribPaint);
    canvas.drawLine(Offset(8, -_trashH / 2 + 18), Offset(6, _trashH / 2 - 6), ribPaint);

    final bodyStroke = _stroke(2, ink.withValues(alpha: trashAlpha));
    canvas.drawPath(bodyPath, bodyStroke);

    // 桶盖 + 提手（吞咽时微抬）
    canvas.save();
    canvas.translate(0, lidLift);
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(-_trashW / 2 - 5, -_trashH / 2 - 2, _trashW + 10, 10),
      const Radius.circular(3),
    );
    canvas.drawRRect(lid, _fill(trashAlpha, bucketArea));
    canvas.drawRRect(lid, bodyStroke);
    final handle = RRect.fromRectAndRadius(
      Rect.fromLTWH(-8, -_trashH / 2 - 9, 16, 8),
      const Radius.circular(2),
    );
    canvas.drawRRect(handle, _fill(trashAlpha, bucketArea));
    canvas.drawRRect(handle, bodyStroke);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlyToTrashPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.fromRect != fromRect ||
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.style != style;
}
