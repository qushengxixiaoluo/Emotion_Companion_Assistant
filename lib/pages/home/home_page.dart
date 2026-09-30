import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/themes/app_colors.dart';
import '../../app/styles/app_styles.dart';
import '../../app/styles/ui_style.dart';
import '../../app/responsive/adaptive_content_wrapper.dart';
import '../../services/storage_service.dart';
import '../../models/emotion_models.dart';
import '../../app/routes/app_routes.dart';
import '../../widgets/app_card.dart';
import '../../widgets/lowpoly_background.dart';
import '../../widgets/emotion_radar.dart';
import '../../widgets/heartbeat_breath_button.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
    _setGreeting();
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
        borderRadius: AppRadius.smB,
      ),
      child: Icon(icon, size: size, color: Theme.of(context).colorScheme.onSurface),
    );
  }

  // ============= Main Build =============

  @override
  Widget build(BuildContext context) {
    final todayAggregated = _getTodayAggregated();
    final todayCount = _getTodayCount();
    final now = DateTime.now();

    return Scaffold(
      // 顶栏与「安慰」「我的」统一：Scaffold 标准 AppBar（主题透明底、标题居中）
      appBar: AppBar(
        title: Text(
          '情绪陪伴',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      body: LowPolyBackground(
        child: SafeArea(
          top: false, // 顶部由 AppBar 承担，避免状态栏双重留白
          child: AdaptiveContentWrapper(
            child: CustomScrollView(
              slivers: [
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
    return SizedBox(
      width: double.infinity,
      child: AppCard(
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
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '我是你的情绪陪伴师',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
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
                  borderRadius: AppRadius.mdB,
                ),
                child: Icon(
                  Icons.cloud_outlined,
                  size: 22,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.hazeBlue.withValues(alpha: 0.06),
              borderRadius: AppRadius.smB,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(now),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  // ============= Heartbeat Section =============

  Widget _buildHeartbeatSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        // 不透明淡染（按明暗取底色）：浅色防网格透出显灰，深色防浅底压白字
        color: Color.lerp(
          Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBackground
              : AppColors.background,
          AppColors.hazeBlue,
          0.05,
        ),
        borderRadius: AppRadius.cardB,
        border: AppStroke.all(context),
      ),
      child: Column(
        children: [
          Text(
            '轻轻点击，开始倾诉...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
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
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }

  // ============= Today's Emotion Card =============

  Widget _buildTodayEmotionCard(EmotionRecord? todayAggregated, int todayCount) {
    return SizedBox(
      width: double.infinity,
      child: AppCard(
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
                  borderRadius: AppRadius.smB,
                ),
                child: Text(
                  '查看详情 →',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
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
              iconColor: Theme.of(context).colorScheme.onSurface,
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
                          color: Theme.of(context).colorScheme.onSurface,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: AppCard(
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
                      size: 14, color: Theme.of(context).colorScheme.onSurface),
                  const SizedBox(width: 4),
                  Text(
                    '归档',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
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
              iconColor: Theme.of(context).colorScheme.onSurface,
              title: '还没有情绪记录',
              subtitle: '开始倾诉，记录你的情绪旅程',
            )
          else
            _buildEmotionTimeline(isDark),
        ],
        ),
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
                color: Theme.of(context).colorScheme.onSurface,
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
                color: Theme.of(context).colorScheme.onSurface,
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
                color: Theme.of(context).colorScheme.onSurface,
                onTap: () => Get.toNamed(AppRoutes.privacy),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAction(
                icon: Icons.nightlight_round,
                label: 'AI梦境解读',
                color: Theme.of(context).colorScheme.onSurface,
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
        borderRadius: AppRadius.mdB,
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
                  color: Theme.of(context).colorScheme.onSurface,
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
        borderRadius: AppRadius.cardB,
      ),
      child: Text(
        emotion,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  /// 每页展示的记录条数（翻页阈值与页容量共用）
  static const _timelinePageSize = 8;

  Widget _buildEmotionTimeline(bool isDark) {
    // 过滤掉"分析中..."占位记录，与 analysis 页保持一致
    final filtered = _records
        .where((r) => r.dominantEmotion != '分析中...')
        .toList();
    if (filtered.isEmpty) return const SizedBox.shrink();

    // ≤ 8 条：保持现状单图显示（不翻页、不显示指示器）
    if (filtered.length <= _timelinePageSize) {
      return _buildTimelineChart(filtered.reversed.toList(), isDark);
    }

    // > 8 条：分页。_records 是时间倒序（最新在前），所以按 8 条切块得到
    // [最新页, ..., 最早页]，再反转成时间正序的页序列（最旧页在第 0 页）。
    // PageView 的 initialPage = 最后一页 = 最新 8 条；向右滑（上一页）即回到更早的页。
    final chunks = <List<EmotionRecord>>[];
    for (var i = 0; i < filtered.length; i += _timelinePageSize) {
      final end = math.min(i + _timelinePageSize, filtered.length);
      chunks.add(filtered.sublist(i, end));
    }
    final pages = chunks.reversed.toList();

    return _PagedEmotionTimeline(
      // 页数变化时重建 State，让 PageController 的 initialPage 重新对准最新页
      key: ValueKey('home_timeline_pages_${pages.length}'),
      pages: pages,
      isDark: isDark,
      emotionColorFn: _emotionColor,
      formatDate: _formatTimelineDate,
    );
  }

  /// 单图时间轴（≤8 条时使用）：records 为时间正序（最新在右）
  Widget _buildTimelineChart(List<EmotionRecord> records, bool isDark) {
    return SizedBox(
      height: 120,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalW = constraints.maxWidth;
          final colW = records.isNotEmpty ? totalW / records.length : totalW;
          return CustomPaint(
            size: Size(totalW, 120),
            painter: _EmotionTimelinePainter(
              records: records,
              emotionColorFn: _emotionColor,
              colWidth: colW,
              formatDate: _formatTimelineDate,
              isDark: isDark,
              style: UiStyleScope.of(context),
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
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardB,
          boxShadow: AppShadow.hard(context, dy: 4, alpha: 0.22),
        ),
        child: AppCard(
          hardShadow: false,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
          children: [
            // 图标容器 — 彩色半透明底
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadius.mdB,
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 24),
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
      ),
    );
  }
}

/// 「近期情绪波动」分页容器。
///
/// [pages] 按时间正序排列（第 0 页最旧、最后一页最新），页内记录保持
/// 时间倒序（最新在前），绘制时 reversed 使每页最旧在左、最新在右。
/// initialPage 指向最后一页 → 默认展示最新记录；向右滑（上一页）看更早记录。
class _PagedEmotionTimeline extends StatefulWidget {
  final List<List<EmotionRecord>> pages;
  final bool isDark;
  final Color Function(String) emotionColorFn;
  final String Function(DateTime) formatDate;

  const _PagedEmotionTimeline({
    super.key,
    required this.pages,
    required this.isDark,
    required this.emotionColorFn,
    required this.formatDate,
  });

  @override
  State<_PagedEmotionTimeline> createState() => _PagedEmotionTimelineState();
}

class _PagedEmotionTimelineState extends State<_PagedEmotionTimeline> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.pages.length - 1; // 默认停在最新页
    _controller = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.pages.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _controller,
            itemCount: pageCount,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) {
              // 页内 reversed：与单图一致，最旧在左、最新在右
              final pageRecords = widget.pages[index].reversed.toList();
              return LayoutBuilder(
                builder: (context, constraints) {
                  final totalW = constraints.maxWidth;
                  return CustomPaint(
                    size: Size(totalW, 120),
                    painter: _EmotionTimelinePainter(
                      records: pageRecords,
                      emotionColorFn: widget.emotionColorFn,
                      colWidth: totalW / pageRecords.length,
                      formatDate: widget.formatDate,
                      isDark: widget.isDark,
                      style: UiStyleScope.of(context),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '左右滑动查看更多',
          style: TextStyle(
            fontSize: 10.5,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 6),
        _buildDots(),
      ],
    );
  }

  /// 翻页指示器：active 实心、inactive 同色 alpha 0.25；
  /// 页数过多时只显示当前页附近的点，保证单行不溢出。
  Widget _buildDots() {
    const maxVisible = 9;
    const dotSize = 6.0;
    const gap = 5.0;
    final count = widget.pages.length;
    var start = 0;
    if (count > maxVisible) {
      start = (_current - 3).clamp(0, count - maxVisible);
    }
    final end = math.min(count, start + maxVisible);
    final ink = AppStroke.ink(isDark: widget.isDark, style: UiStyleScope.of(context));
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = start; i < end; i++)
          Padding(
            padding: EdgeInsets.only(right: i == end - 1 ? 0 : gap),
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _current ? ink : ink.withValues(alpha: 0.25),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmotionTimelinePainter extends CustomPainter {
  final List<EmotionRecord> records;
  final Color Function(String) emotionColorFn;
  final double colWidth;
  final String Function(DateTime) formatDate;
  final bool isDark;
  final AppUiStyle style;

  _EmotionTimelinePainter({
    required this.records,
    required this.emotionColorFn,
    required this.colWidth,
    required this.formatDate,
    this.isDark = false,
    this.style = AppUiStyle.lowPoly,
  });

  static const _barW = 14.0;
  static const _labelGap = 6.0;
  static const _dateGap = 6.0;
  static const _labelFontSize = 9.0;
  static const _dateFontSize = 10.0;

  bool get _watercolor => style == AppUiStyle.watercolor;

  /// 水彩：线宽收细 0.3 + 圆头圆角；lowPoly 原值原样
  double _sw(double w) => _watercolor && w > 0.7 ? w - 0.3 : w;

  /// 语义色填充水彩下 alpha ×0.75（清透）
  double _fillA(double a) => _watercolor ? a * 0.75 : a;

  Paint _stroke(double width, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _sw(width);
    if (_watercolor) {
      p
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;

    final ink = AppStroke.ink(isDark: isDark, style: style);
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
          style: TextStyle(fontSize: _labelFontSize, color: ink, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: colWidth);
      labelTP.paint(canvas, Offset(colCenterX - labelTP.width / 2, barTopY - _labelGap - labelTP.height));

      // Bar body (实色填充) + 描边（lowpoly 硬朗风 / 水彩清透手绘）
      final barRect = RRect.fromLTRBR(
        colCenterX - _barW / 2, barTopY,
        colCenterX + _barW / 2, barBottomY,
        const Radius.circular(4),
      );
      final barPaint = Paint()
        ..color = color.withValues(alpha: _fillA(0.55));
      canvas.drawRRect(barRect, barPaint);
      canvas.drawRRect(barRect, _stroke(2, ink));

      // Date label
      final dateTP = TextPainter(
        text: TextSpan(
          text: formatDate(r.createdAt),
          style: TextStyle(fontSize: _dateFontSize, color: ink),
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
      _drawDashedLine(
        canvas, points[i], points[i + 1], ink.withValues(alpha: 0.6), dashLen, gapLen);
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
          .withValues(alpha: _fillA(1.0))
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(last.dx, last.dy)
      ..lineTo(last.dx - ndx * 10 + ndy * 4, last.dy - ndy * 10 - ndx * 4)
      ..lineTo(last.dx - ndx * 10 - ndy * 4, last.dy - ndy * 10 + ndx * 4)
      ..close();
    canvas.drawPath(path, arrowPaint);
    canvas.drawPath(path, _stroke(1.5, ink));
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Color color,
      double dashLen, double gapLen) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _sw(2)
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
      old.records != records ||
      old.colWidth != colWidth ||
      old.isDark != isDark ||
      old.style != style;
}

