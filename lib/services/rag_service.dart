import 'emotion_knowledge_entry.dart';
import 'emotion_knowledge.dart';

class RagService {
  static final RagService _instance = RagService._();
  factory RagService() => _instance;
  RagService._();

  List<EmotionKnowledgeEntry> search(String userMessage) {
    List<MapEntry<EmotionKnowledgeEntry, int>> scoredEntries = [];

    // 查询片段：按空白/中英文标点切分，用于标签双向命中
    final fragments = userMessage
        .replaceAll(RegExp(r'[，。！？、；：""''（）[\]【】,!?;:：，]'), ' ')
        .split(RegExp(r'\s+'))
        .where((f) => f.isNotEmpty)
        .toList();
    // 查询 2-gram（按片段切，避免跨片段噪声词），用于与 scenario 文本做重叠计分
    final queryGrams = <String>{};
    for (final f in fragments) {
      for (var i = 0; i < f.length - 1; i++) {
        queryGrams.add(f.substring(i, i + 2));
      }
    }

    for (final entry in emotionKnowledgeBase) {
      int score = 0;
      // contextTag 命中 +3（权重最高）
      for (final tag in entry.contextTags) {
        if (_tagHit(fragments, tag)) score += 3;
      }
      // emotionTag 命中 +2
      for (final tag in entry.emotionTags) {
        if (_tagHit(fragments, tag)) score += 2;
      }
      // scenario 与查询的 2-gram 重叠数 ×1，封顶 +4，防止长场景刷分
      // （替代原先的逐字符 +1——常用字必然命中，接近随机）
      if (queryGrams.isNotEmpty) {
        final scenarioGrams = <String>{};
        final scenario = entry.scenario.replaceAll(RegExp(r'\s+'), '');
        for (var i = 0; i < scenario.length - 1; i++) {
          scenarioGrams.add(scenario.substring(i, i + 2));
        }
        final overlap = scenarioGrams.intersection(queryGrams).length;
        score += overlap > 4 ? 4 : overlap;
      }
      scoredEntries.add(MapEntry(entry, score));
    }

    final maxScore = scoredEntries.isEmpty
        ? 0
        : scoredEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    if (maxScore == 0) {
      // 空查询 / 无任何命中的兜底：返回"平静"类条目
      return emotionKnowledgeBase
          .where((e) => e.emotionTags.contains('平静'))
          .take(5)
          .toList();
    }

    scoredEntries.sort((a, b) => b.value.compareTo(a.value));
    return scoredEntries.take(5).map((e) => e.key).toList();
  }

  /// 双向标签命中：查询片段含 tag，或 tag 含查询片段
  bool _tagHit(List<String> fragments, String tag) {
    for (final f in fragments) {
      if (f.contains(tag) || tag.contains(f)) return true;
    }
    return false;
  }

  String buildKnowledgeContext(List<EmotionKnowledgeEntry> entries) {
    if (entries.isEmpty) return '';
    final buffer = StringBuffer('【情绪知识库参考】\n');
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.writeln('${i + 1}. 场景：${entry.scenario}');
      buffer.writeln('   情绪标签：${entry.emotionTags.join("、")}');
      buffer.writeln('   建议策略：${entry.strategies.join("；")}');
      buffer.writeln();
    }
    return buffer.toString();
  }

  List<EmotionKnowledgeEntry> getByEmotion(String emotion) {
    return emotionKnowledgeBase
        .where((e) => e.emotionTags.contains(emotion))
        .toList();
  }
}
