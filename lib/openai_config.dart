import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIConfig {
  static String get apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static String get baseUrl => dotenv.env['OPENAI_BASE_URL'] ?? 'https://api.openai.com';
  static String get model => dotenv.env['OPENAI_MODEL'] ?? 'gpt-3.5-turbo';
  
  // 验证配置是否完整
  static bool get isConfigured => apiKey.isNotEmpty;
  static String get chatCompletionsEndpoint => '$baseUrl/v1/chat/completions';
}
