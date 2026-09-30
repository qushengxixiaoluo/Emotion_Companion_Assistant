import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import '../../app/styles/app_styles.dart';
import '../../app/themes/app_colors.dart';
import '../../app/responsive/adaptive_content_wrapper.dart';
import '../../models/emotion_models.dart';
import '../../services/llm_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/lowpoly_background.dart';
import '../../widgets/unified_config_dialog.dart';

class DreamPage extends StatefulWidget {
  const DreamPage({super.key});

  @override
  State<DreamPage> createState() => _DreamPageState();
}

class _DreamPageState extends State<DreamPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LlmService _llmService = LlmService();
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  String? _resultMarkdown;
  String? _resultTitle;
  String? _errorMessage;
  String _dreamText = '';
  List<DreamRecord> _history = [];
  Timer? _pendingCheckTimer;
  String? _pendingDreamId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _checkAndRestorePendingDream();
  }

  Future<void> _loadHistory() async {
    final records = await _storageService.getAllDreamRecords();
    setState(() => _history = records);
  }

  Future<void> _checkAndRestorePendingDream() async {
    final pendingText = await _storageService.getPendingDreamText();
    final pendingId = await _storageService.getPendingDreamId();
    if (pendingText == null || pendingId == null) return;

    _pendingDreamId = pendingId;
    setState(() {
      _isLoading = true;
      _dreamText = pendingText;
      _resultMarkdown = null;
      _resultTitle = null;
      _errorMessage = null;
    });
    _startPendingPolling();
  }

  void _startPendingPolling() {
    _pendingCheckTimer?.cancel();
    _pendingCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final pendingText = await _storageService.getPendingDreamText();
      if (pendingText == null && mounted) {
        _pendingCheckTimer?.cancel();
        final targetId = _pendingDreamId;
        _pendingDreamId = null;
        await _loadHistory();
        // 按提交时记录的 id 精确匹配本次结果；后台解析失败时
        // pending 已清但记录不存在，绝不能拿历史旧梦顶替
        DreamRecord? matched;
        if (targetId != null) {
          for (final r in _history) {
            if (r.id == targetId) {
              matched = r;
              break;
            }
          }
        }
        if (matched != null) {
          final record = matched;
          setState(() {
            _isLoading = false;
            _resultMarkdown = record.analysis;
            _resultTitle = record.title;
            _dreamText = record.dreamText;
          });
          _scrollToResult();
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = '梦境分析暂时遇到问题，请检查网络或API配置后重试';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _pendingCheckTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitDream() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final recordId = md5.convert(utf8.encode('$text${DateTime.now().millisecondsSinceEpoch}')).toString();
    _pendingDreamId = recordId;

    // 持久化进行中状态，确保退出页面再进入时能恢复
    await _storageService.setPendingDream(recordId, text);

    setState(() {
      _isLoading = true;
      _dreamText = text;
      _resultMarkdown = null;
      _resultTitle = null;
      _errorMessage = null;
    });
    _textController.clear();

    final result = await _llmService.analyzeDream(text);

    if (result != null) {
      final title = result['title'] ?? '梦境解读';
      final analysis = result['analysis'] ?? '';
      if (analysis.isNotEmpty) {
        final record = DreamRecord(
          id: recordId,
          dreamText: text,
          analysis: analysis,
          title: title,
          createdAt: DateTime.now(),
        );
        await _storageService.saveDreamRecord(record);
      }
    }

    // 无论成功失败都清除进行中标记
    await _storageService.clearPendingDream();
    _pendingDreamId = null;
    _pendingCheckTimer?.cancel();

    if (!mounted) return;

    await _loadHistory();

    if (result != null) {
      final analysis = result['analysis'] ?? '';
      if (analysis.isNotEmpty) {
        setState(() {
          _isLoading = false;
          _resultMarkdown = analysis;
          _resultTitle = result['title'] ?? '梦境解读';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '梦境分析暂时遇到问题，请检查网络或API配置后重试';
        });
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = '梦境分析暂时遇到问题，请检查网络或API配置后重试';
      });
    }

    _scrollToResult();
  }

  void _scrollToResult() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearInput() {
    setState(() {
      _resultMarkdown = null;
      _resultTitle = null;
      _errorMessage = null;
      _dreamText = '';
      _textController.clear();
    });
  }

  void _viewHistoryItem(DreamRecord record) {
    setState(() {
      _resultMarkdown = record.analysis;
      _resultTitle = record.title;
      _dreamText = record.dreamText;
      _errorMessage = null;
    });
  }

  Future<void> _deleteHistoryItem(String id) async {
    final wasViewing = _history.any((r) => r.id == id && r.analysis == _resultMarkdown);
    await _storageService.deleteDreamRecord(id);
    await _loadHistory();
    if (wasViewing && mounted) {
      _clearInput();
    }
  }

  Future<void> _deleteAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除全部记录'),
        content: const Text('确定要删除所有梦境解读历史记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除全部'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _storageService.clearAllDreamRecords();
      await _loadHistory();
      _clearInput();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LowPolyBackground(
        tint: AppColors.dreamyLavender,
        tintAlpha: 0.06,
        tintAlphaDark: 0.15,
        child: SafeArea(
          child: AdaptiveContentWrapper(
            child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputArea(),
                      const SizedBox(height: 12),
                      if (_isLoading) _buildLoadingState(),
                      if (_errorMessage != null && !_isLoading) _buildErrorCard(),
                      if (_resultMarkdown != null && !_isLoading) _buildResultCard(),
                      const SizedBox(height: 24),
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

  Widget _buildSliverHeader() {
    return SliverAppBar(
      pinned: true,
      title: Text(
        'AI梦境解读',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
      ),
      centerTitle: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    );
  }

  Widget _buildInputArea() {
    final llmConfigured = _llmService.isConfigured();

    if (!llmConfigured) {
      return _buildConfigPromptCard();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dreamyLavender.withValues(alpha: 0.06),
        borderRadius: AppRadius.cardB,
        border: AppStroke.all(context),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.nightlight_round, size: 20, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 8),
              Text(
                '把梦说给我听',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
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
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: '描述你的梦境……\n比如：我梦到自己在飞，天空是紫色的，还有一只会说话的猫……',
              hintStyle: Theme.of(context).textTheme.bodySmall,
              filled: true,
              fillColor: Theme.of(context).cardColor.withValues(alpha: 0.6),
              contentPadding: const EdgeInsets.all(14),
            ),
            onSubmitted: (_) => _submitDream(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _submitDream,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('开始解读'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.dreamyLavender,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigPromptCard() {
    return AppCard(
      color: AppColors.dreamyLavender.withValues(alpha: 0.06),
      padding: const EdgeInsets.all(24),
      hardShadow: false,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.softOrange.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.settings_outlined, size: 32, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          Text(
            '请先配置大模型 API',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '梦境解读需要大模型服务支持，请先配置 API 后再使用',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              showUnifiedConfigDialog(context).then((_) {
                _llmService.reloadConfig();
                setState(() {});
              });
            },
            icon: const Icon(Icons.api, size: 18),
            label: const Text('去配置'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: const BorderSide(color: AppColors.softOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.dreamyLavender.withValues(alpha: 0.05),
        borderRadius: AppRadius.cardB,
      ),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.dreamyLavender.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '正在深入解读你的梦境……',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '梦是心灵的信使，让我们耐心聆听它的密语',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_outlined, size: 28, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Text(
              '梦境分析暂时遇到问题',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() => _errorMessage = null);
                _textController.text = _dreamText;
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                side: const BorderSide(color: AppColors.dreamyLavender),
              ),
              child: const Text('重新输入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dreamyLavender.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smB,
                  ),
                  child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.onSurface, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _resultTitle ?? '梦境解读',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                GestureDetector(
                  onTap: _clearInput,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.dreamyLavender.withValues(alpha: 0.08),
                      borderRadius: AppRadius.smB,
                    ),
                    child: Icon(Icons.add_comment_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 用户梦境引用
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.dreamyLavender.withValues(alpha: 0.08),
                    AppColors.dreamyLavender.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: AppRadius.smB,
                border: const Border(
                  left: BorderSide(color: AppColors.dreamyLavender, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_quote_rounded, size: 14, color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: 4),
                      Text(
                        '你的梦境',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dreamText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          height: 1.7,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Markdown 分析内容
            MarkdownBody(
              data: _resultMarkdown!,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                h1: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                h2: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.85,
                    ),
                strong: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                em: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
                listBulletPadding: const EdgeInsets.only(left: 4, right: 12, top: 4),
                blockquoteDecoration: BoxDecoration(
                  color: AppColors.dreamyLavender.withValues(alpha: 0.04),
                  borderRadius: AppRadius.smB,
                  border: const Border(
                    left: BorderSide(color: AppColors.dreamyLavender, width: 3),
                  ),
                ),
                blockquotePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                horizontalRuleDecoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.dreamyLavender.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                codeblockDecoration: BoxDecoration(
                  color: AppColors.dreamyLavender.withValues(alpha: 0.04),
                  borderRadius: AppRadius.smB,
                ),
              ),
            ),

            // 底部波浪装饰
            const SizedBox(height: 20),
            Center(
              child: Text(
                '~ ~ ~',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
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

  Widget _buildHistorySection() {
    if (_history.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHistoryTitle(),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.4),
              borderRadius: AppRadius.mdB,
            ),
            child: Column(
              children: [
                Icon(Icons.nightlight_outlined, size: 36, color: Theme.of(context).colorScheme.onSurface),
                const SizedBox(height: 12),
                Text(
                  '还没有解读过梦境',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '写下你的第一个梦，让潜意识的密语被温柔聆听',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHistoryTitle(),
        const SizedBox(height: 12),
        ..._history.map((record) => _buildHistoryCard(record)),
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
            color: AppColors.dreamyLavender.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '历史记录',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(width: 8),
        Text(
          '${_history.length}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        if (_history.isNotEmpty)
          GestureDetector(
            onTap: _deleteAllHistory,
            child: Text(
              '删除全部',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryCard(DreamRecord record) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _viewHistoryItem(record),
        child: AppCard(
          padding: const EdgeInsets.all(14),
          radius: AppRadius.sm,
          hardShadow: false,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.dreamyLavender.withValues(alpha: 0.08),
                  borderRadius: AppRadius.smB,
                ),
                child: Icon(Icons.nightlight_round, size: 18, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.dreamText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDate(record.createdAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                        ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _deleteHistoryItem(record.id),
                    child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
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
}
