import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'chat_models.dart';
import 'openai_config.dart';

class OpenAIService {
  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 2);
  static final Logger _logger = Logger('OpenAIService');

  /// 发送流式聊天请求到 OpenAI API（带重试机制）
  static Stream<String> sendStreamChatRequest(List<ChatMessage> messages) async* {
    if (!OpenAIConfig.isConfigured) {
      throw Exception('OpenAI API 配置不完整，请检查 .env 文件');
    }

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        yield* _attemptStreamRequest(messages);
        return; // 成功则退出重试循环
      } catch (e) {
        _logger.warning('Stream request attempt ${attempt + 1} failed: $e');
        
        if (attempt == _maxRetries - 1) {
          // 最后一次尝试失败，抛出异常
          throw _formatError(e);
        }
        
        // 等待后重试（指数退避）
        final delay = _baseRetryDelay * pow(2, attempt);
        await Future.delayed(delay);
        _logger.info('Retrying stream request in ${delay.inSeconds} seconds...');
      }
    }
  }

  /// 实际执行流式请求
  static Stream<String> _attemptStreamRequest(List<ChatMessage> messages) async* {
    final request = ChatRequest(
      model: OpenAIConfig.model,
      messages: messages,
      temperature: 0.7,
      maxTokens: 1500, // 增加token限制
      stream: true,
    );

    final httpRequest = http.Request(
      'POST',
      Uri.parse(OpenAIConfig.chatCompletionsEndpoint),
    );
    
    httpRequest.headers.addAll({
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
      'Accept': 'text/event-stream',
      'User-Agent': 'ZhiwenX-Flutter-App/1.0',
    });
    
    httpRequest.body = jsonEncode(request.toJson());

    final client = http.Client();
    try {
      final streamedResponse = await client.send(httpRequest).timeout(_timeout);

      if (streamedResponse.statusCode == 200) {
        bool hasContent = false;
        await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
          final lines = chunk.split('\n');
          
          for (final line in lines) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6).trim();
              
              if (data == '[DONE]') {
                if (!hasContent) {
                  throw Exception('API返回空响应，请重试');
                }
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
                      hasContent = true;
                      yield content;
                    }
                  }
                } catch (e) {
                  _logger.warning('Failed to parse stream data: $e');
                  continue;
                }
              }
            }
          }
        }
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        throw _createHttpException(streamedResponse.statusCode, errorBody);
      }
    } finally {
      client.close();
    }
  }

  /// 发送非流式聊天请求到 OpenAI API（保留用于测试连接，带重试机制）
  static Future<ChatResponse> sendChatRequest(List<ChatMessage> messages) async {
    if (!OpenAIConfig.isConfigured) {
      throw Exception('OpenAI API 配置不完整，请检查 .env 文件');
    }

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await _attemptChatRequest(messages);
      } catch (e) {
        _logger.warning('Chat request attempt ${attempt + 1} failed: $e');
        
        if (attempt == _maxRetries - 1) {
          throw _formatError(e);
        }
        
        final delay = _baseRetryDelay * pow(2, attempt);
        await Future.delayed(delay);
        _logger.info('Retrying chat request in ${delay.inSeconds} seconds...');
      }
    }
    
    throw Exception('所有重试尝试都失败了');
  }

  /// 实际执行聊天请求
  static Future<ChatResponse> _attemptChatRequest(List<ChatMessage> messages) async {
    final request = ChatRequest(
      model: OpenAIConfig.model,
      messages: messages,
      temperature: 0.7,
      maxTokens: 1000,
      stream: false,
    );

    final response = await http.post(
      Uri.parse(OpenAIConfig.chatCompletionsEndpoint),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
        'User-Agent': 'ZhiwenX-Flutter-App/1.0',
      },
      body: utf8.encode(jsonEncode(request.toJson())),
    ).timeout(_timeout);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return ChatResponse.fromJson(jsonData);
    } else {
      throw _createHttpException(response.statusCode, utf8.decode(response.bodyBytes));
    }
  }

  /// 创建HTTP异常
  static Exception _createHttpException(int statusCode, String responseBody) {
    try {
      final errorData = jsonDecode(responseBody) as Map<String, dynamic>;
      final errorMessage = errorData['error']?['message'] ?? '未知错误';
      final errorType = errorData['error']?['type'] ?? 'unknown_error';
      
      switch (statusCode) {
        case 401:
          return Exception('API密钥无效，请检查配置');
        case 429:
          return Exception('请求过于频繁，请稍后重试');
        case 500:
        case 502:
        case 503:
        case 504:
          return Exception('服务器暂时不可用，请稍后重试');
        default:
          return Exception('API请求失败 ($statusCode): $errorMessage');
      }
    } catch (e) {
      return Exception('API请求失败 ($statusCode): 响应解析错误');
    }
  }

  /// 格式化错误信息
  static Exception _formatError(dynamic error) {
    if (error.toString().contains('TimeoutException')) {
      return Exception('网络连接超时，请检查网络状态后重试');
    } else if (error.toString().contains('SocketException')) {
      return Exception('网络连接失败，请检查网络设置');
    } else if (error.toString().contains('HandshakeException')) {
      return Exception('SSL连接失败，请检查网络安全设置');
    } else if (error is Exception) {
      return error;
    } else {
      return Exception('未知错误: ${error.toString()}');
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
