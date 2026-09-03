import 'dart:developer' as developer;
import '../../models/emotion_models.dart';
import '../memory_service.dart';
import 'emotion_agent.dart';
import 'retrieval_agent.dart';
import 'response_agent.dart';

/// 多Agent协作 Orchestrator
class AgentOrchestrator {
  static final AgentOrchestrator _instance = AgentOrchestrator._();
  factory AgentOrchestrator() => _instance;
  AgentOrchestrator._();

  final EmotionAgent _emotionAgent = EmotionAgent();
  final RetrievalAgent _retrievalAgent = RetrievalAgent();
  final ResponseAgent _responseAgent = ResponseAgent();
  final MemoryService _memoryService = MemoryService();

  Stream<String> processStream(String userMessage) async* {
    developer.log('【Orchestrator】开始处理: $userMessage');

    try {
      final results = await Future.wait([
        _emotionAgent.analyze(userMessage),
        _retrievalAgent.retrieve(userMessage),
      ]);

      final emotionResult = results[0] as Map<String, dynamic>;
      final retrievedInfo = results[1] as Map<String, String>;

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

  Future<String> process(String userMessage) async {
    developer.log('【Orchestrator】开始处理(非流式): $userMessage');

    try {
      final results = await Future.wait([
        _emotionAgent.analyze(userMessage),
        _retrievalAgent.retrieve(userMessage),
      ]);

      final emotionResult = results[0] as Map<String, dynamic>;
      final retrievedInfo = results[1] as Map<String, String>;

      return await _responseAgent.generate(
        userMessage: userMessage,
        emotionResult: emotionResult,
        retrievedInfo: retrievedInfo,
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
