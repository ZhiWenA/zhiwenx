import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/url_schemes_mcp_server.dart';

/// URL Schemes MCP Server 启动器
class UrlSchemesMcpServerLauncher {
  static UrlSchemesMcpServer? _server;
  static bool _isRunning = false;

  /// 启动 MCP Server
  static Future<void> start({
    String mode = 'stdio',
    int port = 8080,
  }) async {
    if (_isRunning) {
      debugPrint('URL Schemes MCP Server is already running');
      return;
    }

    try {
      _server = UrlSchemesMcpServer();
      await _server!.start(mode: mode, port: port);
      _isRunning = true;
      
      debugPrint('URL Schemes MCP Server started successfully');
      
      // 监听进程退出信号
      _setupSignalHandlers();
    } catch (e) {
      debugPrint('Failed to start URL Schemes MCP Server: $e');
      rethrow;
    }
  }

  /// 停止 MCP Server
  static Future<void> stop() async {
    if (!_isRunning || _server == null) {
      return;
    }

    try {
      // 这里可以添加清理逻辑
      _server = null;
      _isRunning = false;
      debugPrint('URL Schemes MCP Server stopped');
    } catch (e) {
      debugPrint('Error stopping URL Schemes MCP Server: $e');
    }
  }

  /// 检查服务器是否正在运行
  static bool get isRunning => _isRunning;

  /// 获取服务器实例
  static UrlSchemesMcpServer? get server => _server;

  /// 设置信号处理器
  static void _setupSignalHandlers() {
    if (!kIsWeb && !Platform.isWindows) {
      // Unix-like systems
      ProcessSignal.sigint.watch().listen((_) async {
        debugPrint('Received SIGINT, shutting down...');
        await stop();
        exit(0);
      });

      ProcessSignal.sigterm.watch().listen((_) async {
        debugPrint('Received SIGTERM, shutting down...');
        await stop();
        exit(0);
      });
    }
  }
}

/// 独立的 MCP Server 程序入口
Future<void> main(List<String> args) async {
  // 解析命令行参数
  String mode = 'stdio';
  int port = 8080;
  
  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--mcp-stdio-mode':
        mode = 'stdio';
        break;
      case '--mcp-sse-mode':
        mode = 'sse';
        break;
      case '--port':
        if (i + 1 < args.length) {
          port = int.tryParse(args[i + 1]) ?? 8080;
          i++;
        }
        break;
      case '--help':
        _printUsage();
        exit(0);
    }
  }

  try {
    debugPrint('Starting URL Schemes MCP Server...');
    debugPrint('Mode: $mode');
    if (mode == 'sse') {
      debugPrint('Port: $port');
    }

    await UrlSchemesMcpServerLauncher.start(mode: mode, port: port);

    // 保持程序运行
    await Future.delayed(const Duration(hours: 24));
  } catch (e) {
    debugPrint('Error: $e');
    exit(1);
  }
}

void _printUsage() {
  print('''
URL Schemes MCP Server

Usage:
  dart run lib/mcp/url_schemes_mcp_server_launcher.dart [options]

Options:
  --mcp-stdio-mode    Use STDIO transport (default)
  --mcp-sse-mode      Use SSE transport
  --port <port>       Port for SSE transport (default: 8080)
  --help              Show this help message

Examples:
  # Start with STDIO transport
  dart run lib/mcp/url_schemes_mcp_server_launcher.dart --mcp-stdio-mode

  # Start with SSE transport on port 8081
  dart run lib/mcp/url_schemes_mcp_server_launcher.dart --mcp-sse-mode --port 8081
''');
}
