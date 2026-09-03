import 'dart:convert';
import 'dart:developer' as developer;
import 'emotion_service.dart';
import 'ai_comfort_service.dart';
import 'storage_service.dart';

class FunctionTools {
  static const List<Map<String, dynamic>> toolDefinitions = [
    {
      'type': 'function',
      'function': {
        'name': 'emotion_analysis',
        'description': '分析用户文本的情绪状态，返回7维度评分',
        'parameters': {
          'type': 'object',
          'properties': {
            'text': {'type': 'string', 'description': '需要分析情绪的用户文本'}
          },
          'required': ['text']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'knowledge_search',
        'description': '搜索心理健康知识库',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': '搜索关键词'}
          },
          'required': ['query']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'history_query',
        'description': '查询用户过往的对话历史摘要',
        'parameters': {
          'type': 'object',
          'properties': {
            'keyword': {'type': 'string', 'description': '搜索关键词'}
          },
          'required': ['keyword']
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'breathing_guide',
        'description': '提供深呼吸引导',
        'parameters': {
          'type': 'object',
          'properties': {
            'step': {'type': 'integer', 'description': '步骤编号'}
          },
          'required': []
        }
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'goodnight_quote',
        'description': '获取温暖的晚安语录',
        'parameters': {'type': 'object', 'properties': {}, 'required': []}
      }
    },
    {
      'type': 'function',
      'function': {
        'name': 'weather_query',
        'description': '查询指定城市和日期的天气状况',
        'parameters': {
          'type': 'object',
          'properties': {
            'city': {'type': 'string', 'description': '城市名称'},
            'date': {'type': 'string', 'description': '日期'}
          },
          'required': ['city']
        }
      }
    },
  ];

  static Future<String> executeTool(String toolName, Map<String, dynamic> args) async {
    developer.log('【FunctionTool】执行工具: $toolName, 参数: $args');
    switch (toolName) {
      case 'emotion_analysis':
        return _handleEmotionAnalysis(args);
      case 'knowledge_search':
        return _handleKnowledgeSearch(args);
      case 'history_query':
        return _handleHistoryQuery(args);
      case 'breathing_guide':
        return _handleBreathingGuide(args);
      case 'goodnight_quote':
        return _handleGoodnightQuote();
      case 'weather_query':
        return _handleWeatherQuery(args);
      default:
        return jsonEncode({'error': '未知工具: $toolName'});
    }
  }

  static Future<String> _handleEmotionAnalysis(Map<String, dynamic> args) async {
    final text = args['text'] as String? ?? '';
    if (text.isEmpty) return jsonEncode({'error': '文本不能为空'});
    final service = EmotionService();
    final record = service.analyze(text);
    return jsonEncode({
      'sadness': record.sadness, 'anxiety': record.anxiety,
      'anger': record.anger, 'loneliness': record.loneliness,
      'happiness': record.happiness, 'calmness': record.calmness,
      'suppression': record.suppression, 'dominantEmotion': record.dominantEmotion,
    });
  }

  static Future<String> _handleKnowledgeSearch(Map<String, dynamic> args) async {
    final query = args['query'] as String? ?? '';
    if (query.isEmpty) return jsonEncode({'error': '搜索关键词不能为空'});
    const knowledgeBase = {
      '失眠': ['失眠常与焦虑、压力有关。建议：1. 睡前1小时远离电子设备；2. 尝试4-7-8呼吸法；3. 保持规律作息。'],
      '焦虑': ['焦虑是正常情绪反应。缓解方法：1. 深呼吸；2. 正念冥想；3. 适度运动；4. 写下担忧。'],
      '抑郁': ['持续情绪低落值得关注。自我关怀：1. 保持基本作息；2. 与信任的人倾诉；3. 做简单运动。'],
      '压力': ['压力管理：1. 分解大任务为小步骤；2. 学会说不；3. 定期休息；4. 保持社交连接。'],
      '情绪管理': ['情绪管理三步法：1. 觉察；2. 接纳；3. 行动——选择健康应对方式。'],
      '呼吸': ['4-7-8呼吸法：吸气4秒→屏息7秒→呼气8秒。重复3-4轮。'],
      '冥想': ['正念冥想入门：1. 找安静地方；2. 闭眼关注呼吸；3. 注意力漂走时温柔拉回。'],
    };
    final results = <String>[];
    for (final entry in knowledgeBase.entries) {
      if (query.contains(entry.key) || entry.key.contains(query)) results.addAll(entry.value);
    }
    if (results.isEmpty) return jsonEncode({'results': [], 'message': '未找到相关知识。'});
    return jsonEncode({'query': query, 'results': results});
  }

  static Future<String> _handleHistoryQuery(Map<String, dynamic> args) async {
    final keyword = args['keyword'] as String? ?? '';
    if (keyword.isEmpty) return jsonEncode({'error': '关键词不能为空'});
    final storageService = StorageService();
    final summaries = await storageService.searchSummaries(keyword);
    if (summaries.isEmpty) return jsonEncode({'keyword': keyword, 'results': [], 'message': '未找到相关历史记录。'});
    final results = summaries.take(5).map((s) => {
      'summary': s.summary, 'emotionTags': s.emotionTags, 'date': s.createdAt.toIso8601String(),
    }).toList();
    return jsonEncode({'keyword': keyword, 'count': results.length, 'results': results});
  }

  static Future<String> _handleBreathingGuide(Map<String, dynamic> args) async {
    final step = args['step'] as int? ?? 0;
    final service = AiComfortService();
    final guide = service.getBreathGuide(step);
    return jsonEncode({'step': step, 'guide': guide, 'instruction': '请跟随引导语进行深呼吸练习。'});
  }

  static Future<String> _handleGoodnightQuote() async {
    final service = AiComfortService();
    return jsonEncode({'quote': service.getGoodnightWord()});
  }

  static Future<String> _handleWeatherQuery(Map<String, dynamic> args) async {
    final city = args['city'] as String? ?? '未知';
    final date = args['date'] as String? ?? '今天';
    return jsonEncode({
      'city': city, 'date': date, 'temperature': -15, 'weather': '大雪',
      'wind': '北风3级', 'humidity': '85%',
      'suggestion': '天气寒冷，注意保暖，减少外出。大雪天气路滑，出行请注意安全。',
    });
  }
}
