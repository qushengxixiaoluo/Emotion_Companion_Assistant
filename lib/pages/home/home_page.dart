import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/themes/app_colors.dart';
import '../../app/responsive/adaptive_content_wrapper.dart';
import '../../services/storage_service.dart';
import '../../models/emotion_models.dart';
import '../../app/routes/app_routes.dart';
import '../../widgets/emotion_radar.dart';
import '../../widgets/heartbeat_breath_button.dart';
import '../../widgets/fortune_draw.dart';
import '../../widgets/fortune_calendar.dart';
import '../../widgets/emotion_archive_dialog.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onNavigateToComfort;
  const HomePage({super.key, this.onNavigateToComfort});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final StorageService _storageService = StorageService();
  List<EmotionRecord> _records = [];
  String _greeting = '';
  String? _fortuneDate;
  FortuneLevel? _fortuneLevel;
  String? _fortuneBlessing;
  List<String> _checkedDates = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _setGreeting();
    _loadFortuneState();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) {
      _greeting = '夜深了，记得早点休息';
    } else if (hour < 9) {
      _greeting = '早安，新的一天温柔以待';
    } else if (hour < 12) {
      _greeting = '上午好，今天也要照顾好自己';
    } else if (hour < 14) {
      _greeting = '午安，记得好好吃饭';
    } else if (hour < 18) {
      _greeting = '下午好，累了就歇一歇';
    } else if (hour < 22) {
      _greeting = '晚上好，今天辛苦了';
    } else {
      _greeting = '夜深了，把烦恼留给明天';
    }
  }

  Future<void> _loadFortuneState() async {
    final dates = await _storageService.getFortuneCheckinDates();
    final date = await _storageService.getFortuneDate();
    final today = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    FortuneLevel? savedLevel;
    String? savedBlessing;
    if (date == today) {
      final levelIdx = await _storageService.getFortuneLevel();
      final blessing = await _storageService.getFortuneBlessing();
      if (levelIdx != null && levelIdx >= 0 && levelIdx < FortuneLevel.values.length && blessing != null) {
        savedLevel = FortuneLevel.values[levelIdx];
        savedBlessing = blessing;
      }
    }
    if (mounted) {
      setState(() {
        _checkedDates = dates;
        _fortuneDate = date == today ? date : null;
        _fortuneLevel = savedLevel;
        _fortuneBlessing = savedBlessing;
      });
    }
  }

  Future<void> _saveFortune(
      String date, FortuneLevel level, String blessing) async {
    await _storageService.setFortuneDate(date);
    await _storageService.setFortuneLevel(level.index);
    await _storageService.setFortuneBlessing(blessing);
    await _storageService.addFortuneCheckinDate(date);
    final dates = await _storageService.getFortuneCheckinDates();
    setState(() {
      _fortuneDate = date;
      _fortuneLevel = level;
      _fortuneBlessing = blessing;
      _checkedDates = dates;
    });
  }

  Future<void> _loadData() async {
    final records = await _storageService.getAllRecords();
    setState(() => _records = records);
  }

  /// 外部可调用的刷新方法，用于跨页面同步数据
  Future<void> refreshData() async {
    await _loadData();
  }

  String _formatTimelineDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(recordDay).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[dt.weekday - 1];
    }
    return '${dt.month}月${dt.day}日';
  }

  /// 聚合今日所有情绪日记，返回综合分析记录和记录条数
  EmotionRecord? _getTodayAggregated() {
    final todayRecords = _records.where((r) =>
      r.createdAt.year == DateTime.now().year &&
      r.createdAt.month == DateTime.now().month &&
      r.createdAt.day == DateTime.now().day &&
      r.dominantEmotion != '分析中...'  // 过滤占位记录
    ).toList();

    if (todayRecords.isEmpty) return null;

    final n = todayRecords.length;
    double avg(List<double> values) => values.reduce((a, b) => a + b) / n;

    final sadness = avg(todayRecords.map((r) => r.sadness).toList());
    final anxiety = avg(todayRecords.map((r) => r.anxiety).toList());
    final anger = avg(todayRecords.map((r) => r.anger).toList());
    final loneliness = avg(todayRecords.map((r) => r.loneliness).toList());
    final happiness = avg(todayRecords.map((r) => r.happiness).toList());
    final calmness = avg(todayRecords.map((r) => r.calmness).toList());
    final suppression = avg(todayRecords.map((r) => r.suppression).toList());

    final scores = <String, double>{
      '悲伤': sadness, '焦虑': anxiety, '愤怒': anger, '孤独': loneliness,
      '开心': happiness, '平静': calmness, '压抑': suppression,
    };
    final dominant = scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return EmotionRecord(
      id: 'today_aggregated',
      content: '今日情绪综合分析（$n条记录）',
      sadness: sadness,
      anxiety: anxiety,
      anger: anger,
      loneliness: loneliness,
      happiness: happiness,
      calmness: calmness,
      suppression: suppression,
      dominantEmotion: dominant,
      createdAt: todayRecords.first.createdAt,
    );
  }

  int _getTodayCount() {
    return _records.where((r) =>
      r.createdAt.year == DateTime.now().year &&
      r.createdAt.month == DateTime.now().month &&
      r.createdAt.day == DateTime.now().day &&
      r.dominantEmotion != '分析中...'
    ).length;
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final months = [
      '1月', '2月', '3月', '4月', '5月', '6月',
      '7月', '8月', '9月', '10月', '11月', '12月',
    ];
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${months[dt.month - 1]}${dt.day}日 ${weekdays[dt.weekday - 1]}';
  }

  // ============= UI Builders =============

  Widget _buildSectionHeader(String title, Color accentColor, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildIconContainer(IconData icon, Color color, {double size = 18, double containerSize = 38}) {
    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: size, color: color),
    );
  }

  // ============= Main Build =============

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayAggregated = _getTodayAggregated();
    final todayCount = _getTodayCount();
    final now = DateTime.now();

    final gradientColors = isDark
        ? [AppColors.hazeBlue.withValues(alpha: 0.12), AppColors.darkBackground]
        : [AppColors.hazeBlue.withValues(alpha: 0.05), AppColors.background];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: AdaptiveContentWrapper(
            child: CustomScrollView(
              slivers: [
                // ===== SliverAppBar =====
              SliverAppBar(
                pinned: true,
                title: Text(
                  '情绪陪伴',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.hazeBlue,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                centerTitle: false,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _buildFortuneCircle(),
                  ),
                ],
              ),

              // ===== All Content =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // ===== Greeting Header =====
                      _buildGreetingHeader(now),

                      const SizedBox(height: 28),

                      // ===== Heartbeat Breath Button =====
                      _buildHeartbeatSection(),

                      const SizedBox(height: 32),

                      // ===== Today's Emotion Card =====
                      _buildTodayEmotionCard(todayAggregated, todayCount),

                      const SizedBox(height: 16),

                      // ===== Emotion Timeline Card =====
                      _buildTimelineCard(),

                      const SizedBox(height: 16),

                      // ===== Quick Actions =====
                      _buildQuickActionsSection(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  // ============= Greeting Header =============

  Widget _buildGreetingHeader(DateTime now) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.hazeBlue.withValues(alpha: 0.08),
            AppColors.hazeBlue.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.hazeBlue.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.hazeBlue,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '我是你的情绪陪伴师',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.hazeBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.cloud_outlined,
                  size: 22,
                  color: AppColors.hazeBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.hazeBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: AppColors.hazeBlue.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(now),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.hazeBlue.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============= Heartbeat Section =============

  Widget _buildHeartbeatSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.hazeBlue.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.hazeBlue.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            '轻轻点击，开始倾诉...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 16),
          HeartbeatBreathButton(
            // 推送入口返回后刷新首页，避免树洞删除/新增后首页显示旧数据
            onTap: () => Get.toNamed(AppRoutes.treehole)?.then((_) => _loadData()),
          ),
          const SizedBox(height: 16),
          Text(
            '你的每一次倾诉，都会被温柔聆听',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }

  // ============= Fortune Section =============

  Widget _buildFortuneCircle() {
    return GestureDetector(
      onTap: () => _showFortuneDialog(),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: AssetImage('assets/icons/icon.png'),
            fit: BoxFit.cover,
          ),
          border: Border.all(
            color: AppColors.warmBeige.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
    );
  }

  void _showFortuneDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 5,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: AppColors.warmBeige.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 10),
            Text('今日一签',
                style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(ctx).colorScheme.onSurface)),
          ],
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FortuneDraw(
              savedDate: _fortuneDate,
              savedLevel: _fortuneLevel,
              savedBlessing: _fortuneBlessing,
              onFortuneDrawn: _saveFortune,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.of(ctx).pop();
                _showCalendarDialog();
              },
              child: Text('查看日历签到 →',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.hazeBlue.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCalendarDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(ctx).pop();
                _showFortuneDialog();
              },
              child: Icon(Icons.arrow_back_ios, size: 16,
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: 8),
            Text('签到日历',
              style: TextStyle(fontSize: 16, color: Theme.of(ctx).colorScheme.onSurface)),
          ],
        ),
        titlePadding: const EdgeInsets.fromLTRB(16, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        content: FortuneCalendar(checkedDates: _checkedDates),
      ),
    );
  }

  // ============= Today's Emotion Card =============

  Widget _buildTodayEmotionCard(EmotionRecord? todayAggregated, int todayCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.hazeBlue.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            '今日情绪状态',
            AppColors.hazeBlue,
            trailing: GestureDetector(
              onTap: () {
                if (todayAggregated != null) {
                  Get.toNamed(AppRoutes.analysis, arguments: {'record': todayAggregated});
                } else {
                  Get.toNamed(AppRoutes.analysis);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.hazeBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '查看详情 →',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.hazeBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          if (todayAggregated == null) ...[
            const SizedBox(height: 8),
            _buildEmptyState(
              icon: Icons.sentiment_neutral_outlined,
              iconColor: AppColors.hazeBlue,
              title: '还没有情绪记录',
              subtitle: '开始倾诉，让情绪被温柔看见',
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildIconContainer(
                  Icons.auto_awesome,
                  _emotionColor(todayAggregated.dominantEmotion),
                ),
                const SizedBox(width: 12),
                _buildEmotionChip(todayAggregated.dominantEmotion),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '今日 $todayCount 条 · 共 ${_records.length} 条',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: EmotionRadarChart(
                record: todayAggregated,
                textColor: Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _emotionColor(String emotion) {
    const colors = {
      '悲伤': AppColors.softPink,
      '焦虑': AppColors.softOrange,
      '愤怒': AppColors.angerRed,
      '孤独': AppColors.gentlePurple,
      '开心': AppColors.calmGreen,
      '平静': AppColors.lightCyan,
      '压抑': AppColors.warmBeige,
    };
    return colors[emotion] ?? AppColors.hazeBlue;
  }

  // ============= Emotion Timeline Card =============

  Widget _buildTimelineCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.hazeBlue.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            '近期情绪波动',
            AppColors.hazeBlue,
            trailing: GestureDetector(
              onTap: () => showEmotionArchiveDialog(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 14, color: AppColors.hazeBlue.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                  Text(
                    '归档',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.hazeBlue.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_records.isEmpty)
            _buildEmptyState(
              icon: Icons.show_chart_rounded,
              iconColor: AppColors.hazeBlue,
              title: '还没有情绪记录',
              subtitle: '开始倾诉，记录你的情绪旅程',
            )
          else
            _buildEmotionTimeline(),
        ],
      ),
    );
  }

  // ============= Quick Actions =============

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildSectionHeader('功能', AppColors.hazeBlue),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _buildQuickAction(
                icon: Icons.auto_awesome,
                label: 'AI暖心安慰',
                color: AppColors.softPink,
                onTap: () {
                  if (widget.onNavigateToComfort != null) {
                    widget.onNavigateToComfort!();
                  } else {
                    Get.toNamed(AppRoutes.comfort);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAction(
                icon: Icons.analytics_outlined,
                label: '情绪分析',
                color: AppColors.lightCyan,
                onTap: () => Get.toNamed(AppRoutes.analysis),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickAction(
                icon: Icons.shield_outlined,
                label: '隐私中心',
                color: AppColors.gentlePurple,
                onTap: () => Get.toNamed(AppRoutes.privacy),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAction(
                icon: Icons.nightlight_round,
                label: 'AI梦境解读',
                color: AppColors.dreamyLavender,
                onTap: () => Get.toNamed(AppRoutes.dream),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============= Reusable Widget Builders =============

  Widget _buildEmptyState({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: iconColor.withValues(alpha: 0.45)),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionChip(String emotion) {
    final colors = {
      '悲伤': AppColors.softPink,
      '焦虑': AppColors.softOrange,
      '愤怒': AppColors.angerRed,
      '孤独': AppColors.gentlePurple,
      '开心': AppColors.calmGreen,
      '平静': AppColors.lightCyan,
      '压抑': AppColors.warmBeige,
      '未知': AppColors.textHint,
    };
    final color = colors[emotion] ?? AppColors.hazeBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        emotion,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildEmotionTimeline() {
    // 过滤掉"分析中..."占位记录，与 analysis 页保持一致
    final recent = _records
        .where((r) => r.dominantEmotion != '分析中...')
        .take(7)
        .toList()
        .reversed
        .toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 120,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalW = constraints.maxWidth;
          final colW = recent.length > 0 ? totalW / recent.length : totalW;
          return CustomPaint(
            size: Size(totalW, 120),
            painter: _EmotionTimelinePainter(
              records: recent,
              emotionColorFn: _emotionColor,
              colWidth: colW,
              formatDate: _formatTimelineDate,
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            // 底层：彩色柔光投影，营造"浮起"感
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            // 中层：中性灰投影，增加厚度
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // 图标容器 — 彩色半透明底
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            // 标签 — 用主文字色，确保可读性
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmotionTimelinePainter extends CustomPainter {
  final List<EmotionRecord> records;
  final Color Function(String) emotionColorFn;
  final double colWidth;
  final String Function(DateTime) formatDate;

  _EmotionTimelinePainter({
    required this.records,
    required this.emotionColorFn,
    required this.colWidth,
    required this.formatDate,
  });

  static const _barW = 14.0;
  static const _labelGap = 6.0;
  static const _dateGap = 6.0;
  static const _labelFontSize = 9.0;
  static const _dateFontSize = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;

    final n = records.length;
    final barBottomY = size.height - 18; // date(~12) + gap(6)

    // Draw each bar + labels + date
    for (int i = 0; i < n; i++) {
      final r = records[i];
      final color = emotionColorFn(r.dominantEmotion);
      final positive = (r.happiness + r.calmness) / 2;
      final barH = 20 + (positive * 42);
      final colCenterX = (i + 0.5) * colWidth;
      final barTopY = barBottomY - barH;

      // Emotion label
      final labelTP = TextPainter(
        text: TextSpan(
          text: r.dominantEmotion,
          style: TextStyle(fontSize: _labelFontSize, color: color, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: colWidth);
      labelTP.paint(canvas, Offset(colCenterX - labelTP.width / 2, barTopY - _labelGap - labelTP.height));

      // Bar background (rounded rect top)
      final barRect = RRect.fromLTRBR(
        colCenterX - _barW / 2, barTopY,
        colCenterX + _barW / 2, barBottomY,
        const Radius.circular(7),
      );
      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0.25)],
        ).createShader(Rect.fromLTRB(0, barTopY, 0, barBottomY));
      canvas.drawRRect(barRect, barPaint);

      // Date label
      final dateTP = TextPainter(
        text: TextSpan(
          text: formatDate(r.createdAt),
          style: const TextStyle(fontSize: _dateFontSize, color: AppColors.textSecondary),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: colWidth);
      dateTP.paint(canvas, Offset(colCenterX - dateTP.width / 2, barBottomY + _dateGap));
    }

    // Draw dashed trend line connecting bar top midpoints
    if (n < 2) return;
    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final positive = (records[i].happiness + records[i].calmness) / 2;
      final barH = 20 + (positive * 42);
      final x = (i + 0.5) * colWidth;
      final y = barBottomY - barH;
      points.add(Offset(x, y));
    }

    const dashLen = 5.0;
    const gapLen = 4.0;
    for (int i = 0; i < n - 1; i++) {
      final color = emotionColorFn(records[i].dominantEmotion);
      _drawDashedLine(canvas, points[i], points[i + 1], color, dashLen, gapLen);
    }

    // Arrowhead
    final last = points.last;
    final prev = points[n - 2];
    final dx = last.dx - prev.dx;
    final dy = last.dy - prev.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 0.01) return;
    final ndx = dx / dist;
    final ndy = dy / dist;
    final arrowPaint = Paint()
      ..color = emotionColorFn(records.last.dominantEmotion)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(last.dx, last.dy)
      ..lineTo(last.dx - ndx * 10 + ndy * 4, last.dy - ndy * 10 - ndx * 4)
      ..lineTo(last.dx - ndx * 10 - ndy * 4, last.dy - ndy * 10 + ndx * 4)
      ..close();
    canvas.drawPath(path, arrowPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Color color,
      double dashLen, double gapLen) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final total = math.sqrt(dx * dx + dy * dy);
    if (total < 0.01) return;
    final ndx = dx / total;
    final ndy = dy / total;

    double drawn = 0;
    bool onDash = true;
    while (drawn < total) {
      final segEnd = onDash
          ? math.min(drawn + dashLen, total)
          : math.min(drawn + gapLen, total);
      if (onDash) {
        canvas.drawLine(
          Offset(from.dx + ndx * drawn, from.dy + ndy * drawn),
          Offset(from.dx + ndx * segEnd, from.dy + ndy * segEnd),
          paint,
        );
      }
      drawn = segEnd;
      onDash = !onDash;
    }
  }

  @override
  bool shouldRepaint(covariant _EmotionTimelinePainter old) =>
      old.records != records || old.colWidth != colWidth;
}

