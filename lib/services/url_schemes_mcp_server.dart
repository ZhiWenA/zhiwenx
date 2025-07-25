import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mcp_server/mcp_server.dart';
import '../services/url_schemes_service.dart';
import '../models/url_scheme_config.dart';

/// URL Schemes MCP Server
class UrlSchemesMcpServer {
  static const String serverName = 'ZhiWenX URL Schemes';
  static const String serverVersion = '1.0.0';
  
  late Server _server;
  final UrlSchemesService _urlSchemesService = UrlSchemesService();
  bool _isInitialized = false;

  /// 单例实例
  static final UrlSchemesMcpServer _instance = UrlSchemesMcpServer._internal();
  factory UrlSchemesMcpServer() => _instance;
  UrlSchemesMcpServer._internal();

  /// 初始化 MCP Server
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 初始化 URL Schemes 服务
      await _urlSchemesService.initialize();

      // 创建 MCP Server
      _server = Server(
        name: serverName,
        version: serverVersion,
        capabilities: ServerCapabilities.simple(
          tools: true,
          resources: true,
          prompts: true,
          logging: true,
        ),
      );

      // 注册工具、资源和提示
      _registerTools();
      _registerResources();
      _registerPrompts();

      _isInitialized = true;
      debugPrint('URL Schemes MCP Server initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize URL Schemes MCP Server: $e');
      rethrow;
    }
  }

  /// 启动 MCP Server
  Future<void> start({String mode = 'stdio', int port = 8080}) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (mode == 'stdio') {
        final transportResult = McpServer.createStdioTransport();
        final transport = transportResult.get();
        _server.connect(transport);
      } else {
        final sseConfig = SseServerConfig(
          endpoint: '/sse',
          messagesEndpoint: '/messages',
          port: port,
        );
        final transportResult = McpServer.createSseTransport(sseConfig);
        final transport = transportResult.get();
        _server.connect(transport);
      }

      _server.sendLog(McpLogLevel.info, 'URL Schemes MCP Server started in $mode mode');
      debugPrint('URL Schemes MCP Server started in $mode mode');
    } catch (e) {
      debugPrint('Failed to start URL Schemes MCP Server: $e');
      rethrow;
    }
  }

  /// 注册工具
  void _registerTools() {
    // 1. 启动 URL Scheme 工具
    _server.addTool(
      name: 'launch_url_scheme',
      description: '''Launch an app using URL scheme. Available schemes:
- xiaohongshu_search: Search in Little Red Book (小红书) with "keyword" parameter
- wechat_scan: Open WeChat QR scanner (no parameters)
- alipay_scan: Open Alipay QR scanner (no parameters) 
- taobao_search: Search on Taobao with "keyword" parameter
- douyin_search: Search on TikTok with "keyword" parameter
- bilibili_search: Search on Bilibili with "keyword" parameter
- amap_navigation: Navigate with Amap using "poiname", "lat", "lon" parameters

For search functions, use the "keyword" parameter to specify what to search for.''',
      inputSchema: {
        'type': 'object',
        'properties': {
          'scheme_id': {
            'type': 'string',
            'description': 'The ID of the URL scheme to launch. Use exact IDs like "xiaohongshu_search", "wechat_scan", etc.',
            'enum': ['xiaohongshu_search', 'wechat_scan', 'alipay_scan', 'taobao_search', 'douyin_search', 'bilibili_search', 'amap_navigation']
          },
          'parameters': {
            'type': 'object',
            'description': 'Parameters for the URL scheme. For search schemes, use {"keyword": "search_term"}',
            'additionalProperties': true,
            'examples': [
              {'keyword': '阿里云'},
              {'keyword': 'Flutter开发'},
              {'poiname': '北京站', 'lat': 39.9042, 'lon': 116.4074}
            ]
          }
        },
        'required': ['scheme_id']
      },
      handler: _handleLaunchUrlScheme,
    );

    // 2. 获取可用 URL Schemes 工具
    _server.addTool(
      name: 'list_url_schemes',
      description: 'Get list of available URL schemes',
      inputSchema: {
        'type': 'object',
        'properties': {
          'category': {
            'type': 'string',
            'description': 'Filter by category (optional)'
          },
          'enabled_only': {
            'type': 'boolean',
            'description': 'Only return enabled schemes',
            'default': true
          }
        },
        'required': []
      },
      handler: _handleListUrlSchemes,
    );

    // 3. 添加 URL Scheme 工具
    _server.addTool(
      name: 'add_url_scheme',
      description: 'Add a new URL scheme configuration',
      inputSchema: {
        'type': 'object',
        'properties': {
          'scheme_config': {
            'type': 'object',
            'description': 'URL scheme configuration object',
            'properties': {
              'id': {'type': 'string'},
              'name': {'type': 'string'},
              'description': {'type': 'string'},
              'scheme': {'type': 'string'},
              'url_template': {'type': 'string'},
              'category': {'type': 'string'},
              'enabled': {'type': 'boolean'},
              'parameters': {'type': 'object'}
            },
            'required': ['id', 'name', 'description', 'scheme', 'url_template']
          }
        },
        'required': ['scheme_config']
      },
      handler: _handleAddUrlScheme,
    );

    // 4. 更新 URL Scheme 工具
    _server.addTool(
      name: 'update_url_scheme',
      description: 'Update an existing URL scheme configuration',
      inputSchema: {
        'type': 'object',
        'properties': {
          'scheme_id': {
            'type': 'string',
            'description': 'The ID of the URL scheme to update'
          },
          'scheme_config': {
            'type': 'object',
            'description': 'Updated URL scheme configuration'
          }
        },
        'required': ['scheme_id', 'scheme_config']
      },
      handler: _handleUpdateUrlScheme,
    );

    // 5. 删除 URL Scheme 工具
    _server.addTool(
      name: 'remove_url_scheme',
      description: 'Remove a URL scheme configuration',
      inputSchema: {
        'type': 'object',
        'properties': {
          'scheme_id': {
            'type': 'string',
            'description': 'The ID of the URL scheme to remove'
          }
        },
        'required': ['scheme_id']
      },
      handler: _handleRemoveUrlScheme,
    );

    // 6. 切换 URL Scheme 启用状态工具
    _server.addTool(
      name: 'toggle_url_scheme',
      description: 'Enable or disable a URL scheme',
      inputSchema: {
        'type': 'object',
        'properties': {
          'scheme_id': {
            'type': 'string',
            'description': 'The ID of the URL scheme to toggle'
          },
          'enabled': {
            'type': 'boolean',
            'description': 'Whether to enable or disable the scheme'
          }
        },
        'required': ['scheme_id', 'enabled']
      },
      handler: _handleToggleUrlScheme,
    );
  }

  /// 注册资源
  void _registerResources() {
    // 1. URL Schemes 配置资源
    _server.addResource(
      uri: 'urlschemes://config',
      name: 'URL Schemes Configuration',
      description: 'Complete URL schemes configuration',
      mimeType: 'application/json',
      handler: (uri, params) async {
        final config = _urlSchemesService.config;
        if (config == null) {
          throw McpError('URL Schemes service not initialized');
        }

        return ReadResourceResult(
          contents: [
            ResourceContentInfo(
              uri: uri,
              mimeType: 'application/json',
              text: const JsonEncoder.withIndent('  ').convert(config.toJson()),
            ),
          ],
        );
      },
    );

    // 2. 特定 URL Scheme 详情资源
    _server.addResource(
      uri: 'urlschemes://scheme/{id}',
      name: 'URL Scheme Details',
      description: 'Details of a specific URL scheme',
      mimeType: 'application/json',
      uriTemplate: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': 'URL scheme ID'
          }
        }
      },
      handler: (uri, params) async {
        final schemeId = params['id'] ?? uri.substring('urlschemes://scheme/'.length);
        final scheme = _urlSchemesService.config?.findSchemeById(schemeId);
        
        if (scheme == null) {
          throw McpError('URL scheme with id "$schemeId" not found');
        }

        return ReadResourceResult(
          contents: [
            ResourceContentInfo(
              uri: uri,
              mimeType: 'application/json',
              text: const JsonEncoder.withIndent('  ').convert(scheme.toJson()),
            ),
          ],
        );
      },
    );

    // 3. URL Schemes 类别资源
    _server.addResource(
      uri: 'urlschemes://categories',
      name: 'URL Schemes Categories',
      description: 'List of available URL scheme categories',
      mimeType: 'application/json',
      handler: (uri, params) async {
        final categories = _urlSchemesService.getCategories();
        
        return ReadResourceResult(
          contents: [
            ResourceContentInfo(
              uri: uri,
              mimeType: 'application/json',
              text: jsonEncode({
                'categories': categories,
                'total': categories.length,
              }),
            ),
          ],
        );
      },
    );
  }

  /// 注册提示
  void _registerPrompts() {
    // 1. URL Scheme 启动提示
    _server.addPrompt(
      name: 'launch_app_prompt',
      description: 'Generate a prompt for launching an app with URL scheme',
      arguments: [
        PromptArgument(
          name: 'app_name',
          description: 'Name of the app to launch',
          required: true,
        ),
        PromptArgument(
          name: 'action',
          description: 'Action to perform in the app',
          required: false,
        ),
      ],
      handler: (args) async {
        final appName = args['app_name'] as String;
        final action = args['action'] as String? ?? 'open';

        final systemPrompt = '''
You are an assistant that helps users launch mobile apps using URL schemes.
You have access to a comprehensive database of URL schemes for popular Chinese and international apps.
When a user wants to launch an app or perform a specific action, find the appropriate URL scheme and execute it.

Available apps include:
- 小红书 (Little Red Book): Search and discovery
- 微信 (WeChat): Messaging and social features  
- 支付宝 (Alipay): Payments and services
- 淘宝 (Taobao): E-commerce and shopping
- 抖音 (TikTok): Short videos and entertainment
- B站 (Bilibili): Videos and entertainment
- 高德地图 (Amap): Navigation and maps

For each request, determine the correct URL scheme, gather required parameters, and launch the app.
''';

        final messages = [
          Message(
            role: MessageRole.system.toString().split('.').last,
            content: TextContent(text: systemPrompt),
          ),
          Message(
            role: MessageRole.user.toString().split('.').last,
            content: TextContent(text: 'Please help me launch $appName to $action'),
          ),
        ];

        return GetPromptResult(
          description: 'App launch assistance for $appName',
          messages: messages,
        );
      },
    );

    // 2. URL Scheme 配置提示
    _server.addPrompt(
      name: 'configure_url_scheme_prompt',
      description: 'Generate a prompt for configuring URL schemes',
      arguments: [
        PromptArgument(
          name: 'app_name',
          description: 'Name of the app to configure',
          required: true,
        ),
        PromptArgument(
          name: 'scheme',
          description: 'URL scheme protocol',
          required: false,
        ),
      ],
      handler: (args) async {
        final appName = args['app_name'] as String;
        final scheme = args['scheme'] as String? ?? '';

        final systemPrompt = '''
You are an expert in mobile app URL schemes configuration.
Help users create, modify, and manage URL scheme configurations for their apps.

You can:
1. Create new URL scheme configurations
2. Modify existing configurations
3. Add parameters and validation rules
4. Organize schemes by categories
5. Enable/disable schemes

Provide step-by-step guidance and ensure all configurations are valid and secure.
''';

        final messages = [
          Message(
            role: MessageRole.system.toString().split('.').last,
            content: TextContent(text: systemPrompt),
          ),
          Message(
            role: MessageRole.user.toString().split('.').last,
            content: TextContent(text: 'Help me configure URL scheme for $appName${scheme.isNotEmpty ? ' with scheme $scheme' : ''}'),
          ),
        ];

        return GetPromptResult(
          description: 'URL scheme configuration assistance for $appName',
          messages: messages,
        );
      },
    );
  }

  /// 处理启动 URL Scheme 请求（公共方法用于测试）
  Future<CallToolResult> handleLaunchUrlScheme(Map<String, dynamic> args) async {
    return _handleLaunchUrlScheme(args);
  }

  /// 处理列出 URL Schemes 请求（公共方法用于测试）
  Future<CallToolResult> handleListUrlSchemes(Map<String, dynamic> args) async {
    return _handleListUrlSchemes(args);
  }

  /// 处理添加 URL Scheme 请求（公共方法用于测试）
  Future<CallToolResult> handleAddUrlScheme(Map<String, dynamic> args) async {
    return _handleAddUrlScheme(args);
  }

  /// 处理启动 URL Scheme 请求
  Future<CallToolResult> _handleLaunchUrlScheme(Map<String, dynamic> args) async {
    try {
      final schemeId = args['scheme_id'] as String;
      final parameters = args['parameters'] as Map<String, dynamic>? ?? {};

      // 先尝试直接匹配 scheme_id
      var targetScheme = _urlSchemesService.config?.findSchemeById(schemeId);
      
      // 如果找不到，尝试智能匹配
      if (targetScheme == null) {
        final allSchemes = _urlSchemesService.getAllSchemes();
        
        // 尝试通过名称模糊匹配
        for (final scheme in allSchemes) {
          if (scheme.name.toLowerCase().contains(schemeId.toLowerCase()) ||
              scheme.id.toLowerCase().contains(schemeId.toLowerCase()) ||
              scheme.scheme.toLowerCase().contains(schemeId.toLowerCase())) {
            targetScheme = scheme;
            break;
          }
        }
        
        // 如果还是找不到，尝试根据参数推断
        if (targetScheme == null && parameters.isNotEmpty) {
          final paramKeys = parameters.keys.toSet();
          
          for (final scheme in allSchemes) {
            final schemeParamKeys = scheme.parameters.keys.toSet();
            
            // 如果参数匹配度较高，选择这个 scheme
            if (paramKeys.intersection(schemeParamKeys).isNotEmpty) {
              targetScheme = scheme;
              break;
            }
          }
        }
      }

      if (targetScheme == null) {
        // 如果仍然找不到，返回可用的 schemes 列表
        final allSchemes = _urlSchemesService.getAllSchemes();
        final availableSchemes = allSchemes.map((s) => {
          'id': s.id,
          'name': s.name,
          'description': s.description,
          'parameters': s.parameters.keys.toList(),
        }).toList();
        
        return CallToolResult(
          content: [TextContent(text: 'URL scheme "$schemeId" not found. Available schemes:\n${const JsonEncoder.withIndent('  ').convert(availableSchemes)}')],
          isError: true,
        );
      }

      // 智能参数映射
      final mappedParameters = <String, dynamic>{};
      
      // 直接映射匹配的参数
      for (final entry in targetScheme.parameters.entries) {
        final paramName = entry.key;
        
        if (parameters.containsKey(paramName)) {
          mappedParameters[paramName] = parameters[paramName];
        } else {
          // 尝试智能映射常见参数
          final value = _smartMapParameter(paramName, parameters);
          if (value != null) {
            mappedParameters[paramName] = value;
          }
        }
      }

      final success = await _urlSchemesService.launchUrlScheme(targetScheme.id, mappedParameters);
      
      if (success) {
        return CallToolResult(
          content: [TextContent(text: 'Successfully launched ${targetScheme.name} (${targetScheme.id}) with parameters: ${mappedParameters}')],
        );
      } else {
        return CallToolResult(
          content: [TextContent(text: 'Failed to launch URL scheme: ${targetScheme.id}')],
          isError: true,
        );
      }
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error launching URL scheme: $e')],
        isError: true,
      );
    }
  }

  /// 智能参数映射
  dynamic _smartMapParameter(String targetParam, Map<String, dynamic> sourceParams) {
    // 常见参数映射规则
    final paramMappings = {
      'keyword': ['query', 'search', 'q', 'term', 'text'],
      'query': ['keyword', 'search', 'q', 'term', 'text'],
      'search': ['keyword', 'query', 'q', 'term', 'text'],
      'text': ['keyword', 'query', 'search', 'q', 'term'],
      'url': ['link', 'uri', 'address'],
      'title': ['name', 'subject'],
      'lat': ['latitude'],
      'lon': ['longitude', 'lng'],
      'longitude': ['lon', 'lng'],
      'latitude': ['lat'],
    };

    final possibleKeys = paramMappings[targetParam] ?? [];
    
    for (final key in possibleKeys) {
      if (sourceParams.containsKey(key)) {
        return sourceParams[key];
      }
    }

    // 如果找不到直接映射，检查是否有包含目标参数名的键
    for (final entry in sourceParams.entries) {
      if (entry.key.toLowerCase().contains(targetParam.toLowerCase()) ||
          targetParam.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return null;
  }

  /// 处理列出 URL Schemes 请求
  Future<CallToolResult> _handleListUrlSchemes(Map<String, dynamic> args) async {
    try {
      final category = args['category'] as String?;
      final enabledOnly = args['enabled_only'] as bool? ?? true;

      List<UrlSchemeItem> schemes;
      if (category != null) {
        schemes = _urlSchemesService.getSchemesByCategory(category);
      } else {
        schemes = enabledOnly 
            ? _urlSchemesService.getAllSchemes()
            : (_urlSchemesService.config?.schemes ?? []);
      }

      final schemesJson = schemes.map((s) => s.toJson()).toList();
      final result = {
        'schemes': schemesJson,
        'total': schemes.length,
        'categories': _urlSchemesService.getCategories(),
      };

      return CallToolResult(
        content: [TextContent(text: const JsonEncoder.withIndent('  ').convert(result))],
      );
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error listing URL schemes: $e')],
        isError: true,
      );
    }
  }

  /// 处理添加 URL Scheme 请求
  Future<CallToolResult> _handleAddUrlScheme(Map<String, dynamic> args) async {
    try {
      final schemeConfig = args['scheme_config'] as Map<String, dynamic>;
      final scheme = UrlSchemeItem.fromJson(schemeConfig);
      
      await _urlSchemesService.addScheme(scheme);
      
      return CallToolResult(
        content: [TextContent(text: 'Successfully added URL scheme: ${scheme.id}')],
      );
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error adding URL scheme: $e')],
        isError: true,
      );
    }
  }

  /// 处理更新 URL Scheme 请求
  Future<CallToolResult> _handleUpdateUrlScheme(Map<String, dynamic> args) async {
    try {
      final schemeId = args['scheme_id'] as String;
      final schemeConfig = args['scheme_config'] as Map<String, dynamic>;
      final updatedScheme = UrlSchemeItem.fromJson(schemeConfig);
      
      await _urlSchemesService.updateScheme(schemeId, updatedScheme);
      
      return CallToolResult(
        content: [TextContent(text: 'Successfully updated URL scheme: $schemeId')],
      );
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error updating URL scheme: $e')],
        isError: true,
      );
    }
  }

  /// 处理删除 URL Scheme 请求
  Future<CallToolResult> _handleRemoveUrlScheme(Map<String, dynamic> args) async {
    try {
      final schemeId = args['scheme_id'] as String;
      
      await _urlSchemesService.removeScheme(schemeId);
      
      return CallToolResult(
        content: [TextContent(text: 'Successfully removed URL scheme: $schemeId')],
      );
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error removing URL scheme: $e')],
        isError: true,
      );
    }
  }

  /// 处理切换 URL Scheme 启用状态请求
  Future<CallToolResult> _handleToggleUrlScheme(Map<String, dynamic> args) async {
    try {
      final schemeId = args['scheme_id'] as String;
      final enabled = args['enabled'] as bool;
      
      await _urlSchemesService.toggleScheme(schemeId, enabled);
      
      final status = enabled ? 'enabled' : 'disabled';
      return CallToolResult(
        content: [TextContent(text: 'Successfully $status URL scheme: $schemeId')],
      );
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error toggling URL scheme: $e')],
        isError: true,
      );
    }
  }

  /// 获取服务器实例
  Server get server => _server;

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;
}
