import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../models/emotion_models.dart';
import 'storage_service.dart';
import 'llm_service.dart';

class MemoryService {
  static final MemoryService _instance = MemoryService._();
  factory MemoryService() => _instance;
  MemoryService._();

  final StorageService _storage = StorageService();
  final LlmService _llm = LlmService();

  String _generateId(String content) {
    return md5.convert(utf8.encode('$content${DateTime.now().millisecondsSinceEpoch}')).toString();
  }

  Future<void> extractAndUpdateProfile(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    try {
      final conversationText = messages.where((m) => m.isUser).map((m) => '用户：${m.content}').join('\n');
      if (conversationText.isEmpty) return;

      final prompt = '''你是一位心理学分析助手。请从以下用户对话中提取3-5个用户偏好或特征标签。
要求：标签反映用户的情绪模式、行为习惯、沟通偏好等。只返回JSON格式：
{"tags": ["标签1", "标签2", "标签3"]}''';

      final response = await _callLlm(systemPrompt: prompt, userContent: '请分析以下对话：\n$conversationText');
      if (response == null || response.isEmpty) return;

      List<String> newTags = [];
      try {
        String jsonStr = response.trim();
        if (jsonStr.contains('```json')) jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        else if (jsonStr.contains('```')) jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        final result = jsonDecode(jsonStr) as Map<String, dynamic>;
        newTags = (result['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      } catch (_) { return; }

      if (newTags.isEmpty) return;
      UserProfile profile = await _storage.getUserProfile() ??
          UserProfile(id: _generateId('profile'), createdAt: DateTime.now(), updatedAt: DateTime.now());

      final existingTags = Set<String>.from(profile.preferenceTags);
      for (final tag in newTags) { if (!existingTags.contains(tag)) profile.preferenceTags.add(tag); }
      if (profile.preferenceTags.length > 15) profile.preferenceTags = profile.preferenceTags.sublist(profile.preferenceTags.length - 15);

      profile.updatedAt = DateTime.now();
      await _storage.saveUserProfile(profile);
    } catch (e) { developer.log('【记忆服务】提取用户画像异常: $e'); }
  }

  Future<UserProfile?> getCurrentProfile() async => await _storage.getUserProfile();

  Future<void> summarizeConversation(Conversation conv) async {
    if (conv.messages.isEmpty) return;
    try {
      final conversationText = conv.messages.map((m) => '${m.isUser ? "用户" : "AI"}：${m.content}').join('\n');
      final prompt = '''你是一位心理学分析助手。请为以下对话生成简短摘要。
要求：50字以内概括核心内容，提取1-3个情绪标签。只返回JSON：
{"summary": "摘要", "emotionTags": ["标签"]}''';

      final response = await _callLlm(systemPrompt: prompt, userContent: '请为以下对话生成摘要：\n$conversationText');
      if (response == null || response.isEmpty) return;

      String summary = '';
      List<String> emotionTags = [];
      try {
        String jsonStr = response.trim();
        if (jsonStr.contains('```json')) jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        else if (jsonStr.contains('```')) jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        final result = jsonDecode(jsonStr) as Map<String, dynamic>;
        summary = result['summary'] as String? ?? '';
        emotionTags = (result['emotionTags'] as List<dynamic>?)?.cast<String>() ?? [];
      } catch (_) { return; }

      if (summary.isEmpty) return;
      await _storage.saveSummary(ConversationSummary(
        id: _generateId(conv.id), conversationId: conv.id, summary: summary,
        emotionTags: emotionTags, createdAt: DateTime.now(),
      ));
    } catch (e) { developer.log('【记忆服务】生成摘要异常: $e'); }
  }

  Future<List<ConversationSummary>> retrieveRelevantMemories(String userMessage) async {
    try {
      final keywords = _extractKeywords(userMessage);
      if (keywords.isEmpty) return [];
      final allMatches = <ConversationSummary>[];
      for (final keyword in keywords) { allMatches.addAll(await _storage.searchSummaries(keyword)); }
      final seen = <String>{};
      final unique = allMatches.where((s) => seen.add(s.id)).toList();
      unique.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return unique.take(5).toList();
    } catch (e) { return []; }
  }

  Future<String> buildMemoryContext(String userMessage) async {
    final contextParts = <String>[];
    try {
      final profile = await getCurrentProfile();
      if (profile != null && profile.preferenceTags.isNotEmpty) contextParts.add('【用户画像】${profile.preferenceTags.join("、")}');
      final relevantMemories = await retrieveRelevantMemories(userMessage);
      if (relevantMemories.isNotEmpty) {
        final summariesText = relevantMemories.map((m) => '• ${m.summary}（${m.emotionTags.join("、")}）').join('\n');
        contextParts.add('【历史记忆】\n$summariesText');
      }
    } catch (_) {}
    return contextParts.isEmpty ? '' : contextParts.join('\n\n');
  }

  Future<String?> _callLlm({required String systemPrompt, required String userContent, int maxTokens = 256, double temperature = 0.3}) async {
    if (!_llm.isConfigured()) return null;
    try {
      final uri = Uri.parse('${_llm.baseUrl}/chat/completions');
      final response = await http.post(uri,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${_llm.apiKey}'},
        body: jsonEncode({'model': _llm.model, 'messages': [
          {'role': 'system', 'content': systemPrompt}, {'role': 'user', 'content': userContent},
        ], 'max_tokens': maxTokens, 'temperature': temperature}),
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['choices']?[0]?['message']?['content'] as String?)?.trim();
      }
      return null;
    } catch (e) { return null; }
  }

  List<String> _extractKeywords(String message) {
    final raw = message.replaceAll(RegExp(r'[，。！？、；：""''（）[\]【】]'), ' ').split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
    final seen = <String>{};
    final keywords = <String>[];
    for (final w in raw) { if (seen.add(w)) keywords.add(w); }
    return keywords.take(5).toList();
  }
}
