import 'dart:developer' as developer;
import '../../models/emotion_models.dart';
import '../emotion_service.dart';
import '../memory_service.dart';
import 'retrieval_agent.dart';
import 'response_agent.dart';

/// 多Agent协作 Orchestrator
class AgentOrchestrator {
  static final AgentOrchestrator _instance = AgentOrchestrator._();
  factory AgentOrchestrator() => _instance;
  AgentOrchestrator._();

  final RetrievalAgent _retrievalAgent = RetrievalAgent();
  final ResponseAgent _responseAgent = ResponseAgent();
  final MemoryService _memoryService = MemoryService();
  final EmotionService _localEmotion = EmotionService();

  /// 聊天路径的本地情绪分析（毫秒级）。
  /// 原先此处 await 3 轮**串行 LLM** 深度情绪分析，每条消息在回复开始前
  /// 多等 2~6 秒，而该结果只影响失败兜底话术的情绪选择（气泡情绪本就走
  /// 本地分析）。树洞记录的 AI 深度分析是独立链路，不受影响。
  Map<String, dynamic> _emotionOf(String text) {
    final r = _localEmotion.analyze(text);
    return {
      'sadness': r.sadness,
      'anxiety': r.anxiety,
      'anger': r.anger,
      'loneliness': r.loneliness,
      'happiness': r.happiness,
      'calmness': r.calmness,
      'suppression': r.suppression,
      'dominantEmotion': r.dominantEmotion,
      'interpretation': '',
      'suggestions': <String>[],
      'source': 'local',
    };
  }

  Stream<String> processStream(String userMessage) async* {
    developer.log('【Orchestrator】开始处理: $userMessage');

    try {
      final retrievedInfo = await _retrievalAgent.retrieve(userMessage);
      final emotionResult = _emotionOf(userMessage);

      developer.log('【Orchestrator】情绪分析完成: ${emotionResult['dominantEmotion']} (${emotionResult['source']})');
      developer.log('【Orchestrator】信息检索完成: 知识库=${(retrievedInfo['knowledgeContext'] ?? '').length}字, 记忆=${(retrievedInfo['memoryContext'] ?? '').length}字');

      yield* _responseAgent.generateStream(
        userMessage: userMessage,
        emotionResult: emotionResult,
        retrievedInfo: retrievedInfo,
      );
    } catch (e) {
      developer.log('【Orchestrator】处理异常: $e');
      yield '抱歉，处理时出现了问题，请再试一次。';
    }
  }

  Future<String> process(String userMessage, {bool appendUserToHistory = true}) async {
    developer.log('【Orchestrator】开始处理(非流式): $userMessage');

    try {
      final retrievedInfo = await _retrievalAgent.retrieve(userMessage);
      final emotionResult = _emotionOf(userMessage);

      return await _responseAgent.generate(
        userMessage: userMessage,
        emotionResult: emotionResult,
        retrievedInfo: retrievedInfo,
        appendUserToHistory: appendUserToHistory,
      );
    } catch (e) {
      developer.log('【Orchestrator】处理异常: $e');
      return '抱歉，处理时出现了问题，请再试一次。';
    }
  }

  Future<void> onConversationEnd({
    required String conversationId,
    required List<Map<String, String>> messages,
  }) async {
    if (messages.isEmpty) return;

    try {
      final chatMessages = messages.map((m) => ChatMessage(
        id: '',
        content: m['content'] ?? '',
        isUser: m['role'] == 'user',
        createdAt: DateTime.now(),
      )).toList();

      final conversation = Conversation(
        id: conversationId,
        messages: chatMessages,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await Future.wait([
        _memoryService.extractAndUpdateProfile(chatMessages),
        _memoryService.summarizeConversation(conversation),
      ]);

      developer.log('【Orchestrator】对话结束处理完成: $conversationId');
    } catch (e) {
      developer.log('【Orchestrator】对话结束处理异常（已跳过）: $e');
    }
  }
}
