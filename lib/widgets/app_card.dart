import 'package:flutter/material.dart';

import '../app/styles/app_styles.dart';
import '../app/styles/ui_style.dart';

/// 卡片外壳（双风格）：
/// - lowpoly：2px ink 描边 + 硬投影 + 18 圆角（可选切角/强调条）
/// - watercolor：无 ink 硬边、圆角柔投影、纸色底分层，强调条改柔和渐变
///
/// 只替换卡片"外壳"（decoration），内容逐处保留。
/// 判定标准：decoration 同时满足 ① cardColor ② radius≥18 ③ padding≥16 才换。
enum CutCorner { none, topLeft, topRight }

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.color,
    this.tint,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.radius,
    this.strokeWidth = AppStroke.standard,
    this.hardShadow = true,
    this.accentStripe = false,
    this.cutCorner = CutCorner.none,
  });

  final Widget child;
  final Color? color;

  /// 页面强调色（驱动顶部强调条，可不传）
  final Color? tint;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final double strokeWidth;
  final bool hardShadow;

  /// 顶部 4px 强调色条
  final bool accentStripe;

  /// 几何切角：topLeft/topRight 用 BeveledRectangleBorder 做斜切点缀
  /// （仅 lowpoly 生效；watercolor 自动降级为普通圆角）
  final CutCorner cutCorner;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppRadius.card;
    final isWatercolor = UiStyleScope.of(context) == AppUiStyle.watercolor;
    final side = isWatercolor
        // 水彩：无 ink 硬边，层次靠纸色 + 柔投影
        ? BorderSide.none
        : AppStroke.side(context, width: strokeWidth);
    final boxColor = color ?? Theme.of(context).cardColor;
    // AppShadow.hard 内部按风格分流：lowpoly 零模糊硬投影 / watercolor 柔投影
    final shadows = hardShadow ? AppShadow.hard(context) : null;

    final Widget card;
    if (isWatercolor || cutCorner == CutCorner.none) {
      card = Container(
        padding: padding,
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(r),
          border: isWatercolor
              ? null
              : Border.all(color: side.color, width: strokeWidth),
          boxShadow: shadows,
        ),
        child: child,
      );
    } else {
      // 斜切角（lowpoly 签名元素）：BeveledRectangleBorder 四角均倒角
      card = Container(
        padding: padding,
        decoration: ShapeDecoration(
          color: boxColor,
          shadows: shadows,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(r),
            side: side,
          ),
        ),
        child: child,
      );
    }

    Widget result = card;
    if (accentStripe && tint != null) {
      result = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            decoration: isWatercolor
                ? BoxDecoration(
                    // 水彩：柔和渐变细条，不压 ink 分隔线
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        tint!,
                        tint!.withValues(alpha: 0.25),
                      ],
                    ),
                  )
                : BoxDecoration(
                    color: tint,
                    border: Border(
                      bottom: BorderSide(color: side.color, width: strokeWidth),
                    ),
                  ),
          ),
          result,
        ],
      );
    }
    if (margin != null) result = Padding(padding: margin!, child: result);
    return result;
  }
}
