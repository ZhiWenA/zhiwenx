import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'chat_models.dart';
import 'openai_config.dart';
import 'openai_service.dart';
import 'mcp_service.dart';

/// 增强的OpenAI服务，集成MCP功能，支持AI自动工具调用
class EnhancedOpenAIService {
  static final Logger _logger = Logger('enhanced_openai_service');
  static final McpService _mcpService = McpService();
  static bool _isInitialized = false;
  static Timer? _healthCheckTimer;
  static Timer? _toolRefreshTimer;
  static final Map<String, List<McpToolInfo>> _toolCache = {};
  static DateTime _lastToolRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  /// 初始化增强服务
  static Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      await _mcpService.initialize();
      
      // 自动连接到已配置的MCP服务器
      await _autoConnectServers();
      
      // 启动健康检查和工具刷新定时器
      _startPeriodicTasks();
      
      _isInitialized = true;
      _logger.info('Enhanced OpenAI service initialized successfully');
    } catch (e) {
      _logger.severe('Failed to initialize enhanced OpenAI service: $e');
      // 不抛出异常，降级到标准服务
    }
  }

  /// 自动连接到配置的MCP服务器
  static Future<void> _autoConnectServers() async {
    final servers = _mcpService.serverStatuses;
    for (final server in servers) {
      if (server.state == McpConnectionState.disconnected) {
        try {
          _logger.info('Auto-connecting to MCP server: ${server.serverName}');
          await _mcpService.connectToServer(server.serverId);
        } catch (e) {
          _logger.warning('Failed to auto-connect to ${server.serverName}: $e');
        }
      }
    }
  }

  /// 启动周期性任务
  static void _startPeriodicTasks() {
    // 每30秒进行健康检查
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performHealthCheck();
    });

    // 每10秒刷新工具缓存
    _toolRefreshTimer?.cancel();
    _toolRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshToolCache();
    });
  }

  /// 执行健康检查
  static Future<void> _performHealthCheck() async {
    try {
      final servers = _mcpService.serverStatuses;
      for (final server in servers) {
        if (server.state == McpConnectionState.connected) {
          // 测试连接是否仍然有效
          try {
            await _mcpService.getServerTools(server.serverId);
          } catch (e) {
            _logger.warning('Health check failed for ${server.serverName}, attempting reconnect');
            await _mcpService.connectToServer(server.serverId);
          }
        } else if (server.state == McpConnectionState.disconnected) {
          // 尝试重新连接
          await _mcpService.connectToServer(server.serverId);
        }
      }
    } catch (e) {
      _logger.warning('Health check error: $e');
    }
  }

  /// 刷新工具缓存
  static Future<void> _refreshToolCache() async {
    try {
      final now = DateTime.now();
      if (now.difference(_lastToolRefresh).inSeconds < 5) return;

      _toolCache.clear();
      final servers = _mcpService.serverStatuses;
      
      for (final server in servers) {
        if (server.state == McpConnectionState.connected) {
          try {
            final tools = await _mcpService.getServerTools(server.serverId);
            _toolCache[server.serverId] = tools;
          } catch (e) {
            _logger.warning('Failed to refresh tools for ${server.serverName}: $e');
          }
        }
      }
      
      _lastToolRefresh = now;
      
      final totalTools = _toolCache.values.fold<int>(0, (sum, tools) => sum + tools.length);
      if (totalTools > 0) {
        _logger.info('Tool cache refreshed: $totalTools tools from ${_toolCache.length} servers');
      }
    } catch (e) {
      _logger.warning('Tool cache refresh error: $e');
    }
  }

  /// 发送聊天请求（支持MCP工具调用）
  static Stream<String> sendStreamChatRequest(List<ChatMessage> messages) async* {
    if (!OpenAIConfig.isConfigured) {
      yield* _fallbackToStandardService(messages);
      return;
    }

    // 确保初始化
    if (!_isInitialized) {
      await initialize();
    }

    // 获取可用工具（使用缓存）
    final availableTools = await _getAvailableToolsFromCache();
    
    if (availableTools.isNotEmpty) {
      yield* _sendEnhancedChatRequest(messages, availableTools);
    } else {
      // 如果没有工具，尝试刷新一次
      await _refreshToolCache();
      final refreshedTools = await _getAvailableToolsFromCache();
      
      if (refreshedTools.isNotEmpty) {
        yield* _sendEnhancedChatRequest(messages, refreshedTools);
      } else {
        yield* _fallbackToStandardService(messages);
      }
    }
  }

  /// 从缓存获取可用工具
  static Future<List<McpToolInfo>> _getAvailableToolsFromCache() async {
    final tools = <McpToolInfo>[];
    for (final toolList in _toolCache.values) {
      tools.addAll(toolList);
    }
    return tools;
  }

  /// 发送增强的聊天请求（包含MCP工具调用）
  static Stream<String> _sendEnhancedChatRequest(List<ChatMessage> messages, List<McpToolInfo> tools) async* {
    try {
      _logger.info('Processing chat request with ${tools.length} available MCP tools');

      // 获取用户最后一条消息
      final userMessage = messages.where((m) => m.role == 'user').last.content;
      
      // 使用AI分析是否需要工具调用
      final toolAnalysis = await _analyzeToolNeedsWithAI(userMessage, tools);
      
      if (toolAnalysis.needsTools && toolAnalysis.recommendedTools.isNotEmpty) {
        _logger.info('AI determined need for ${toolAnalysis.recommendedTools.length} tools');
        
        // 先尝试调用工具获取信息
        final toolResults = <String, dynamic>{};
        
        yield '🔧 正在调用相关工具获取信息...\n\n';
        
        for (final toolInfo in toolAnalysis.recommendedTools) {
          try {
            yield '• 调用 ${toolInfo.name}...';
            final result = await _callToolWithSmartArguments(toolInfo, userMessage, toolAnalysis.context);
            toolResults[toolInfo.name] = result;
            yield ' ✅ 完成\n';
          } catch (e) {
            yield ' ❌ 失败: $e\n';
            _logger.warning('Tool call failed for ${toolInfo.name}: $e');
          }
        }

        yield '\n📝 基于工具结果生成回答...\n\n';

        // 将工具结果添加到消息上下文中
        final enhancedMessages = _buildEnhancedMessages(messages, toolResults, toolAnalysis);
        
        // 使用增强的消息获取AI回复
        yield* _fallbackToStandardService(enhancedMessages);
        
      } else {
        // 直接使用标准服务
        yield* _fallbackToStandardService(messages);
      }

    } catch (e) {
      _logger.severe('Enhanced chat request failed: $e');
      yield* _fallbackToStandardService(messages);
    }
  }

  /// 使用AI分析工具需求
  static Future<ToolAnalysisResult> _analyzeToolNeedsWithAI(String userMessage, List<McpToolInfo> tools) async {
    try {
      // 构建工具分析提示
      final toolsDescription = tools.map((tool) => 
        '- ${tool.name}: ${tool.description}'
      ).join('\n');
      
      final analysisPrompt = '''
请分析用户的请求是否需要调用外部工具来获取信息或执行操作。

用户请求: "$userMessage"

可用工具:
$toolsDescription

请按照以下JSON格式回复:
{
  "needs_tools": true/false,
  "reasoning": "分析原因",
  "recommended_tools": ["tool1", "tool2"],
  "context": {
    "task_type": "search/calculation/file_operation/etc",
    "parameters": {"key": "value"}
  }
}

只回复JSON，不要其他内容。
''';

      final analysisMessages = [
        ChatMessage.system('你是一个工具调用分析助手，帮助判断用户请求是否需要调用外部工具。'),
        ChatMessage.user(analysisPrompt),
      ];

      // 使用标准服务获取分析结果
      final analysisStream = OpenAIService.sendStreamChatRequest(analysisMessages);
      final analysisResponse = await analysisStream.join('');
      
      // 解析JSON响应
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(analysisResponse);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final analysis = jsonDecode(jsonStr);
        
        final recommendedTools = <McpToolInfo>[];
        if (analysis['recommended_tools'] is List) {
          for (final toolName in analysis['recommended_tools']) {
            final tool = tools.where((t) => t.name.toLowerCase().contains(toolName.toLowerCase())).firstOrNull;
            if (tool != null) {
              recommendedTools.add(tool);
            }
          }
        }
        
        return ToolAnalysisResult(
          needsTools: analysis['needs_tools'] ?? false,
          reasoning: analysis['reasoning'] ?? '',
          recommendedTools: recommendedTools,
          context: Map<String, dynamic>.from(analysis['context'] ?? {}),
        );
      }
    } catch (e) {
      _logger.warning('AI tool analysis failed: $e');
    }
    
    // 降级到简单规则匹配
    return _analyzeToolNeedsWithRules(userMessage, tools);
  }

  /// 基于规则的工具需求分析（降级方案）
  static ToolAnalysisResult _analyzeToolNeedsWithRules(String userMessage, List<McpToolInfo> tools) {
    final lowerMessage = userMessage.toLowerCase();
    final neededTools = <McpToolInfo>[];
    
    for (final tool in tools) {
      final toolName = tool.name.toLowerCase();
      final toolDesc = tool.description.toLowerCase();
      
      // 关键词匹配
      final keywords = [
        ...toolName.split(RegExp(r'[_\s-]')),
        ...toolDesc.split(RegExp(r'[_\s-]')),
      ];
      
      for (final keyword in keywords) {
        if (keyword.length > 2 && lowerMessage.contains(keyword)) {
          neededTools.add(tool);
          break;
        }
      }
      
      // 功能匹配
      if (toolName.contains('search') && (lowerMessage.contains('搜索') || lowerMessage.contains('查找') || lowerMessage.contains('找'))) {
        neededTools.add(tool);
      }
      if (toolName.contains('calc') && (lowerMessage.contains('计算') || lowerMessage.contains('数学') || lowerMessage.contains('算'))) {
        neededTools.add(tool);
      }
      if (toolName.contains('file') && (lowerMessage.contains('文件') || lowerMessage.contains('读取'))) {
        neededTools.add(tool);
      }
      if (toolName.contains('weather') && (lowerMessage.contains('天气') || lowerMessage.contains('温度'))) {
        neededTools.add(tool);
      }
      if (toolName.contains('time') && (lowerMessage.contains('时间') || lowerMessage.contains('日期'))) {
        neededTools.add(tool);
      }
    }
    
    return ToolAnalysisResult(
      needsTools: neededTools.isNotEmpty,
      reasoning: '基于关键词匹配分析',
      recommendedTools: neededTools.take(3).toList(),
      context: {'task_type': 'general'},
    );
  }

  /// 智能调用工具
  static Future<String> _callToolWithSmartArguments(McpToolInfo tool, String userMessage, Map<String, dynamic> context) async {
    try {
      final arguments = await _generateSmartToolArguments(tool, userMessage, context);
      _logger.info('Calling tool ${tool.name} with arguments: $arguments');
      
      final result = await _mcpService.callTool(tool.serverId, tool.name, arguments);
      return result;
    } catch (e) {
      _logger.warning('Smart tool call failed for ${tool.name}: $e');
      throw Exception('工具调用失败: $e');
    }
  }

  /// 智能生成工具参数
  static Future<Map<String, dynamic>> _generateSmartToolArguments(McpToolInfo tool, String userMessage, Map<String, dynamic> context) async {
    final arguments = <String, dynamic>{};
    
    try {
      // 使用AI来生成更智能的参数
      final schema = tool.inputSchema;
      if (schema['properties'] is Map) {
        final properties = schema['properties'] as Map;
        
        // 构建参数生成提示
        final paramPrompt = '''
为工具 "${tool.name}" 生成参数。

工具描述: ${tool.description}
用户请求: "$userMessage"
上下文: ${jsonEncode(context)}

参数结构:
${jsonEncode(properties)}

请生成合适的参数JSON，只回复JSON格式，不要其他内容:
''';

        final paramMessages = [
          ChatMessage.system('你是一个参数生成助手，根据用户请求和工具定义生成合适的参数。'),
          ChatMessage.user(paramPrompt),
        ];

        final paramStream = OpenAIService.sendStreamChatRequest(paramMessages);
        final paramResponse = await paramStream.join('');
        
        // 解析JSON响应
        final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(paramResponse);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0)!;
          final generatedArgs = jsonDecode(jsonStr);
          arguments.addAll(Map<String, dynamic>.from(generatedArgs));
        }
      }
    } catch (e) {
      _logger.warning('Smart argument generation failed: $e');
    }
    
    // 降级到基本参数生成
    if (arguments.isEmpty) {
      arguments.addAll(_generateBasicToolArguments(tool, userMessage));
    }
    
    return arguments;
  }

  /// 基本工具参数生成
  static Map<String, dynamic> _generateBasicToolArguments(McpToolInfo tool, String userMessage) {
    final arguments = <String, dynamic>{};
    
    final schema = tool.inputSchema;
    if (schema['properties'] is Map) {
      final properties = schema['properties'] as Map;
      
      for (final entry in properties.entries) {
        final prop = entry.value as Map;
        final propName = entry.key as String;
        final type = prop['type'] as String?;
        
        // 智能参数匹配
        if (propName.toLowerCase().contains('query') || 
            propName.toLowerCase().contains('text') ||
            propName.toLowerCase().contains('message') ||
            propName.toLowerCase().contains('input')) {
          arguments[propName] = userMessage;
        } else if (propName.toLowerCase().contains('city') && userMessage.contains('天气')) {
          // 从用户消息中提取城市名
          final cityMatch = RegExp(r'(\w+)[市]?[的]?天气').firstMatch(userMessage);
          arguments[propName] = cityMatch?.group(1) ?? '北京';
        } else if (type == 'string') {
          arguments[propName] = prop['default'] ?? userMessage;
        } else if (type == 'number' || type == 'integer') {
          arguments[propName] = prop['default'] ?? 1;
        } else if (type == 'boolean') {
          arguments[propName] = prop['default'] ?? true;
        }
      }
    }
    
    return arguments;
  }

  /// 构建增强的消息列表
  static List<ChatMessage> _buildEnhancedMessages(List<ChatMessage> originalMessages, Map<String, dynamic> toolResults, ToolAnalysisResult analysis) {
    final enhancedMessages = List<ChatMessage>.from(originalMessages);
    
    if (toolResults.isNotEmpty) {
      final toolResultText = StringBuffer();
      toolResultText.writeln('工具调用结果:');
      
      toolResults.forEach((toolName, result) {
        toolResultText.writeln('• $toolName: $result');
      });
      
      toolResultText.writeln('\n请基于以上工具结果回答用户的问题。');
      
      enhancedMessages.add(ChatMessage.system(toolResultText.toString()));
    }
    
    return enhancedMessages;
  }

  /// 回退到标准OpenAI服务
  static Stream<String> _fallbackToStandardService(List<ChatMessage> messages) {
    _logger.info('Using standard OpenAI service');
    return OpenAIService.sendStreamChatRequest(messages);
  }

  /// 测试连接
  static Future<bool> testConnection() async {
    final standardTest = await OpenAIService.testConnection();
    
    // 如果还未初始化，先初始化
    if (!_isInitialized) {
      await initialize();
    }
    
    final mcpStatuses = _mcpService.serverStatuses;
    final mcpConnected = mcpStatuses.any((s) => s.state == McpConnectionState.connected);
    
    _logger.info('Standard OpenAI: $standardTest, MCP connected: $mcpConnected');
    return standardTest;
  }

  /// 获取可用的MCP工具列表
  static Future<List<McpToolInfo>> getAvailableTools() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // 强制刷新工具缓存
    await _refreshToolCache();
    return await _getAvailableToolsFromCache();
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
    final result = await _mcpService.connectToServer(serverId);
    if (result) {
      // 连接成功后刷新工具缓存
      await _refreshToolCache();
    }
    return result;
  }

  /// 断开MCP服务器连接
  static Future<void> disconnectFromMcpServer(String serverId) async {
    await _mcpService.disconnectFromServer(serverId);
    // 移除对应的工具缓存
    _toolCache.remove(serverId);
  }

  /// 强制刷新所有工具
  static Future<void> refreshAllTools() async {
    _logger.info('Force refreshing all MCP tools');
    await _refreshToolCache();
  }

  /// 清理资源
  static Future<void> dispose() async {
    _healthCheckTimer?.cancel();
    _toolRefreshTimer?.cancel();
    _mcpService.dispose();
    _isInitialized = false;
  }
}

/// 工具分析结果
class ToolAnalysisResult {
  final bool needsTools;
  final String reasoning;
  final List<McpToolInfo> recommendedTools;
  final Map<String, dynamic> context;

  ToolAnalysisResult({
    required this.needsTools,
    required this.reasoning,
    required this.recommendedTools,
    required this.context,
  });
}
