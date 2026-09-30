import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import 'ui_style.dart';

/// UI 风格统一令牌层（贴纸描边 lowpoly / 水彩天空 watercolor 双风格）
///
/// 核心设计：浅/深描边色分支与风格分支都收敛在 `AppStroke.inkOf(context)` /
/// `AppStroke.ink(isDark:, style:)` 内部，页面代码里禁止再手写分支。
abstract final class AppStroke {
  /// 内部分隔线、背景 mesh 用
  static const double hairline = 1.0;

  /// 图内网格、次级描边
  static const double thin = 1.5;

  /// 卡片/按钮/输入框统一描边（用户拍板标准 2px）
  static const double standard = 2.0;

  /// 当前主题+风格的描边主色：
  /// lowpoly → 浅近黑 / 深暖白；watercolor → 浅暖棕 / 深暖米白
  static Color inkOf(BuildContext context) =>
      ink(
        isDark: Theme.of(context).brightness == Brightness.dark,
        style: UiStyleScope.of(context),
      );

  /// 无 context 场景（CustomPainter）用：调用方从 build 里把 style 传进来
  static Color ink({required bool isDark, AppUiStyle style = AppUiStyle.lowPoly}) {
    if (style == AppUiStyle.watercolor) {
      return isDark ? AppColors.inkWaterDark : AppColors.inkWaterLight;
    }
    return isDark ? AppColors.inkDark : AppColors.inkLight;
  }

  /// 统一 2px 描边的 BorderSide（accent 可覆盖为强调色，如 focused 输入框）
  static BorderSide side(BuildContext context,
          {double width = standard, Color? accent, double alpha = 1.0}) =>
      BorderSide(
        color: (accent ?? inkOf(context)).withValues(alpha: alpha),
        width: width,
      );

  /// 统一 2px 描边的 Border（用于 BoxDecoration.border）
  static Border all(BuildContext context,
          {double width = standard, Color? accent, double alpha = 1.0}) =>
      Border.all(
        color: (accent ?? inkOf(context)).withValues(alpha: alpha),
        width: width,
      );
}

/// 圆角收敛：现有 15 种 → 5 档
abstract final class AppRadius {
  static const double xs = 8; // 装饰小条、图标底
  static const double sm = 12; // chip、列表项、输入框、次级按钮
  static const double md = 16; // 主按钮、聊天气泡
  static const double card = 18; // 卡片
  static const double dialog = 20; // 对话框
  static const double pill = 999; // 胶囊

  static BorderRadius get xsB => BorderRadius.circular(xs);
  static BorderRadius get smB => BorderRadius.circular(sm);
  static BorderRadius get mdB => BorderRadius.circular(md);
  static BorderRadius get cardB => BorderRadius.circular(card);
  static BorderRadius get dialogB => BorderRadius.circular(dialog);
  static BorderRadius get pillB => BorderRadius.circular(pill);

  /// 机械映射：旧值 → 新档（≤7 的装饰小值保留原样）
  static double map(double v) =>
      v <= 7 ? v : v <= 12 ? sm : v <= 16 ? md : v <= 22 ? card : dialog;
}

/// 阴影：lowpoly 硬投影（blurRadius: 0 + offset + ink 色，与 2px 黑描边
/// 同一套视觉语言）；watercolor 自动切换为柔和投影（签名不变，调用方零改动）。
abstract final class AppShadow {
  /// 投影。lowpoly：零模糊硬投影；watercolor：blur 14、暖棕低透明柔投影。
  /// 深色模式自动用 inkDark / inkWaterDark（lowpoly 推荐调用方传 alpha: 0.35, dy: 2）
  static List<BoxShadow> hard(
    BuildContext context, {
    double dy = 3,
    double dx = 0,
    double alpha = 0.18,
  }) {
    if (UiStyleScope.of(context) == AppUiStyle.watercolor) {
      // 水彩天空：无硬边可依附，改用低透明大模糊柔影撑起纸面层次
      return [
        BoxShadow(
          color: AppStroke.inkOf(context).withValues(alpha: alpha * 0.5),
          blurRadius: 14,
          offset: Offset(dx, dy < 3 ? 3 : dy),
        ),
      ];
    }
    return [
      BoxShadow(
        color: AppStroke.inkOf(context).withValues(alpha: alpha),
        blurRadius: 0,
        offset: Offset(dx, dy),
      ),
    ];
  }

  /// 无阴影（层次完全由描边承担）
  static const List<BoxShadow> none = [];
}

/// 几何形状：切角（lowpoly 签名元素）与带描边的圆角矩形
abstract final class AppShape {
  /// 45° 切角按钮（低多边形语言的按钮形态）
  static const BeveledRectangleBorder cut45 = BeveledRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  );

  /// 按风格选按钮形状：lowpoly 切角 / watercolor 圆角。
  /// 页面（有 context）用这个；主题层无 context，用 [cut45ForStyle]。
  static OutlinedBorder cut45For(BuildContext context) =>
      cut45ForStyle(UiStyleScope.of(context));

  /// 主题层/无 context 场景的风格分流版本
  static OutlinedBorder cut45ForStyle(AppUiStyle style) =>
      style == AppUiStyle.watercolor ? round(10) : cut45;

  static RoundedRectangleBorder round(double r) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

  /// 带统一描边的圆角矩形（对话框/卡片 shape 用）
  static RoundedRectangleBorder roundSide(
    BuildContext c,
    double r, {
    Color? accent,
    double width = AppStroke.standard,
  }) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r),
        side: AppStroke.side(c, accent: accent, width: width),
      );
}
