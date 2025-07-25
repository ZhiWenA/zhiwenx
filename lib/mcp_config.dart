import 'package:flutter_dotenv/flutter_dotenv.dart';

/// MCP服务器类型
enum McpServerType {
  sse('SSE'),
  http('HTTP');

  const McpServerType(this.displayName);
  final String displayName;
}

/// MCP服务器配置
class McpServerConfig {
  final String id;
  final String name;
  final String description;
  final McpServerType type;
  final String url;
  final Map<String, String> headers;
  final String? bearerToken;
  final bool enabled;
  final Duration? timeout;
  final bool enableCompression;
  final Duration? heartbeatInterval;

  const McpServerConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.url,
    this.headers = const {},
    this.bearerToken,
    this.enabled = true,
    this.timeout,
    this.enableCompression = false,
    this.heartbeatInterval,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'url': url,
      'headers': headers,
      'bearerToken': bearerToken,
      'enabled': enabled,
      'timeout': timeout?.inMilliseconds,
      'enableCompression': enableCompression,
      'heartbeatInterval': heartbeatInterval?.inMilliseconds,
    };
  }

  factory McpServerConfig.fromJson(Map<String, dynamic> json) {
    return McpServerConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      type: McpServerType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => McpServerType.sse,
      ),
      url: json['url'] as String,
      headers: Map<String, String>.from(json['headers'] ?? {}),
      bearerToken: json['bearerToken'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      timeout: json['timeout'] != null 
          ? Duration(milliseconds: json['timeout'] as int)
          : null,
      enableCompression: json['enableCompression'] as bool? ?? false,
      heartbeatInterval: json['heartbeatInterval'] != null 
          ? Duration(milliseconds: json['heartbeatInterval'] as int)
          : null,
    );
  }

  McpServerConfig copyWith({
    String? id,
    String? name,
    String? description,
    McpServerType? type,
    String? url,
    Map<String, String>? headers,
    String? bearerToken,
    bool? enabled,
    Duration? timeout,
    bool? enableCompression,
    Duration? heartbeatInterval,
  }) {
    return McpServerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      bearerToken: bearerToken ?? this.bearerToken,
      enabled: enabled ?? this.enabled,
      timeout: timeout ?? this.timeout,
      enableCompression: enableCompression ?? this.enableCompression,
      heartbeatInterval: heartbeatInterval ?? this.heartbeatInterval,
    );
  }
}

/// MCP配置管理类
class McpConfig {
  static List<McpServerConfig> _defaultServers = [];
  static List<McpServerConfig> _userServers = [];

  /// 是否已加载配置
  static bool get isConfigured => _defaultServers.isNotEmpty || _userServers.isNotEmpty;

  /// 获取所有服务器配置（默认 + 用户自定义）
  static List<McpServerConfig> get allServers => [..._defaultServers, ..._userServers];

  /// 获取已启用的服务器配置
  static List<McpServerConfig> get enabledServers => allServers.where((s) => s.enabled).toList();

  /// 获取默认服务器配置
  static List<McpServerConfig> get defaultServers => _defaultServers;

  /// 获取用户自定义服务器配置
  static List<McpServerConfig> get userServers => _userServers;

  /// 从.env文件加载默认MCP服务器配置
  static void loadFromEnv() {
    _defaultServers.clear();

    // 添加内置的 URL Schemes MCP Server（始终可用）
    _defaultServers.add(McpServerConfig(
      id: 'url_schemes',
      name: 'URL Schemes 服务器',
      description: '提供应用启动和 URL Schemes 管理功能',
      type: McpServerType.sse,
      url: 'builtin://url_schemes',  // 使用特殊的内置URL标识
      enabled: true,
    ));

    // 加载文件系统服务器
    final fileSystemUrl = dotenv.env['MCP_FILESYSTEM_URL'];
    if (fileSystemUrl != null && fileSystemUrl.isNotEmpty) {
      _defaultServers.add(McpServerConfig(
        id: 'filesystem',
        name: '文件系统服务器',
        description: '提供文件系统访问和操作功能',
        type: McpServerType.sse,
        url: fileSystemUrl,
        headers: _parseHeaders(dotenv.env['MCP_FILESYSTEM_HEADERS']),
        bearerToken: dotenv.env['MCP_FILESYSTEM_TOKEN'],
        enableCompression: dotenv.env['MCP_FILESYSTEM_COMPRESSION'] == 'true',
        heartbeatInterval: _parseDuration(dotenv.env['MCP_FILESYSTEM_HEARTBEAT']),
      ));
    }

    // 加载搜索服务器
    final searchUrl = dotenv.env['MCP_SEARCH_URL'];
    if (searchUrl != null && searchUrl.isNotEmpty) {
      _defaultServers.add(McpServerConfig(
        id: 'search',
        name: '搜索服务器',
        description: '提供网络搜索功能',
        type: _parseServerType(dotenv.env['MCP_SEARCH_TYPE']) ?? McpServerType.http,
        url: searchUrl,
        headers: _parseHeaders(dotenv.env['MCP_SEARCH_HEADERS']),
        bearerToken: dotenv.env['MCP_SEARCH_TOKEN'],
        timeout: _parseDuration(dotenv.env['MCP_SEARCH_TIMEOUT']),
        enableCompression: dotenv.env['MCP_SEARCH_COMPRESSION'] == 'true',
        heartbeatInterval: _parseDuration(dotenv.env['MCP_SEARCH_HEARTBEAT']),
      ));
    }

    // 加载数据库服务器
    final dbUrl = dotenv.env['MCP_DATABASE_URL'];
    if (dbUrl != null && dbUrl.isNotEmpty) {
      _defaultServers.add(McpServerConfig(
        id: 'database',
        name: '数据库服务器',
        description: '提供数据库查询和操作功能',
        type: _parseServerType(dotenv.env['MCP_DATABASE_TYPE']) ?? McpServerType.http,
        url: dbUrl,
        headers: _parseHeaders(dotenv.env['MCP_DATABASE_HEADERS']),
        bearerToken: dotenv.env['MCP_DATABASE_TOKEN'],
        timeout: _parseDuration(dotenv.env['MCP_DATABASE_TIMEOUT']),
        enableCompression: dotenv.env['MCP_DATABASE_COMPRESSION'] == 'true',
        heartbeatInterval: _parseDuration(dotenv.env['MCP_DATABASE_HEARTBEAT']),
      ));
    }

    // 加载自定义服务器
    for (int i = 1; i <= 5; i++) {
      final customUrl = dotenv.env['MCP_CUSTOM${i}_URL'];
      if (customUrl != null && customUrl.isNotEmpty) {
        _defaultServers.add(McpServerConfig(
          id: 'custom$i',
          name: dotenv.env['MCP_CUSTOM${i}_NAME'] ?? '自定义服务器 $i',
          description: dotenv.env['MCP_CUSTOM${i}_DESC'] ?? '自定义MCP服务器',
          type: _parseServerType(dotenv.env['MCP_CUSTOM${i}_TYPE']) ?? McpServerType.sse,
          url: customUrl,
          headers: _parseHeaders(dotenv.env['MCP_CUSTOM${i}_HEADERS']),
          bearerToken: dotenv.env['MCP_CUSTOM${i}_TOKEN'],
          timeout: _parseDuration(dotenv.env['MCP_CUSTOM${i}_TIMEOUT']),
          enableCompression: dotenv.env['MCP_CUSTOM${i}_COMPRESSION'] == 'true',
          heartbeatInterval: _parseDuration(dotenv.env['MCP_CUSTOM${i}_HEARTBEAT']),
        ));
      }
    }
  }

  /// 添加用户自定义服务器
  static void addUserServer(McpServerConfig server) {
    _userServers.removeWhere((s) => s.id == server.id);
    _userServers.add(server);
  }

  /// 移除用户自定义服务器
  static void removeUserServer(String serverId) {
    _userServers.removeWhere((s) => s.id == serverId);
  }

  /// 更新服务器配置
  static void updateServer(McpServerConfig server) {
    // 先尝试更新用户服务器
    final userIndex = _userServers.indexWhere((s) => s.id == server.id);
    if (userIndex != -1) {
      _userServers[userIndex] = server;
      return;
    }

    // 如果是默认服务器的修改，则添加到用户服务器中
    final defaultIndex = _defaultServers.indexWhere((s) => s.id == server.id);
    if (defaultIndex != -1) {
      _userServers.add(server);
    }
  }

  /// 重置所有配置
  static void reset() {
    _defaultServers.clear();
    _userServers.clear();
  }

  /// 解析服务器类型
  static McpServerType? _parseServerType(String? type) {
    if (type == null) return null;
    return McpServerType.values.where((e) => e.name.toLowerCase() == type.toLowerCase()).firstOrNull;
  }

  /// 解析请求头
  static Map<String, String> _parseHeaders(String? headers) {
    if (headers == null || headers.isEmpty) return {};
    
    final Map<String, String> result = {};
    final pairs = headers.split(',');
    
    for (final pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        result[parts[0].trim()] = parts[1].trim();
      }
    }
    
    return result;
  }

  /// 解析时间间隔
  static Duration? _parseDuration(String? duration) {
    if (duration == null || duration.isEmpty) return null;
    
    final seconds = int.tryParse(duration);
    if (seconds != null) {
      return Duration(seconds: seconds);
    }
    
    return null;
  }
}
