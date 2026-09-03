import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:emotion_companion/services/react_agent.dart';

void main() {
  group('parseAction', () {
    test('解析标准 Action 格式', () {
      final response = 'Thought: 需要查询天气\nAction: weather_query(city="北京")\n然后回复用户。';
      final result = ReactAgent.parseAction(response);
      expect(result, isNotNull);
      expect(result!['toolName'], 'weather_query');
      final args = jsonDecode(result['args']!) as Map<String, dynamic>;
      expect(args['city'], '北京');
    });

    test('解析带空格的 Action', () {
      final response = 'Thought: 需要分析情绪\nAction: emotion_analysis(text="我很开心")';
      final result = ReactAgent.parseAction(response);
      expect(result, isNotNull);
      expect(result!['toolName'], 'emotion_analysis');
    });

    test('无 Action 返回 null', () {
      final response = 'Thought: 我觉得用户很开心\n回复用户。';
      final result = ReactAgent.parseAction(response);
      expect(result, isNull);
    });

    test('解析多个参数', () {
      final response = 'Action: tool(arg1="val1", arg2="val2")';
      final result = ReactAgent.parseAction(response);
      expect(result, isNotNull);
      final args = jsonDecode(result!['args']!) as Map<String, dynamic>;
      expect(args['arg1'], 'val1');
      expect(args['arg2'], 'val2');
    });

    test('解析数字参数', () {
      final response = 'Action: breathing_guide(step=3)';
      final result = ReactAgent.parseAction(response);
      expect(result, isNotNull);
      final args = jsonDecode(result!['args']!) as Map<String, dynamic>;
      expect(args['step'], 3);
    });

    test('解析无参数 Action', () {
      final response = 'Action: goodnight_quote()';
      final result = ReactAgent.parseAction(response);
      expect(result, isNotNull);
      expect(result!['toolName'], 'goodnight_quote');
    });

    test('大小写不敏感', () {
      final response = 'action: weather_query(city="上海")';
      final result = ReactAgent.parseAction(response);
      expect(result, isNotNull);
    });

    test('不同 Action 关键字位置', () {
      final response = '我认为需要天气数据。\nAction: weather_query(city="广州")\n然后回复。';
      final result = ReactAgent.parseAction(response);
      expect(result, isNotNull);
      expect(result!['toolName'], 'weather_query');
    });
  });

  group('parseArgs', () {
    test('解析 JSON 参数', () {
      final args = ReactAgent.parseArgs('{"text": "hello", "count": 5}');
      expect(args['text'], 'hello');
      expect(args['count'], 5);
    });

    test('解析空对象', () {
      final args = ReactAgent.parseArgs('{}');
      expect(args, isEmpty);
    });

    test('解析嵌套 JSON', () {
      final args = ReactAgent.parseArgs('{"key": {"nested": "value"}}');
      expect(args['key'], isA<Map>());
    });
  });

  group('System Prompt', () {
    test('包含所有工具说明', () {
      expect(ReactAgent.reactSystemPrompt.contains('weather_query'), true);
      expect(ReactAgent.reactSystemPrompt.contains('emotion_analysis'), true);
      expect(ReactAgent.reactSystemPrompt.contains('knowledge_search'), true);
      expect(ReactAgent.reactSystemPrompt.contains('history_query'), true);
      expect(ReactAgent.reactSystemPrompt.contains('breathing_guide'), true);
      expect(ReactAgent.reactSystemPrompt.contains('goodnight_quote'), true);
    });

    test('包含 Thought-Action-Observation 模式说明', () {
      expect(ReactAgent.reactSystemPrompt.contains('Thought'), true);
      expect(ReactAgent.reactSystemPrompt.contains('Action'), true);
      expect(ReactAgent.reactSystemPrompt.contains('Observation'), true);
    });

    test('说明每次只能调用一个工具', () {
      expect(ReactAgent.reactSystemPrompt.contains('每次只能调用一个工具'), true);
    });
  });

  group('执行流程模拟', () {
    test('最多迭代 5 次', () {
      expect(ReactAgent.maxIterations, 5);
    });

    test('Thought → Action → Observation 三阶段流程', () {
      final response = 'Thought: 用户询问天气，需要调用天气工具\nAction: weather_query(city="北京", date="2026年5月2日")\n';
      final result = ReactAgent.parseAction(response);
      expect(result, isNotNull);
      expect(result!['toolName'], 'weather_query');
    });

    test('无需工具时直接回复', () {
      final response = 'Thought: 用户心情很好，不需要工具\n根据你的描述，你今天心情不错呢！希望你能保持这份好心情。';
      final result = ReactAgent.parseAction(response);
      expect(result, isNull);
    });
  });
}
