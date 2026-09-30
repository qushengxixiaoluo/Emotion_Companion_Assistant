import 'dart:developer' as developer;
import '../llm_service.dart';
import '../ai_comfort_service.dart';
import '../function_tools.dart';
import '../react_agent.dart';

/// 回复生成 Agent
///
/// 三层自动降级（用户无感知，无需手动切换）：
/// 1. LLM 原生 Function Calling（tools 工具调用）
/// 2. API 不支持工具时 → ReAct 文本工具循环
/// 3. LLM 不可用 → 本地安慰话术
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
        yield* _llm.chatStream(userMessage,
            systemPrompt: systemPrompt, tools: FunctionTools.toolDefinitions);
        return;
      } catch (e) {
        // 工具调用不受支持 / 网络失败 → 降级 ReAct 文本工具循环
        developer.log('【回复Agent】LLM 流式失败: $e，降级 ReAct');
        final reactText = await _tryReact(userMessage);
        if (reactText != null) {
          yield* _chunked(reactText);
          return;
        }
        developer.log('【回复Agent】ReAct 也不可用，降级本地安慰话术');
      }
    }

    yield* _fallbackResponse(userMessage, emotionResult);
  }

  Future<String> generate({
    required String userMessage,
    required Map<String, dynamic> emotionResult,
    required Map<String, String> retrievedInfo,
    bool appendUserToHistory = true,
  }) async {
    if (_llm.isConfigured()) {
      try {
        final systemPrompt = _buildSystemPrompt(retrievedInfo);
        return await _llm.chatOrThrow(userMessage,
            systemPrompt: systemPrompt,
            tools: FunctionTools.toolDefinitions,
            appendUserToHistory: appendUserToHistory);
      } catch (e) {
        developer.log('【回复Agent】LLM 生成失败: $e，降级 ReAct');
        final reactText = await _tryReact(userMessage);
        if (reactText != null) return reactText;
        developer.log('【回复Agent】ReAct 也不可用，降级本地安慰话术');
      }
    }

    return _fallback.chat(userMessage, emotionResult['dominantEmotion'] ?? '平静');
  }

  /// ReAct 文本工具循环（LLM 不支持原生 tools 时的备选）；LLM 不可用返回 null
  Future<String?> _tryReact(String userMessage) async {
    try {
      return await ReactAgent.run(
        userMessage: userMessage,
        baseUrl: _llm.baseUrl,
        apiKey: _llm.apiKey,
        model: _llm.model,
        apiFormat: _llm.apiFormat,
      );
    } catch (e) {
      developer.log('【回复Agent】ReAct 异常: $e');
      return null;
    }
  }

  Stream<String> _chunked(String text) async* {
    final chunks = text.split(RegExp(r'(?<=\n)|(?<=[。！？，…])'));
    for (final chunk in chunks) {
      if (chunk.isNotEmpty) yield chunk;
    }
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
