import 'package:flutter/material.dart';
import '../styles/app_styles.dart';
import '../styles/ui_style.dart';
import 'app_colors.dart';

class AppTheme {
  /// 风格化主题入口：默认 lowPoly（保持兼容），watercolor 走水彩分支。
  /// 文字颜色规则两套共用：浅色纯黑 / 深色 #D8D5D0。
  static ThemeData light({AppUiStyle style = AppUiStyle.lowPoly}) =>
      style == AppUiStyle.watercolor ? _watercolorLight : _lowPolyLight;

  static ThemeData dark({AppUiStyle style = AppUiStyle.lowPoly}) =>
      style == AppUiStyle.watercolor ? _watercolorDark : _lowPolyDark;

  /// 兼容旧调用点（screenshot_main 等）：固定 lowpoly，与改造前输出一致
  static ThemeData get lightTheme => _lowPolyLight;
  static ThemeData get darkTheme => _lowPolyDark;

  // ===================== lowpoly（现状原样，禁止改动）=====================
  static ThemeData get _lowPolyLight => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        dialogTheme: DialogThemeData(
          surfaceTintColor: Colors.transparent,
          backgroundColor: AppColors.cardBackground,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.dialogB,
            side: const BorderSide(color: AppColors.inkLight, width: AppStroke.standard),
          ),
        ),
        colorScheme: ColorScheme.light(
          primary: AppColors.hazeBlue,
          secondary: AppColors.softPink,
          surface: AppColors.cardBackground,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.textPrimary,
          outline: AppColors.inkLight,
          outlineVariant: AppColors.inkLight.withValues(alpha: 0.18),
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardB,
            side: const BorderSide(color: AppColors.inkLight, width: AppStroke.standard),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: AppColors.textPrimary),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.cardBackground,
          selectedItemColor: Colors.black,
          unselectedItemColor: AppColors.textHint,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
        ),
        // 主按钮：几何切角 + 2px ink 描边
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.hazeBlue,
            foregroundColor: Colors.white,
            side: const BorderSide(color: AppColors.inkLight, width: AppStroke.standard),
            shape: const BeveledRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        // 文本按钮：不加框（2px 框对纯文字按钮过重）；文字黑白
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smB),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            side: const BorderSide(color: AppColors.inkLight, width: AppStroke.standard),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smB),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.hazeBlue,
            foregroundColor: Colors.white,
            side: const BorderSide(color: AppColors.inkLight, width: AppStroke.standard),
            shape: const BeveledRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.milkWhite,
          border: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(color: AppColors.inkLight, width: AppStroke.standard),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(color: AppColors.inkLight, width: AppStroke.standard),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(color: AppColors.hazeBlue, width: AppStroke.standard),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(color: AppColors.angerRed, width: AppStroke.standard),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(color: AppColors.angerRed, width: AppStroke.standard),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 15),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: Colors.black,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: Colors.black,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.hazeBlue,
          inactiveTrackColor: AppColors.divider,
          thumbColor: AppColors.hazeBlue,
          trackHeight: 6,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: Colors.black,
          linearTrackColor: AppColors.divider,
          circularTrackColor: AppColors.divider,
          strokeWidth: 3,
        ),
        dividerTheme: DividerThemeData(
          color: AppColors.inkLight.withValues(alpha: 0.18),
          thickness: 1,
          space: 1,
        ),
        // SnackBar：米白底 + 黑字（白字压彩色底太亮，统一贴纸风）
        snackBarTheme: SnackBarThemeData(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.cardBackground,
          contentTextStyle: const TextStyle(color: Colors.black, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smB,
            side: const BorderSide(color: AppColors.inkLight, width: AppStroke.standard),
          ),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smB),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smB,
            side: const BorderSide(color: AppColors.inkLight, width: AppStroke.standard),
          ),
        ),
        textTheme: TextTheme(
          headlineLarge: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          labelLarge: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          labelMedium: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w400),
          labelSmall: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w400),
          bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16, height: 1.6),
          bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
          bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      );

  static ThemeData get _lowPolyDark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        dialogTheme: DialogThemeData(
          surfaceTintColor: Colors.transparent,
          backgroundColor: AppColors.darkCard,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.dialogB,
            side: const BorderSide(color: AppColors.inkDark, width: AppStroke.standard),
          ),
        ),
        colorScheme: ColorScheme.dark(
          primary: AppColors.hazeBlue,
          secondary: AppColors.softPink,
          surface: AppColors.darkCard,
          onPrimary: AppColors.darkTextPrimary,
          onSecondary: AppColors.darkTextPrimary,
          onSurface: AppColors.darkTextPrimary,
          outline: AppColors.inkDark,
          outlineVariant: AppColors.inkDark.withValues(alpha: 0.18),
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardB,
            side: const BorderSide(color: AppColors.inkDark, width: AppStroke.standard),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.darkTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.hazeBlue,
            foregroundColor: AppColors.darkTextPrimary,
            side: const BorderSide(color: AppColors.inkDark, width: AppStroke.standard),
            shape: const BeveledRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.darkTextPrimary,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smB),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.darkTextPrimary,
            side: const BorderSide(color: AppColors.inkDark, width: AppStroke.standard),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smB),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.hazeBlue,
            foregroundColor: AppColors.darkTextPrimary,
            side: const BorderSide(color: AppColors.inkDark, width: AppStroke.standard),
            shape: const BeveledRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkInputFill,
          border: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(color: AppColors.inkDark, width: AppStroke.standard),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(color: AppColors.inkDark, width: AppStroke.standard),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(color: AppColors.hazeBlue, width: AppStroke.standard),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(color: AppColors.angerRed, width: AppStroke.standard),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(color: AppColors.angerRed, width: AppStroke.standard),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: TextStyle(color: AppColors.darkTextHint, fontSize: 15),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkCard,
          selectedItemColor: AppColors.darkTextPrimary,
          unselectedItemColor: AppColors.darkTextSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: AppColors.darkTextPrimary,
          unselectedLabelColor: AppColors.darkTextHint,
          indicatorColor: AppColors.darkTextPrimary,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.hazeBlue,
          inactiveTrackColor: AppColors.darkInputFill,
          thumbColor: AppColors.hazeBlue,
          trackHeight: 6,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: AppColors.darkTextPrimary,
          linearTrackColor: AppColors.darkInputFill,
          circularTrackColor: AppColors.darkInputFill,
          strokeWidth: 3,
        ),
        dividerTheme: DividerThemeData(
          color: AppColors.inkDark.withValues(alpha: 0.18),
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.darkCard,
          contentTextStyle: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smB,
            side: const BorderSide(color: AppColors.inkDark, width: AppStroke.standard),
          ),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smB),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smB,
            side: const BorderSide(color: AppColors.inkDark, width: AppStroke.standard),
          ),
        ),
        textTheme: TextTheme(
          headlineLarge: TextStyle(color: AppColors.darkTextPrimary, fontSize: 28, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: AppColors.darkTextPrimary, fontSize: 22, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: AppColors.darkTextPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: AppColors.darkTextPrimary, fontSize: 20, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: AppColors.darkTextPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(color: AppColors.darkTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          labelLarge: TextStyle(color: AppColors.darkTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          labelMedium: TextStyle(color: AppColors.darkTextSecondary, fontSize: 12, fontWeight: FontWeight.w400),
          labelSmall: TextStyle(color: AppColors.darkTextSecondary, fontSize: 11, fontWeight: FontWeight.w400),
          bodyLarge: TextStyle(color: AppColors.darkTextPrimary, fontSize: 16, height: 1.6),
          bodyMedium: TextStyle(color: AppColors.darkTextPrimary, fontSize: 14, height: 1.5),
          bodySmall: TextStyle(color: AppColors.darkTextSecondary, fontSize: 12),
        ),
      );

  // ===================== watercolor（水彩天空）=====================
  /// 浅色：奶油纸底 + 纸白卡 + 天蓝 primary + 暖棕描边/选中，无 ink 硬边卡框
  static ThemeData get _watercolorLight => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.waterCreamBg,
        dialogTheme: DialogThemeData(
          surfaceTintColor: Colors.transparent,
          backgroundColor: AppColors.waterCard,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.dialogB,
            // 水彩对话框：1px 暖棕发丝线（2px 黑边是 lowpoly 语言）
            side: const BorderSide(
                color: AppColors.inkWaterLight, width: AppStroke.hairline),
          ),
        ),
        colorScheme: ColorScheme.light(
          primary: AppColors.waterSkyBlue,
          // 语义情绪色（悲伤=softPink 等）两套风格共用，不随风格切换
          secondary: AppColors.softPink,
          surface: AppColors.waterCard,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.textPrimary,
          outline: AppColors.inkWaterLight,
          outlineVariant: AppColors.inkWaterLight.withValues(alpha: 0.18),
        ),
        cardTheme: CardThemeData(
          color: AppColors.waterCard,
          elevation: 0,
          // 水彩卡片无 ink 硬边：靠纸色分层 + AppShadow 柔投影
          shape: RoundedRectangleBorder(borderRadius: AppRadius.cardB),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: AppColors.textPrimary),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.waterCard,
          // 选中暖棕（在纸白上对比度充足），未选中黑降透明度以拉开层级
          selectedItemColor: AppColors.inkWaterLight,
          unselectedItemColor: AppColors.textHint.withValues(alpha: 0.45),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
        ),
        // 主按钮：圆角（切角是 lowpoly 语言）+ 天蓝 + 2px 暖棕描边
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.waterSkyBlue,
            foregroundColor: Colors.white,
            side: const BorderSide(
                color: AppColors.inkWaterLight, width: AppStroke.standard),
            shape: AppShape.cut45ForStyle(AppUiStyle.watercolor),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smB),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            side: const BorderSide(
                color: AppColors.inkWaterLight, width: AppStroke.standard),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smB),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.waterSkyBlue,
            foregroundColor: Colors.white,
            side: const BorderSide(
                color: AppColors.inkWaterLight, width: AppStroke.standard),
            shape: AppShape.cut45ForStyle(AppUiStyle.watercolor),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(
                color: AppColors.inkWaterLight, width: AppStroke.standard),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(
                color: AppColors.inkWaterLight, width: AppStroke.standard),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(
                color: AppColors.waterSkyBlue, width: AppStroke.standard),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(
                color: AppColors.angerRed, width: AppStroke.standard),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(
                color: AppColors.angerRed, width: AppStroke.standard),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 15),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: AppColors.inkWaterLight,
          unselectedLabelColor: AppColors.textHint.withValues(alpha: 0.5),
          indicatorColor: AppColors.waterSkyBlue,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.waterSkyBlue,
          inactiveTrackColor: AppColors.divider,
          thumbColor: AppColors.waterSkyBlue,
          trackHeight: 6,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: Colors.black,
          linearTrackColor: AppColors.divider,
          circularTrackColor: AppColors.divider,
          strokeWidth: 3,
        ),
        // 暖灰分隔（inkWaterLight 低透明）
        dividerTheme: DividerThemeData(
          color: AppColors.inkWaterLight.withValues(alpha: 0.15),
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.waterCard,
          contentTextStyle: const TextStyle(color: Colors.black, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smB),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smB),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.waterCard,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smB,
            side: const BorderSide(
                color: AppColors.inkWaterLight, width: AppStroke.hairline),
          ),
        ),
        textTheme: TextTheme(
          headlineLarge: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          labelLarge: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          labelMedium: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w400),
          labelSmall: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w400),
          bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16, height: 1.6),
          bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
          bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      );

  /// 深色（新海诚夜空）：夜空蓝底/卡 + 输入更深一档；文字仍用 darkTextPrimary
  static ThemeData get _watercolorDark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.waterDarkBg,
        dialogTheme: DialogThemeData(
          surfaceTintColor: Colors.transparent,
          backgroundColor: AppColors.waterDarkCard,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.dialogB,
            side: const BorderSide(
                color: AppColors.inkWaterDark, width: AppStroke.hairline),
          ),
        ),
        colorScheme: ColorScheme.dark(
          primary: AppColors.waterSkyBlue,
          // 语义情绪色两套共用
          secondary: AppColors.softPink,
          surface: AppColors.waterDarkCard,
          onPrimary: AppColors.darkTextPrimary,
          onSecondary: AppColors.darkTextPrimary,
          onSurface: AppColors.darkTextPrimary,
          outline: AppColors.inkWaterDark,
          outlineVariant: AppColors.inkWaterDark.withValues(alpha: 0.18),
        ),
        cardTheme: CardThemeData(
          color: AppColors.waterDarkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.cardB),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.darkTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.waterSkyBlue,
            foregroundColor: AppColors.darkTextPrimary,
            side: const BorderSide(
                color: AppColors.inkWaterDark, width: AppStroke.standard),
            shape: AppShape.cut45ForStyle(AppUiStyle.watercolor),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.darkTextPrimary,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smB),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.darkTextPrimary,
            side: const BorderSide(
                color: AppColors.inkWaterDark, width: AppStroke.standard),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smB),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.waterSkyBlue,
            foregroundColor: AppColors.darkTextPrimary,
            side: const BorderSide(
                color: AppColors.inkWaterDark, width: AppStroke.standard),
            shape: AppShape.cut45ForStyle(AppUiStyle.watercolor),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.waterDarkInput,
          border: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(
                color: AppColors.inkWaterDark, width: AppStroke.standard),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(
                color: AppColors.inkWaterDark, width: AppStroke.standard),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(
                color: AppColors.waterSkyBlue, width: AppStroke.standard),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(
                color: AppColors.angerRed, width: AppStroke.standard),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppRadius.smB,
            borderSide: const BorderSide(
                color: AppColors.angerRed, width: AppStroke.standard),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: TextStyle(color: AppColors.darkTextHint, fontSize: 15),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.waterDarkCard,
          // 深色选中/文字仍走共用文字规则（darkTextPrimary）
          selectedItemColor: AppColors.darkTextPrimary,
          unselectedItemColor: AppColors.darkTextSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: AppColors.darkTextPrimary,
          unselectedLabelColor: AppColors.darkTextHint,
          indicatorColor: AppColors.waterSkyBlue,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.waterSkyBlue,
          inactiveTrackColor: AppColors.waterDarkInput,
          thumbColor: AppColors.waterSkyBlue,
          trackHeight: 6,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: AppColors.darkTextPrimary,
          linearTrackColor: AppColors.waterDarkInput,
          circularTrackColor: AppColors.waterDarkInput,
          strokeWidth: 3,
        ),
        dividerTheme: DividerThemeData(
          color: AppColors.inkWaterDark.withValues(alpha: 0.18),
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.waterDarkCard,
          contentTextStyle: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smB),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smB),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.waterDarkCard,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smB,
            side: const BorderSide(
                color: AppColors.inkWaterDark, width: AppStroke.hairline),
          ),
        ),
        textTheme: TextTheme(
          headlineLarge: TextStyle(color: AppColors.darkTextPrimary, fontSize: 28, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: AppColors.darkTextPrimary, fontSize: 22, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: AppColors.darkTextPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: AppColors.darkTextPrimary, fontSize: 20, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: AppColors.darkTextPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(color: AppColors.darkTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          labelLarge: TextStyle(color: AppColors.darkTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          labelMedium: TextStyle(color: AppColors.darkTextSecondary, fontSize: 12, fontWeight: FontWeight.w400),
          labelSmall: TextStyle(color: AppColors.darkTextSecondary, fontSize: 11, fontWeight: FontWeight.w400),
          bodyLarge: TextStyle(color: AppColors.darkTextPrimary, fontSize: 16, height: 1.6),
          bodyMedium: TextStyle(color: AppColors.darkTextPrimary, fontSize: 14, height: 1.5),
          bodySmall: TextStyle(color: AppColors.darkTextSecondary, fontSize: 12),
        ),
      );
}
