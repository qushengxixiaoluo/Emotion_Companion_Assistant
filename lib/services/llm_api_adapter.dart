import 'dart:convert';
import 'dart:developer' as developer;
import 'llm_service.dart';

/// LLM API 格式适配层（OpenAI 兼容 ↔ Anthropic 原生）。
///
/// 项目内所有出站 LLM 请求统一经过这里：
/// - `openai`（默认）：POST `{baseUrl}/chat/completions`，`Authorization: Bearer` 头
/// - `anthropic`：POST `{baseUrl}/v1/messages`，`x-api-key` + `anthropic-version` 头
///
/// 请求侧入参一律使用 OpenAI 形状（messages 内含 system/tool 消息、
/// tools 为 function 形状），响应侧统一还原为 OpenAI 形状
/// （等价 `choices[0].message`），使工具执行循环、历史记录等下游零改动复用。
class LlmApiAdapter {
  LlmApiAdapter._();

  /// OpenAI 兼容格式（默认）
  static const String formatOpenai = 'openai';

  /// Anthropic 原生格式
  static const String formatAnthropic = 'anthropic';

  /// 规范化格式值：缺失/未知一律回落为 OpenAI 兼容
  static String normalize(String? format) =>
      format == formatAnthropic ? formatAnthropic : formatOpenai;

  static bool isAnthropic(String format) => format == formatAnthropic;

  /// 解析聊天补全端点 URL。
  /// Anthropic 三种写法自适应：以 `/v1/messages` 结尾 → 原样；
  /// 以 `/v1` 结尾 → + `/messages`；否则 → + `/v1/messages`。
  static String chatUrl(String baseUrl, String apiFormat) {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (isAnthropic(apiFormat)) {
      if (base.endsWith('/v1/messages')) return base;
      if (base.endsWith('/v1')) return '$base/messages';
      return '$base/v1/messages';
    }
    return '$base/chat/completions';
  }

  /// 请求头：Anthropic 用 `x-api-key` + `anthropic-version`（不带 Bearer）；
  /// OpenAI 兼容用 `Authorization: Bearer`。
  static Map<String, String> headers(String apiKey, String apiFormat) {
    if (isAnthropic(apiFormat)) {
      return {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      };
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
  }

  /// 构建请求体。入参一律为 OpenAI 形状：
  /// - messages：含 `role: system` 与 `role: tool` 消息
  /// - tools：`{type:'function', function:{name,description,parameters}}`
  ///
  /// Anthropic 时内部转换：system 抽到顶层、tool 消息转 user+tool_result、
  /// assistant(tool_calls) 转 text+tool_use 块、tools 转 input_schema。
  static Map<String, dynamic> buildBody({
    required String model,
    required List<Map<String, dynamic>> messages,
    required int maxTokens,
    required double temperature,
    List<Map<String, dynamic>>? tools,
    bool stream = false,
    String apiFormat = formatOpenai,
  }) {
    if (!isAnthropic(apiFormat)) {
      final body = <String, dynamic>{
        'model': model,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': temperature,
      };
      if (tools != null && tools.isNotEmpty) body['tools'] = tools;
      if (stream) body['stream'] = true;
      return body;
    }

    // ---- Anthropic 请求体 ----
    final systemParts = <String>[];
    final outMessages = <Map<String, dynamic>>[];

    for (final msg in messages) {
      final role = msg['role'];
      final content = msg['content'];

      // system 消息抽到顶层 system 字段
      if (role == 'system') {
        if (content is String && content.isNotEmpty) systemParts.add(content);
        continue;
      }

      // tool 结果 → user 消息 + tool_result 内容块
      if (role == 'tool') {
        outMessages.add({
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': msg['tool_call_id'] ?? '',
              'content': content ?? '',
            },
          ],
        });
        continue;
      }

      if (role == 'assistant') {
        final toolCalls = msg['tool_calls'];
        if (toolCalls is List && toolCalls.isNotEmpty) {
          // 历史里的 assistant(tool_calls) → text + tool_use 块，
          // 否则后续 tool_result 会因找不到配对的 tool_use 被 Anthropic 拒绝
          final blocks = <Map<String, dynamic>>[];
          if (content is String && content.isNotEmpty) {
            blocks.add({'type': 'text', 'text': content});
          }
          for (final call in toolCalls) {
            if (call is! Map) continue;
            final fn = call['function'];
            if (fn is! Map) continue;
            dynamic input = <String, dynamic>{};
            final args = fn['arguments'];
            if (args is String && args.isNotEmpty) {
              try {
                final decoded = jsonDecode(args);
                if (decoded is Map) input = decoded;
              } catch (_) {
                // 参数不是合法 JSON 时按空参数处理，不让整次请求失败
              }
            }
            blocks.add({
              'type': 'tool_use',
              'id': call['id'] ?? '',
              'name': fn['name'] ?? '',
              'input': input,
            });
          }
          outMessages.add({'role': 'assistant', 'content': blocks});
        } else {
          // 普通 assistant 消息：字符串 content 即可
          outMessages.add({'role': 'assistant', 'content': content ?? ''});
        }
        continue;
      }

      // user 消息原样保留
      outMessages.add({'role': 'user', 'content': content ?? ''});
    }

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'temperature': temperature,
      'messages': outMessages,
    };
    if (systemParts.isNotEmpty) body['system'] = systemParts.join('\n\n');
    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map(toAnthropicTool).toList();
    }
    if (stream) body['stream'] = true;
    return body;
  }

  /// OpenAI function 工具 → Anthropic 工具定义（parameters → input_schema）
  static Map<String, dynamic> toAnthropicTool(Map<String, dynamic> tool) {
    final fn = tool['function'];
    final fnMap = fn is Map ? fn : const <String, dynamic>{};
    final parameters = fnMap['parameters'];
    return {
      'name': fnMap['name'] ?? '',
      'description': fnMap['description'] ?? '',
      'input_schema': parameters is Map
          ? parameters
          : <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{},
            },
    };
  }

  /// 解析非流式响应为 OpenAI 形状的 message（等价 `choices[0].message`）。
  /// Anthropic 的 `content` 块数组在此还原：text 块拼接为 content，
  /// tool_use 块映射回 `tool_calls[].function.{name,arguments}`。
  static Map<String, dynamic>? parseMessage(String body, String apiFormat) {
    final data = jsonDecode(body);
    if (data is! Map) return null;

    if (!isAnthropic(apiFormat)) {
      final choices = data['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final first = choices.first;
      if (first is! Map) return null;
      final message = first['message'];
      return message is Map ? Map<String, dynamic>.from(message) : null;
    }

    final content = data['content'];
    if (content is! List) return null;
    final text = StringBuffer();
    final toolCalls = <Map<String, dynamic>>[];
    for (final block in content) {
      if (block is! Map) continue;
      if (block['type'] == 'text') {
        text.write(block['text'] ?? '');
      } else if (block['type'] == 'tool_use') {
        toolCalls.add({
          'id': block['id'] ?? '',
          'type': 'function',
          'function': {
            'name': block['name'] ?? '',
            'arguments': jsonEncode(
              block['input'] ?? <String, dynamic>{},
            ),
          },
        });
      }
    }

    final message = <String, dynamic>{
      'role': 'assistant',
      'content': text.toString(),
    };
    if (toolCalls.isNotEmpty) message['tool_calls'] = toolCalls;
    return message;
  }

  /// 提取错误信息：两种格式都是 `error.message`，取不到时回落原始报文
  static String extractErrorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        final error = data['error'];
        if (error is Map && error['message'] != null) {
          return error['message'].toString();
        }
        if (data['message'] != null) return data['message'].toString();
      }
    } catch (_) {
      // 非 JSON 报文：直接用原文
    }
    return body;
  }
}

/// 流式 SSE 归一化适配器。
///
/// 把 OpenAI（`data: {choices[0].delta}`）与 Anthropic
/// （`content_block_delta` / `content_block_stop` 等事件）两种事件流
/// 统一转成「文本增量 + OpenAI 形状 tool_calls」，供同一套下游
/// （历史写入、流式失败降级重发、工具执行循环）处理。
class ChatStreamAdapter {
  ChatStreamAdapter(this.apiFormat);

  final String apiFormat;

  /// 累积的完整回复文本
  final StringBuffer fullReply = StringBuffer();

  /// 流中合成的工具调用（OpenAI 形状）
  final List<Map<String, dynamic>> _toolCalls = [];

  /// Anthropic：content 块 index → 进行中的 tool_use（partial_json 累积）
  final Map<int, Map<String, dynamic>> _anthropicBlocks = {};

  /// OpenAI：tool_calls 分片 index → 归并中的 tool_call
  final Map<int, Map<String, dynamic>> _openaiBlocks = {};

  /// 处理一条已 trim 的 SSE 行。返回本次需下发的文本增量；
  /// 无文本产出返回 null；Anthropic `error` 事件抛 [LlmException]。
  String? processLine(String line) {
    if (line.isEmpty || line == 'data: [DONE]') return null;
    // `event:` 行本身不带数据（ping/error 的类型在 data 载荷里），跳过
    if (!line.startsWith('data: ')) return null;

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(line.substring(6));
      if (decoded is Map) json = Map<String, dynamic>.from(decoded);
    } catch (e) {
      developer.log('【LLM流式】解析单行失败: $e, 行内容: $line');
      return null;
    }
    if (json == null) return null;

    try {
      return LlmApiAdapter.isAnthropic(apiFormat)
          ? _processAnthropic(json)
          : _processOpenai(json);
    } on LlmException {
      rethrow;
    } catch (e) {
      developer.log('【LLM流式】处理事件失败: $e');
      return null;
    }
  }

  String? _processOpenai(Map<String, dynamic> json) {
    // 中途出错时 OpenAI 兼容网关会推 data: {"error": {...}}
    final error = json['error'];
    if (error is Map &&
        error['message'] != null &&
        json['choices'] == null) {
      throw LlmException(error['message'].toString());
    }

    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final delta = first['delta'];
    if (delta is! Map) return null;

    // 流式 tool_calls 分片归并（id/name 只在首片，arguments 逐片追加）
    final calls = delta['tool_calls'];
    if (calls is List) {
      for (final call in calls) {
        if (call is! Map) continue;
        final index = (call['index'] as num?)?.toInt() ?? 0;
        final target = _openaiBlocks.putIfAbsent(
          index,
          () => <String, dynamic>{'id': '', 'name': '', 'args': ''},
        );
        if (call['id'] != null) target['id'] = call['id'];
        final fn = call['function'];
        if (fn is Map) {
          if (fn['name'] != null) target['name'] = fn['name'];
          final args = fn['arguments']?.toString();
          if (args != null && args.isNotEmpty) {
            target['args'] = '${target['args']}$args';
          }
        }
      }
    }

    final content = delta['content'];
    if (content is! String || content.isEmpty) return null;
    fullReply.write(content);
    return content;
  }

  String? _processAnthropic(Map<String, dynamic> json) {
    final index = (json['index'] as num?)?.toInt() ?? 0;

    switch (json['type']) {
      case 'content_block_start':
        final block = json['content_block'];
        if (block is Map && block['type'] == 'tool_use') {
          _anthropicBlocks[index] = {
            'id': block['id'] ?? '',
            'name': block['name'] ?? '',
            'args': '',
          };
        }
        return null;

      case 'content_block_delta':
        final delta = json['delta'];
        if (delta is! Map) return null;
        // 文本增量 → 当作一个 delta 下发
        if (delta['type'] == 'text_delta') {
          final text = delta['text']?.toString() ?? '';
          if (text.isEmpty) return null;
          fullReply.write(text);
          return text;
        }
        // 工具入参增量 → 累积 partial_json
        if (delta['type'] == 'input_json_delta') {
          final partial = delta['partial_json']?.toString() ?? '';
          final block = _anthropicBlocks[index];
          if (block != null && partial.isNotEmpty) {
            block['args'] = '${block['args']}$partial';
          }
        }
        return null;

      case 'content_block_stop':
        // 工具块结束 → 合成一个 OpenAI 形状 tool_call
        final block = _anthropicBlocks.remove(index);
        if (block != null) {
          final args = block['args'] as String;
          _toolCalls.add({
            'id': block['id'],
            'type': 'function',
            'function': {
              'name': block['name'],
              'arguments': args.isEmpty ? '{}' : args,
            },
          });
        }
        return null;

      case 'error':
        final error = json['error'];
        final message =
            error is Map ? error['message']?.toString() : null;
        throw LlmException(message ?? 'Anthropic 流式返回错误');

      // ping / message_start / message_delta / message_stop 等：无需处理
      default:
        return null;
    }
  }

  /// 流结束后调用：归并 OpenAI 分片 tool_calls（Anthropic 已在
  /// content_block_stop 时合成），返回 OpenAI 形状列表。
  /// 可重复调用（内部会清空分片缓存）。
  List<Map<String, dynamic>> buildToolCalls() {
    final indexes = _openaiBlocks.keys.toList()..sort();
    for (final i in indexes) {
      final b = _openaiBlocks[i]!;
      final args = b['args'] as String;
      _toolCalls.add({
        'id': b['id'],
        'type': 'function',
        'function': {
          'name': b['name'],
          'arguments': args.isEmpty ? '{}' : args,
        },
      });
    }
    _openaiBlocks.clear();
    return _toolCalls;
  }
}
