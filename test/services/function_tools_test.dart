import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:emotion_companion/services/function_tools.dart';

void main() {
  group('FunctionTools.toolDefinitions', () {
    test('定义了 6 个工具', () {
      expect(FunctionTools.toolDefinitions.length, 6);
    });

    test('所有工具都有正确的类型结构', () {
      for (final tool in FunctionTools.toolDefinitions) {
        expect(tool['type'], 'function');
        expect(tool['function'], isA<Map>());
        expect(tool['function']['name'], isA<String>());
        expect(tool['function']['description'], isA<String>());
        expect(tool['function']['parameters'], isA<Map>());
      }
    });

    test('包含 emotion_analysis 工具', () {
      final names = FunctionTools.toolDefinitions.map((t) => t['function']['name']).toList();
      expect(names, contains('emotion_analysis'));
    });

    test('包含 knowledge_search 工具', () {
      final names = FunctionTools.toolDefinitions.map((t) => t['function']['name']).toList();
      expect(names, contains('knowledge_search'));
    });

    test('包含 history_query 工具', () {
      final names = FunctionTools.toolDefinitions.map((t) => t['function']['name']).toList();
      expect(names, contains('history_query'));
    });

    test('包含 breathing_guide 工具', () {
      final names = FunctionTools.toolDefinitions.map((t) => t['function']['name']).toList();
      expect(names, contains('breathing_guide'));
    });

    test('包含 goodnight_quote 工具', () {
      final names = FunctionTools.toolDefinitions.map((t) => t['function']['name']).toList();
      expect(names, contains('goodnight_quote'));
    });

    test('包含 weather_query 工具', () {
      final names = FunctionTools.toolDefinitions.map((t) => t['function']['name']).toList();
      expect(names, contains('weather_query'));
    });

    test('emotion_analysis 有 text 参数', () {
      final tool = FunctionTools.toolDefinitions.firstWhere((t) => t['function']['name'] == 'emotion_analysis');
      final params = tool['function']['parameters'];
      expect(params['properties']['text'], isA<Map>());
      expect(params['required'], contains('text'));
    });

    test('weather_query 有 city 参数', () {
      final tool = FunctionTools.toolDefinitions.firstWhere((t) => t['function']['name'] == 'weather_query');
      final params = tool['function']['parameters'];
      expect(params['properties']['city'], isA<Map>());
      expect(params['required'], contains('city'));
    });
  });

  group('executeTool - weather_query', () {
    test('返回大雪天气', () async {
      final result = await FunctionTools.executeTool('weather_query', {'city': '北京', 'date': '2026年5月2日'});
      final json = jsonDecode(result);
      expect(json['weather'], '大雪');
    });

    test('返回温度 -15°C', () async {
      final result = await FunctionTools.executeTool('weather_query', {'city': '上海'});
      final json = jsonDecode(result);
      expect(json['temperature'], -15);
    });

    test('包含城市名', () async {
      final result = await FunctionTools.executeTool('weather_query', {'city': '深圳'});
      final json = jsonDecode(result);
      expect(json['city'], '深圳');
    });

    test('缺少城市时使用默认值', () async {
      final result = await FunctionTools.executeTool('weather_query', {});
      final json = jsonDecode(result);
      expect(json['city'], '未知');
    });

    test('缺少日期时使用默认值', () async {
      final result = await FunctionTools.executeTool('weather_query', {'city': '广州'});
      final json = jsonDecode(result);
      expect(json['date'], '今天');
    });

    test('返回建议', () async {
      final result = await FunctionTools.executeTool('weather_query', {'city': '北京'});
      final json = jsonDecode(result);
      expect(json['suggestion'], isA<String>());
      expect(json['suggestion'].isNotEmpty, true);
    });

    test('任何城市都返回相同天气', () async {
      final result1 = await FunctionTools.executeTool('weather_query', {'city': '北京'});
      final result2 = await FunctionTools.executeTool('weather_query', {'city': '广州'});
      final json1 = jsonDecode(result1);
      final json2 = jsonDecode(result2);
      expect(json1['weather'], json2['weather']);
      expect(json1['temperature'], json2['temperature']);
    });

    test('返回北风3级', () async {
      final result = await FunctionTools.executeTool('weather_query', {'city': '北京'});
      final json = jsonDecode(result);
      expect(json['wind'], '北风3级');
    });

    test('返回湿度85%', () async {
      final result = await FunctionTools.executeTool('weather_query', {'city': '北京'});
      final json = jsonDecode(result);
      expect(json['humidity'], '85%');
    });
  });

  group('executeTool - 其他工具', () {
    test('emotion_analysis 正常返回', () async {
      final result = await FunctionTools.executeTool('emotion_analysis', {'text': '我很开心'});
      final json = jsonDecode(result);
      expect(json.containsKey('dominantEmotion'), true);
    });

    test('knowledge_search 正常返回', () async {
      final result = await FunctionTools.executeTool('knowledge_search', {'query': '焦虑'});
      final json = jsonDecode(result);
      expect(json.containsKey('results'), true);
    });

    test('breathing_guide 正常返回', () async {
      final result = await FunctionTools.executeTool('breathing_guide', {'step': 1});
      final json = jsonDecode(result);
      expect(json.containsKey('guide'), true);
    });

    test('goodnight_quote 正常返回', () async {
      final result = await FunctionTools.executeTool('goodnight_quote', {});
      final json = jsonDecode(result);
      expect(json.containsKey('quote'), true);
    });

    test('未知工具返回错误', () async {
      final result = await FunctionTools.executeTool('unknown_tool', {});
      final json = jsonDecode(result);
      expect(json.containsKey('error'), true);
    });

    test('history_query 关键词为空时返回错误', () async {
      final result = await FunctionTools.executeTool('history_query', {'keyword': ''});
      final json = jsonDecode(result);
      expect(json.containsKey('error'), true);
    });

    test('knowledge_search 关键词为空时返回错误', () async {
      final result = await FunctionTools.executeTool('knowledge_search', {'query': ''});
      final json = jsonDecode(result);
      expect(json.containsKey('error'), true);
    });
  });
}
