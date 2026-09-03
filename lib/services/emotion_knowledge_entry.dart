// 情绪知识条目数据模型

/// 情绪知识条目
class EmotionKnowledgeEntry {
  final String id;
  final String scenario;
  final List<String> emotionTags;
  final List<String> strategies;
  final List<String> contextTags;

  const EmotionKnowledgeEntry({
    required this.id,
    required this.scenario,
    required this.emotionTags,
    required this.strategies,
    required this.contextTags,
  });
}
