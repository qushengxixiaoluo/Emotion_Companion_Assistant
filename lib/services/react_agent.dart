import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'function_tools.dart';
import 'llm_api_adapter.dart';

class ReactAgent {
  static const int maxIterations = 5;

  static const String reactSystemPrompt = '''你是一个情绪陪伴AI助手。在回复用户之前，请按以下步骤思考：

Thought: 分析用户的情绪状态和需求，判断是否需要调用工具获取更多信息。
Action: 决定需要调用什么工具（如果有），格式为 Action: tool_name(arg1="value1", arg2="value2")
Observation: 工具返回的结果（由系统自动填入）

规则：
- 每次只能调用一个工具
- 当你有足够的信息来回复用户时，不要调用工具，直接输出回复
- 最终回复时，用温暖共情的语气，简洁（2-4句话）

可用工具：
- emotion_analysis(text): 分析文本情绪状态
- knowledge_search(query): 搜索心理健康知识库
- history_query(keyword): 查询对话历史摘要
- breathing_guide(step): 获取呼吸引导语
- goodnight_quote(): 获取晚安语录''';

  /// 返回 null 表示 LLM 不可用（调用方据此继续降级到本地话术）
  static Future<String?> run({
    required String userMessage,
    required String baseUrl,
    required String apiKey,
    required String model,
    String apiFormat = LlmApiAdapter.formatOpenai,
    List<Map<String, String>>? contextHistory,
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': reactSystemPrompt},
    ];
    if (contextHistory != null && contextHistory.isNotEmpty) {
      final recent = contextHistory.length > 10 ? contextHistory.sublist(contextHistory.length - 10) : contextHistory;
      messages.addAll(recent);
    }
    messages.add({'role': 'user', 'content': userMessage});

    for (int i = 0; i < maxIterations; i++) {
      final response = await _callLlm(baseUrl: baseUrl, apiKey: apiKey, model: model, apiFormat: apiFormat, messages: messages);
      if (response == null) return null;

      final actionMatch = parseAction(response);
      if (actionMatch == null) return response.trim();

      final toolName = actionMatch['toolName']!;
      final toolArgs = parseArgs(actionMatch['args']!);
      // 工具参数类型不符等异常不让整轮对话崩溃，降级为错误观察继续循环
      String toolResult;
      try {
        toolResult = await FunctionTools.executeTool(toolName, toolArgs);
      } catch (e) {
        toolResult = '工具执行出错: $e';
      }

      messages.add({'role': 'assistant', 'content': response});
      messages.add({'role': 'user', 'content': 'Observation: $toolResult\n\n请根据以上工具返回的结果继续思考和回复。'});
    }

    final lastResponse = await _callLlm(baseUrl: baseUrl, apiKey: apiKey, model: model, apiFormat: apiFormat, messages: messages);
    if (lastResponse == null) return null;
    final finalText = lastResponse.trim();
    // 循环耗尽后模型仍可能输出 Thought/Action 推理原文：剥离，不把内部推理展示给用户
    if (parseAction(finalText) != null) {
      final cleaned = _stripToFinalAnswer(finalText);
      return cleaned.isNotEmpty ? cleaned : '抱歉，我还没想好怎么回答，换个说法试试？';
    }
    return finalText;
  }

  static Map<String, String>? parseAction(String response) {
    final actionRegex = RegExp(r'Action:\s*(\w+)\(([^)]*)\)', caseSensitive: false);
    final match = actionRegex.firstMatch(response);
    if (match == null) return null;

    final toolName = match.group(1)!;
    final argsStr = match.group(2)!;
    final args = <String, dynamic>{};

    final argRegex = RegExp(r'(\w+)\s*=\s*"([^"]*)"');
    for (final argMatch in argRegex.allMatches(argsStr)) {
      final key = argMatch.group(1)!;
      final value = argMatch.group(2)!;
      if (int.tryParse(value) != null) args[key] = int.parse(value);
      else if (double.tryParse(value) != null) args[key] = double.parse(value);
      else args[key] = value;
    }

    if (args.isEmpty && argsStr.trim().isNotEmpty) {
      final simpleArgRegex = RegExp(r'(\w+)\s*=\s*([^,\s"]+)');
      for (final m in simpleArgRegex.allMatches(argsStr)) {
        final key = m.group(1)!;
        final value = m.group(2)!;
        if (int.tryParse(value) != null) args[key] = int.parse(value);
        else if (double.tryParse(value) != null) args[key] = double.parse(value);
        else args[key] = value;
      }
    }

    return {'toolName': toolName, 'args': jsonEncode(args)};
  }

  /// 单次 LLM 调用：URL/请求头/请求体/响应解析全部复用 LlmApiAdapter，
  /// OpenAI 兼容与 Anthropic 原生格式在此自动切换（返回内容为纯文本）。
  static Future<String?> _callLlm({
    required String baseUrl, required String apiKey, required String model,
    String apiFormat = LlmApiAdapter.formatOpenai,
    required List<Map<String, String>> messages,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(LlmApiAdapter.chatUrl(baseUrl, apiFormat)),
        headers: LlmApiAdapter.headers(apiKey, apiFormat),
        body: jsonEncode(LlmApiAdapter.buildBody(
          model: model,
          messages: messages,
          maxTokens: 2048,
          temperature: 0.7,
          apiFormat: apiFormat,
        )),
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final message = LlmApiAdapter.parseMessage(response.body, apiFormat);
        return message?['content'] as String?;
      }
      return null;
    } catch (e) {
      developer.log('【ReAct Agent】请求异常: $e');
      return null;
    }
  }

  static Map<String, dynamic> parseArgs(String argsJson) {
    try { return jsonDecode(argsJson) as Map<String, dynamic>; } catch (_) { return {}; }
  }

  /// 剥离到最后一行 Action 之后的内容（丢弃 Thought/Action 推理原文）
  static String _stripToFinalAnswer(String text) {
    final lines = text.split('\n');
    int lastAction = -1;
    for (int i = 0; i < lines.length; i++) {
      if (RegExp(r'^\s*Action\s*:', caseSensitive: false).hasMatch(lines[i])) lastAction = i;
    }
    if (lastAction < 0) return text.trim();
    return lines.sublist(lastAction + 1).join('\n').trim();
  }
}
