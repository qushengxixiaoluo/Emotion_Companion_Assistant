import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../app/themes/app_colors.dart';
import '../../app/responsive/responsive_utils.dart';
import '../../app/config/speech_config.dart';
import '../../services/emotion_service.dart';
import '../../services/llm_service.dart';
import '../../services/function_tools.dart';
import '../../services/ai_comfort_service.dart';
import '../../services/agents/orchestrator.dart';
import '../../services/speech_service.dart';
import '../../services/storage_service.dart';
import '../../models/emotion_models.dart';
import '../../widgets/unified_config_dialog.dart';
import '../../widgets/speech_params_dialog.dart';

class ComfortPage extends StatefulWidget {
  const ComfortPage({super.key});

  @override
  State<ComfortPage> createState() => ComfortPageState();
}

class ComfortPageState extends State<ComfortPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final EmotionService _emotionService = EmotionService();
  final LlmService _llmService = LlmService();
  final AiComfortService _fallbackService = AiComfortService();
  final StorageService _storageService = StorageService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<_ChatBubble> _messages = [];
  String _currentEmotion = '平静';
  bool _isLoading = false;
  bool _useLlm = true;
  bool _useStream = true;
  bool _useMultiAgent = false;
  final AgentOrchestrator _orchestrator = AgentOrchestrator();
  Timer? _typeTimer;
  Timer? _streamDisplayTimer;
  Timer? _cursorBlinkTimer;
  String _streamBuffer = '';
  int _streamDisplayPos = 0;
  bool _streamEnded = false;
  bool _cursorVisible = true;

  // 语音服务 (豆包 TTS)
  final SpeechService _speechService = SpeechService();
  final AudioPlayer _ttsPlayer = AudioPlayer();
  String? _playingMessageIndex;
  String? _ttsVoiceType;

  // 对话管理
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  bool _titleGenerated = false;
  bool _showConversationPanel = false;

  /// Toggle the conversation panel visibility (used for desktop screenshots).
  void toggleConversationPanel() {
    setState(() => _showConversationPanel = !_showConversationPanel);
  }

  @override
  void initState() {
    super.initState();
    _speechService.reloadTtsConfig();
    _loadConversations();
    _loadVoicePreference();
    // 如果 LLM 未配置，强制使用本地模式
    if (!_llmService.isConfigured()) {
      _useLlm = false;
    }
  }

  Future<void> _loadVoicePreference() async {
    final voice = await _storageService.getTtsVoiceType();
    if (mounted) setState(() => _ttsVoiceType = voice);
  }

  String get _ttsVoiceDisplayName {
    if (_speechService.provider == SpeechConfig.providerSystem) {
      if (_ttsVoiceType != null && _ttsVoiceType!.contains('|')) {
        return _ttsVoiceType!.split('|').first;
      }
      return _ttsVoiceType ?? '系统默认语音';
    }
    return SpeechConfig.voiceTypeLabels[_ttsVoiceType ?? ''] ?? _ttsVoiceType ?? '选择音色';
  }

  List<Map<String, String>> get _availableVoices {
    if (_speechService.provider == SpeechConfig.providerSystem) {
      return _speechService.systemVoices;
    }
    return SpeechConfig.voiceTypeLabels.entries.map((e) => {'name': e.key, 'locale': e.value}).toList();
  }

  Future<void> _loadConversations() async {
    _conversations = await _storageService.getAllConversations();
    final activeId = await _storageService.getActiveConversationId();
    if (activeId != null) {
      _currentConversation = _conversations.where((c) => c.id == activeId).firstOrNull;
      if (_currentConversation != null) {
        _restoreMessages();
        _titleGenerated = _currentConversation!.title != '新对话';
        if (mounted) setState(() {});
        return;
      }
    }
    // 没有活跃对话或找不到，取最近一个
    if (_conversations.isNotEmpty) {
      _currentConversation = _conversations.first;
      _restoreMessages();
      _titleGenerated = _currentConversation!.title != '新对话';
    } else {
      _addWelcomeMessage();
    }
    if (mounted) setState(() {});
  }

  void _restoreMessages() {
    _messages.clear();
    final historyList = <Map<String, String>>[];
    for (final msg in _currentConversation!.messages) {
      _messages.add(_ChatBubble(
        content: msg.content,
        isUser: msg.isUser,
        emotion: msg.emotion,
      ));
      historyList.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.content,
      });
    }
    _llmService.loadHistory(historyList);
    if (_messages.isEmpty) {
      _addWelcomeMessage();
    }
  }

  void _addWelcomeMessage() {
    _messages.add(_ChatBubble(
      content: '你好呀，我是你的暖心陪伴师。无论开心还是难过，我都在这里陪你。想说什么都可以告诉我。',
      isUser: false,
      emotion: '平静',
    ));
  }

  ChatMessage _bubbleToMessage(_ChatBubble bubble) {
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: bubble.content,
      isUser: bubble.isUser,
      createdAt: DateTime.now(),
      emotion: bubble.emotion,
    );
  }

  Future<void> _saveCurrentConversation() async {
    final now = DateTime.now();
    if (_currentConversation == null) {
      _currentConversation = Conversation(
        id: now.microsecondsSinceEpoch.toString(),
        createdAt: now,
        updatedAt: now,
      );
      _conversations.insert(0, _currentConversation!);
    }
    _currentConversation!.updatedAt = now;
    // 过滤掉欢迎语（不保存到持久化）
    _currentConversation!.messages = _messages
        .where((b) => b.content != '你好呀，我是你的暖心陪伴师。无论开心还是难过，我都在这里陪你。想说什么都可以告诉我。')
        .map(_bubbleToMessage)
        .toList();
    await _storageService.saveConversation(_currentConversation!);
    await _storageService.setActiveConversationId(_currentConversation!.id);
  }

  PopupMenuEntry<String> _buildMenuSectionHeader(String title) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 28,
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textHint.withValues(alpha: 0.45),
          letterSpacing: 0.8,
          height: 1,
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildSettingItem({
    required String value,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.2),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: AppColors.textHint.withValues(alpha: 0.7), height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _maybeGenerateTitle() async {
    if (_titleGenerated) return;
    _titleGenerated = true;
    // 找到第一个用户消息和第一个AI回复
    final userMsgs = _messages.where((b) => b.isUser).toList();
    final aiMsgs = _messages.where((b) => !b.isUser && !b.isError && b.content.isNotEmpty && b.content != '你好呀，我是你的暖心陪伴师。无论开心还是难过，我都在这里陪你。想说什么都可以告诉我。').toList();
    if (userMsgs.isEmpty || aiMsgs.isEmpty) return;
    final title = await _llmService.generateTitle(userMsgs.first.content, aiMsgs.first.content);
    if (mounted && _currentConversation != null) {
      _currentConversation!.title = title;
      await _saveCurrentConversation();
      // 更新对话列表
      _conversations = await _storageService.getAllConversations();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _streamDisplayTimer?.cancel();
    _cursorBlinkTimer?.cancel();
    _ttsPlayer.dispose();
    _speechService.dispose();
    _saveCurrentConversation(); // fire-and-forget
    super.dispose();
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final record = _emotionService.analyze(text);
    setState(() {
      _currentEmotion = record.dominantEmotion;
      _messages.add(_ChatBubble(content: text, isUser: true, emotion: record.dominantEmotion));
      _isLoading = true;
      _messages.add(_ChatBubble(content: '', isUser: false, emotion: _currentEmotion, isStreaming: true));
    });

    _textController.clear();
    _scrollToBottom();

    if (_useLlm) {
      if (_useStream) {
        // ===== 流式模式：HTTP SSE 接收 + 字词块逐块显示，模拟人类打字 =====
        _streamBuffer = '';
        _streamDisplayPos = 0;
        _streamEnded = false;
        _cursorVisible = true;
        _streamDisplayTimer?.cancel();
        _cursorBlinkTimer?.cancel();

        // 光标闪烁定时器
        _cursorBlinkTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
          if (!mounted) { _cursorBlinkTimer?.cancel(); return; }
          setState(() => _cursorVisible = !_cursorVisible);
        });

        // 启动定时器，按字词块节奏显示已缓冲的文本
        _streamDisplayTimer = Timer.periodic(const Duration(milliseconds: 45), (_) {
          if (!mounted) { _streamDisplayTimer?.cancel(); return; }
          if (_streamDisplayPos < _streamBuffer.length) {
            final chunkSize = _nextChunkSize(_streamBuffer, _streamDisplayPos);
            _streamDisplayPos += chunkSize;
          }
          final cursor = _cursorVisible ? '▌' : '';
          setState(() {
            _messages.last.content = _streamBuffer.substring(0, _streamDisplayPos) + cursor;
            _messages.last.isStreaming = _streamBuffer.isEmpty;
          });
          if (_streamDisplayPos > 0) _scrollToBottom();
          if (_streamEnded && _streamDisplayPos >= _streamBuffer.length) {
            _streamDisplayTimer?.cancel();
            _cursorBlinkTimer?.cancel();
            setState(() {
              _messages.last.content = _streamBuffer;
              _messages.last.isStreaming = false;
            });
            _saveCurrentConversation().then((_) => _maybeGenerateTitle());
          }
        });

        try {
          final stream = _useMultiAgent
              ? _orchestrator.processStream(text)
              : _llmService.chatStream(text, tools: FunctionTools.toolDefinitions);
          await for (final delta in stream) {
            if (!mounted) break;
            _streamBuffer += delta;
          }
          _streamEnded = true;
          // 流式返回了空内容（API可能不支持流式），降级到非流式
          if (_streamBuffer.isEmpty && mounted) {
            _streamDisplayTimer?.cancel();
            _cursorBlinkTimer?.cancel();
            _messages.removeLast();
            _messages.add(_ChatBubble(content: '', isUser: false, emotion: _currentEmotion, isStreaming: true));
            final response = _useMultiAgent
                ? await _orchestrator.process(text)
                : await _llmService.chat(text, tools: FunctionTools.toolDefinitions);
            if (mounted) {
              if (response.contains('失败') || response.contains('错误') || response.contains('异常') || response.contains('无法回复')) {
                _messages.removeLast();
                _messages.add(_ChatBubble(
                  content: '$response\n\n【已自动切换到本地模式回复】\n${_fallbackService.chat(text, _currentEmotion)}',
                  isUser: false, emotion: _currentEmotion, isError: true,
                ));
                _saveCurrentConversation();
              } else {
                _typewriterEffect(response);
              }
            }
          }
        } catch (e) {
          _streamDisplayTimer?.cancel();
          _cursorBlinkTimer?.cancel();
          // 流式失败，自动降级到非流式请求
          if (mounted) {
            _messages.removeLast();
            _messages.add(_ChatBubble(content: '', isUser: false, emotion: _currentEmotion, isStreaming: true));
            final response = _useMultiAgent
                ? await _orchestrator.process(text)
                : await _llmService.chat(text, tools: FunctionTools.toolDefinitions);
            if (mounted) {
              if (response.contains('失败') || response.contains('错误') || response.contains('异常') || response.contains('无法回复')) {
                _messages.removeLast();
                _messages.add(_ChatBubble(
                  content: '$response\n\n【已自动切换到本地模式回复】\n${_fallbackService.chat(text, _currentEmotion)}',
                  isUser: false, emotion: _currentEmotion, isError: true,
                ));
                _saveCurrentConversation();
              } else {
                _typewriterEffect(response);
              }
            }
          }
        }
      } else {
        // ===== 非流式模式：先请求，再打字机逐字显示 =====
        final response = _useMultiAgent
            ? await _orchestrator.process(text)
            : await _llmService.chat(text, tools: FunctionTools.toolDefinitions);
        if (mounted) {
          if (response.contains('失败') ||
              response.contains('错误') ||
              response.contains('异常') ||
              response.contains('无法回复')) {
            setState(() {
              _messages.removeLast();
              _messages.add(_ChatBubble(
                content: '$response\n\n【已自动切换到本地模式回复】\n${_fallbackService.chat(text, _currentEmotion)}',
                isUser: false,
                emotion: _currentEmotion,
                isError: true,
              ));
            });
            _saveCurrentConversation();
          } else {
            // 打字机效果逐字显示
            _typewriterEffect(response);
          }
        }
      }
    } else {
      // 本地预设话术模式：也做打字机效果
      await Future.delayed(const Duration(milliseconds: 300));
      final response = _fallbackService.chat(text, _currentEmotion);
      if (mounted) _typewriterEffect(response);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (_messages.isNotEmpty) _messages.last.isStreaming = false;
      });
    }
  }

  /// 计算下一块显示的字数，模拟人类逐词/逐句打字的节奏
  int _nextChunkSize(String text, int pos) {
    if (pos >= text.length) return 0;
    int size = 0;
    while (pos + size < text.length) {
      final char = text[pos + size];
      size++;
      // 遇到标点或换行，连标点一起显示后停止
      if ('，。！？；：、…\n'.contains(char)) break;
      // 普通字词每次显示1-2个字
      if (size >= 2) break;
    }
    return size;
  }

  /// 打字机效果：逐字显示文本
  void _typewriterEffect(String fullText) {
    int index = 0;
    _typeTimer?.cancel();

    _typeTimer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (index <= fullText.length) {
        setState(() {
          _messages.last.content = fullText.substring(0, index);
        });
        index++;
        _scrollToBottom();
      } else {
        timer.cancel();
        setState(() {
          _messages.last.isStreaming = false;
        });
        _saveCurrentConversation().then((_) => _maybeGenerateTitle());
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 30), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 朗读AI消息
  Future<void> _speakMessage(int index, String text) async {
    if (_playingMessageIndex == '$index') {
      await _speechService.stop();
      await _ttsPlayer.stop();
      setState(() => _playingMessageIndex = null);
      return;
    }

    await _ttsPlayer.stop();
    await _speechService.stop();

    // 去除 Markdown 符号
    var plainText = text
        .replaceAll(RegExp(r'[#*>`~_\[\]|]'), '')
        .replaceAll(RegExp(r'\n{2,}'), '。')
        .replaceAll('\n', '。')
        .replaceAll('---', '。')
        .trim();

    if (plainText.isEmpty) return;

    setState(() => _playingMessageIndex = '$index');

    if (_speechService.provider == SpeechConfig.providerSystem) {
      // 系统 TTS：直接朗读
      final success = await _speechService.speak(plainText);
      if (mounted) {
        if (!success) {
          setState(() => _playingMessageIndex = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('系统语音合成失败'),
              backgroundColor: AppColors.softOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        // 系统 TTS 通过回调通知完成
        _speechService.setOnComplete(() {
          if (mounted) setState(() => _playingMessageIndex = null);
        });
      }
    } else {
      // API TTS：合成音频，使用内存字节播放
      final audioBytes = await _speechService.synthesizeToBytes(plainText);
      if (audioBytes != null && mounted) {
        await _ttsPlayer.play(BytesSource(audioBytes));
        _ttsPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _playingMessageIndex = null);
        });
      } else {
        if (mounted) {
          setState(() => _playingMessageIndex = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('语音合成失败，请检查API配置'),
              backgroundColor: AppColors.softOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  // ============================================================
  // UI 构建
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (ResponsiveUtils.isDesktop(context)) {
      return _buildDesktopChatLayout();
    }
    return _buildMobileChatLayout();
  }

  Widget _buildMobileChatLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [AppColors.softPink.withValues(alpha: 0.06), AppColors.darkBackground]
        : [AppColors.softPink.withValues(alpha: 0.04), AppColors.background];

    final showWelcomeCard = _messages.isEmpty;

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: Column(
          children: [
            _buildEmotionStatusBar(),
            Expanded(
              child: showWelcomeCard
                  ? _buildWelcomeCard()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final showDivider = index > 0 &&
                            _messages[index].isUser != _messages[index - 1].isUser;
                        return Column(
                          children: [
                            if (showDivider) _buildMessageGroupDivider(),
                            _buildMessage(_messages[index], index),
                          ],
                        );
                      },
                    ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
      endDrawer: _buildEndDrawer(),
    );
  }

  Widget _buildDesktopChatLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [AppColors.softPink.withValues(alpha: 0.06), AppColors.darkBackground]
        : [AppColors.softPink.withValues(alpha: 0.04), AppColors.background];

    final showWelcomeCard = _messages.isEmpty;

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(
        onMenuTap: () => setState(() => _showConversationPanel = !_showConversationPanel),
      ),
      body: Row(
        children: [
          if (_showConversationPanel) ...[
            Container(
              width: 280,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: AppColors.hazeBlue.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
              ),
              child: _buildConversationPanel(),
            ),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradientColors,
                ),
              ),
              child: Column(
                children: [
                  _buildEmotionStatusBar(),
                  Expanded(
                    child: showWelcomeCard
                        ? _buildWelcomeCard()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final showDivider = index > 0 &&
                                  _messages[index].isUser != _messages[index - 1].isUser;
                              return Column(
                                children: [
                                  if (showDivider) _buildMessageGroupDivider(),
                                  _buildMessage(_messages[index], index),
                                ],
                              );
                            },
                          ),
                  ),
                  _buildInputArea(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({bool showMenuButton = true, VoidCallback? onMenuTap}) {
    final hasEmotion = _currentEmotion != '平静';
    final themeColor = hasEmotion ? AppColors.softPink : AppColors.hazeBlue;

    return AppBar(
      leading: showMenuButton
          ? Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: Icon(_showConversationPanel ? Icons.menu_open : Icons.menu, size: 20, color: themeColor),
                onPressed: onMenuTap ?? () => _scaffoldKey.currentState?.openEndDrawer(),
                tooltip: '对话记录',
              ),
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _currentConversation?.title ?? 'AI暖心安慰',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            _useLlm ? '大模型${_useStream ? " · 实时流式" : " · 打字机"}' : '本地模式 · 打字机',
            style: TextStyle(
              fontSize: 11,
              color: themeColor.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
      actions: [
        _buildThemedActionButton(Icons.self_improvement, '深呼吸引导', _showBreathGuide),
        _buildThemedActionButton(Icons.nightlight_outlined, '晚安语录', _showGoodnight),
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: PopupMenuButton<String>(
            tooltip: '显示菜单',
            offset: const Offset(0, 48),
            elevation: 12,
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              Icons.settings_outlined,
              size: 18,
              color: themeColor,
            ),
            onSelected: _onPopupMenuSelected,
            itemBuilder: (context) => [
              _buildMenuSectionHeader('对话模式'),
              _buildSettingItem(
                value: 'toggle_llm',
                icon: _useLlm ? Icons.cloud_outlined : Icons.psychology_outlined,
                color: AppColors.hazeBlue,
                title: _useLlm ? '大模型模式' : '本地预设模式',
                subtitle: _useLlm ? '点击切换到本地' : '点击切换到大模型',
              ),
              _buildSettingItem(
                value: 'toggle_stream',
                icon: _useStream ? Icons.bolt : Icons.text_snippet_outlined,
                color: AppColors.calmGreen,
                title: _useStream ? '实时流式输出' : '打字机模式',
                subtitle: _useStream ? '点击切换打字机' : '点击切换流式',
              ),
              const PopupMenuDivider(height: 1),
              _buildMenuSectionHeader('语音设置'),
              _buildSettingItem(
                value: 'voice',
                icon: Icons.record_voice_over,
                color: AppColors.gentlePurple,
                title: '朗读音色',
                subtitle: _ttsVoiceDisplayName,
              ),
              _buildSettingItem(
                value: 'speech_params',
                icon: Icons.tune,
                color: AppColors.softOrange,
                title: '语音参数',
                subtitle: '语速与音量调节',
              ),
              const PopupMenuDivider(height: 1),
              _buildMenuSectionHeader('更多'),
              _buildSettingItem(
                value: 'api_config',
                icon: Icons.api,
                color: AppColors.hazeBlue,
                title: 'API 配置',
                subtitle: '大模型 & 语音合成',
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onPopupMenuSelected(String value) {
    if (value == 'toggle_llm') {
      if (!_useLlm && !_llmService.isConfigured()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('请先配置大模型 API 后再切换'),
            backgroundColor: AppColors.softOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: '去配置',
              textColor: Colors.white,
              onPressed: () {
                showUnifiedConfigDialog(context).then((_) async {
                  _llmService.reloadConfig();
                  _speechService.reloadTtsConfig();
                  await _loadVoicePreference();
                  if (_llmService.isConfigured()) {
                    setState(() => _useLlm = true);
                  }
                });
              },
            ),
          ),
        );
        return;
      }
      setState(() => _useLlm = !_useLlm);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_useLlm ? '已切换到大模型模式' : '已切换到本地预设模式'),
          backgroundColor: AppColors.hazeBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (value == 'toggle_stream') {
      setState(() => _useStream = !_useStream);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_useStream ? '已开启流式输出（API实时推送）' : '已关闭流式（打字机效果）'),
          backgroundColor: AppColors.hazeBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (value == 'voice') {
      _showVoicePicker();
    } else if (value == 'api_config') {
      showUnifiedConfigDialog(context).then((_) async {
        _llmService.reloadConfig();
        _speechService.reloadTtsConfig();
        await _loadVoicePreference();
        setState(() {
          if (!_llmService.isConfigured()) {
            _useLlm = false;
          }
        });
      });
    } else if (value == 'speech_params') {
      showSpeechParamsDialog(context).then((_) => _speechService.reloadTtsConfig());
    }
  }

  Widget _buildThemedActionButton(IconData icon, String tooltip, VoidCallback onPressed) {
    final hasEmotion = _currentEmotion != '平静';
    final themeColor = hasEmotion ? AppColors.softPink : AppColors.hazeBlue;

    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: themeColor),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildEmotionStatusBar() {
    final hasEmotion = _currentEmotion != '平静';
    final color = hasEmotion ? AppColors.softPink : AppColors.hazeBlue;
    final llmConfigured = _llmService.isConfigured();
    final showConfigBanner = !llmConfigured;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: color.withValues(alpha: 0.35), width: 3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasEmotion ? Icons.favorite_outline : Icons.cloud_outlined,
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasEmotion
                      ? '我感受到你现在有些$_currentEmotion'
                      : (_useLlm
                          ? '大模型模式${_useStream ? " · 实时流式" : " · 打字机"} · 随时倾诉'
                          : '本地模式 · 打字机 · 随时倾诉'),
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showConfigBanner && !hasEmotion)
          GestureDetector(
            onTap: () {
              showUnifiedConfigDialog(context).then((_) async {
                _llmService.reloadConfig();
                _speechService.reloadTtsConfig();
                await _loadVoicePreference();
                if (_llmService.isConfigured()) {
                  setState(() => _useLlm = true);
                } else {
                  setState(() => _useLlm = false);
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.softOrange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.softOrange.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, size: 14, color: AppColors.softOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请配置大模型服务以使用 AI 对话功能',
                      style: TextStyle(fontSize: 12, color: AppColors.softOrange.withValues(alpha: 0.8)),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: AppColors.softOrange.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.softPink.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.softPink.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 大图标
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.softPink.withValues(alpha: 0.25),
                      AppColors.softPink.withValues(alpha: 0.08),
                    ],
                  ),
                ),
                child: const Icon(Icons.favorite_outline, size: 40, color: AppColors.softPink),
              ),
              const SizedBox(height: 28),
              // 诗意欢迎文字
              Text(
                '你好呀',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.softPink,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                '我是你的暖心陪伴师',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 6),
              Text(
                '无论开心还是难过，我都在这里陪你',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.softPink.withValues(alpha: 0.55),
                    ),
              ),
              const SizedBox(height: 20),
              // 装饰性分割线
              Text(
                '~ ~ ~',
                style: TextStyle(
                  color: AppColors.softPink.withValues(alpha: 0.18),
                  fontSize: 16,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '想说什么都可以告诉我',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.hazeBlue.withValues(alpha: 0.45),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageGroupDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Center(
        child: Text(
          '·',
          style: TextStyle(
            color: AppColors.softPink.withValues(alpha: 0.18),
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(_ChatBubble msg, int index) {
    if (msg.isUser) {
      return _buildUserMessage(msg);
    }
    return _buildAiMessage(msg, index);
  }

  Widget _buildUserMessage(_ChatBubble msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.hazeBlue.withValues(alpha: 0.25)
                    : AppColors.hazeBlue.withValues(alpha: 0.13),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(
                  color: AppColors.hazeBlue.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Text(
                msg.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiMessage(_ChatBubble msg, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI 头像 - 渐变圆形
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.softPink, AppColors.hazeBlue],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.softPink.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: msg.isError
                    ? AppColors.softPink.withValues(alpha: 0.1)
                    : Theme.of(context).cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                border: Border(
                  left: BorderSide(
                    color: msg.isError
                        ? AppColors.softPink.withValues(alpha: 0.7)
                        : AppColors.softPink.withValues(alpha: 0.45),
                    width: 3,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.content.isEmpty)
                    Text('……', style: Theme.of(context).textTheme.bodyMedium)
                  else if (msg.isStreaming)
                    Text(
                      msg.content,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
                    )
                  else
                    MarkdownBody(
                      data: msg.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.7,
                              color: msg.isError ? AppColors.softPink : null,
                            ),
                        h1: Theme.of(context).textTheme.titleLarge,
                        h2: Theme.of(context).textTheme.titleMedium,
                        h3: Theme.of(context).textTheme.titleSmall,
                        strong: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        em: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                        code: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          backgroundColor: AppColors.hazeBlue.withValues(alpha: 0.1),
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: AppColors.hazeBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider, width: 0.5),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: AppColors.softPink.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: AppColors.softPink.withValues(alpha: 0.35),
                              width: 3,
                            ),
                          ),
                        ),
                        horizontalRuleDecoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: AppColors.softPink.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                        ),
                        listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.7,
                            ),
                        tableHead: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        tableBody: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  // AI消息朗读按钮（非流式、非空）
                  if (!msg.isStreaming && msg.content.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _isLoading ? null : () => _speakMessage(index, msg.content),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _playingMessageIndex == '$index'
                                  ? AppColors.softPink.withValues(alpha: 0.15)
                                  : AppColors.textHint.withValues(alpha: 0.08),
                              border: _playingMessageIndex == '$index'
                                  ? Border.all(
                                      color: AppColors.softPink.withValues(alpha: 0.3),
                                    )
                                  : null,
                            ),
                            child: Icon(
                              _playingMessageIndex == '$index'
                                  ? Icons.volume_up
                                  : Icons.volume_up_outlined,
                              size: 16,
                              color: _playingMessageIndex == '$index'
                                  ? AppColors.softPink
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        if (_playingMessageIndex == '$index') ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.softPink.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (msg.isStreaming) ...[
                    const SizedBox(height: 6),
                    _buildTypingIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.softPink.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '正在思考中',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: AppColors.softPink.withValues(alpha: 0.5),
              ),
        ),
      ],
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: AppColors.softPink.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.softPink.withValues(alpha: 0.15),
                  ),
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: _isLoading ? 'AI正在思考……' : '说说你的心事……',
                    hintStyle: Theme.of(context).textTheme.bodySmall,
                    filled: true,
                    fillColor: isDark ? AppColors.darkInputFill : AppColors.milkWhite,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: AppColors.softPink.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: FilledButton(
                onPressed: _isLoading ? null : _sendMessage,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.softPink,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.softPink.withValues(alpha: 0.3),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 侧边抽屉 / 桌面端对话列表面板
  // ============================================================

  Widget _buildEndDrawer() {
    return Drawer(
      width: 280,
      child: SafeArea(
        child: _buildConversationPanel(),
      ),
    );
  }

  Widget _buildConversationPanel() {
    return Column(
      children: [
        // 标题栏
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
              child: Row(
                children: [
                  // 左侧强调条
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.softPink.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '对话记录',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  // 数量标签
                  if (_conversations.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.softPink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_conversations.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.softPink.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // 新建按钮
                  GestureDetector(
                    onTap: _newConversation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.softPink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 16, color: AppColors.softPink),
                          const SizedBox(width: 4),
                          Text(
                            '新建',
                            style: TextStyle(fontSize: 13, color: AppColors.softPink),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 对话列表 或 空状态
            Expanded(
              child: _conversations.isEmpty
                  ? _buildDrawerEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final conv = _conversations[index];
                        final isActive = _currentConversation?.id == conv.id;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.softPink.withValues(alpha: 0.06)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            selected: isActive,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            title: Text(
                              conv.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                color: isActive ? AppColors.softPink : null,
                              ),
                            ),
                            subtitle: Text(
                              '${conv.messages.length} 条消息 · ${conv.updatedAt.month}月${conv.updatedAt.day}日',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.3),
                              ),
                              onPressed: () => _deleteConversation(conv),
                            ),
                            onTap: () => _switchConversation(conv),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
  }

  Widget _buildDrawerEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 44,
              color: AppColors.softPink.withValues(alpha: 0.22),
            ),
            const SizedBox(height: 16),
            Text(
              '还没有对话记录',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              '开始倾诉，每一段心语都会被温柔珍藏',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: AppColors.softPink.withValues(alpha: 0.4),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 对话管理方法
  // ============================================================

  Future<void> _newConversation() async {
    // 保存当前对话（如果有内容）
    if (_currentConversation != null) {
      await _saveCurrentConversation();
    }
    _llmService.clearHistory();
    _currentConversation = null;
    _titleGenerated = false;
    _messages.clear();
    _addWelcomeMessage();
    await _storageService.setActiveConversationId(null);
    _showConversationPanel = false;
    setState(() {});
  }

  Future<void> _switchConversation(Conversation conv) async {
    if (_currentConversation?.id == conv.id) {
      _scaffoldKey.currentState?.closeEndDrawer();
      _showConversationPanel = false;
      return;
    }
    await _saveCurrentConversation();
    _llmService.clearHistory();
    _currentConversation = conv;
    _titleGenerated = conv.title != '新对话';
    _restoreMessages();
    await _storageService.setActiveConversationId(conv.id);
    _scaffoldKey.currentState?.closeEndDrawer();
    _showConversationPanel = false;
    setState(() {});
  }

  Future<void> _deleteConversation(Conversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.softPink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, size: 18, color: AppColors.softPink),
            ),
            const SizedBox(width: 8),
            const Text('删除对话'),
          ],
        ),
        content: Text('确定要删除「${conv.title}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: AppColors.softPink)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storageService.deleteConversation(conv.id);
    if (_currentConversation?.id == conv.id) {
      _currentConversation = null;
      _llmService.clearHistory();
      _messages.clear();
      _addWelcomeMessage();
      _titleGenerated = false;
    }
    _conversations = await _storageService.getAllConversations();
    if (_currentConversation == null && _conversations.isNotEmpty) {
      _currentConversation = _conversations.first;
      _restoreMessages();
      _titleGenerated = _currentConversation!.title != '新对话';
      await _storageService.setActiveConversationId(_currentConversation!.id);
    } else if (_currentConversation == null) {
      await _storageService.setActiveConversationId(null);
    }
    setState(() {});
  }

  void _showVoicePicker() {
    final isSystem = _speechService.provider == SpeechConfig.providerSystem;
    final voices = _availableVoices;

    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => SimpleDialog(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.softPink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.record_voice_over, size: 18, color: AppColors.softPink),
            ),
            const SizedBox(width: 8),
            Text(isSystem ? '选择系统语音' : '选择朗读音色'),
          ],
        ),
        children: voices.isNotEmpty
            ? voices.map((v) {
                final name = v['name'] ?? '';
                final locale = v['locale'] ?? '';
                final voiceId = '$name|$locale';
                final isSelected = voiceId == _ttsVoiceType;
                return RadioListTile<String>(
                  value: voiceId,
                  groupValue: _ttsVoiceType,
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AppColors.softPink : null,
                    ),
                  ),
                  subtitle: locale.isNotEmpty ? Text(locale, style: const TextStyle(fontSize: 11)) : null,
                  activeColor: AppColors.softPink,
                  onChanged: (val) async {
                    if (val != null && val != _ttsVoiceType) {
                      if (isSystem) {
                        await _speechService.setSystemVoice(name);
                      } else {
                        await _storageService.setTtsVoiceType(name);
                      }
                      setState(() => _ttsVoiceType = val);
                      if (mounted) Navigator.pop(ctx);
                    }
                  },
                );
              }).toList()
            : [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, size: 32, color: AppColors.textHint.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                        isSystem ? '未检测到系统语音' : '无可用音色',
                        style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
              ],
      ),
    );
  }

  void _showBreathGuide() {
    int step = 0;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.softPink.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.self_improvement, color: AppColors.softPink, size: 18),
              ),
              const SizedBox(width: 8),
              const Text('深呼吸引导'),
            ],
          ),
          content: SizedBox(
            height: 260,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 渐变圆环装饰
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.softPink.withValues(alpha: 0.15),
                        AppColors.softPink.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.softPink.withValues(alpha: 0.25),
                            AppColors.softPink.withValues(alpha: 0.08),
                          ],
                        ),
                      ),
                      child: const Icon(Icons.air, color: AppColors.softPink, size: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _fallbackService.getBreathGuide(step),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
            TextButton(
              onPressed: () => setDialogState(() => step++),
              child: Text('下一步', style: TextStyle(color: AppColors.softPink)),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoodnight() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.gentlePurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.nightlight, color: AppColors.gentlePurple, size: 18),
            ),
            const SizedBox(width: 8),
            const Text('晚安'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 装饰元素
            Center(
              child: Icon(
                Icons.nightlight_round,
                size: 32,
                color: AppColors.gentlePurple.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _fallbackService.getGoodnightWord(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.8),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // 装饰性分割线
            Center(
              child: Text(
                '~ ~ ~',
                style: TextStyle(
                  color: AppColors.gentlePurple.withValues(alpha: 0.18),
                  fontSize: 14,
                  letterSpacing: 6,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('晚安', style: TextStyle(color: AppColors.gentlePurple)),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble {
  String content;
  final bool isUser;
  final String emotion;
  bool isStreaming;
  bool isError;

  _ChatBubble({
    required this.content,
    required this.isUser,
    required this.emotion,
    this.isStreaming = false,
    this.isError = false,
  });
}
