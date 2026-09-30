import 'package:flutter/material.dart';
import '../../services/storage_service.dart';

/// 全局 UI 风格（运行时可切换，两套并存）
///
/// - [AppUiStyle.lowPoly]    贴纸描边：2px ink 硬边 + 零模糊硬投影 + 三角面片背景
/// - [AppUiStyle.watercolor] 水彩天空：吉卜力暖色手绘质感 × 新海诚天空光影的融合
///
/// 文字颜色规则两套风格**共用**（浅色纯黑 / 深色 #D8D5D0），
/// 风格只切换背景、描边、阴影、装饰与主题色。
enum AppUiStyle {
  lowPoly,
  watercolor;

  /// 从持久化值还原（缺失/未知回退 lowPoly）
  static AppUiStyle fromStorage(String? raw) =>
      raw == 'watercolor' ? AppUiStyle.watercolor : AppUiStyle.lowPoly;

  /// 持久化值
  String get storageValue =>
      this == AppUiStyle.watercolor ? 'watercolor' : 'lowpoly';

  /// 设置页展示名
  String get label =>
      this == AppUiStyle.watercolor ? '水彩天空' : '贴纸描边';

  /// 一句话简介（设置页副标题）
  String get caption => this == AppUiStyle.watercolor
      ? '吉卜力暖色 × 新海诚天空光影'
      : '黑描边贴纸 × 三角面片背景';
}

/// 风格作用域：挂在 GetMaterialApp 之上。
///
/// 读取：`UiStyleScope.of(context)` —— token 层与所有组件唯一取值入口；
/// 切换：`UiStyleScope.set(style)` —— 持久化 + notifier 变更 → 根部监听者重建整树即时换肤。
class UiStyleScope extends InheritedWidget {
  final AppUiStyle style;
  const UiStyleScope({super.key, required this.style, required super.child});

  /// 全局切换源；根部（ValueListenableBuilder）监听它重建主题与整树
  static final ValueNotifier<AppUiStyle> notifier =
      ValueNotifier(AppUiStyle.lowPoly);

  /// 取当前风格（scope 未挂载时回退 notifier 当前值，保证任何 context 可用）
  static AppUiStyle of(BuildContext context) => context
          .dependOnInheritedWidgetOfExactType<UiStyleScope>()
          ?.style ??
      notifier.value;

  static bool isWatercolor(BuildContext context) =>
      of(context) == AppUiStyle.watercolor;

  /// 切换风格：立即全局生效并写入 settings box
  static Future<void> set(AppUiStyle style) async {
    notifier.value = style;
    await StorageService().setUiStyle(style.storageValue);
  }

  /// 启动时从持久化恢复（main.dart 在 runApp 前调用）
  static Future<void> restore() async {
    notifier.value = AppUiStyle.fromStorage(await StorageService().getUiStyle());
  }

  @override
  bool updateShouldNotify(UiStyleScope oldWidget) => oldWidget.style != style;
}
