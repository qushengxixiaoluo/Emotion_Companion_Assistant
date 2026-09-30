import 'package:flutter/material.dart';

class AppColors {
  // 主色调 - lowpoly 贴纸配色（同色相加深，保证文字/图标在浅底上的对比度；
  // 原莫兰迪雾彩色（9BB0C1 等）当文字色时对比度仅 ~2:1，不可读）
  static const Color milkWhite = Color(0xFFF5F0EB);
  static const Color hazeBlue = Color(0xFF5B7A91);
  static const Color softPink = Color(0xFFC47272);
  static const Color lightCyan = Color(0xFF4E9A9A);
  static const Color warmBeige = Color(0xFF6D8299);
  static const Color gentlePurple = Color(0xFF8A76AD);
  static const Color calmGreen = Color(0xFF6F9B66);
  static const Color softOrange = Color(0xFFC0834B);
  static const Color dreamyLavender = Color(0xFF9B82B8);
  static const Color angerRed = Color(0xFFC97B7B);
  static const Color morandiRed = Color(0xFFB86B66);

  // 文字颜色：浅色模式全部纯黑，深色模式全部纯白（不留灰阶）
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF000000);
  static const Color textHint = Color(0xFF000000);
  static const Color textLight = Color(0xFF000000);

  // 功能色
  static const Color background = Color(0xFFF8F4F0);
  static const Color cardBackground = Color(0xFFFFFBF7);
  static const Color divider = Color(0xFFE8E0D8);

  // 夜间模式
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF252540);
  static const Color darkInputFill = Color(0xFF2E2E50);
  // 夜间文字：更柔和的暖白（FF 纯白刺眼，E8 仍偏亮，再降一档到 D8）
  static const Color darkTextPrimary = Color(0xFFD8D5D0);
  static const Color darkTextSecondary = Color(0xFFD8D5D0);
  static const Color darkTextHint = Color(0xFFD8D5D0);

  // ============ lowpoly 描边 ============
  /// 浅色模式主描边：近黑（比 textPrimary 深，读作"黑"但不刺眼）
  static const Color inkLight = Color(0xFF16161A);

  /// 深色模式主描边：暖白。纯黑在 darkBackground(1A1A2E) 上对比度 1.1:1 完全不可见
  static const Color inkDark = Color(0xFFF0EBE4);

  // ============ 水彩天空风格（吉卜力×新海诚融合）描边 ============
  /// 水彩浅色描边：暖棕（替代近黑硬边，手绘感）
  static const Color inkWaterLight = Color(0xFF4E4237);

  /// 水彩深色描边：暖米白（夜空底上的柔光）
  static const Color inkWaterDark = Color(0xFFEDE4D6);

  // ============ lowpoly 面片色板（从马卡龙色推导：保色相、压饱和）============
  /// 浅色网格面片：base.lerp(milkWhite, ~0.88)
  static const List<Color> lowPolyLight = [
    Color(0xFFF1EBE4), // milkWhite
    Color(0xFFEFF1F3), // hazeBlue
    Color(0xFFF5ECEC), // softPink
    Color(0xFFEFF4F4), // lightCyan
    Color(0xFFF1EFF4), // gentlePurple
    Color(0xFFF0F3EF), // calmGreen
    Color(0xFFF5EFEA), // softOrange
    Color(0xFFF2EFF3), // dreamyLavender
  ];

  /// 深色网格面片：base.lerp(darkBackground, ~0.82)
  static const List<Color> lowPolyDark = [
    Color(0xFF232333),
    Color(0xFF21242F),
    Color(0xFF282231),
    Color(0xFF212A2E),
    Color(0xFF272436),
    Color(0xFF232B27),
    Color(0xFF2B2723),
    Color(0xFF292535),
  ];

  // ============ 水彩天空色板（吉卜力暖色 × 新海诚天空光影）============
  // —— 浅色（watercolor light）——
  /// 页面底色：奶油纸（scaffold cream），黑字对比度 ~19:1
  static const Color waterCreamBg = Color(0xFFFAF5EC);

  /// 卡片纸白（比底色更亮一档，靠明度分层替代硬描边）
  static const Color waterCard = Color(0xFFFFFDF8);

  /// 主色：天蓝（按钮/选中/进度等 primary，白字对比 ~3.5:1）
  static const Color waterSkyBlue = Color(0xFF4A90C2);

  /// 浅天蓝（渐变顶部、次级天光）
  static const Color waterSkyLight = Color(0xFF7BB8D9);

  /// 晚霞橙（次级强调、暖色点缀）
  static const Color waterSunset = Color(0xFFE8A87C);

  /// 草地绿（情绪/成功类点缀）
  static const Color waterMeadow = Color(0xFF8FBC7A);

  /// 淡天蓝（水彩背景渐变顶）
  static const Color waterWashTopLight = Color(0xFFCFE7F5);

  /// 雾白（水彩背景渐变中段）
  static const Color waterMistLight = Color(0xFFF7F5F0);

  // —— 深色（新海诚夜空）——
  /// 夜空底色（scaffold bg）
  static const Color waterDarkBg = Color(0xFF1B2438);

  /// 夜空卡片
  static const Color waterDarkCard = Color(0xFF22304C);

  /// 夜空输入框填充
  static const Color waterDarkInput = Color(0xFF2A3A5C);

  /// 深靛（夜空背景渐变顶）
  static const Color waterWashTopDark = Color(0xFF111729);

  // ============ splash 专属（从 app_splash 硬编码 hex 迁入）============
  static const Color splashTopLight = Color(0xFFF5F0EB);
  static const Color splashMidLight = Color(0xFFF0E8E0);
  static const Color splashBotLight = Color(0xFFEEE5DA);
  static const Color splashTopDark = Color(0xFF1A1A2E);
  static const Color splashMidDark = Color(0xFF162038);
  static const Color splashBotDark = Color(0xFF131A2E);
  static const Color splashLogoDark = Color(0xFF3A3A60);
  static const Color splashDotDark = Color(0xFF7B8BA0);
}
