import 'package:flutter/material.dart';
import 'enhanced_openai_service_v2.dart';
import 'mcp_service.dart';
import 'chat_models.dart';

class McpTestPage extends StatefulWidget {
  const McpTestPage({super.key});

  @override
  State<McpTestPage> createState() => _McpTestPageState();
}

class _McpTestPageState extends State<McpTestPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<String> _logs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeMcp();
  }

  void _initializeMcp() async {
    _addLog('🚀 初始化MCP服务...');
    try {
      await EnhancedOpenAIService.initialize();
      _addLog('✅ MCP服务初始化成功');
      
      // 获取可用工具
      final tools = await EnhancedOpenAIService.getAvailableTools();
      _addLog('🔧 发现 ${tools.length} 个可用工具:');
      for (final tool in tools) {
        _addLog('  • ${tool.name}: ${tool.description}');
      }
    } catch (e) {
      _addLog('❌ MCP服务初始化失败: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
  }

  void _testMcpIntegration() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    _addLog('📝 测试消息: "$message"');

    try {
      // 模拟聊天消息
      final messages = [
        ChatMessage.system('你是一个有用的AI助手，可以调用外部工具来帮助用户。'),
        ChatMessage.user(message),
      ];

      _addLog('🤖 AI正在分析是否需要调用工具...');

      // 使用增强服务处理
      final responseStream = EnhancedOpenAIService.sendStreamChatRequest(messages);
      
      final buffer = StringBuffer();
      await for (final chunk in responseStream) {
        buffer.write(chunk);
      }
      
      final response = buffer.toString();
      _addLog('💬 AI回复: ${response.substring(0, response.length > 100 ? 100 : response.length)}...');

      // 检查工具状态
      final tools = await EnhancedOpenAIService.getAvailableTools();
      _addLog('🔧 当前可用工具数量: ${tools.length}');

    } catch (e) {
      _addLog('❌ 测试失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

    _messageController.clear();
  }

  void _testDirectToolCall() async {
    _addLog('🧪 直接测试工具调用...');
    
    try {
      final tools = await EnhancedOpenAIService.getAvailableTools();
      if (tools.isEmpty) {
        _addLog('❌ 没有可用的工具');
        return;
      }

      final tool = tools.first;
      _addLog('🔧 测试调用工具: ${tool.name}');

      final mcpService = McpService();
      final result = await mcpService.callTool(
        tool.serverId, 
        tool.name, 
        {'query': '测试调用'}
      );
      
      _addLog('✅ 工具调用成功: $result');
    } catch (e) {
      _addLog('❌ 工具调用失败: $e');
    }
  }

  void _refreshMcpStatus() async {
    _addLog('🔄 刷新MCP状态...');
    
    try {
      await EnhancedOpenAIService.refreshAllTools();
      
      final statuses = EnhancedOpenAIService.getMcpServerStatuses();
      _addLog('📊 MCP服务器状态:');
      for (final status in statuses) {
        _addLog('  • ${status.serverName}: ${status.state.name} (${status.tools.length} 工具)');
      }
    } catch (e) {
      _addLog('❌ 刷新失败: $e');
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
        title: const Text('MCP 功能测试'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refreshMcpStatus,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新状态',
          ),
          IconButton(
            onPressed: _clearLogs,
            icon: const Icon(Icons.clear_all),
            tooltip: '清空日志',
          ),
        ],
      ),
      body: Column(
        children: [
          // 控制面板
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'MCP功能测试',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                // 测试消息输入
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: '输入测试消息，如: "帮我查询当前时间"',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (_) => _testMcpIntegration(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testMcpIntegration,
                      child: _isLoading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('测试'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // 控制按钮
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _testDirectToolCall,
                      icon: const Icon(Icons.build, size: 16),
                      label: const Text('直接调用工具'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _refreshMcpStatus,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('刷新状态'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 日志显示
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '测试日志',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_logs.length} 条记录',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _logs.isEmpty
                          ? const Center(
                              child: Text(
                                '点击上方按钮开始测试...',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                Color textColor = Colors.white;
                                
                                if (log.contains('❌')) {
                                  textColor = Colors.red.shade300;
                                } else if (log.contains('✅')) {
                                  textColor = Colors.green.shade300;
                                } else if (log.contains('🤖') || log.contains('💬')) {
                                  textColor = Colors.blue.shade300;
                                } else if (log.contains('🔧')) {
                                  textColor = Colors.orange.shade300;
                                }
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 1),
                                  child: SelectableText(
                                    log,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
