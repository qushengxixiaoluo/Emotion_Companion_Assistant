import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'app/themes/app_theme.dart';
import 'app/themes/app_colors.dart';
import 'app/routes/app_routes.dart';
import 'app/app_controller.dart';
import 'pages/home/home_page.dart';
import 'pages/treehole/treehole_page.dart';
import 'pages/comfort/comfort_page.dart';
import 'pages/privacy/privacy_page.dart';
import 'services/hive_adapters.dart';
import 'services/llm_service.dart';
import 'services/speech_service.dart';
import 'services/storage_service.dart';
import 'app/responsive/responsive_utils.dart';
import 'app/responsive/desktop_sidebar.dart';
import 'widgets/app_splash.dart';
import 'widgets/unified_config_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(EmotionRecordAdapter());
  Hive.registerAdapter(ChatMessageAdapter());
  Hive.registerAdapter(ConversationAdapter());
  Hive.registerAdapter(DreamRecordAdapter());
  await StorageService.init();
  await LlmService().reloadConfig();
  Get.put(AppController());
  runApp(const EmotionCompanionApp());
}

class EmotionCompanionApp extends StatefulWidget {
  const EmotionCompanionApp({super.key});

  @override
  State<EmotionCompanionApp> createState() => _EmotionCompanionAppState();
}

class _EmotionCompanionAppState extends State<EmotionCompanionApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    return Obx(() => GetMaterialApp(
          title: '抱抱情绪云',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: controller.isDarkMode.value ? ThemeMode.dark : ThemeMode.light,
          home: _showSplash
              ? AppSplash(
                  appInit: controller.ready,
                  isDarkMode: controller.isDarkMode.value,
                  onFinished: () => setState(() => _showSplash = false),
                )
              : const MainNavigation(),
          getPages: AppRoutes.routes,
        ));
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final GlobalKey<HomePageState> _homeKey = GlobalKey<HomePageState>();
  final GlobalKey<TreeholePageState> _treeholeKey = GlobalKey<TreeholePageState>();
  final GlobalKey<PrivacyPageState> _privacyKey = GlobalKey<PrivacyPageState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    LlmService().reloadConfig();
    SpeechService().reloadTtsConfig();
    _pages = [
      HomePage(key: _homeKey, onNavigateToComfort: () => _onTabChanged(2)),
      TreeholePage(key: _treeholeKey),
      const ComfortPage(),
      PrivacyPage(key: _privacyKey),
    ];
    _checkFirstLaunchConfig();
  }

  Future<void> _checkFirstLaunchConfig() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final storageService = StorageService();
    final llmSubmitted = await storageService.isLlmConfigSubmitted();

    if (!llmSubmitted) {
      if (!mounted) return;
      await showUnifiedConfigDialog(context, isFirstLaunch: true);
      await LlmService().reloadConfig();
      await SpeechService().reloadTtsConfig();
    } else {
      final ttsSubmitted = await storageService.isTtsConfigSubmitted();
      if (!ttsSubmitted) {
        await storageService.setTtsConfigSubmitted(true);
      }
    }

    // 首帧已渲染，安全调用平台通道初始化 TTS 引擎
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SpeechService().ensureReady();
    });
  }

  void _onTabChanged(int index) {
    setState(() => _currentIndex = index);
    // 切换页面时刷新数据，确保多端同步
    if (index == 0) {
      _homeKey.currentState?.refreshData();
    } else if (index == 1) {
      _treeholeKey.currentState?.refreshData();
    } else if (index == 3) {
      _privacyKey.currentState?.refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveUtils.tabletBreakpoint) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, '首页'),
                _buildNavItem(1, Icons.edit_note_outlined, Icons.edit_note_rounded, '树洞'),
                _buildNavItem(2, Icons.auto_awesome_outlined, Icons.auto_awesome, '安慰'),
                _buildNavItem(3, Icons.person_outlined, Icons.person, '我的'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          DesktopSidebar(
            currentIndex: _currentIndex,
            onTabChanged: _onTabChanged,
          ),
          Container(
            width: 1,
            color: AppColors.hazeBlue.withValues(alpha: 0.08),
          ),
          Expanded(
            child: SafeArea(
              child: IndexedStack(
                index: _currentIndex,
                children: _pages,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? AppColors.darkTextHint : AppColors.textHint;
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.hazeBlue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.hazeBlue : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppColors.hazeBlue : inactiveColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
