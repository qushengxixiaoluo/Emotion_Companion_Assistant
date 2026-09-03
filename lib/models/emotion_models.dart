class EmotionRecord {
  final String id;
  final String content;
  final double sadness;
  final double anxiety;
  final double anger;
  final double loneliness;
  final double happiness;
  final double calmness;
  final double suppression;
  final String dominantEmotion;
  final DateTime createdAt;
  final String interpretation;
  final List<String> suggestions;

  EmotionRecord({
    required this.id,
    required this.content,
    this.sadness = 0,
    this.anxiety = 0,
    this.anger = 0,
    this.loneliness = 0,
    this.happiness = 0,
    this.calmness = 0,
    this.suppression = 0,
    this.dominantEmotion = '平静',
    required this.createdAt,
    this.interpretation = '',
    this.suggestions = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'sadness': sadness,
        'anxiety': anxiety,
        'anger': anger,
        'loneliness': loneliness,
        'happiness': happiness,
        'calmness': calmness,
        'suppression': suppression,
        'dominantEmotion': dominantEmotion,
        'createdAt': createdAt.toIso8601String(),
        'interpretation': interpretation,
        'suggestions': suggestions,
      };

  factory EmotionRecord.fromJson(Map<String, dynamic> json) => EmotionRecord(
        id: json['id'],
        content: json['content'],
        sadness: (json['sadness'] ?? 0).toDouble(),
        anxiety: (json['anxiety'] ?? 0).toDouble(),
        anger: (json['anger'] ?? 0).toDouble(),
        loneliness: (json['loneliness'] ?? 0).toDouble(),
        happiness: (json['happiness'] ?? 0).toDouble(),
        calmness: (json['calmness'] ?? 0).toDouble(),
        suppression: (json['suppression'] ?? 0).toDouble(),
        dominantEmotion: json['dominantEmotion'] ?? '平静',
        createdAt: DateTime.parse(json['createdAt']),
        interpretation: json['interpretation'] ?? '',
        suggestions: (json['suggestions'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}

class DreamRecord {
  final String id;
  final String dreamText;
  final String analysis;
  final String title;
  final DateTime createdAt;

  DreamRecord({
    required this.id,
    required this.dreamText,
    required this.analysis,
    required this.title,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dreamText': dreamText,
        'analysis': analysis,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DreamRecord.fromJson(Map<String, dynamic> json) => DreamRecord(
        id: json['id'],
        dreamText: json['dreamText'],
        analysis: json['analysis'],
        title: json['title'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime createdAt;
  final String emotion;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.createdAt,
    this.emotion = '平静',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'isUser': isUser,
        'createdAt': createdAt.toIso8601String(),
        'emotion': emotion,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'],
        content: json['content'],
        isUser: json['isUser'],
        createdAt: DateTime.parse(json['createdAt']),
        emotion: json['emotion'] ?? '平静',
      );
}

class Conversation {
  final String id;
  String title;
  List<ChatMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;

  Conversation({
    required this.id,
    this.title = '新对话',
    this.messages = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'],
        title: json['title'] ?? '新对话',
        messages: (json['messages'] as List<dynamic>?)
                ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );
}

/// 用户画像（长期记忆）
class UserProfile {
  final String id;
  List<String> preferenceTags;
  final DateTime createdAt;
  DateTime updatedAt;

  UserProfile({
    required this.id,
    this.preferenceTags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'preferenceTags': preferenceTags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'],
        preferenceTags: (json['preferenceTags'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );
}

/// 对话摘要（情景记忆）
class ConversationSummary {
  final String id;
  final String conversationId;
  final String summary;
  final List<String> emotionTags;
  final DateTime createdAt;

  ConversationSummary({
    required this.id,
    required this.conversationId,
    required this.summary,
    this.emotionTags = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'summary': summary,
        'emotionTags': emotionTags,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ConversationSummary.fromJson(Map<String, dynamic> json) => ConversationSummary(
        id: json['id'],
        conversationId: json['conversationId'],
        summary: json['summary'],
        emotionTags: (json['emotionTags'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: DateTime.parse(json['createdAt']),
      );
}
