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

  Map<String, dynamic> toJson() => {
        'id': id,
        'scenario': scenario,
        'emotionTags': emotionTags,
        'strategies': strategies,
        'contextTags': contextTags,
      };

  factory EmotionKnowledgeEntry.fromJson(Map<String, dynamic> json) => EmotionKnowledgeEntry(
        id: json['id'] as String,
        scenario: json['scenario'] as String,
        emotionTags: (json['emotionTags'] as List).cast<String>(),
        strategies: (json['strategies'] as List).cast<String>(),
        contextTags: (json['contextTags'] as List).cast<String>(),
      );
}
