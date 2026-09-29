import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/themes/app_colors.dart';
import '../../app/responsive/adaptive_content_wrapper.dart';
import '../../services/storage_service.dart';
import '../../models/emotion_models.dart';
import '../../widgets/emotion_radar.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final StorageService _storageService = StorageService();
  List<EmotionRecord> _records = [];
  EmotionRecord? _targetRecord;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    // 过滤掉 dominantEmotion == '分析中...' 的占位记录，
    // 覆盖 records.firstOrNull（默认目标记录）与趋势图 _records.take(7) 两处
    final records = (await _storageService.getAllRecords())
        .where((r) => r.dominantEmotion != '分析中...')
        .toList();
    if (mounted) {
      setState(() {
        _records = records;
        // 从路由参数获取指定记录：优先使用传入的完整记录对象，其次是recordId，最后取最新记录
        final args = Get.arguments as Map<String, dynamic>?;
        final passedRecord = args?['record'] as EmotionRecord?;
        if (passedRecord != null) {
          _targetRecord = passedRecord;
        } else {
          final recordId = args?['recordId'] as String?;
          if (recordId != null) {
            _targetRecord = records.where((r) => r.id == recordId).firstOrNull ?? records.firstOrNull;
          } else {
            _targetRecord = records.firstOrNull;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestRecord = _targetRecord;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [AppColors.lightCyan.withValues(alpha: 0.1), AppColors.darkBackground]
        : [AppColors.lightCyan.withValues(alpha: 0.06), AppColors.background];

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
                _buildSliverHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      if (latestRecord == null)
                        _buildEmptyState()
                      else ...[
                        _buildEmotionRadarCard(latestRecord),
                        const SizedBox(height: 16),
                        _buildEmotionDimensionCard(latestRecord),
                        const SizedBox(height: 16),
                        _buildInterpretationCard(latestRecord),
                        const SizedBox(height: 16),
                        _buildComfortCard(latestRecord),
                        if (_records.length >= 2) ...[
                          const SizedBox(height: 16),
                          _buildTrendCard(),
                        ],
                      ],
                      const SizedBox(height: 24),
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

  Widget _buildSliverHeader() {
    return SliverAppBar(
      pinned: true,
      title: Text(
        '情绪分析报告',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.hazeBlue,
              fontWeight: FontWeight.w600,
            ),
      ),
      centerTitle: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 32),
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.lightCyan.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightCyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 40,
              color: AppColors.lightCyan.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有情绪数据',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '去树洞写下你的心事，我会为你分析每一份情绪',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionRadarCard(EmotionRecord record) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.lightCyan.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightCyan.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.lightCyan.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.lightCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.radar,
                    size: 16,
                    color: AppColors.lightCyan,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '情绪雷达图',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: EmotionRadarChart(
                record: record,
                textColor: Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionDimensionCard(EmotionRecord record) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.lightCyan.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightCyan.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.lightCyan.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.lightCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    size: 16,
                    color: AppColors.lightCyan,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '情绪维度',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildEmotionBar('😢', '悲伤', record.sadness, AppColors.softPink),
            _buildEmotionBar('😰', '焦虑', record.anxiety, AppColors.softOrange),
            _buildEmotionBar('😠', '愤怒', record.anger, AppColors.angerRed),
            _buildEmotionBar('🥺', '孤独', record.loneliness, AppColors.gentlePurple),
            _buildEmotionBar('😊', '开心', record.happiness, AppColors.calmGreen),
            _buildEmotionBar('😌', '平静', record.calmness, AppColors.lightCyan),
            _buildEmotionBar('😔', '压抑', record.suppression, AppColors.warmBeige),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionBar(String emoji, String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(emoji, style: const TextStyle(fontSize: 15)),
          ),
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.05, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 1.0),
                          color.withValues(alpha: 0.65),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '${(value * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.85),
                  ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterpretationCard(EmotionRecord record) {
    final hasAiAnalysis = record.interpretation.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.lightCyan.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightCyan.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.lightCyan.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.lightCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: AppColors.lightCyan,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '情绪解读',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (hasAiAnalysis) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.lightCyan.withValues(alpha: 0.12),
                          AppColors.hazeBlue.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                        left: BorderSide(
                          color: AppColors.lightCyan,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      'AI深度分析',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.lightCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _getEmotionInterpretation(record),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.85,
                  ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '~ ~ ~',
                style: TextStyle(
                  color: AppColors.lightCyan.withValues(alpha: 0.2),
                  fontSize: 16,
                  letterSpacing: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComfortCard(EmotionRecord record) {
    final suggestions = _getComfortSuggestions(record);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.calmGreen.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.calmGreen.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.calmGreen.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.calmGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.spa_outlined,
                    size: 16,
                    color: AppColors.calmGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '舒缓建议',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.calmGreen.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.calmGreen.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.calmGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.favorite_border_rounded,
                            size: 14,
                            color: AppColors.calmGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.lightCyan.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightCyan.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.lightCyan.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.lightCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.trending_up_rounded,
                    size: 16,
                    color: AppColors.lightCyan,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '近期情绪趋势',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildTrendChart(),
          ],
        ),
      ),
    );
  }

  String _getEmotionInterpretation(EmotionRecord record) {
    // 优先使用记录中存储的大模型解读
    if (record.interpretation.isNotEmpty) return record.interpretation;

    final interpretations = <String>[];

    if (record.sadness > 0.5) interpretations.add('你当前有些悲伤的情绪，这可能来源于近期的失落或不舍。');
    if (record.anxiety > 0.5) interpretations.add('焦虑感比较明显，可能是因为对未来有些不确定或担心。');
    if (record.anger > 0.5) interpretations.add('你感到有些愤怒，这通常意味着你的边界或底线被触碰了。');
    if (record.loneliness > 0.5) interpretations.add('孤独感较强，你可能需要更多温暖的连接和陪伴。');
    if (record.suppression > 0.5) interpretations.add('压抑感明显，你可能长期承受了一些没有释放的压力。');
    if (record.happiness > 0.5) interpretations.add('你目前的状态不错，开心和愉悦的情绪占据主导。');
    if (record.calmness > 0.5) interpretations.add('你处于相对平静的状态，这是很好的内心平衡。');

    if (interpretations.isEmpty) {
      interpretations.add('你的情绪状态整体比较平稳，没有明显的波动。保持这份内心的安宁。');
    }

    return interpretations.join('\n\n');
  }

  List<String> _getComfortSuggestions(EmotionRecord record) {
    // 优先使用记录中存储的大模型建议
    if (record.suggestions.isNotEmpty) return record.suggestions;

    final suggestions = <String>[];

    if (record.sadness > 0.3) suggestions.addAll(['允许自己哭泣，眼泪是最好的自我疗愈', '听一首温暖的音乐，让旋律陪你度过']);
    if (record.anxiety > 0.3) suggestions.addAll(['试试4-7-8深呼吸法，慢慢平复心跳', '把担心的事情写下来，逐一分析是否可控']);
    if (record.anger > 0.3) suggestions.addAll(['出去走走，让身体释放紧张能量', '对着枕头大声说出你的不满，然后放下']);
    if (record.loneliness > 0.3) suggestions.addAll(['给自己一个温暖的拥抱，你值得被爱', '回忆一个让你感到温暖的时刻']);
    if (record.suppression > 0.3) suggestions.addAll(['找一个安全的地方释放情绪，不需要压抑', '允许自己不完美，你已经在尽力了']);
    if (record.happiness > 0.3) suggestions.add('记录下让你开心的事情，不开心时翻看');
    if (record.calmness > 0.3) suggestions.add('保持这份平静，享受当下的安宁');

    if (suggestions.isEmpty) suggestions.add('好好休息，照顾好自己');
    return suggestions;
  }

  Widget _buildTrendChart() {
    final recent = _records.take(7).toList().reversed.toList();
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: recent.map((r) {
          final emotionColors = {
            '悲伤': AppColors.softPink,
            '焦虑': AppColors.softOrange,
            '愤怒': AppColors.angerRed,
            '孤独': AppColors.gentlePurple,
            '开心': AppColors.calmGreen,
            '平静': AppColors.lightCyan,
            '压抑': AppColors.warmBeige,
          };
          // 正向指数：0~1，越高情绪越积极
          final positive = (r.happiness + r.calmness) / 2;
          final barHeight = 24 + (positive * 72); // 24~96，安全范围
          final dominantColor = emotionColors[r.dominantEmotion] ?? AppColors.hazeBlue;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 主导情绪标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: dominantColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.dominantEmotion,
                  style: TextStyle(
                    fontSize: 10,
                    color: dominantColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 22,
                height: barHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      dominantColor.withValues(alpha: 0.7),
                      dominantColor.withValues(alpha: 0.25),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${r.createdAt.month}/${r.createdAt.day}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
