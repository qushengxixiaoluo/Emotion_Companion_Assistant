// 情绪知识库 - 主文件
// 导入6类知识条目并合并为统一列表

import 'emotion_knowledge_entry.dart';
import 'emotion_knowledge_sadness.dart';
import 'emotion_knowledge_anxiety.dart';
import 'emotion_knowledge_anger.dart';
import 'emotion_knowledge_loneliness.dart';
import 'emotion_knowledge_suppression.dart';
import 'emotion_knowledge_happiness.dart';

/// 完整的情绪知识库（210 条目：6类 ×35条）
final List<EmotionKnowledgeEntry> emotionKnowledgeBase = [
  ...sadnessEntries,
  ...anxietyEntries,
  ...angerEntries,
  ...lonelinessEntries,
  ...suppressionEntries,
  ...happinessEntries,
];
