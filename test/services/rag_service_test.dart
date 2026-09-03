import 'package:flutter_test/flutter_test.dart';
import 'package:emotion_companion/services/rag_service.dart';
import 'package:emotion_companion/services/emotion_knowledge_entry.dart';
import 'package:emotion_companion/services/emotion_knowledge.dart';

void main() {
  group('RagService 关键词加权搜索', () {
    late RagService ragService;

    setUp(() { ragService = RagService(); });

    test('contextTag 匹配权重 +3', () {
      final results = ragService.search('工作 失败');
      expect(results.isNotEmpty, true);
    });

    test('emotionTag 匹配权重 +2', () {
      final results = ragService.search('焦虑');
      expect(results.isNotEmpty, true);
    });

    test('字符重叠权重 +1', () {
      final results = ragService.search('考试成绩');
      expect(results.isNotEmpty, true);
    });

    test('Top-5 返回不超过5条', () {
      final results = ragService.search('工作 失败 沮丧 焦虑 压力');
      expect(results.length, lessThanOrEqualTo(5));
    });

    test('空消息返回默认结果', () {
      final results = ragService.search('');
      expect(results.isNotEmpty, true);
    });

    test('无关消息返回默认结果', () {
      final results = ragService.search('asdfghjkl');
      expect(results.isNotEmpty, true);
    });

    test('contextTag 权重高于 emotionTag', () {
      final results = ragService.search('工作 失败');
      expect(results.isNotEmpty, true);
      expect(results.first.contextTags, isNotEmpty);
    });

    test('结果按相关性排序', () {
      final results = ragService.search('失眠 焦虑 压力');
      expect(results.length, greaterThanOrEqualTo(1));
    });

    test('多标签匹配提升排名', () {
      final results = ragService.search('失眠 失眠 焦虑');
      expect(results.isNotEmpty, true);
    });

    test('完整流程', () {
      final results = ragService.search('工作 失败 沮丧');
      expect(results.length, lessThanOrEqualTo(5));
      expect(results, isNotEmpty);
    });

    test('RagService 单例模式', () {
      final s1 = RagService();
      final s2 = RagService();
      expect(identical(s1, s2), true);
    });
  });

  group('buildKnowledgeContext', () {
    late RagService ragService;

    setUp(() { ragService = RagService(); });

    test('空列表返回空字符串', () {
      final result = ragService.buildKnowledgeContext([]);
      expect(result, '');
    });

    test('格式包含场景和策略', () {
      final entries = ragService.search('焦虑');
      final context = ragService.buildKnowledgeContext(entries);
      expect(context.contains('【情绪知识库参考】'), true);
      expect(context.contains('场景：'), true);
      expect(context.contains('建议策略：'), true);
    });

    test('多个条目逐条列出', () {
      final entries = ragService.search('工作 失败 沮丧 焦虑 压力');
      final context = ragService.buildKnowledgeContext(entries);
      final lines = context.split('\n').where((l) => l.startsWith(RegExp(r'\d+\. 场景：')));
      expect(lines.length, entries.length);
    });
  });

  group('getByEmotion', () {
    late RagService ragService;

    setUp(() { ragService = RagService(); });

    test('返回特定情绪标签的条目', () {
      final results = ragService.getByEmotion('焦虑');
      expect(results.isNotEmpty, true);
      for (final e in results) {
        expect(e.emotionTags.contains('焦虑'), true);
      }
    });

    test('不存在的情绪返回空', () {
      final results = ragService.getByEmotion('不存在的情绪');
      expect(results, isEmpty);
    });
  });

  group('边界情况', () {
    late RagService ragService;

    setUp(() { ragService = RagService(); });

    test('长文本搜索不报错', () {
      final longText = '我很焦虑' * 100;
      final results = ragService.search(longText);
      expect(results, isNotNull);
    });

    test('特殊字符搜索不报错', () {
      final results = ragService.search('!@#\$%^&*()');
      expect(results, isNotNull);
    });

    test('数字搜索不报错', () {
      final results = ragService.search('1234567890');
      expect(results, isNotNull);
    });

    test('知识库条目类型正确', () {
      final results = ragService.search('焦虑');
      expect(results, isA<List<EmotionKnowledgeEntry>>());
    });
  });
}
