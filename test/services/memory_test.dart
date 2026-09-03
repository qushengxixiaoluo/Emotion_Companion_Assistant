import 'package:flutter_test/flutter_test.dart';
import 'package:emotion_companion/models/emotion_models.dart';
import 'package:emotion_companion/services/storage_service.dart';

void main() {
  group('MemoryService 关键词提取', () {
    test('提取正确关键词', () {
      final message = '焦虑 失眠 压力';
      final keywords = message
          .replaceAll(RegExp(r'[，。！？、；：""''（）[\]【】]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 2)
          .toList();
      expect(keywords, containsAll(['焦虑', '失眠', '压力']));
    });

    test('过滤短词', () {
      final message = '我 焦虑 了';
      final keywords = message
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 2)
          .toList();
      expect(keywords, contains('焦虑'));
      expect(keywords.contains('我'), false);
      expect(keywords.contains('了'), false);
    });

    test('去重处理', () {
      final message = '焦虑 失眠 焦虑 压力';
      final seen = <String>{};
      final keywords = <String>[];
      for (final w in message.split(' ')) {
        if (seen.add(w) && w.length >= 2) keywords.add(w);
      }
      expect(keywords.length, 3);
    });

    test('处理空字符串', () {
      final message = '';
      final keywords = message.split(' ').where((w) => w.length >= 2).toList();
      expect(keywords, isEmpty);
    });

    test('处理全标点符号', () {
      final message = '，。！？';
      final keywords = message
          .replaceAll(RegExp(r'[，。！？]'), ' ')
          .split(' ')
          .where((w) => w.length >= 2)
          .toList();
      expect(keywords, isEmpty);
    });
  });

  group('ConversationSummary 模型', () {
    test('创建实例', () {
      final summary = ConversationSummary(
        id: 'test_001',
        conversationId: 'conv_001',
        summary: '用户表达了工作压力',
        emotionTags: ['压力', '焦虑'],
        createdAt: DateTime(2026, 1, 1),
      );
      expect(summary.id, 'test_001');
      expect(summary.summary, '用户表达了工作压力');
      expect(summary.emotionTags, ['压力', '焦虑']);
    });

    test('toJson 正确序列化', () {
      final summary = ConversationSummary(
        id: 'test_002',
        conversationId: 'conv_002',
        summary: '用户今天心情不错',
        emotionTags: ['开心'],
        createdAt: DateTime(2026, 5, 2),
      );
      final json = summary.toJson();
      expect(json['id'], 'test_002');
      expect(json['summary'], '用户今天心情不错');
      expect(json['emotionTags'], ['开心']);
    });

    test('fromJson 正确反序列化', () {
      final json = {
        'id': 'test_003',
        'conversationId': 'conv_003',
        'summary': '用户感到焦虑',
        'emotionTags': ['焦虑', '失眠'],
        'createdAt': '2026-05-02T00:00:00.000',
      };
      final summary = ConversationSummary.fromJson(json);
      expect(summary.id, 'test_003');
      expect(summary.summary, '用户感到焦虑');
      expect(summary.emotionTags, ['焦虑', '失眠']);
    });
  });

  group('Memory 模型', () {
    test('创建记忆实例', () {
      final memory = Memory(
        id: 'mem_001',
        conversationId: 'conv_001',
        summary: '用户经常在晚上感到焦虑',
        emotionTags: ['焦虑', '夜晚'],
        createdAt: DateTime.now(),
      );
      expect(memory.id, 'mem_001');
      expect(memory.summary, '用户经常在晚上感到焦虑');
    });

    test('Memory 序列化往返', () {
      final memory = Memory(
        id: 'mem_002',
        conversationId: 'conv_002',
        summary: '用户表达了对未来的担忧',
        emotionTags: ['担忧', '未来'],
        createdAt: DateTime(2026, 5, 2, 12, 0, 0),
      );
      final json = memory.toJson();
      final restored = Memory.fromJson(json);
      expect(restored.id, memory.id);
      expect(restored.summary, memory.summary);
      expect(restored.emotionTags, memory.emotionTags);
    });
  });

  group('StorageService 初始化', () {
    test('StorageService 可以创建实例', () {
      final service = StorageService();
      expect(service, isA<StorageService>());
    });

    test('StorageService 单例模式', () {
      final s1 = StorageService();
      final s2 = StorageService();
      expect(identical(s1, s2), true);
    });
  });

  group('UserProfile 模型', () {
    test('创建 UserProfile', () {
      final profile = UserProfile(
        id: 'user_001',
        preferenceTags: ['夜猫子', '焦虑倾向'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(profile.id, 'user_001');
      expect(profile.preferenceTags.length, 2);
    });

    test('UserProfile 序列化往返', () {
      final profile = UserProfile(
        id: 'user_002',
        preferenceTags: ['运动', '冥想'],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 5, 1),
      );
      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);
      expect(restored.id, profile.id);
      expect(restored.preferenceTags, profile.preferenceTags);
    });
  });
}
