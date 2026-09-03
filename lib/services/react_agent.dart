import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'function_tools.dart';

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
- goodnight_quote(): 获取晚安语录
- weather_query(city, date): 查询指定城市和日期的天气''';

  static Future<String> run({
    required String userMessage,
    required String baseUrl,
    required String apiKey,
    required String model,
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
      final response = await _callLlm(baseUrl: baseUrl, apiKey: apiKey, model: model, messages: messages);
      if (response == null) return '抱歉，AI暂时无法回复，请稍后再试。';

      final actionMatch = parseAction(response);
      if (actionMatch == null) return response.trim();

      final toolName = actionMatch['toolName']!;
      final toolArgs = parseArgs(actionMatch['args']!);
      final toolResult = await FunctionTools.executeTool(toolName, toolArgs);

      messages.add({'role': 'assistant', 'content': response});
      messages.add({'role': 'user', 'content': 'Observation: $toolResult\n\n请根据以上工具返回的结果继续思考和回复。'});
    }

    final lastResponse = await _callLlm(baseUrl: baseUrl, apiKey: apiKey, model: model, messages: messages);
    return lastResponse?.trim() ?? '抱歉，处理过程中遇到困难，请再试一次。';
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

  static Future<String?> _callLlm({
    required String baseUrl, required String apiKey, required String model,
    required List<Map<String, String>> messages,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/chat/completions');
      final response = await http.post(uri,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
        body: jsonEncode({'model': model, 'messages': messages, 'max_tokens': 2048, 'temperature': 0.7}),
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices']?[0]?['message']?['content'] as String?;
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
}
