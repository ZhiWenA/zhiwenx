import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'chat_models.dart';
import 'openai_config.dart';

class OpenAIService {
  static const Duration _timeout = Duration(seconds: 30);

  /// 发送流式聊天请求到 OpenAI API
  static Stream<String> sendStreamChatRequest(List<ChatMessage> messages) async* {
    if (!OpenAIConfig.isConfigured) {
      throw Exception('OpenAI API 配置不完整，请检查 .env 文件');
    }

    final request = ChatRequest(
      model: OpenAIConfig.model,
      messages: messages,
      temperature: 0.7,
      maxTokens: 1000,
      stream: true,
    );

    try {
      final httpRequest = http.Request(
        'POST',
        Uri.parse(OpenAIConfig.chatCompletionsEndpoint),
      );
      
      httpRequest.headers.addAll({
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
        'Accept': 'text/event-stream',
      });
      
      httpRequest.body = jsonEncode(request.toJson());

      final streamedResponse = await http.Client().send(httpRequest);

      if (streamedResponse.statusCode == 200) {
        await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
          final lines = chunk.split('\n');
          
          for (final line in lines) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6).trim();
              
              if (data == '[DONE]') {
                return;
              }
              
              if (data.isNotEmpty) {
                try {
                  final jsonData = jsonDecode(data) as Map<String, dynamic>;
                  final choices = jsonData['choices'] as List?;
                  
                  if (choices != null && choices.isNotEmpty) {
                    final delta = choices[0]['delta'] as Map<String, dynamic>?;
                    final content = delta?['content'] as String?;
                    
                    if (content != null && content.isNotEmpty) {
                      yield content;
                    }
                  }
                } catch (e) {
                  // 忽略解析错误，继续处理下一行
                  continue;
                }
              }
            }
          }
        }
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        final errorData = jsonDecode(errorBody) as Map<String, dynamic>;
        final errorMessage = errorData['error']?['message'] ?? '未知错误';
        throw Exception('API 请求失败 (${streamedResponse.statusCode}): $errorMessage');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('请求超时，请检查网络连接');
      }
      rethrow;
    }
  }

  /// 发送非流式聊天请求到 OpenAI API（保留用于测试连接）
  static Future<ChatResponse> sendChatRequest(List<ChatMessage> messages) async {
    if (!OpenAIConfig.isConfigured) {
      throw Exception('OpenAI API 配置不完整，请检查 .env 文件');
    }

    final request = ChatRequest(
      model: OpenAIConfig.model,
      messages: messages,
      temperature: 0.7,
      maxTokens: 1000,
      stream: false,
    );

    try {
      final response = await http.post(
        Uri.parse(OpenAIConfig.chatCompletionsEndpoint),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
        },
        body: utf8.encode(jsonEncode(request.toJson())),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ChatResponse.fromJson(jsonData);
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final errorMessage = errorData['error']?['message'] ?? '未知错误';
        throw Exception('API 请求失败 (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('请求超时，请检查网络连接');
      }
      rethrow;
    }
  }

  /// 测试 API 连接
  static Future<bool> testConnection() async {
    try {
      final testMessages = [
        ChatMessage.system('你是一个有用的助手。'),
        ChatMessage.user('测试连接，请回复"连接成功"'),
      ];
      
      final response = await sendChatRequest(testMessages);
      return response.choices.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
