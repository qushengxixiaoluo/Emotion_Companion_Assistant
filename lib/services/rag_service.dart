import 'emotion_knowledge_entry.dart';
import 'emotion_knowledge.dart';

class RagService {
  static final RagService _instance = RagService._();
  factory RagService() => _instance;
  RagService._();

  List<EmotionKnowledgeEntry> search(String userMessage) {
    List<MapEntry<EmotionKnowledgeEntry, int>> scoredEntries = [];

    for (final entry in emotionKnowledgeBase) {
      int score = 0;
      for (final tag in entry.contextTags) {
        if (userMessage.contains(tag)) score += 3;
      }
      for (final tag in entry.emotionTags) {
        if (userMessage.contains(tag)) score += 2;
      }
      final userChars = userMessage.split('');
      for (final ch in userChars) {
        if (ch.length == 1 && entry.scenario.contains(ch)) score += 1;
      }
      scoredEntries.add(MapEntry(entry, score));
    }

    final maxScore = scoredEntries.isEmpty
        ? 0
        : scoredEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    if (maxScore == 0) {
      return emotionKnowledgeBase
          .where((e) => e.emotionTags.contains('平静'))
          .take(5)
          .toList();
    }

    scoredEntries.sort((a, b) => b.value.compareTo(a.value));
    return scoredEntries.take(5).map((e) => e.key).toList();
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
