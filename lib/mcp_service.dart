import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:mcp_client/mcp_client.dart' as mcp;
import 'package:mcp_llm/mcp_llm.dart';
import 'mcp_config.dart';
import 'services/url_schemes_mcp_server.dart';



/// MCP工具信息
class McpToolInfo {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final String serverId;

  const McpToolInfo({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.serverId,
  });
}

/// MCP服务器连接状态
enum McpConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// MCP服务器状态
class McpServerStatus {
  final String serverId;
  final String serverName;
  final McpConnectionState state;
  final String? error;
  final DateTime? lastConnected;
  final List<McpToolInfo> tools;
  final mcp.ServerInfo? serverInfo;

  const McpServerStatus({
    required this.serverId,
    required this.serverName,
    required this.state,
    this.error,
    this.lastConnected,
    this.tools = const [],
    this.serverInfo,
  });

  McpServerStatus copyWith({
    String? serverId,
    String? serverName,
    McpConnectionState? state,
    String? error,
    DateTime? lastConnected,
    List<McpToolInfo>? tools,
    mcp.ServerInfo? serverInfo,
  }) {
    return McpServerStatus(
      serverId: serverId ?? this.serverId,
      serverName: serverName ?? this.serverName,
      state: state ?? this.state,
      error: error ?? this.error,
      lastConnected: lastConnected ?? this.lastConnected,
      tools: tools ?? this.tools,
      serverInfo: serverInfo ?? this.serverInfo,
    );
  }
}

/// MCP服务管理类
class McpService {
  static final McpService _instance = McpService._internal();
  factory McpService() => _instance;
  McpService._internal();

  final Logger _logger = Logger('mcp_service');
  final Map<String, mcp.Client> _clients = {};
  final Map<String, McpServerStatus> _serverStatuses = {};
  final StreamController<List<McpServerStatus>> _statusController = 
      StreamController<List<McpServerStatus>>.broadcast();

  // 内置服务器实例
  UrlSchemesMcpServer? _urlSchemesServer;

  /// 获取服务器状态流
  Stream<List<McpServerStatus>> get serverStatusStream => _statusController.stream;

  /// 获取当前服务器状态列表
  List<McpServerStatus> get serverStatuses => _serverStatuses.values.toList();

  /// 获取已连接的客户端
  Map<String, mcp.Client> get connectedClients => Map.unmodifiable(_clients);

  /// 初始化MCP服务
  Future<void> initialize() async {
    _logger.info('Initializing MCP service...');
    
    // 设置日志级别
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((record) {
      if (kDebugMode) {
        print('[${record.level.name}] ${record.loggerName}: ${record.message}');
      }
    });

    // 加载配置
    McpConfig.loadFromEnv();
    
    // 初始化服务器状态
    for (final server in McpConfig.allServers) {
      _serverStatuses[server.id] = McpServerStatus(
        serverId: server.id,
        serverName: server.name,
        state: McpConnectionState.disconnected,
      );
    }
    
    _notifyStatusUpdate();
    _logger.info('MCP service initialized with ${McpConfig.allServers.length} servers');
  }

  /// 连接到指定服务器
  Future<bool> connectToServer(String serverId) async {
    final server = McpConfig.allServers.where((s) => s.id == serverId).firstOrNull;
    if (server == null) {
      _logger.warning('Server not found: $serverId');
      return false;
    }

    if (_clients.containsKey(serverId)) {
      _logger.info('Already connected to server: $serverId');
      return true;
    }

    _updateServerStatus(serverId, McpConnectionState.connecting);

    try {
      // 检查是否为内置 URL Schemes 服务器
      if (serverId == 'url_schemes' && server.url == 'builtin://url_schemes') {
        return await _connectToBuiltinUrlSchemesServer(serverId, server);
      }

      _logger.info('Connecting to MCP server: ${server.name} (${server.url})');

      // 创建客户端配置
      final config = mcp.McpClient.simpleConfig(
        name: 'ZhiWenX Client',
        version: '1.0.0',
        enableDebugLogging: kDebugMode,
      );

      // 创建传输配置
      late mcp.TransportConfig transportConfig;
      
      if (server.type == McpServerType.sse) {
        transportConfig = mcp.TransportConfig.sse(
          serverUrl: server.url,
          headers: server.headers,
          bearerToken: server.bearerToken,
          enableCompression: server.enableCompression,
          heartbeatInterval: server.heartbeatInterval,
        );
      } else {
        transportConfig = mcp.TransportConfig.streamableHttp(
          baseUrl: server.url,
          headers: server.headers,
          timeout: server.timeout ?? const Duration(seconds: 30),
          enableCompression: server.enableCompression,
          heartbeatInterval: server.heartbeatInterval,
        );
      }

      // 创建并连接客户端
      final clientResult = await mcp.McpClient.createAndConnect(
        config: config,
        transportConfig: transportConfig,
      );

      final client = clientResult.fold(
        (c) => c,
        (error) => throw Exception('Failed to connect: $error'),
      );

      _clients[serverId] = client;

      // 设置事件监听器
      _setupClientEventListeners(serverId, client);

      // 获取服务器信息和工具列表
      final tools = await _loadServerTools(serverId, client);
      
      _updateServerStatus(
        serverId, 
        McpConnectionState.connected,
        tools: tools,
        lastConnected: DateTime.now(),
      );

      _logger.info('Successfully connected to server: ${server.name}');
      return true;

    } catch (e) {
      _logger.severe('Failed to connect to server $serverId: $e');
      _updateServerStatus(
        serverId, 
        McpConnectionState.error,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 断开与指定服务器的连接
  Future<void> disconnectFromServer(String serverId) async {
    final client = _clients.remove(serverId);
    if (client != null) {
      client.dispose();
      _logger.info('Disconnected from server: $serverId');
    }

    // 如果是内置 URL Schemes 服务器，清理实例
    if (serverId == 'url_schemes') {
      _urlSchemesServer = null;
    }

    _updateServerStatus(serverId, McpConnectionState.disconnected);
  }

  /// 连接到内置 URL Schemes 服务器
  Future<bool> _connectToBuiltinUrlSchemesServer(String serverId, McpServerConfig server) async {
    try {
      _logger.info('Connecting to builtin URL Schemes server...');

      // 初始化内置 URL Schemes 服务器
      _urlSchemesServer = UrlSchemesMcpServer();
      await _urlSchemesServer!.initialize();

      // 创建模拟的工具列表
      final tools = [
        McpToolInfo(
          name: 'launch_url_scheme',
          description: 'Launch an app using URL scheme with parameters',
          inputSchema: {
            'type': 'object',
            'properties': {
              'scheme_id': {'type': 'string', 'description': 'The ID of the URL scheme to launch'},
              'parameters': {'type': 'object', 'description': 'Parameters to pass to the URL scheme'},
            },
            'required': ['scheme_id']
          },
          serverId: serverId,
        ),
        McpToolInfo(
          name: 'list_url_schemes',
          description: 'Get list of available URL schemes',
          inputSchema: {
            'type': 'object',
            'properties': {
              'category': {'type': 'string', 'description': 'Filter by category (optional)'},
              'enabled_only': {'type': 'boolean', 'description': 'Only return enabled schemes', 'default': true},
            },
            'required': []
          },
          serverId: serverId,
        ),
        McpToolInfo(
          name: 'add_url_scheme',
          description: 'Add a new URL scheme configuration',
          inputSchema: {
            'type': 'object',
            'properties': {
              'scheme_config': {'type': 'object', 'description': 'URL scheme configuration object'},
            },
            'required': ['scheme_config']
          },
          serverId: serverId,
        ),
        McpToolInfo(
          name: 'update_url_scheme',
          description: 'Update an existing URL scheme configuration',
          inputSchema: {
            'type': 'object',
            'properties': {
              'scheme_id': {'type': 'string', 'description': 'The ID of the URL scheme to update'},
              'scheme_config': {'type': 'object', 'description': 'Updated URL scheme configuration'},
            },
            'required': ['scheme_id', 'scheme_config']
          },
          serverId: serverId,
        ),
        McpToolInfo(
          name: 'remove_url_scheme',
          description: 'Remove a URL scheme configuration',
          inputSchema: {
            'type': 'object',
            'properties': {
              'scheme_id': {'type': 'string', 'description': 'The ID of the URL scheme to remove'},
            },
            'required': ['scheme_id']
          },
          serverId: serverId,
        ),
        McpToolInfo(
          name: 'toggle_url_scheme',
          description: 'Enable or disable a URL scheme',
          inputSchema: {
            'type': 'object',
            'properties': {
              'scheme_id': {'type': 'string', 'description': 'The ID of the URL scheme to toggle'},
              'enabled': {'type': 'boolean', 'description': 'Whether to enable or disable the scheme'},
            },
            'required': ['scheme_id', 'enabled']
          },
          serverId: serverId,
        ),
      ];

      _updateServerStatus(
        serverId,
        McpConnectionState.connected,
        tools: tools,
        lastConnected: DateTime.now(),
      );

      _logger.info('Successfully connected to builtin URL Schemes server');
      return true;
    } catch (e) {
      _logger.severe('Failed to connect to builtin URL Schemes server: $e');
      _updateServerStatus(
        serverId,
        McpConnectionState.error,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 断开所有连接
  Future<void> disconnectAll() async {
    _logger.info('Disconnecting from all MCP servers...');
    
    for (final client in _clients.values) {
      client.dispose();
    }
    
    _clients.clear();

    for (final serverId in _serverStatuses.keys) {
      _updateServerStatus(serverId, McpConnectionState.disconnected);
    }

    _logger.info('Disconnected from all servers');
  }

  /// 测试与服务器的连接
  Future<bool> testConnection(McpServerConfig server) async {
    try {
      _logger.info('Testing connection to: ${server.name}');

      // 如果是内置 URL Schemes 服务器，直接返回成功
      if (server.id == 'url_schemes' && server.url == 'builtin://url_schemes') {
        _logger.info('Builtin URL Schemes server test successful');
        return true;
      }

      final config = mcp.McpClient.simpleConfig(
        name: 'ZhiWenX Test Client',
        version: '1.0.0',
        enableDebugLogging: false,
      );

      late mcp.TransportConfig transportConfig;
      
      if (server.type == McpServerType.sse) {
        transportConfig = mcp.TransportConfig.sse(
          serverUrl: server.url,
          headers: server.headers,
          bearerToken: server.bearerToken,
        );
      } else {
        transportConfig = mcp.TransportConfig.streamableHttp(
          baseUrl: server.url,
          headers: server.headers,
          timeout: const Duration(seconds: 10),
        );
      }

      final clientResult = await mcp.McpClient.createAndConnect(
        config: config,
        transportConfig: transportConfig,
      );

      final client = clientResult.fold(
        (c) => c,
        (error) => throw Exception('Connection failed: $error'),
      );

      // 测试基本功能
      await client.listTools();
      
      // 立即断开连接
      client.dispose();

      _logger.info('Connection test successful for: ${server.name}');
      return true;

    } catch (e) {
      _logger.warning('Connection test failed for ${server.name}: $e');
      return false;
    }
  }

  /// 获取指定服务器的工具列表
  Future<List<McpToolInfo>> getServerTools(String serverId) async {
    final status = _serverStatuses[serverId];
    if (status != null && status.state == McpConnectionState.connected) {
      return status.tools;
    }
    return [];
  }

  /// 调用指定服务器的工具
  Future<String> callTool(String serverId, String toolName, Map<String, dynamic> arguments) async {
    // 检查是否为内置 URL Schemes 服务器
    if (serverId == 'url_schemes' && _urlSchemesServer != null) {
      return await _callBuiltinUrlSchemesTool(toolName, arguments);
    }

    final client = _clients[serverId];
    if (client == null) {
      throw Exception('Server not connected: $serverId');
    }

    try {
      _logger.info('Calling tool $toolName on server $serverId with arguments: $arguments');
      
      final result = await client.callTool(toolName, arguments);
      
      if (result.content.isNotEmpty) {
        final content = result.content.first;
        if (content is mcp.TextContent) {
          return content.text;
        }
      }
      
      return 'Tool executed successfully';

    } catch (e) {
      _logger.severe('Failed to call tool $toolName on server $serverId: $e');
      throw Exception('Tool execution failed: $e');
    }
  }

  /// 调用内置 URL Schemes 工具
  Future<String> _callBuiltinUrlSchemesTool(String toolName, Map<String, dynamic> arguments) async {
    if (_urlSchemesServer == null) {
      throw Exception('URL Schemes server not initialized');
    }

    try {
      _logger.info('Calling builtin URL Schemes tool: $toolName with arguments: $arguments');

      late final result;
      switch (toolName) {
        case 'launch_url_scheme':
          result = await _urlSchemesServer!.handleLaunchUrlScheme(arguments);
          break;
        case 'list_url_schemes':
          result = await _urlSchemesServer!.handleListUrlSchemes(arguments);
          break;
        case 'add_url_scheme':
          result = await _urlSchemesServer!.handleAddUrlScheme(arguments);
          break;
        default:
          throw Exception('Unknown tool: $toolName');
      }

      if (result.content.isNotEmpty) {
        final content = result.content.first;
        if (content.text != null) {
          return content.text!;
        }
      }

      return 'Tool executed successfully';
    } catch (e) {
      _logger.severe('Failed to call builtin URL Schemes tool $toolName: $e');
      throw Exception('Tool execution failed: $e');
    }
  }

  /// 重新加载配置
  Future<void> reloadConfig() async {
    _logger.info('Reloading MCP configuration...');
    
    // 断开所有连接
    await disconnectAll();
    
    // 重新加载配置
    McpConfig.loadFromEnv();
    
    // 更新服务器状态
    _serverStatuses.clear();
    for (final server in McpConfig.allServers) {
      _serverStatuses[server.id] = McpServerStatus(
        serverId: server.id,
        serverName: server.name,
        state: McpConnectionState.disconnected,
      );
    }
    
    _notifyStatusUpdate();
    _logger.info('Configuration reloaded');
  }

  /// 设置客户端事件监听器
  void _setupClientEventListeners(String serverId, mcp.Client client) {
    client.onConnect.listen((serverInfo) {
      _logger.info('Server $serverId connected: ${serverInfo.name} v${serverInfo.version}');
      _updateServerStatus(serverId, McpConnectionState.connected, serverInfo: serverInfo);
    });

    client.onDisconnect.listen((reason) {
      _logger.info('Server $serverId disconnected: $reason');
      _clients.remove(serverId);
      _updateServerStatus(serverId, McpConnectionState.disconnected);
    });

    client.onError.listen((error) {
      _logger.severe('Error from server $serverId: ${error.message}');
      _updateServerStatus(serverId, McpConnectionState.error, error: error.message);
    });
  }

  /// 加载服务器工具列表
  Future<List<McpToolInfo>> _loadServerTools(String serverId, mcp.Client client) async {
    try {
      final tools = await client.listTools();
      return tools.map((tool) => McpToolInfo(
        name: tool.name,
        description: tool.description.isNotEmpty ? tool.description : 'No description available',
        inputSchema: tool.inputSchema,
        serverId: serverId,
      )).toList();
    } catch (e) {
      _logger.warning('Failed to load tools for server $serverId: $e');
      return [];
    }
  }

  /// 更新服务器状态
  void _updateServerStatus(
    String serverId,
    McpConnectionState state, {
    String? error,
    DateTime? lastConnected,
    List<McpToolInfo>? tools,
    mcp.ServerInfo? serverInfo,
  }) {
    final currentStatus = _serverStatuses[serverId];
    if (currentStatus != null) {
      _serverStatuses[serverId] = currentStatus.copyWith(
        state: state,
        error: error,
        lastConnected: lastConnected,
        tools: tools,
        serverInfo: serverInfo,
      );
      _notifyStatusUpdate();
    }
  }

  /// 通知状态更新
  void _notifyStatusUpdate() {
    if (!_statusController.isClosed) {
      _statusController.add(serverStatuses);
    }
  }

  /// 释放资源
  void dispose() {
    disconnectAll();
    _statusController.close();
  }
}
