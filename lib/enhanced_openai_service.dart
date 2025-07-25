import 'dart:async';
import 'package:logging/logging.dart';
import 'chat_models.dart';
import 'openai_config.dart';
import 'openai_service.dart';
import 'mcp_service.dart';

/// 增强的OpenAI服务，集成MCP功能
class EnhancedOpenAIService {
  static final Logger _logger = Logger('enhanced_openai_service');
  static final McpService _mcpService = McpService();

  /// 初始化增强服务
  static Future<void> initialize() async {
    try {
      await _mcpService.initialize();
      _logger.info('Enhanced OpenAI service initialized');
    } catch (e) {
      _logger.severe('Failed to initialize enhanced OpenAI service: $e');
      rethrow;
    }
  }

  /// 发送聊天请求（支持MCP工具调用）
  static Stream<String> sendStreamChatRequest(List<ChatMessage> messages) async* {
    if (!OpenAIConfig.isConfigured) {
      yield* _fallbackToStandardService(messages);
      return;
    }

    // 检查是否有可用的MCP工具
    final availableTools = await getAvailableTools();
    
    if (availableTools.isNotEmpty) {
      yield* _sendEnhancedChatRequest(messages, availableTools);
    } else {
      // 否则回退到标准服务
      yield* _fallbackToStandardService(messages);
    }
  }

  /// 发送增强的聊天请求（包含MCP工具调用）
  static Stream<String> _sendEnhancedChatRequest(List<ChatMessage> messages, List<McpToolInfo> tools) async* {
    try {
      _logger.info('Sending enhanced chat request with ${tools.length} available MCP tools');

      // 获取用户最后一条消息
      final userMessage = messages.where((m) => m.role == 'user').last.content;
      
      // 检查用户消息是否可能需要工具调用
      final needsTools = _analyzeMessageForToolNeeds(userMessage, tools);
      
      if (needsTools.isNotEmpty) {
        // 先返回标准LLM响应
        yield* _fallbackToStandardService(messages);
        
        // 然后尝试调用相关工具
        yield '\n\n[MCP 工具调用]\n';
        for (final tool in needsTools) {
          try {
            yield '正在调用 ${tool.name}...';
            final result = await _callToolWithContext(tool, userMessage);
            yield '\n• ${tool.name}: $result\n';
          } catch (e) {
            yield '\n• ${tool.name}: 调用失败 - $e\n';
          }
        }
      } else {
        // 如果不需要工具，直接使用标准服务
        yield* _fallbackToStandardService(messages);
      }

    } catch (e) {
      _logger.severe('Enhanced chat request failed: $e');
      // 回退到标准服务
      yield* _fallbackToStandardService(messages);
    }
  }

  /// 分析消息内容，判断可能需要的工具
  static List<McpToolInfo> _analyzeMessageForToolNeeds(String message, List<McpToolInfo> tools) {
    final neededTools = <McpToolInfo>[];
    final lowerMessage = message.toLowerCase();
    
    for (final tool in tools) {
      // 简单的关键词匹配逻辑
      final toolName = tool.name.toLowerCase();
      final toolDesc = tool.description.toLowerCase();
      
      if (lowerMessage.contains(toolName) || 
          toolDesc.split(' ').any((word) => lowerMessage.contains(word))) {
        neededTools.add(tool);
      }
      
      // 添加一些通用匹配规则
      if (toolName.contains('search') && (lowerMessage.contains('搜索') || lowerMessage.contains('查找'))) {
        neededTools.add(tool);
      }
      if (toolName.contains('file') && (lowerMessage.contains('文件') || lowerMessage.contains('读取'))) {
        neededTools.add(tool);
      }
      if (toolName.contains('calc') && (lowerMessage.contains('计算') || lowerMessage.contains('数学'))) {
        neededTools.add(tool);
      }
    }


    return neededTools.toList(); // 返回所有匹配的工具
  }

  /// 根据上下文调用工具
  static Future<String> _callToolWithContext(McpToolInfo tool, String context) async {
    try {
      // 生成基本参数（这里需要根据具体工具类型来改进）
      final arguments = _generateToolArguments(tool, context);
      return await _mcpService.callTool(tool.serverId, tool.name, arguments);
    } catch (e) {
      _logger.warning('Tool call failed for ${tool.name}: $e');
      return '工具调用失败: $e';
    }
  }

  /// 为工具生成参数
  static Map<String, dynamic> _generateToolArguments(McpToolInfo tool, String context) {
    final arguments = <String, dynamic>{};
    
    // 根据工具的输入模式生成参数
    final schema = tool.inputSchema;
    if (schema['properties'] is Map) {
      final properties = schema['properties'] as Map;
      
      for (final entry in properties.entries) {
        final prop = entry.value as Map;
        final propName = entry.key as String;
        final type = prop['type'] as String?;
        
        // 根据属性名和类型生成合适的值
        if (propName.toLowerCase().contains('query') || 
            propName.toLowerCase().contains('text') ||
            propName.toLowerCase().contains('message')) {
          arguments[propName] = context;
        } else if (type == 'string') {
          arguments[propName] = prop['default'] ?? 'default_value';
        } else if (type == 'number' || type == 'integer') {
          arguments[propName] = prop['default'] ?? 0;
        } else if (type == 'boolean') {
          arguments[propName] = prop['default'] ?? false;
        }
      }
    }
    
    return arguments;
  }

  /// 回退到标准OpenAI服务
  static Stream<String> _fallbackToStandardService(List<ChatMessage> messages) {
    _logger.info('Using standard OpenAI service');
    return OpenAIService.sendStreamChatRequest(messages);
  }

  /// 测试连接
  static Future<bool> testConnection() async {
    // 测试标准OpenAI连接
    final standardTest = await OpenAIService.testConnection();
    
    // 如果有MCP连接，也测试MCP状态
    final mcpStatuses = _mcpService.serverStatuses;
    final mcpConnected = mcpStatuses.any((s) => s.state == McpConnectionState.connected);
    
    _logger.info('Standard OpenAI: $standardTest, MCP connected: $mcpConnected');
    return standardTest;
  }

  /// 获取可用的MCP工具列表
  static Future<List<McpToolInfo>> getAvailableTools() async {
    final tools = <McpToolInfo>[];
    for (final status in _mcpService.serverStatuses) {
      if (status.state == McpConnectionState.connected) {
        tools.addAll(status.tools);
      }
    }
    return tools;
  }

  /// 获取MCP服务器状态
  static List<McpServerStatus> getMcpServerStatuses() {
    return _mcpService.serverStatuses;
  }

  /// 监听MCP服务器状态变化
  static Stream<List<McpServerStatus>> get mcpServerStatusStream {
    return _mcpService.serverStatusStream;
  }

  /// 连接到MCP服务器
  static Future<bool> connectToMcpServer(String serverId) async {
    return await _mcpService.connectToServer(serverId);
  }

  /// 断开MCP服务器连接
  static Future<void> disconnectFromMcpServer(String serverId) async {
    await _mcpService.disconnectFromServer(serverId);
  }

  /// 清理资源
  static Future<void> dispose() async {
    _mcpService.dispose();
  }
}
