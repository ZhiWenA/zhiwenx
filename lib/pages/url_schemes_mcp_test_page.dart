import 'dart:async';
import 'package:flutter/material.dart';
import '../services/url_schemes_mcp_server.dart';
import '../mcp_service.dart';
import '../utils/url_schemes_mcp_test.dart';

class UrlSchemesMcpTestPage extends StatefulWidget {
  const UrlSchemesMcpTestPage({super.key});

  @override
  State<UrlSchemesMcpTestPage> createState() => _UrlSchemesMcpTestPageState();
}

class _UrlSchemesMcpTestPageState extends State<UrlSchemesMcpTestPage> {
  final UrlSchemesMcpServer _mcpServer = UrlSchemesMcpServer();
  final McpService _mcpService = McpService();
  bool _isServerRunning = false;
  bool _isBuiltinConnected = false;
  String _serverStatus = '未启动';
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _checkServerStatus();
    _checkBuiltinConnection();
  }

  void _checkServerStatus() {
    setState(() {
      _isServerRunning = _mcpServer.isInitialized;
      _updateServerStatus();
    });
  }

  void _checkBuiltinConnection() async {
    // 检查内置服务器连接状态
    final statuses = _mcpService.serverStatuses;
    final urlSchemesStatus = statuses.where((s) => s.serverId == 'url_schemes').firstOrNull;
    setState(() {
      _isBuiltinConnected = urlSchemesStatus?.state == McpConnectionState.connected;
      _updateServerStatus();
    });
  }

  void _updateServerStatus() {
    if (_isBuiltinConnected) {
      _serverStatus = '内置服务器已连接';
    } else if (_isServerRunning) {
      _serverStatus = '独立服务器运行中';
    } else {
      _serverStatus = '未启动';
    }
  }

  Future<void> _connectToBuiltinServer() async {
    try {
      _addLog('正在连接到内置 URL Schemes MCP Server...');
      
      // 初始化 MCP 服务
      await _mcpService.initialize();
      
      // 连接到内置 URL Schemes 服务器
      final success = await _mcpService.connectToServer('url_schemes');
      
      if (success) {
        setState(() {
          _isBuiltinConnected = true;
          _updateServerStatus();
        });
        _addLog('成功连接到内置 URL Schemes MCP Server');
        _addLog('现在可以通过 AI 对话调用 URL Schemes 功能');
      } else {
        _addLog('连接到内置服务器失败');
      }
    } catch (e) {
      _addLog('连接失败: $e');
    }
  }

  Future<void> _disconnectFromBuiltinServer() async {
    try {
      _addLog('正在断开内置 URL Schemes MCP Server...');
      
      await _mcpService.disconnectFromServer('url_schemes');
      
      setState(() {
        _isBuiltinConnected = false;
        _updateServerStatus();
      });
      
      _addLog('已断开内置 URL Schemes MCP Server');
    } catch (e) {
      _addLog('断开连接失败: $e');
    }
  }

  Future<void> _runIntegrationTest() async {
    try {
      _addLog('开始运行集成测试...');
      await UrlSchemesMcpIntegrationTest.runTest();
      _addLog('集成测试完成，请查看调试输出');
    } catch (e) {
      _addLog('集成测试失败: $e');
    }
  }

  Future<void> _testBuiltinConnection() async {
    if (!_isBuiltinConnected) {
      _addLog('请先连接到内置服务器');
      return;
    }

    try {
      _addLog('测试内置服务器: 获取 URL Schemes 列表');
      
      final result = await _mcpService.callTool('url_schemes', 'list_url_schemes', {
        'enabled_only': true,
      });
      
      _addLog('内置服务器测试成功');
      _addLog('返回数据: ${result.length > 100 ? result.substring(0, 100) + '...' : result}');
    } catch (e) {
      _addLog('内置服务器测试失败: $e');
    }
  }

  Future<void> _testSmartLaunch() async {
    if (!_isBuiltinConnected) {
      _addLog('请先连接到内置服务器');
      return;
    }

    try {
      _addLog('测试智能启动: 小红书搜索阿里云');
      
      // 模拟 AI 可能发送的错误参数格式
      final result = await _mcpService.callTool('url_schemes', 'launch_url_scheme', {
        'scheme_id': 'xiaohongshu',  // 错误的ID，应该被智能修正
        'parameters': {
          'action': 'search',       // 错误的参数名，应该被映射为keyword
          'query': '阿里云'          // 另一个错误的参数名，也应该被映射为keyword
        }
      });
      
      _addLog('智能启动测试完成');
      _addLog('结果: $result');
    } catch (e) {
      _addLog('智能启动测试失败: $e');
    }
  }

  Future<void> _startServer() async {
    try {
      _addLog('正在启动 URL Schemes MCP Server...');
      await _mcpServer.initialize();
      await _mcpServer.start(mode: 'stdio');
      
      setState(() {
        _isServerRunning = true;
        _serverStatus = '运行中 (STDIO)';
      });
      
      _addLog('MCP Server 启动成功');
    } catch (e) {
      _addLog('启动失败: $e');
      setState(() {
        _isServerRunning = false;
        _serverStatus = '启动失败';
      });
    }
  }

  Future<void> _startServerSSE() async {
    try {
      _addLog('正在启动 URL Schemes MCP Server (SSE模式)...');
      await _mcpServer.initialize();
      await _mcpServer.start(mode: 'sse', port: 8081);
      
      setState(() {
        _isServerRunning = true;
        _serverStatus = '运行中 (SSE:8081)';
      });
      
      _addLog('MCP Server 启动成功 (SSE模式, 端口: 8081)');
      _addLog('SSE 端点: http://localhost:8081/sse');
      _addLog('消息端点: http://localhost:8081/messages');
    } catch (e) {
      _addLog('启动失败: $e');
      setState(() {
        _isServerRunning = false;
        _serverStatus = '启动失败';
      });
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)} - $message');
    });
  }

  Future<void> _testListSchemes() async {
    if (!_isServerRunning) {
      _addLog('请先启动 MCP Server');
      return;
    }

    try {
      _addLog('测试: 获取 URL Schemes 列表');
      
      // 直接调用服务方法而不是通过MCP工具
      final result = await _mcpServer.handleListUrlSchemes({
        'enabled_only': true,
      });
      
      if (result.isError ?? false) {
        _addLog('获取列表失败: ${result.content.first}');
      } else {
        _addLog('成功获取 URL Schemes 列表');
        final content = result.content.first.toString();
        _addLog('返回数据: ${content.length > 100 ? content.substring(0, 100) + '...' : content}');
      }
    } catch (e) {
      _addLog('测试失败: $e');
    }
  }

  Future<void> _testLaunchScheme() async {
    if (!_isServerRunning) {
      _addLog('请先启动 MCP Server');
      return;
    }

    try {
      _addLog('测试: 启动小红书搜索');
      
      // 直接调用服务方法
      final result = await _mcpServer.handleLaunchUrlScheme({
        'scheme_id': 'xiaohongshu_search',
        'parameters': {
          'keyword': '测试关键词'
        }
      });
      
      if (result.isError ?? false) {
        _addLog('启动失败: ${result.content.first}');
      } else {
        _addLog('启动命令执行完成');
        _addLog('结果: ${result.content.first.toString()}');
      }
    } catch (e) {
      _addLog('测试失败: $e');
    }
  }

  Future<void> _testAddScheme() async {
    if (!_isServerRunning) {
      _addLog('请先启动 MCP Server');
      return;
    }

    try {
      _addLog('测试: 添加自定义 URL Scheme');
      
      final schemeConfig = {
        'id': 'test_app_scheme',
        'name': '测试应用',
        'description': '这是一个测试用的 URL Scheme',
        'scheme': 'testapp',
        'url_template': 'testapp://open?param={param}',
        'category': 'test',
        'enabled': true,
        'parameters': {
          'param': {
            'name': 'param',
            'description': '测试参数',
            'type': 'string',
            'required': false,
            'url_encode': true
          }
        }
      };
      
      // 直接调用服务方法
      final result = await _mcpServer.handleAddUrlScheme({
        'scheme_config': schemeConfig
      });
      
      if (result.isError ?? false) {
        _addLog('添加失败: ${result.content.first}');
      } else {
        _addLog('添加 URL Scheme 成功');
        _addLog('结果: ${result.content.first.toString()}');
      }
    } catch (e) {
      _addLog('测试失败: $e');
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('URL Schemes MCP 测试'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 服务器状态区域
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_isBuiltinConnected || _isServerRunning) ? Colors.green.shade50 : Colors.red.shade50,
              border: Border.all(
                color: (_isBuiltinConnected || _isServerRunning) ? Colors.green : Colors.red,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      (_isBuiltinConnected || _isServerRunning) ? Icons.check_circle : Icons.error,
                      color: (_isBuiltinConnected || _isServerRunning) ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'URL Schemes MCP 状态: $_serverStatus',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: (_isBuiltinConnected || _isServerRunning) ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'URL Schemes MCP Server 提供以下功能：\n'
                  '• 启动应用 URL Schemes\n'
                  '• 管理 URL Scheme 配置\n'
                  '• 获取可用 schemes 列表\n'
                  '• 支持 AI 对话调用\n'
                  '\n模式说明：\n'
                  '• 内置服务器：集成到 AI 对话系统，自动可用\n'
                  '• 独立服务器：可供外部应用连接',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // 控制按钮区域
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 内置服务器控制
                ElevatedButton.icon(
                  onPressed: _isBuiltinConnected ? _disconnectFromBuiltinServer : _connectToBuiltinServer,
                  icon: Icon(_isBuiltinConnected ? Icons.link_off : Icons.link),
                  label: Text(_isBuiltinConnected ? '断开内置服务器' : '连接内置服务器'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isBuiltinConnected ? Colors.orange : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isBuiltinConnected ? _testBuiltinConnection : null,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('测试内置服务器'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isBuiltinConnected ? _testSmartLaunch : null,
                  icon: const Icon(Icons.smart_toy),
                  label: const Text('测试智能启动'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _runIntegrationTest,
                  icon: const Icon(Icons.science),
                  label: const Text('运行集成测试'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
                
                // 分隔线
                const SizedBox(width: 16, child: Divider()),
                
                // 独立服务器控制
                ElevatedButton.icon(
                  onPressed: _isServerRunning ? null : _startServer,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('启动独立 (STDIO)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isServerRunning ? null : _startServerSSE,
                  icon: const Icon(Icons.web),
                  label: const Text('启动独立 (SSE)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isServerRunning ? _testListSchemes : null,
                  icon: const Icon(Icons.list),
                  label: const Text('测试列表'),
                ),
                ElevatedButton.icon(
                  onPressed: _isServerRunning ? _testLaunchScheme : null,
                  icon: const Icon(Icons.launch),
                  label: const Text('测试启动'),
                ),
                ElevatedButton.icon(
                  onPressed: _isServerRunning ? _testAddScheme : null,
                  icon: const Icon(Icons.add),
                  label: const Text('测试添加'),
                ),
                ElevatedButton.icon(
                  onPressed: _clearLogs,
                  icon: const Icon(Icons.clear),
                  label: const Text('清空日志'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 日志区域
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '测试日志',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _logs.isEmpty
                        ? const Center(
                            child: Text(
                              '暂无日志\n点击上方按钮开始测试',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  _logs[index],
                                  style: const TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // 使用说明
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      '使用说明',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '推荐使用方式：\n'
                  '1. 点击"连接内置服务器"启用 AI 对话集成\n'
                  '2. 使用"测试内置服务器"验证功能\n'
                  '3. 在 AI 对话中直接调用 URL Schemes 功能\n'
                  '\n独立服务器模式：\n'
                  '4. STDIO 模式适合命令行集成\n'
                  '5. SSE 模式适合 Web 应用集成',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
