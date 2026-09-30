import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'app/themes/app_theme.dart';
import 'app/routes/app_routes.dart';
import 'app/app_controller.dart';
import 'app/responsive/responsive_utils.dart';
import 'app/responsive/desktop_sidebar.dart';
import 'pages/home/home_page.dart';
import 'pages/treehole/treehole_page.dart';
import 'pages/comfort/comfort_page.dart';
import 'pages/privacy/privacy_page.dart';
import 'pages/analysis/analysis_page.dart';
import 'pages/dream/dream_page.dart';
import 'services/hive_adapters.dart';
import 'services/storage_service.dart';
import 'services/llm_service.dart';
import 'services/speech_service.dart';
import 'widgets/unified_config_dialog.dart';

final GlobalKey _repaintKey = GlobalKey();
final GlobalKey _scaffoldKey = GlobalKey(); // For accessing context inside GetMaterialApp

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(EmotionRecordAdapter());
  Hive.registerAdapter(ChatMessageAdapter());
  Hive.registerAdapter(ConversationAdapter());
  Hive.registerAdapter(DreamRecordAdapter());
  await StorageService.init();
  Get.put(AppController());

  // Pre-configure to skip first-launch dialog
  final storageService = StorageService();
  await storageService.setLlmConfigSubmitted(true);
  await storageService.setTtsConfigSubmitted(true);
  LlmService().reloadConfig();
  SpeechService().reloadTtsConfig();

  runApp(const ScreenshotApp());
}

class ScreenshotApp extends StatefulWidget {
  const ScreenshotApp({super.key});

  @override
  State<ScreenshotApp> createState() => _ScreenshotAppState();
}

class _ScreenshotAppState extends State<ScreenshotApp> {
  int _tabIndex = 0;
  final GlobalKey<HomePageState> _homeKey = GlobalKey<HomePageState>();
  final GlobalKey<TreeholePageState> _treeholeKey = GlobalKey<TreeholePageState>();
  final GlobalKey<ComfortPageState> _comfortKey = GlobalKey<ComfortPageState>();
  final GlobalKey<PrivacyPageState> _privacyKey = GlobalKey<PrivacyPageState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(key: _homeKey, onNavigateToComfort: () {}),
      TreeholePage(key: _treeholeKey),
      ComfortPage(key: _comfortKey),
      PrivacyPage(key: _privacyKey),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSequence());
  }

  Future<void> _runSequence() async {
    // Wait for initial render
    await Future.delayed(const Duration(seconds: 4));

    // 1. Home
    await _capture('home');

    // 2. Treehole
    setState(() => _tabIndex = 1);
    await Future.delayed(const Duration(seconds: 2));
    await _capture('treehole');

    // 3. Comfort (collapsed)
    setState(() => _tabIndex = 2);
    await Future.delayed(const Duration(seconds: 2));
    await _capture('comfort');

    // 4. Comfort (panel expanded)
    _comfortKey.currentState?.toggleConversationPanel();
    await Future.delayed(const Duration(milliseconds: 500));
    await _capture('comfort_panel');

    // 5. Privacy
    setState(() => _tabIndex = 3);
    await Future.delayed(const Duration(seconds: 2));
    await _capture('privacy');

    // 6. Analysis (push route)
    Get.to(() => const AnalysisPage());
    await Future.delayed(const Duration(seconds: 2));
    await _capture('analysis');
    Get.back();
    await Future.delayed(const Duration(seconds: 1));

    // 7. Dream (push route)
    Get.to(() => const DreamPage());
    await Future.delayed(const Duration(seconds: 2));
    await _capture('dream');
    Get.back();
    await Future.delayed(const Duration(seconds: 1));

    // 8. Config dialog (on privacy page)
    setState(() => _tabIndex = 3);
    await Future.delayed(const Duration(seconds: 1));

    // Show the unified config dialog using context inside GetMaterialApp
    final scaffoldContext = _scaffoldKey.currentContext;
    if (scaffoldContext != null) {
      // ignore: unawaited_futures
      showUnifiedConfigDialog(scaffoldContext);
      // Wait for dialog animation to complete
      await Future.delayed(const Duration(milliseconds: 800));
      await _capture('config');
      // Close the dialog using GetX
      Get.back();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Signal completion via a DOM element
    html.document.body?.appendHtml('<div id="screenshots-done" style="display:none;"></div>');
  }

  Future<void> _capture(String name) async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final blob = html.Blob([bytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', '$name.png')
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      // Add marker element so Playwright knows this screenshot was captured
      html.document.body?.appendHtml('<div id="captured-$name" style="display:none;"></div>');
    } catch (e) {
      // ignore errors in individual captures
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      key: _repaintKey,
      child: GetMaterialApp(
      title: '抱抱情绪云',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      getPages: AppRoutes.routes,
      home: Scaffold(
            key: _scaffoldKey,
            body: Row(
          children: [
            DesktopSidebar(
              currentIndex: _tabIndex,
              onTabChanged: (i) => setState(() => _tabIndex = i),
            ),
            // 与 main.dart 桌面布局保持一致：sidebar 容器右侧 2px ink，
            // 这里只留 1px 纯间隔，避免同屏双线
            const SizedBox(width: 1),
            Expanded(
              child: SafeArea(
                child: IndexedStack(
                  index: _tabIndex,
                  children: _pages,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
      );
  }
}
