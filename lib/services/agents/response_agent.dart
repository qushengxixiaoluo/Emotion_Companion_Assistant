import 'dart:developer' as developer;
import '../llm_service.dart';
import '../ai_comfort_service.dart';

/// 回复生成 Agent
class ResponseAgent {
  final LlmService _llm = LlmService();
  final AiComfortService _fallback = AiComfortService();

  Stream<String> generateStream({
    required String userMessage,
    required Map<String, dynamic> emotionResult,
    required Map<String, String> retrievedInfo,
  }) async* {
    if (_llm.isConfigured()) {
      try {
        final systemPrompt = _buildSystemPrompt(retrievedInfo);
        yield* _llm.chatStream(userMessage, systemPrompt: systemPrompt);
        return;
      } catch (e) {
        developer.log('【回复Agent】LLM 流式生成失败: $e，降级到本地安慰话术');
      }
    }

    yield* _fallbackResponse(userMessage, emotionResult);
  }

  Future<String> generate({
    required String userMessage,
    required Map<String, dynamic> emotionResult,
    required Map<String, String> retrievedInfo,
  }) async {
    if (_llm.isConfigured()) {
      try {
        final systemPrompt = _buildSystemPrompt(retrievedInfo);
        return await _llm.chat(userMessage, systemPrompt: systemPrompt);
      } catch (e) {
        developer.log('【回复Agent】LLM 生成失败: $e，降级到本地安慰话术');
      }
    }

    return _fallback.chat(userMessage, emotionResult['dominantEmotion'] ?? '平静');
  }

  String _buildSystemPrompt(Map<String, String> retrievedInfo) {
    final memoryContext = retrievedInfo['memoryContext'] ?? '';
    final knowledgeContext = retrievedInfo['knowledgeContext'] ?? '';

    return _llm.buildEnhancedSystemPrompt(
      memoryContext: memoryContext.isNotEmpty ? memoryContext : null,
      knowledgeContext: knowledgeContext.isNotEmpty ? knowledgeContext : null,
    );
  }

  Stream<String> _fallbackResponse(
    String userMessage,
    Map<String, dynamic> emotionResult,
  ) async* {
    final emotion = emotionResult['dominantEmotion'] ?? '平静';
    final response = _fallback.chat(userMessage, emotion);

    for (final char in response.split('')) {
      yield char;
    }
  }
}
