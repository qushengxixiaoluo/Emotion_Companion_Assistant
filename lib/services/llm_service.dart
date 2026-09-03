import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../app/config/llm_config.dart';
import 'storage_service.dart';
import 'function_tools.dart';

class LlmService {
  static final LlmService _instance = LlmService._();
  factory LlmService() => _instance;
  LlmService._();

  String _baseUrl = '';
  String _apiKey = '';
  String _model = '';
  int _maxTokens = LlmConfig.maxTokens;
  double _temperature = LlmConfig.temperature;

  final StorageService _storageService = StorageService();

  Future<void> reloadConfig() async {
    final userUrl = await _storageService.getLlmBaseUrl();
    final userKey = await _storageService.getLlmApiKey();
    final userModel = await _storageService.getLlmModel();

    _baseUrl = (userUrl != null && userUrl.isNotEmpty) ? userUrl : '';
    _apiKey = (userKey != null && userKey.isNotEmpty) ? userKey : '';
    _model = (userModel != null && userModel.isNotEmpty) ? userModel : '';
    _maxTokens = LlmConfig.maxTokens;
    _temperature = LlmConfig.temperature;

    developer.log('【LLM配置】baseUrl: $_baseUrl, model: $_model, configured: ${_baseUrl.isNotEmpty && _apiKey.isNotEmpty}');
  }

  bool isConfigured() {
    return _baseUrl.isNotEmpty && _apiKey.isNotEmpty && _model.isNotEmpty;
  }

  Future<bool> isUsingUserConfig() async {
    return _storageService.hasLlmUserConfig();
  }

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  String get model => _model;

  final List<Map<String, dynamic>> _history = [];

  static const String _systemPrompt = '''你是一位温柔、共情、专业的情绪陪伴师。你的职责是：
1. 用温暖轻柔的语气陪伴用户，绝不生硬机械回复
2. 根据用户的情绪状态智能匹配安慰话术：难过时温柔共情安抚、焦虑时理性疏导解压、愤怒时耐心情绪平复、孤独时暖心陪伴聊天
3. 支持深夜emo专属陪伴、压力大专属疏导、失恋暖心安慰、学业职场压力开导
4. 需要时提供正念深呼吸引导、情绪冥想放松话术、睡前暖心晚安治愈语录
5. 不评判、不指责、只温柔陪伴
6. 回复简洁温暖，不要过长，2-4句话为佳
7. 如果用户提到想睡、晚安等，给予温暖的晚安祝福
8. 如果用户要求呼吸引导或放松，引导做深呼吸练习
9. 可使用Markdown格式让回复更美观：加粗关键词、用小标题分层、短引用表达共情、分隔线区分段落、列表展示建议''';

  /// 发送消息并获取AI回复（非流式）
  Future<String> chat(String userMessage, {List<Map<String, dynamic>>? tools, String? systemPrompt}) async {
    _history.add({'role': 'user', 'content': userMessage});

    final effectiveSystemPrompt = systemPrompt ?? _systemPrompt;

    final messages = [
      {'role': 'system', 'content': effectiveSystemPrompt},
      ..._history.length > 20 ? _history.sublist(_history.length - 20) : _history,
    ];

    developer.log('【LLM请求】URL: $_baseUrl/chat/completions');
    developer.log('【LLM请求】模型: $_model');
    developer.log('【LLM请求】消息数: ${messages.length}');
    if (tools != null) developer.log('【LLM请求】工具数: ${tools.length}');

    try {
      final uri = Uri.parse('$_baseUrl/chat/completions');
      final body = <String, dynamic>{
        'model': _model,
        'messages': messages,
        'max_tokens': _maxTokens,
        'temperature': _temperature,
      };

      // Function Calling：仅在提供 tools 时附加
      if (tools != null && tools.isNotEmpty) {
        body['tools'] = tools;
      }

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 60));

      developer.log('【LLM响应】状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final message = data['choices']?[0]?['message'];
        final reply = message?['content'] as String? ?? '';

        // 检查是否有 tool_calls
        final toolCalls = message?['tool_calls'] as List<dynamic>?;
        if (toolCalls != null && toolCalls.isNotEmpty && tools != null) {
          developer.log('【Function Calling】检测到 ${toolCalls.length} 个工具调用');

          // 将 assistant 的 tool_calls 消息加入历史（保持原始 List 格式）
          _history.add({
            'role': 'assistant',
            'content': reply,
            'tool_calls': toolCalls,
          });

          // 逐个执行工具调用
          for (final toolCall in toolCalls) {
            final function = toolCall['function'];
            final toolName = function['name'] as String;
            final argsStr = function['arguments'] as String;
            final args = jsonDecode(argsStr) as Map<String, dynamic>;
            final toolCallId = toolCall['id'] as String? ?? '';

            developer.log('【Function Calling】执行: $toolName($argsStr)');

            final result = await FunctionTools.executeTool(toolName, args);

            _history.add({
              'role': 'tool',
              'tool_call_id': toolCallId,
              'content': result,
            });
          }

          // 将工具结果反馈给模型，获取最终回复
          final followUpMessages = [
            {'role': 'system', 'content': effectiveSystemPrompt},
            ..._history.length > 25 ? _history.sublist(_history.length - 25) : _history,
          ];

          final followUpResponse = await http.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': followUpMessages,
              'max_tokens': _maxTokens,
              'temperature': _temperature,
            }),
          ).timeout(const Duration(seconds: 60));

          if (followUpResponse.statusCode == 200) {
            final followUpData = jsonDecode(followUpResponse.body);
            final finalReply = followUpData['choices']?[0]?['message']?['content'] as String?;
            if (finalReply != null && finalReply.isNotEmpty) {
              _history.add({'role': 'assistant', 'content': finalReply});
              return finalReply.trim();
            }
          }

          // 工具调用后模型未返回内容，使用本地降级
          if (reply.isNotEmpty) {
            _history.add({'role': 'assistant', 'content': reply});
            return reply.trim();
          }
          return '抱歉，AI处理工具调用后未能生成回复。';
        }

        // 普通回复（无工具调用）
        if (reply.isNotEmpty) {
          _history.add({'role': 'assistant', 'content': reply});
          return reply.trim();
        } else {
          return '抱歉，AI返回了空内容。';
        }
      } else {
        String errorDetail;
        try {
          final errorJson = jsonDecode(response.body);
          errorDetail = errorJson['error']?['message'] ?? errorJson['message'] ?? response.body;
        } catch (_) {
          errorDetail = response.body;
        }
        return 'API调用失败（状态码: ${response.statusCode}）\n错误信息: $errorDetail';
      }
    } on FormatException catch (e) {
      developer.log('【LLM错误】格式异常: $e');
      return '响应解析失败: $e。请确认API为OpenAI兼容格式。';
    } on Exception catch (e) {
      developer.log('【LLM错误】网络异常: $e');
      return '网络连接失败: $e。请检查网络或API地址是否正确。';
    } catch (e) {
      developer.log('【LLM错误】未知异常: $e');
      return '发生未知错误: $e';
    }
  }

  /// 流式输出（SSE）
  Stream<String> chatStream(String userMessage, {List<Map<String, dynamic>>? tools, String? systemPrompt}) async* {
    _history.add({'role': 'user', 'content': userMessage});

    final effectiveSystemPrompt = systemPrompt ?? _systemPrompt;

    final messages = [
      {'role': 'system', 'content': effectiveSystemPrompt},
      ..._history.length > 20 ? _history.sublist(_history.length - 20) : _history,
    ];

    developer.log('【LLM流式】URL: $_baseUrl/chat/completions');
    if (tools != null) developer.log('【LLM流式】工具数: ${tools.length}');

    // 如果提供了工具，先用非流式请求处理 Function Calling
    if (tools != null && tools.isNotEmpty) {
      yield* _chatStreamWithTools(messages, tools, systemPrompt: effectiveSystemPrompt);
      return;
    }

    try {
      final uri = Uri.parse('$_baseUrl/chat/completions');
      final client = http.Client();
      final request = http.Request('POST', uri);
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      });
      request.body = jsonEncode({
        'model': _model,
        'messages': messages,
        'max_tokens': _maxTokens,
        'temperature': _temperature,
        'stream': true,
      });

      final response = await client.send(request).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        developer.log('【LLM流式错误】状态码: ${response.statusCode}, 内容: $body');
        yield 'API调用失败（状态码: ${response.statusCode}）\n响应内容: $body';
        return;
      }

      final buffer = StringBuffer();
      String fullReply = '';

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer.write(chunk);
        final text = buffer.toString();
        final lines = text.split('\n');
        buffer.clear();

        if (lines.isNotEmpty) buffer.write(lines.last);

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty || line == 'data: [DONE]') continue;
          if (line.startsWith('data: ')) {
            try {
              final jsonStr = line.substring(6);
              final json = jsonDecode(jsonStr);
              final choices = json['choices'];
              if (choices == null || choices.isEmpty) continue;
              final delta = choices[0]['delta'];
              if (delta == null) continue;
              final content = delta['content'];
              if (content == null || content.isEmpty) continue;
              fullReply += content;
              yield content;
            } catch (e) {
              developer.log('【LLM流式】解析单行失败: $e, 行内容: $line');
            }
          }
        }
      }

      final remaining = buffer.toString().trim();
      if (remaining.startsWith('data: ') && remaining != 'data: [DONE]') {
        try {
          final json = jsonDecode(remaining.substring(6));
          final content = json['choices']?[0]?['delta']?['content'];
          if (content != null && content.isNotEmpty) {
            fullReply += content;
            yield content;
          }
        } catch (_) {}
      }

      if (fullReply.isNotEmpty) {
        _history.add({'role': 'assistant', 'content': fullReply});
      }
    } catch (e) {
      developer.log('【LLM流式错误】异常: $e');
      yield '发生错误: $e';
    }
  }

  /// 流式模式下，先通过非流式请求处理工具调用，再对最终回复做流式输出
  Stream<String> _chatStreamWithTools(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools, {
    String? systemPrompt,
  }) async* {
    try {
      final uri = Uri.parse('$_baseUrl/chat/completions');

      // 第一步：非流式请求，检测是否有 tool_calls
      final firstResponse = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'max_tokens': _maxTokens,
          'temperature': _temperature,
          'tools': tools,
        }),
      ).timeout(const Duration(seconds: 60));

      if (firstResponse.statusCode != 200) {
        yield 'API调用失败（状态码: ${firstResponse.statusCode}）';
        return;
      }

      final firstData = jsonDecode(firstResponse.body);
      final firstMessage = firstData['choices']?[0]?['message'];

      if (firstMessage == null) {
        yield '抱歉，AI返回了空内容。';
        return;
      }

      // 检查是否有 tool_calls
      final toolCalls = firstMessage['tool_calls'] as List<dynamic>?;
      if (toolCalls != null && toolCalls.isNotEmpty) {
        developer.log('【Function Calling 流式】检测到 ${toolCalls.length} 个工具调用');

        // 将 assistant 的 tool_calls 加入历史（保持原始 List 格式）
        _history.add({
          'role': 'assistant',
          'content': firstMessage['content'] ?? '',
          'tool_calls': toolCalls,
        });

        // 执行所有工具调用
        for (final toolCall in toolCalls) {
          final function = toolCall['function'];
          final toolName = function['name'] as String;
          final argsStr = function['arguments'] as String;
          final args = jsonDecode(argsStr) as Map<String, dynamic>;
          final toolCallId = toolCall['id'] as String? ?? '';

          developer.log('【Function Calling 流式】执行: $toolName');

          final result = await FunctionTools.executeTool(toolName, args);

          _history.add({
            'role': 'tool',
            'tool_call_id': toolCallId,
            'content': result,
          });
        }

        // 第二步：流式输出最终回复
        final followUpMessages = [
          {'role': 'system', 'content': systemPrompt ?? _systemPrompt},
          ..._history.length > 25 ? _history.sublist(_history.length - 25) : _history,
        ];

        yield* _streamChat(followUpMessages);
        return;
      }

      // 无工具调用，直接流式输出
      final content = firstMessage['content'] as String? ?? '';
      if (content.isNotEmpty) {
        _history.add({'role': 'assistant', 'content': content});
        yield content;
      }
    } catch (e) {
      developer.log('【Function Calling 流式】异常: $e');
      yield '发生错误: $e';
    }
  }

  /// 纯流式输出（用于 Function Calling 后的第二步）
  Stream<String> _streamChat(List<Map<String, dynamic>> messages) async* {
    try {
      final uri = Uri.parse('$_baseUrl/chat/completions');
      final client = http.Client();
      final request = http.Request('POST', uri);
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      });
      request.body = jsonEncode({
        'model': _model,
        'messages': messages,
        'max_tokens': _maxTokens,
        'temperature': _temperature,
        'stream': true,
      });

      final response = await client.send(request).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        yield 'API调用失败（状态码: ${response.statusCode}）';
        return;
      }

      final buffer = StringBuffer();
      String fullReply = '';

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer.write(chunk);
        final text = buffer.toString();
        final lines = text.split('\n');
        buffer.clear();
        if (lines.isNotEmpty) buffer.write(lines.last);

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty || line == 'data: [DONE]') continue;
          if (line.startsWith('data: ')) {
            try {
              final jsonStr = line.substring(6);
              final json = jsonDecode(jsonStr);
              final content = json['choices']?[0]?['delta']?['content'];
              if (content != null && content.isNotEmpty) {
                fullReply += content;
                yield content;
              }
            } catch (_) {}
          }
        }
      }

      if (fullReply.isNotEmpty) {
        _history.add({'role': 'assistant', 'content': fullReply});
      }
    } catch (e) {
      yield '发生错误: $e';
    }
  }

  /// 情绪分析：调用大模型做结构化7维度分析
  Future<Map<String, dynamic>?> analyzeEmotion(String text, {bool enableCoT = false}) async {
    String analyzePrompt = '''你是一位专业的心理学情绪分析师。请对用户的倾诉内容进行深度情绪分析。

要求：
1. 从以下7个维度给出0.0-1.0的评分（0=完全没有，1=极度强烈）：
   - sadness（悲伤）
   - anxiety（焦虑）
   - anger（愤怒）
   - loneliness（孤独）
   - happiness（开心/幸福）
   - calmness（平静/放松）
   - suppression（压抑/内耗）
2. 判断主导情绪 dominantEmotion，从以下选择一项：悲伤、焦虑、愤怒、孤独、开心、平静、压抑
3. 给出专业的情绪解读 interpretation（2-4句话，温柔共情的语气）
4. 给出3-5条具体的舒缓建议 suggestions（数组格式，每条一句话）

必须严格返回以下JSON格式，不要包含任何其他文字：
{
  "sadness": 0.0,
  "anxiety": 0.0,
  "anger": 0.0,
  "loneliness": 0.0,
  "happiness": 0.0,
  "calmness": 0.0,
  "suppression": 0.0,
  "dominantEmotion": "",
  "interpretation": "",
  "suggestions": [""]''';

    // CoT 模式：添加思维链引导
    if (enableCoT) {
      analyzePrompt += '''

注意：请先在Thought部分逐步分析用户的情绪线索，然后给出最终的JSON结果。
Thought: （你的逐步分析过程）
Result: （上面要求的JSON格式）''';
    }

    try {
      final uri = Uri.parse('$_baseUrl/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': analyzePrompt},
            {'role': 'user', 'content': '请分析以下倾诉内容：\n$text'},
          ],
          'max_tokens': 2048,
          'temperature': 0.3,
        }),
      ).timeout(const Duration(seconds: 60));

      developer.log('【情绪分析】状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices']?[0]?['message']?['content'] as String?;
        if (reply == null || reply.isEmpty) return null;

        String jsonStr = reply.trim();

        // CoT 模式：提取 Result: 后面的 JSON
        if (enableCoT && jsonStr.contains('Result:')) {
          jsonStr = jsonStr.split('Result:').last.trim();
        }

        if (jsonStr.contains('```json')) {
          jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        } else if (jsonStr.contains('```')) {
          jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        }

        final result = jsonDecode(jsonStr) as Map<String, dynamic>;
        developer.log('【情绪分析】结果: $result');
        return result;
      } else {
        developer.log('【情绪分析】失败: ${response.body}');
        return null;
      }
    } catch (e) {
      developer.log('【情绪分析】异常: $e');
      return null;
    }
  }

  /// Self-Consistency 情绪分析：3轮投票取中位数/众数
  Future<Map<String, dynamic>?> analyzeEmotionWithConsistency(String text) async {
    if (!isConfigured()) return null;

    final results = <Map<String, dynamic>>[];
    final dimensions = ['sadness', 'anxiety', 'anger', 'loneliness', 'happiness', 'calmness', 'suppression'];

    // 3轮独立分析
    for (int i = 0; i < 3; i++) {
      try {
        final result = await analyzeEmotion(text);
        if (result != null) {
          results.add(result);
        }
      } catch (e) {
        developer.log('【Self-Consistency】第${i + 1}轮失败: $e');
      }
    }

    if (results.isEmpty) return null;

    // 取各维度中位数
    final aggregated = <String, dynamic>{};
    for (final dim in dimensions) {
      final values = results.map((r) => (r[dim] as num?)?.toDouble() ?? 0.0).toList();
      values.sort();
      final mid = values[values.length ~/ 2];
      aggregated[dim] = mid;
    }

    // 取主导情绪的众数
    final dominantVotes = results.map((r) => r['dominantEmotion'] as String? ?? '平静').toList();
    final freq = <String, int>{};
    for (final vote in dominantVotes) {
      freq[vote] = (freq[vote] ?? 0) + 1;
    }
    aggregated['dominantEmotion'] = freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    // 取第一个结果的解读和建议
    aggregated['interpretation'] = results.first['interpretation'] ?? '';
    aggregated['suggestions'] = results.first['suggestions'] ?? [];

    developer.log('【Self-Consistency】聚合结果: ${aggregated['dominantEmotion']} (3轮投票)');
    return aggregated;
  }

  /// 构建增强版系统提示词（注入记忆和知识上下文）
  String buildEnhancedSystemPrompt({String? memoryContext, String? knowledgeContext}) {
    final parts = <String>[_systemPrompt];

    if (memoryContext != null && memoryContext.isNotEmpty) {
      parts.add('\n$memoryContext');
    }
    if (knowledgeContext != null && knowledgeContext.isNotEmpty) {
      parts.add('\n$knowledgeContext');
    }

    return parts.join('\n');
  }

  /// 梦境解读
  Future<Map<String, String>?> analyzeDream(String dreamText) async {
    const String dreamPrompt = '''你是一位温柔、专业、富有同理心的梦境解读师。请对用户描述的梦境进行深度分析。

你必须严格按照以下格式回复，第一行是标题，之后是Markdown正文：

# [为这个梦境起一个富有诗意的简短标题，8字以内]

然后使用Markdown格式进行多维度分析，必须使用"## "作为每部分标题：

## 梦境主题与象征
识别梦中的核心意象和符号，解读它们可能象征的含义。

## 情绪分析
分析梦境中反映的情绪基调，以及这些情绪可能与用户当下心理状态的联系。

## 心理学解读
从心理学视角进行温和的深入解读。保持开放性，避免武断结论。

## 生活关联
探索梦境与用户现实生活可能的联结。

## 建议与引导
基于梦境的整体分析，提供3-5条温暖、具体、可操作的心灵成长建议。

回复规则：
1. 语气温柔共情
2. 大量使用"可能""或许"等开放性措辞
3. 每个方面写2-4句话，整体控制在800-1000字
4. 在回复末尾添加一小段总结性的温暖话语，用"---"分隔线隔开''';

    try {
      final uri = Uri.parse('$_baseUrl/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': dreamPrompt},
            {'role': 'user', 'content': '请解读以下梦境：\n$dreamText'},
          ],
          'max_tokens': 3072,
          'temperature': 0.5,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices']?[0]?['message']?['content'] as String?;
        if (reply == null || reply.isEmpty) return null;

        String result = reply.trim();
        if (result.startsWith('```')) {
          final start = result.indexOf('\n');
          if (start != -1) {
            result = result.substring(start + 1);
            if (result.endsWith('```')) {
              result = result.substring(0, result.lastIndexOf('```')).trim();
            }
          }
        }

        String title = '梦境解读';
        String analysis = result;
        final firstLineEnd = result.indexOf('\n');
        if (firstLineEnd != -1) {
          final firstLine = result.substring(0, firstLineEnd).trim();
          if (firstLine.startsWith('# ')) {
            title = firstLine.substring(2).trim();
            analysis = result.substring(firstLineEnd + 1).trim();
          }
        }

        return {'title': title, 'analysis': analysis};
      }
      return null;
    } catch (e) {
      developer.log('【梦境解读】异常: $e');
      return null;
    }
  }

  /// 根据对话内容生成简短标题
  Future<String> generateTitle(String userMessage, String aiReply) async {
    const prompt = '根据以下对话内容，生成一个10字以内的简短标题，直接返回标题文字，不要引号、标点或额外说明。';

    try {
      final uri = Uri.parse('$_baseUrl/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': prompt},
            {'role': 'user', 'content': '用户：$userMessage\nAI：${aiReply.length > 200 ? aiReply.substring(0, 200) : aiReply}'},
          ],
          'max_tokens': 32,
          'temperature': 0.5,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final title = data['choices']?[0]?['message']?['content'] as String?;
        if (title != null && title.trim().isNotEmpty) {
          return title.trim().length > 15 ? title.trim().substring(0, 15) : title.trim();
        }
      }
    } catch (_) {}
    return userMessage.length > 15 ? '${userMessage.substring(0, 15)}…' : userMessage;
  }

  /// 测试连接
  Future<(bool, String)> testConnection({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': 'Hi'},
          ],
          'max_tokens': 16,
          'temperature': 0,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return (true, '连接成功，大模型响应正常');
      } else {
        String errorDetail;
        try {
          final errorJson = jsonDecode(response.body);
          errorDetail = errorJson['error']?['message'] ?? errorJson['message'] ?? response.body;
        } catch (_) {
          errorDetail = response.body;
        }
        return (false, '连接失败 (状态码: ${response.statusCode})\n$errorDetail');
      }
    } on FormatException {
      return (false, '响应格式异常，请确认 API 为 OpenAI 兼容格式');
    } on Exception catch (e) {
      return (false, '网络连接失败，请检查 API 地址是否正确\n$e');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return (false, '连接超时，请检查网络或 API 地址');
      }
      return (false, '连接测试异常: $e');
    }
  }

  void loadHistory(List<Map<String, String>> messages) {
    _history.clear();
    if (messages.isEmpty) return;
    final limited = messages.length > 20 ? messages.sublist(messages.length - 20) : messages;
    for (final msg in limited) {
      var content = msg['content'] ?? '';
      if (content.length > 800) {
        content = '${content.substring(0, 797)}...';
      }
      _history.add({'role': msg['role']!, 'content': content});
    }
  }

  void clearHistory() {
    _history.clear();
  }
}
