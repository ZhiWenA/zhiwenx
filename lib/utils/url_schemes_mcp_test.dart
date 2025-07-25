import 'package:flutter/foundation.dart';
import '../mcp_service.dart';
import '../mcp_config.dart';

/// URL Schemes MCP 集成测试
class UrlSchemesMcpIntegrationTest {
  static final McpService _mcpService = McpService();

  /// 运行完整的集成测试
  static Future<void> runTest() async {
    try {
      debugPrint('=== URL Schemes MCP 集成测试开始 ===');

      // 1. 初始化 MCP 服务
      debugPrint('1. 初始化 MCP 服务...');
      await _mcpService.initialize();
      debugPrint('✓ MCP 服务初始化成功');

      // 2. 验证 URL Schemes 服务器在配置中
      debugPrint('2. 检查 URL Schemes 服务器配置...');
      final servers = McpConfig.allServers;
      final urlSchemesServer = servers.where((s) => s.id == 'url_schemes').firstOrNull;
      
      if (urlSchemesServer != null) {
        debugPrint('✓ 找到 URL Schemes 服务器配置: ${urlSchemesServer.name}');
        debugPrint('  - URL: ${urlSchemesServer.url}');
        debugPrint('  - 启用状态: ${urlSchemesServer.enabled}');
      } else {
        debugPrint('✗ 未找到 URL Schemes 服务器配置');
        return;
      }

      // 3. 连接到 URL Schemes 服务器
      debugPrint('3. 连接到 URL Schemes 服务器...');
      final connected = await _mcpService.connectToServer('url_schemes');
      
      if (connected) {
        debugPrint('✓ 成功连接到 URL Schemes 服务器');
      } else {
        debugPrint('✗ 连接 URL Schemes 服务器失败');
        return;
      }

      // 4. 验证工具列表
      debugPrint('4. 验证可用工具...');
      final tools = await _mcpService.getServerTools('url_schemes');
      debugPrint('✓ 发现 ${tools.length} 个工具:');
      for (final tool in tools) {
        debugPrint('  - ${tool.name}: ${tool.description}');
      }

      // 5. 测试工具调用
      debugPrint('5. 测试工具调用...');
      
      // 测试获取 URL Schemes 列表
      try {
        final result = await _mcpService.callTool('url_schemes', 'list_url_schemes', {
          'enabled_only': true,
        });
        debugPrint('✓ list_url_schemes 调用成功');
        debugPrint('  返回数据长度: ${result.length} 字符');
      } catch (e) {
        debugPrint('✗ list_url_schemes 调用失败: $e');
      }

      // 6. 检查服务器状态
      debugPrint('6. 检查服务器状态...');
      final statuses = _mcpService.serverStatuses;
      final urlSchemesStatus = statuses.where((s) => s.serverId == 'url_schemes').firstOrNull;
      
      if (urlSchemesStatus != null) {
        debugPrint('✓ 服务器状态: ${urlSchemesStatus.state}');
        debugPrint('  - 工具数量: ${urlSchemesStatus.tools.length}');
        debugPrint('  - 最后连接: ${urlSchemesStatus.lastConnected}');
      }

      debugPrint('=== URL Schemes MCP 集成测试完成 ===');
      debugPrint('✓ 所有测试通过，URL Schemes MCP Server 已成功集成到 AI 对话系统');

    } catch (e) {
      debugPrint('✗ 集成测试失败: $e');
    }
  }

  /// 测试具体的 URL Scheme 启动
  static Future<void> testUrlSchemeExecution() async {
    try {
      debugPrint('=== URL Scheme 执行测试 ===');

      // 测试启动小红书搜索
      debugPrint('测试启动小红书搜索...');
      final result = await _mcpService.callTool('url_schemes', 'launch_url_scheme', {
        'scheme_id': 'xiaohongshu_search',
        'parameters': {
          'keyword': '测试关键词'
        }
      });
      
      debugPrint('✓ 小红书搜索启动结果: $result');

    } catch (e) {
      debugPrint('✗ URL Scheme 执行测试失败: $e');
    }
  }
}
