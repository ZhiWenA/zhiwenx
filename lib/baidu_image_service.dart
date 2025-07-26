import 'dart:convert';
import 'package:http/http.dart' as http;
import 'baidu_config.dart';

class BaiduImageService {
  // 获取访问令牌
  static Future<String?> getAccessToken() async {
    try {
      if (BaiduConfig.isTokenValid) {
        return BaiduConfig.accessToken;
      }

      final response = await http.post(
        Uri.parse('${BaiduConfig.tokenUrl}?grant_type=client_credentials&client_id=${BaiduConfig.clientId}&client_secret=${BaiduConfig.clientSecret}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accessToken = data['access_token'];
        final expiresIn = data['expires_in'] ?? 2592000; // 默认30天
        
        BaiduConfig.setAccessToken(accessToken, expiresIn);
        return accessToken;
      } else {
        print('获取access_token失败: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('获取access_token异常: $e');
      return null;
    }
  }

  // 提交图片理解任务
  static Future<String?> submitImageUnderstanding(String base64Image, String question) async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        return null;
      }

      final requestData = {
        'image': base64Image,
        'question': question,
      };

      final response = await http.post(
        Uri.parse('${BaiduConfig.imageUnderstandingUrl}/request?access_token=$accessToken'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result']?['task_id'];
      } else {
        print('提交图片理解任务失败: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('提交图片理解任务异常: $e');
      return null;
    }
  }

  // 获取图片理解结果
  static Future<String?> getImageUnderstandingResult(String taskId) async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        return null;
      }

      final requestData = {
        'task_id': taskId,
      };

      final response = await http.post(
        Uri.parse('${BaiduConfig.imageUnderstandingUrl}/get-result?access_token=$accessToken'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];
        
        if (result['ret_code'] == 0) {
          return result['description'];
        } else if (result['ret_code'] == 1) {
          // 任务处理中，需要继续轮询
          return null;
        } else {
          print('图片理解失败: ${result['ret_msg']}');
          return '图片理解失败: ${result['ret_msg']}';
        }
      } else {
        print('获取图片理解结果失败: ${response.statusCode} - ${response.body}');
        return '获取结果失败';
      }
    } catch (e) {
      print('获取图片理解结果异常: $e');
      return '获取结果异常: $e';
    }
  }

  // 轮询获取结果的便捷方法
  static Future<String> getImageDescription(String base64Image, {String question = '解释图片信息'}) async {
    try {
      // 提交任务
      final taskId = await submitImageUnderstanding(base64Image, question);
      if (taskId == null) {
        return '提交任务失败';
      }

      // 轮询获取结果
      int attempts = 0;
      const maxAttempts = 30; // 最多尝试30次
      const delay = Duration(seconds: 2); // 每次间隔2秒

      while (attempts < maxAttempts) {
        await Future.delayed(delay);
        
        final result = await getImageUnderstandingResult(taskId);
        if (result != null) {
          return result;
        }
        
        attempts++;
      }

      return '获取结果超时，请稍后重试';
    } catch (e) {
      return '处理异常: $e';
    }
  }
}
