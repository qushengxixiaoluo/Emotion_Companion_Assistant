/// 一套大模型配置档案（多套并存，可随时切换）。
///
/// 存储在 settings box 的 `llm_profiles` 键（JSON 数组字符串）中；
/// 切换时通过 `StorageService.applyLlmProfile` 写回 legacy 键
/// （`llm_base_url` / `llm_api_key` / `llm_model` / `llm_api_format`），
/// 使 LlmService 等现有读取方零改动即生效。
class LlmProfile {
  String id; // 时间戳字符串即可
  String name; // 用户起的名称，如 "DeepSeek"
  String baseUrl;
  String apiKey;
  String model;

  /// API 格式：'openai'（OpenAI 兼容，默认）| 'anthropic'（Anthropic 原生）
  String apiFormat;

  LlmProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.apiFormat = 'openai',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'apiFormat': apiFormat,
      };

  factory LlmProfile.fromJson(Map<String, dynamic> json) => LlmProfile(
        id: (json['id'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        baseUrl: (json['baseUrl'] ?? '') as String,
        apiKey: (json['apiKey'] ?? '') as String,
        model: (json['model'] ?? '') as String,
        // 旧档案没有该字段 → 默认 OpenAI 兼容
        apiFormat: (json['apiFormat'] ?? 'openai') as String,
      );
}
