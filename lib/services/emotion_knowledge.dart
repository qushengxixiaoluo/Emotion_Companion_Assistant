// 情绪知识库 - 主文件
// 导入7类知识条目并合并为统一列表（与7维情绪模型一一对应）

import 'emotion_knowledge_entry.dart';
import 'emotion_knowledge_sadness.dart';
import 'emotion_knowledge_anxiety.dart';
import 'emotion_knowledge_anger.dart';
import 'emotion_knowledge_loneliness.dart';
import 'emotion_knowledge_suppression.dart';
import 'emotion_knowledge_happiness.dart';
import 'emotion_knowledge_calmness.dart';

/// 完整的情绪知识库（245 条目：7类 ×35条）
final List<EmotionKnowledgeEntry> emotionKnowledgeBase = [
  ...sadnessEntries,
  ...anxietyEntries,
  ...angerEntries,
  ...lonelinessEntries,
  ...suppressionEntries,
  ...happinessEntries,
  ...calmnessEntries,
];
