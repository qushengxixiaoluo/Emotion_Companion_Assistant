import 'dart:developer' as developer;
import '../llm_service.dart';
import '../emotion_service.dart';

/// 情绪分析 Agent
class EmotionAgent {
  final LlmService _llm = LlmService();
  final EmotionService _localEmotion = EmotionService();

  Future<Map<String, dynamic>> analyze(String userMessage) async {
    if (_llm.isConfigured()) {
      try {
        final result = await _llm.analyzeEmotionWithConsistency(userMessage);
        if (result != null) {
          result['source'] = 'llm_consistency';
          developer.log('【情绪Agent】Self-Consistency 分析成功');
          return result;
        }
      } catch (e) {
        developer.log('【情绪Agent】Self-Consistency 失败: $e');
      }

      try {
        final result = await _llm.analyzeEmotion(userMessage, enableCoT: true);
        if (result != null) {
          result['source'] = 'llm';
          developer.log('【情绪Agent】单次 LLM 分析成功');
          return result;
        }
      } catch (e) {
        developer.log('【情绪Agent】单次 LLM 分析失败: $e');
      }
    }

    return _localFallback(userMessage);
  }

  Map<String, dynamic> _localFallback(String userMessage) {
    developer.log('【情绪Agent】降级到本地关键词分析');
    final record = _localEmotion.analyze(userMessage);

    return {
      'sadness': record.sadness,
      'anxiety': record.anxiety,
      'anger': record.anger,
      'loneliness': record.loneliness,
      'happiness': record.happiness,
      'calmness': record.calmness,
      'suppression': record.suppression,
      'dominantEmotion': record.dominantEmotion,
      'interpretation': '',
      'suggestions': <String>[],
      'source': 'local',
    };
  }
}
