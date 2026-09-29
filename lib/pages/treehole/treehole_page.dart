import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/themes/app_colors.dart';
import '../../app/responsive/adaptive_content_wrapper.dart';
import '../../services/emotion_service.dart';
import '../../services/llm_service.dart';
import '../../services/storage_service.dart';
import '../../services/white_noise_service.dart';
import '../../models/emotion_models.dart';
import '../../app/routes/app_routes.dart';
import '../../widgets/unified_config_dialog.dart';

class TreeholePage extends StatefulWidget {
  const TreeholePage({super.key});

  @override
  State<TreeholePage> createState() => TreeholePageState();
}

class TreeholePageState extends State<TreeholePage> {
  final TextEditingController _textController = TextEditingController();
  final EmotionService _emotionService = EmotionService();
  final StorageService _storageService = StorageService();
  List<EmotionRecord> _records = [];
  bool _isLocked = false;
  bool _showPinDialog = false;

  // PIN 解锁失败限制：连续 5 次错误后禁用输入 30 秒（页面内状态，无需持久化）
  static const int _pinMaxFails = 5;
  static const int _pinLockSeconds = 30;
  int _pinFailCount = 0;
  DateTime? _pinLockUntil;
  Timer? _pinLockTimer;
  final TextEditingController _pinInputController = TextEditingController();

  bool get _isPinLockedOut =>
      _pinLockUntil != null && DateTime.now().isBefore(_pinLockUntil!);

  int get _pinLockRemaining {
    if (_pinLockUntil == null) return 0;
    final s = _pinLockUntil!.difference(DateTime.now()).inSeconds;
    return s < 1 ? 1 : s;
  }

  void _beginPinLockout() {
    _pinLockUntil = DateTime.now().add(const Duration(seconds: _pinLockSeconds));
    _pinLockTimer?.cancel();
    _pinLockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        _pinLockTimer = null;
        return;
      }
      if (_isPinLockedOut) {
        setState(() {}); // 刷新倒计时
      } else {
        timer.cancel();
        _pinLockTimer = null;
        setState(() {
          _pinLockUntil = null;
          _pinFailCount = 0;
        });
      }
    });
  }

  void _resetPinFailures() {
    _pinFailCount = 0;
    _pinLockUntil = null;
    _pinLockTimer?.cancel();
    _pinLockTimer = null;
  }

  // 白噪音：由全局 WhiteNoiseService 单例播放（两个入口共享，退出页面不中断）
  final WhiteNoiseService _noiseService = WhiteNoiseService();

  @override
  void initState() {
    super.initState();
    _checkLock();
    _loadRecords();
    // 监听全局噪音状态：任一入口切换，所有存活实例同步刷新高亮
    _noiseService.currentNoise.addListener(_onNoiseChanged);
  }

  void _onNoiseChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _noiseService.currentNoise.removeListener(_onNoiseChanged);
    _pinLockTimer?.cancel();
    _pinInputController.dispose();
    // 注意：不释放白噪音播放器——它属于应用级单例，退出页面声音继续
    super.dispose();
  }

  Future<void> _checkLock() async {
    final locked = await _storageService.isLocked();
    final hasPin = await _storageService.hasPin();
    // 兜底：已锁定却没有 PIN 时不进锁屏，
    // 否则 verifyPin 恒为 false 会造成永久死锁（锁屏、无 PIN、任何密码都进不去）。
    setState(() => _isLocked = locked && hasPin);
  }

  Future<void> _loadRecords() async {
    final records = await _storageService.getAllRecords();
    setState(() => _records = records);
  }

  /// 外部可调用的刷新方法，用于跨页面同步数据
  Future<void> refreshData() async {
    await _checkLock();
    await _loadRecords();
  }

  Future<void> _submitEmotion() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final llmService = LlmService();
    final useLlm = llmService.isConfigured();

    // 1. 生成记录
    final recordId = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();

    // 占位记录是否仍在库里（失败时必须在 catch 里替换成兜底记录）
    bool placeholderSaved = false;
    // 加载弹窗是否仍打开 —— 这是唯一的"加载态"，finally 必须关闭它
    bool dialogOpen = false;
    bool dialogCancelled = false;

    try {
      if (useLlm) {
        // LLM 模式：先创建占位记录，显示加载弹窗，后台分析
        final pendingRecord = EmotionRecord(
          id: recordId,
          content: text,
          dominantEmotion: '分析中...',
          createdAt: now,
        );
        await _storageService.saveRecord(pendingRecord);
        placeholderSaved = true;
        _textController.clear();
        await _loadRecords();

        // 显示加载弹窗
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('AI情绪分析', style: TextStyle(fontSize: 16)),
                    GestureDetector(
                      onTap: () {
                        dialogCancelled = true;
                        dialogOpen = false;
                        Navigator.of(ctx).pop();
                      },
                      child: Icon(Icons.close, size: 20, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3)),
                    ),
                  ],
                ),
                titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                content: const SizedBox(
                  height: 100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text('正在生成详细情绪报告中……', style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              );
            },
          );
          // showDialog 返回后立即标记（builder 可能尚未执行，不能依赖 builder 内赋值）
          dialogOpen = true;
        }

        final llmResult = await llmService.analyzeEmotion(text);

        // 构建最终记录：AI成功用AI结果，失败用本地兜底
        final EmotionRecord finalRecord;
        if (llmResult != null) {
          double numAt(String key) => (llmResult[key] as num?)?.toDouble() ?? 0;
          finalRecord = EmotionRecord(
            id: recordId,
            content: text,
            sadness: numAt('sadness'),
            anxiety: numAt('anxiety'),
            anger: numAt('anger'),
            loneliness: numAt('loneliness'),
            happiness: numAt('happiness'),
            calmness: numAt('calmness'),
            suppression: numAt('suppression'),
            dominantEmotion: llmResult['dominantEmotion']?.toString() ?? '平静',
            createdAt: pendingRecord.createdAt,
            interpretation: llmResult['interpretation']?.toString() ?? '',
            suggestions: (llmResult['suggestions'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const [],
          );
        } else {
          finalRecord = _localFallbackRecord(recordId, text, pendingRecord.createdAt);
        }

        // 用最终结果替换占位记录，刷新列表
        await _storageService.saveRecord(finalRecord);
        placeholderSaved = false;
        await _loadRecords();

        if (dialogCancelled) {
          // 用户已关弹窗 → 结果已静默更新到列表
        } else {
          if (dialogOpen && mounted) {
            dialogOpen = false;
            Navigator.of(context).pop();
          }
          if (mounted) {
            Get.toNamed(AppRoutes.analysis, arguments: {'recordId': finalRecord.id});
          }
        }
      } else {
        // 本地模式：直接分析，无需弹窗
        final finalRecord = _localFallbackRecord(recordId, text, now);
        await _storageService.saveRecord(finalRecord);
        _textController.clear();
        await _loadRecords();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('已使用本地分析，配置大模型 API 可获得 AI 深度分析'),
              backgroundColor: AppColors.hazeBlue,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: '去配置',
                textColor: Colors.white,
                onPressed: () {
                  showUnifiedConfigDialog(context).then((_) => _loadRecords());
                },
              ),
            ),
          );
        }
      }
    } catch (_) {
      // 分析中途失败：绝不让"分析中..."占位记录永留库里
      bool fallbackSaved = false;
      if (placeholderSaved) {
        try {
          final fallback = _localFallbackRecord(recordId, text, now);
          await _storageService.saveRecord(fallback);
          placeholderSaved = false;
          fallbackSaved = true;
        } catch (_) {
          // 兜底也失败 → 删除占位记录，至少不留假数据
          try {
            await _storageService.deleteRecord(recordId);
            placeholderSaved = false;
          } catch (_) {}
        }
      }
      if (mounted) {
        await _loadRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(fallbackSaved ? 'AI 分析失败，已改用本地分析' : 'AI 分析失败，请稍后重试'),
            backgroundColor: AppColors.softPink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // 结束加载态：确保加载弹窗一定被关闭
      if (dialogOpen) {
        dialogOpen = false;
        if (mounted) {
          try {
            Navigator.of(context).pop();
          } catch (_) {}
        }
      }
    }
  }

  /// 本地分析兜底记录
  EmotionRecord _localFallbackRecord(String id, String text, DateTime createdAt) {
    final localRecord = _emotionService.analyze(text);
    return EmotionRecord(
      id: id,
      content: text,
      sadness: localRecord.sadness,
      anxiety: localRecord.anxiety,
      anger: localRecord.anger,
      loneliness: localRecord.loneliness,
      happiness: localRecord.happiness,
      calmness: localRecord.calmness,
      suppression: localRecord.suppression,
      dominantEmotion: localRecord.dominantEmotion,
      createdAt: createdAt,
    );
  }

  // ============ BUILD ============

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return _buildLockedView();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [AppColors.hazeBlue.withOpacity(0.12), AppColors.darkBackground]
        : [AppColors.hazeBlue.withOpacity(0.05), AppColors.background];

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
                      _buildPrivacyBanner(),
                      const SizedBox(height: 12),
                      _buildInputArea(),
                      const SizedBox(height: 12),
                      _buildNoiseChipsSection(),
                      const SizedBox(height: 20),
                      _buildHistorySection(),
                      const SizedBox(height: 20),
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

  // ============ UI SECTIONS ============

  Widget _buildSliverHeader() {
    return SliverAppBar(
      pinned: true,
      title: Text(
        '情绪树洞',
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
        IconButton(
          icon: const Icon(Icons.lock_outline, size: 20),
          onPressed: _lockTreehole,
          tooltip: '锁定树洞',
        ),
      ],
    );
  }

  Widget _buildPrivacyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.hazeBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: const Border(
          left: BorderSide(color: AppColors.hazeBlue, width: 3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.hazeBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield_outlined, size: 16, color: AppColors.hazeBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '这里是你的私密空间，所有内容仅你可见，全程加密保护',
              style: TextStyle(
                color: AppColors.hazeBlue,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.hazeBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.hazeBlue.withOpacity(0.12),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.park_outlined, size: 20, color: AppColors.hazeBlue),
              const SizedBox(width: 8),
              Text(
                '把心事写在这里',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.hazeBlue,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            maxLines: null,
            minLines: 2,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: '把心事写在这里吧，我静静听着……',
              hintStyle: Theme.of(context).textTheme.bodySmall,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.hazeBlue.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.hazeBlue.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.hazeBlue, width: 1.5),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor.withOpacity(0.6),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _submitEmotion,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('投入树洞'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.hazeBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoiseChipsSection() {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.hazeBlue.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '白噪音',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.hazeBlue,
              ),
        ),
        const SizedBox(width: 12),
        _buildNoiseChip('小雨', Icons.water_drop_outlined, 'rain'),
        const SizedBox(width: 8),
        _buildNoiseChip('晚风', Icons.air, 'wind'),
        const SizedBox(width: 8),
        _buildNoiseChip('溪流', Icons.waves_outlined, 'stream'),
      ],
    );
  }

  Widget _buildHistorySection() {
    if (_records.isEmpty) {
      return _buildEmptyHistoryState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHistoryTitle(),
        const SizedBox(height: 12),
        ..._records.map((record) => _buildRecordCard(record)),
      ],
    );
  }

  Widget _buildHistoryTitle() {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.hazeBlue.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '情绪日记',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(width: 8),
        Text(
          '${_records.length}',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.hazeBlue.withOpacity(0.5),
          ),
        ),
        const Spacer(),
        if (_records.isNotEmpty)
          GestureDetector(
            onTap: _deleteAllRecords,
            child: Text(
              '清空全部',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.softPink.withOpacity(0.6),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyHistoryState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHistoryTitle(),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(Icons.park_outlined, size: 36, color: AppColors.hazeBlue.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text(
                '还没有记录',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '写下你的第一个心事，让树洞温柔接纳你的每一份情绪',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============ COMPONENT BUILDERS ============

  Widget _buildNoiseChip(String label, IconData icon, String key) {
    final isActive = _noiseService.currentNoise.value == key;
    return GestureDetector(
      onTap: () => _toggleNoise(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.hazeBlue.withOpacity(0.12)
              : Theme.of(context).cardColor.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.hazeBlue.withOpacity(0.4) : AppColors.divider.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? AppColors.hazeBlue
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? AppColors.hazeBlue
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(EmotionRecord record) {
    final emotionColors = {
      '悲伤': AppColors.softPink,
      '焦虑': AppColors.softOrange,
      '愤怒': AppColors.angerRed,
      '孤独': AppColors.gentlePurple,
      '开心': AppColors.calmGreen,
      '平静': AppColors.lightCyan,
      '压抑': AppColors.warmBeige,
      '分析中...': AppColors.textHint,
    };

    final emotionColor = emotionColors[record.dominantEmotion] ?? AppColors.hazeBlue;
    final isPending = record.dominantEmotion == '分析中...';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.hazeBlue.withOpacity(0.08),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧情绪图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: emotionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                isPending ? '⏳' : _emotionEmoji(record.dominantEmotion),
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            // 右侧内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: emotionColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPending) ...[
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: emotionColor.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              record.dominantEmotion,
                              style: TextStyle(
                                fontSize: 11,
                                color: emotionColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDate(record.createdAt),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11),
                          ),
                          if (!isPending) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _deleteRecord(record.id),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    record.content.length > 100
                        ? '${record.content.substring(0, 100)}……'
                        : record.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.hazeBlue.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '正在AI深度分析中，请稍候……',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ] else if (record.interpretation.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Get.toNamed(AppRoutes.analysis, arguments: {'recordId': record.id});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.hazeBlue.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.hazeBlue.withOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 14, color: AppColors.hazeBlue),
                            const SizedBox(width: 6),
                            Text(
                              '查看详细情绪报告',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.hazeBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedView() {
    void tryUnlock() async {
      if (_isPinLockedOut) return;
      final verified = await _storageService.verifyPin(_pinInputController.text);
      if (!mounted) return;
      if (verified) {
        _resetPinFailures();
        setState(() {
          _isLocked = false;
          _pinInputController.clear();
        });
        return;
      }
      _pinFailCount += 1;
      if (_pinFailCount >= _pinMaxFails) {
        _beginPinLockout();
      }
      setState(() {}); // 刷新剩余次数/倒计时
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isPinLockedOut
                ? '连续$_pinMaxFails次错误，已禁用输入$_pinLockSeconds秒（${_pinLockRemaining}秒后恢复）'
                : '密码错误，还可尝试${_pinMaxFails - _pinFailCount}次',
          ),
          backgroundColor: AppColors.softPink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [AppColors.hazeBlue.withOpacity(0.12), AppColors.darkBackground]
        : [AppColors.hazeBlue.withOpacity(0.05), AppColors.background];

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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.hazeBlue.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: AppColors.hazeBlue.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '树洞已锁定',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '输入密码解锁，回到你的私密空间',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _pinInputController,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    enabled: !_isPinLockedOut,
                    decoration: InputDecoration(
                      hintText: _isPinLockedOut ? '$_pinLockRemaining秒后可重试' : '请输入密码',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.hazeBlue.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.hazeBlue.withOpacity(0.15)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.hazeBlue, width: 1.5),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.lock_open_outlined, color: AppColors.hazeBlue),
                        onPressed: _isPinLockedOut ? null : tryUnlock,
                      ),
                    ),
                    onSubmitted: (_) {
                      if (!_isPinLockedOut) tryUnlock();
                    },
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _showForgotPasswordDialog(),
                  child: Text(
                    '忘记密码？',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.hazeBlue.withOpacity(0.7),
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.hazeBlue.withOpacity(0.35),
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

  // ============ AUDIO ============

  /// 白噪音切换：委托全局单例（状态变化经 ValueNotifier 回调 _onNoiseChanged 刷新 UI）
  void _toggleNoise(String key) {
    _noiseService.toggle(key);
  }

  // ============ HELPERS ============

  String _emotionEmoji(String emotion) {
    const emojis = {
      '悲伤': '😢',
      '焦虑': '😰',
      '愤怒': '😠',
      '孤独': '🥺',
      '开心': '😊',
      '平静': '😌',
      '压抑': '😔',
    };
    return emojis[emotion] ?? '😌';
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ============ RECORD MANAGEMENT ============

  Future<void> _deleteRecord(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除日记'),
        content: const Text('确定要删除这条情绪日记吗？删除后无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: AppColors.softPink)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _storageService.deleteRecord(id);
      await _loadRecords();
    }
  }

  Future<void> _deleteAllRecords() async {
    if (_records.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('清空所有日记'),
        content: const Text('确定要删除全部情绪日记吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('全部删除', style: TextStyle(color: AppColors.softPink)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // 本入口只负责"情绪日记"，用仅清日记的方法，避免误删对话/梦境等数据
      await _storageService.clearEmotionRecords();
      await _loadRecords();
    }
  }

  // ============ LOCK / PIN ============

  Future<void> _lockTreehole() async {
    final hasPin = await _storageService.hasPin();
    if (!hasPin) {
      final set = await _showCreatePinDialog(title: '首次锁定树洞', hint: '请设置4-6位数字密码');
      if (set == true) {
        await _storageService.setLocked(true);
        setState(() => _isLocked = true);
        if (mounted) {
          await _showRecoveryQASetupDialog();
        }
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('锁定树洞'),
          content: const Text('锁定后需要输入密码才能访问，是否确认？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('确认锁定', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _storageService.setLocked(true);
        setState(() => _isLocked = true);
      }
    }
  }

  /// 创建密码弹窗（两步验证：输入 → 确认）
  Future<bool?> _showCreatePinDialog({required String title, required String hint}) {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('请输入4-6位数字密码', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: hint,
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final pin = controller.text;
                if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
                  setDialogState(() => errorText = '请输入4-6位数字密码');
                  return;
                }
                // 弹出确认密码弹窗
                final confirmed = await _showConfirmPinDialog(pin);
                if (confirmed == true) {
                  await _storageService.setPin(pin);
                  Navigator.pop(context, true);
                } else if (confirmed == false) {
                  setDialogState(() => errorText = '两次输入不一致，请重新输入');
                  controller.clear();
                }
              },
              child: Text('下一步', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      ),
    );
  }

  /// 确认密码弹窗（二次输入）
  Future<bool?> _showConfirmPinDialog(String firstPin) {
    final controller = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('请再次输入密码以确认', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: '请再次输入密码'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () {
              if (controller.text == firstPin) {
                Navigator.pop(context, true);
              } else {
                Navigator.pop(context, false);
              }
            },
            child: Text('确认', style: TextStyle(color: AppColors.hazeBlue)),
          ),
        ],
      ),
    );
  }

  /// 二级安保：设置密保问题与答案（强制设置）
  Future<void> _showRecoveryQASetupDialog() async {
    final questionController = TextEditingController();
    final answerController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.security, color: AppColors.softOrange, size: 24),
            const SizedBox(width: 8),
            const Text('二级安保设置'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '设置密保问题，忘记密码时可通过回答此问题找回',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: questionController,
              decoration: const InputDecoration(
                hintText: '请输入密保问题（如：我的小名是什么？）',
                labelText: '密保问题',
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answerController,
              decoration: const InputDecoration(
                hintText: '请输入答案',
                labelText: '密保答案',
              ),
              maxLength: 30,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final q = questionController.text.trim();
              final a = answerController.text.trim();
              if (q.isEmpty || a.isEmpty) return;
              await _storageService.setRecoveryQA(q, a);
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('密保已设置，忘记密码时可通过密保找回'),
                    backgroundColor: AppColors.calmGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text('确认设置', style: TextStyle(color: AppColors.hazeBlue)),
          ),
        ],
      ),
    );
  }

  /// 忘记密码 → 密保验证 → 重置密码
  Future<void> _showForgotPasswordDialog() async {
    final hasQA = await _storageService.hasRecoveryQA();
    if (!hasQA) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('无法找回'),
            content: const Text('尚未设置密保问题，无法通过此方式找回密码。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('知道了', style: TextStyle(color: AppColors.hazeBlue)),
              ),
            ],
          ),
        );
      }
      return;
    }

    final question = await _storageService.getRecoveryQuestion();
    final answerController = TextEditingController();
    String? errorText;

    if (!mounted) return;
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.help_outline, color: AppColors.softOrange, size: 24),
              const SizedBox(width: 8),
              const Text('找回密码'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('请回答以下密保问题：', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softOrange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  question ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: answerController,
                decoration: InputDecoration(
                  hintText: '请输入答案',
                  errorText: errorText,
                ),
                maxLength: 30,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final ok = await _storageService.verifyRecoveryAnswer(answerController.text.trim());
                if (ok) {
                  Navigator.pop(context, true);
                } else {
                  setDialogState(() => errorText = '答案错误，请重试');
                }
              },
              child: Text('验证', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      ),
    );

    if (verified == true && mounted) {
      // 密保验证通过 → 重置密码。
      // 注意：此处不清空旧 PIN。_showCreatePinDialog 成功时才调用 setPin 覆盖；
      // 用户若中途取消，旧 PIN 原样保留，锁依然生效（不会出现"锁还在但无 PIN"的万能解锁态）。
      final set = await _showCreatePinDialog(title: '重置密码', hint: '请设置新的4-6位数字密码');
      if (set == true && mounted) {
        // 重新设置密保
        _showRecoveryQASetupDialog();
        // 解锁
        _resetPinFailures();
        setState(() => _isLocked = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('密码已重置，树洞已解锁'),
            backgroundColor: AppColors.calmGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
