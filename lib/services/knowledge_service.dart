import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/knowledge_models.dart';

class KnowledgeService {
  static const String _baseUrl = 'https://api.ai.zhheo.com';
  
  // 从环境变量获取配置
  static String? get _token => dotenv.env['KNOWLEDGE_TOKEN'];
  static String? get _apiKey => dotenv.env['KNOWLEDGE_API_KEY'];
  static String? get _projectId => dotenv.env['KNOWLEDGE_PROJECT_ID'];

  /// 上传文件到知识库
  static Future<KnowledgeUploadResponse> uploadFiles({
    required List<File> files,
    String? title,
  }) async {
    if (_token == null || _projectId == null) {
      throw Exception('知识库配置缺失，请检查环境变量中的 KNOWLEDGE_TOKEN 和 KNOWLEDGE_PROJECT_ID');
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/knowledge/upload');
      final request = http.MultipartRequest('POST', uri);

      // 添加请求头
      request.headers['Authorization'] = 'Bearer $_token';

      // 添加项目ID
      request.fields['project_id'] = _projectId!;
      
      // 添加标题（可选）
      if (title != null && title.isNotEmpty) {
        request.fields['title'] = title;
      }

      // 添加文件
      for (var file in files) {
        final multipartFile = await http.MultipartFile.fromPath(
          'files',
          file.path,
        );
        request.files.add(multipartFile);
      }

      // 发送请求
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseBody);
        return KnowledgeUploadResponse.fromJson(jsonResponse);
      } else {
        throw Exception('上传失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('上传文件时发生错误: $e');
    }
  }

  /// 搜索知识库
  static Future<KnowledgeSearchResponse> searchKnowledge({
    required String content,
    int? topN,
  }) async {
    if (_apiKey == null) {
      throw Exception('知识库配置缺失，请检查环境变量中的 KNOWLEDGE_API_KEY');
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/knowledge/search').replace(
        queryParameters: {'key': _apiKey},
      );

      final request = KnowledgeSearchRequest(
        content: content,
        topN: topN,
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return KnowledgeSearchResponse.fromJson(jsonResponse);
      } else {
        throw Exception('搜索失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('搜索知识库时发生错误: $e');
    }
  }

  /// 检查配置是否完整
  static bool isConfigured() {
    return _token != null && 
           _apiKey != null && 
           _projectId != null &&
           _token!.isNotEmpty && 
           _apiKey!.isNotEmpty && 
           _projectId!.isNotEmpty;
  }

  /// 获取配置状态
  static Map<String, bool> getConfigStatus() {
    return {
      'token': _token != null && _token!.isNotEmpty,
      'apiKey': _apiKey != null && _apiKey!.isNotEmpty,
      'projectId': _projectId != null && _projectId!.isNotEmpty,
    };
  }
}
