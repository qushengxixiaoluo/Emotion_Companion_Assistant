import 'package:flutter_test/flutter_test.dart';
import 'package:emotion_companion/services/emotion_knowledge_entry.dart';
import 'package:emotion_companion/services/emotion_knowledge.dart';

void main() {
  group('EmotionKnowledgeEntry 数据类', () {
    test('创建实例包含所有字段', () {
      final entry = EmotionKnowledgeEntry(
        id: 'test_01', scenario: '测试场景',
        emotionTags: ['开心', '快乐'], strategies: ['策略1', '策略2'],
        contextTags: ['工作', '学习'],
      );
      expect(entry.id, 'test_01');
      expect(entry.scenario, '测试场景');
      expect(entry.emotionTags, ['开心', '快乐']);
      expect(entry.strategies, ['策略1', '策略2']);
      expect(entry.contextTags, ['工作', '学习']);
    });

    test('toJson 转换正确', () {
      final entry = EmotionKnowledgeEntry(
        id: 'test_02', scenario: '场景B',
        emotionTags: ['焦虑'], strategies: ['深呼吸'],
        contextTags: ['压力'],
      );
      final json = entry.toJson();
      expect(json['id'], 'test_02');
      expect(json['scenario'], '场景B');
      expect(json['emotionTags'], ['焦虑']);
      expect(json['strategies'], ['深呼吸']);
      expect(json['contextTags'], ['压力']);
    });

    test('fromJson 还原正确', () {
      final json = {
        'id': 'test_03', 'scenario': '场景C',
        'emotionTags': ['愤怒'], 'strategies': ['冷静'],
        'contextTags': ['冲突'],
      };
      final entry = EmotionKnowledgeEntry.fromJson(json);
      expect(entry.id, 'test_03');
      expect(entry.scenario, '场景C');
      expect(entry.emotionTags, ['愤怒']);
      expect(entry.strategies, ['冷静']);
      expect(entry.contextTags, ['冲突']);
    });

    test('scenario 长度限制 ≤ 100', () {
      for (final entry in emotionKnowledgeBase) {
        expect(entry.scenario.length, lessThanOrEqualTo(100), reason: '${entry.id} scenario 超长');
      }
    });

    test('每个条目有 emotionTags 和 strategies', () {
      for (final entry in emotionKnowledgeBase) {
        expect(entry.emotionTags.isNotEmpty, true, reason: '${entry.id} 缺少 emotionTags');
        expect(entry.strategies.isNotEmpty, true, reason: '${entry.id} 缺少 strategies');
      }
    });

    test('ID 前缀与分类一致', () {
      final validPrefixes = ['sadness', 'anxiety', 'anger', 'loneliness', 'suppression', 'happiness'];
      for (final entry in emotionKnowledgeBase) {
        final prefix = entry.id.split('_').first;
        expect(validPrefixes.contains(prefix), true, reason: '${entry.id} 前缀不匹配');
      }
    });
  });

  group('情感知识库合并', () {
    test('总计 210 条知识条目', () {
      expect(emotionKnowledgeBase.length, 210);
    });

    test('每类恰好 35 条', () {
      final counts = <String, int>{};
      for (final e in emotionKnowledgeBase) {
        final prefix = e.id.split('_').first;
        counts[prefix] = (counts[prefix] ?? 0) + 1;
      }
      for (final prefix in ['sadness', 'anxiety', 'anger', 'loneliness', 'suppression', 'happiness']) {
        expect(counts[prefix], 35, reason: '$prefix 应有 35 条');
      }
    });

    test('无重复 ID', () {
      final ids = emotionKnowledgeBase.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('所有条目可序列化', () {
      for (final entry in emotionKnowledgeBase) {
        final json = entry.toJson();
        final restored = EmotionKnowledgeEntry.fromJson(json);
        expect(restored.id, entry.id);
        expect(restored.scenario, entry.scenario);
        expect(restored.emotionTags, entry.emotionTags);
        expect(restored.strategies, entry.strategies);
        expect(restored.contextTags, entry.contextTags);
      }
    });

    test('每类有标准情绪标签', () {
      final expectedLabels = {
        'sadness': '悲伤', 'anxiety': '焦虑', 'anger': '愤怒',
        'loneliness': '孤独', 'suppression': '压抑', 'happiness': '快乐',
      };
      for (final prefix in expectedLabels.keys) {
        final entries = emotionKnowledgeBase.where((e) => e.id.startsWith(prefix)).toList();
        final allTags = entries.expand((e) => e.emotionTags).toSet();
        expect(allTags.contains(expectedLabels[prefix]), true, reason: '$prefix 缺少情绪标签 ${expectedLabels[prefix]}');
      }
    });

    test('每个条目有 contextTags', () {
      for (final entry in emotionKnowledgeBase) {
        expect(entry.contextTags.isNotEmpty, true, reason: '${entry.id} 缺少 contextTags');
      }
    });

    test('每个条目有至少 2 个策略', () {
      for (final entry in emotionKnowledgeBase) {
        expect(entry.strategies.length, greaterThanOrEqualTo(2), reason: '${entry.id} 策略不足');
      }
    });

    test('ID 格式统一为 prefix_NN', () {
      final regex = RegExp(r'^(sadness|anxiety|anger|loneliness|suppression|happiness)_\d+$');
      for (final entry in emotionKnowledgeBase) {
        expect(regex.hasMatch(entry.id), true, reason: '${entry.id} 格式不正确');
      }
    });

    test('toJson/fromJson 完整往返', () {
      final entry = emotionKnowledgeBase.first;
      final json = entry.toJson();
      final restored = EmotionKnowledgeEntry.fromJson(json);
      expect(restored.toJson(), json);
    });

    test('每类标签包含核心关键词', () {
      final coreKeywords = {
        'sadness': ['悲伤', '失落'],
        'anxiety': ['焦虑', '紧张'],
        'anger': ['愤怒', '不满'],
        'loneliness': ['孤独', '寂寞'],
        'suppression': ['压抑', '隐忍'],
        'happiness': ['快乐', '满足'],
      };
      for (final prefix in coreKeywords.keys) {
        final entries = emotionKnowledgeBase.where((e) => e.id.startsWith(prefix)).toList();
        final allTags = entries.expand((e) => e.emotionTags).toSet();
        bool hasKeyword = coreKeywords[prefix]!.any((kw) => allTags.contains(kw));
        expect(hasKeyword, true, reason: '$prefix 缺少核心关键词');
      }
    });
  });
}
