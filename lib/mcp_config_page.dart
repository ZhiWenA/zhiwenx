import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'mcp_config.dart';
import 'mcp_service.dart';
import 'enhanced_openai_service_v2.dart';

class McpConfigPage extends StatefulWidget {
  const McpConfigPage({super.key});

  @override
  State<McpConfigPage> createState() => _McpConfigPageState();
}

class _McpConfigPageState extends State<McpConfigPage> with SingleTickerProviderStateMixin {
  final McpService _mcpService = McpService();
  late TabController _tabController;
  List<McpServerStatus> _serverStatuses = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeMcp();
    _listenToStatusUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeMcp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _mcpService.initialize();
    } catch (e) {
      _showErrorSnackBar('MCP 初始化失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _listenToStatusUpdates() {
    _mcpService.serverStatusStream.listen((statuses) {
      if (mounted) {
        setState(() {
          _serverStatuses = statuses;
        });
      }
    });
    
    // 立即获取当前状态
    setState(() {
      _serverStatuses = _mcpService.serverStatuses;
    });
    
    // 启动定时刷新
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _refreshTools();
    });
  }

  void _refreshTools() async {
    try {
      await EnhancedOpenAIService.refreshAllTools();
    } catch (e) {
      // 静默失败，不显示错误
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP 配置'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.settings_remote), text: '服务器'),
            Tab(icon: Icon(Icons.build), text: '工具'),
            Tab(icon: Icon(Icons.info_outline), text: '帮助'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _reloadConfig,
            icon: const Icon(Icons.refresh),
            tooltip: '重新加载配置',
          ),
          IconButton(
            onPressed: _showAddServerDialog,
            icon: const Icon(Icons.add),
            tooltip: '添加服务器',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildServerTab(),
                _buildToolsTab(),
                _buildHelpTab(),
              ],
            ),
    );
  }

  Widget _buildServerTab() {
    return RefreshIndicator(
      onRefresh: _reloadConfig,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _serverStatuses.length,
        itemBuilder: (context, index) {
          final status = _serverStatuses[index];
          return _buildServerCard(status);
        },
      ),
    );
  }

  Widget _buildServerCard(McpServerStatus status) {
    final server = McpConfig.allServers.where((s) => s.id == status.serverId).firstOrNull;
    if (server == null) return const SizedBox.shrink();

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status.state) {
      case McpConnectionState.connected:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = '已连接';
        break;
      case McpConnectionState.connecting:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = '连接中...';
        break;
      case McpConnectionState.error:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = '连接失败';
        break;
      case McpConnectionState.disconnected:
        statusColor = Colors.grey;
        statusIcon = Icons.radio_button_unchecked;
        statusText = '未连接';
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ExpansionTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(
          server.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(server.description),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    server.type.displayName,
                    style: const TextStyle(fontSize: 12),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status.state == McpConnectionState.connected)
              IconButton(
                onPressed: () => _disconnectServer(status.serverId),
                icon: const Icon(Icons.link_off),
                tooltip: '断开连接',
              )
            else if (status.state != McpConnectionState.connecting)
              IconButton(
                onPressed: () => _connectServer(status.serverId),
                icon: const Icon(Icons.link),
                tooltip: '连接',
              ),
            IconButton(
              onPressed: () => _testConnection(server),
              icon: const Icon(Icons.wifi_find),
              tooltip: '测试连接',
            ),
            if (!McpConfig.defaultServers.contains(server))
              IconButton(
                onPressed: () => _editServer(server),
                icon: const Icon(Icons.edit),
                tooltip: '编辑',
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('服务器ID', status.serverId),
                _buildInfoRow('服务器URL', server.url),
                if (server.bearerToken != null)
                  _buildInfoRow('认证令牌', '***已配置***'),
                if (server.headers.isNotEmpty)
                  _buildInfoRow('自定义请求头', server.headers.entries.map((e) => '${e.key}: ${e.value}').join('\n')),
                if (status.serverInfo != null) ...[
                  const Divider(),
                  const Text('服务器信息:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildInfoRow('服务器名称', status.serverInfo!.name),
                  _buildInfoRow('服务器版本', status.serverInfo!.version),
                  _buildInfoRow('协议版本', status.serverInfo!.protocolVersion ?? 'Unknown'),
                ],
                if (status.tools.isNotEmpty) ...[
                  const Divider(),
                  Text('可用工具 (${status.tools.length}个):', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...status.tools.map((tool) => Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.build, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tool.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text(tool.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
                if (status.error != null) ...[
                  const Divider(),
                  Text('错误信息:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.error!,
                      style: TextStyle(color: Colors.red.shade700, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: value));
                _showSuccessSnackBar('已复制到剪贴板');
              },
              child: Text(
                value,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsTab() {
    final connectedServers = _serverStatuses.where((s) => s.state == McpConnectionState.connected).toList();
    
    if (connectedServers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '没有已连接的MCP服务器',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              '请在"服务器"标签页中连接MCP服务器',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: connectedServers.length,
      itemBuilder: (context, index) {
        final serverStatus = connectedServers[index];
        return _buildServerToolsCard(serverStatus);
      },
    );
  }

  Widget _buildServerToolsCard(McpServerStatus serverStatus) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.dns, color: Colors.blue),
        title: Text(serverStatus.serverName),
        subtitle: Text('${serverStatus.tools.length} 个工具'),
        children: [
          if (serverStatus.tools.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('此服务器未提供工具'),
            )
          else
            ...serverStatus.tools.map((tool) => ListTile(
              leading: const Icon(Icons.build, size: 20),
              title: Text(tool.name),
              subtitle: Text(tool.description),
              trailing: IconButton(
                onPressed: () => _showToolDetails(tool),
                icon: const Icon(Icons.info_outline),
                tooltip: '查看详情',
              ),
              onTap: () => _testTool(tool),
            )),
        ],
      ),
    );
  }

  Widget _buildHelpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MCP (Model Context Protocol) 配置说明',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          _buildHelpSection(
            '什么是 MCP？',
            'Model Context Protocol (MCP) 是一个标准化协议，用于连接AI应用程序与外部工具和数据源。通过MCP，AI可以访问文件系统、数据库、搜索引擎等各种服务。',
          ),
          
          _buildHelpSection(
            '支持的服务器类型',
            '• SSE (Server-Sent Events): 适用于实时数据流和长连接\n'
            '• HTTP: 适用于标准REST API调用和批量操作',
          ),
          
          _buildHelpSection(
            '环境变量配置',
            '在项目根目录的 .env 文件中配置默认MCP服务器：\n\n'
            '# 文件系统服务器\n'
            'MCP_FILESYSTEM_URL=https://api.example.com/filesystem/sse\n'
            'MCP_FILESYSTEM_TOKEN=your_token_here\n'
            'MCP_FILESYSTEM_COMPRESSION=true\n\n'
            '# 搜索服务器\n'
            'MCP_SEARCH_URL=https://api.example.com/search\n'
            'MCP_SEARCH_TYPE=http\n'
            'MCP_SEARCH_TOKEN=your_search_token\n\n'
            '# 数据库服务器\n'
            'MCP_DATABASE_URL=https://api.example.com/database\n'
            'MCP_DATABASE_TYPE=http\n'
            'MCP_DATABASE_TIMEOUT=30\n\n'
            '# 自定义服务器 (最多5个)\n'
            'MCP_CUSTOM1_URL=https://api.example.com/custom\n'
            'MCP_CUSTOM1_NAME=我的自定义服务器\n'
            'MCP_CUSTOM1_DESC=提供自定义功能的MCP服务器\n'
            'MCP_CUSTOM1_TYPE=sse',
          ),
          
          _buildHelpSection(
            '连接状态说明',
            '• 🔴 未连接: 服务器未建立连接\n'
            '• 🟡 连接中: 正在尝试连接到服务器\n'
            '• 🟢 已连接: 服务器连接正常，可以使用工具\n'
            '• 🔴 连接失败: 服务器连接出现错误',
          ),
          
          _buildHelpSection(
            '使用说明',
            '1. 配置 .env 文件中的MCP服务器信息\n'
            '2. 点击"重新加载配置"按钮加载配置\n'
            '3. 在服务器列表中点击"连接"按钮连接服务器\n'
            '4. 连接成功后，在"工具"标签页查看可用工具\n'
            '5. 在AI对话中，AI将自动调用相关的MCP工具',
          ),
          
          _buildHelpSection(
            '故障排除',
            '• 如果连接失败，请检查网络连接和服务器URL\n'
            '• 确认认证令牌是否正确配置\n'
            '• 检查服务器是否支持所选的传输类型\n'
            '• 查看错误信息了解具体问题\n'
            '• 使用"测试连接"功能验证服务器可用性',
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, String content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reloadConfig() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _mcpService.reloadConfig();
      _showSuccessSnackBar('配置已重新加载');
    } catch (e) {
      _showErrorSnackBar('重新加载配置失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _connectServer(String serverId) async {
    try {
      final success = await _mcpService.connectToServer(serverId);
      if (success) {
        _showSuccessSnackBar('服务器连接成功');
      } else {
        _showErrorSnackBar('服务器连接失败');
      }
    } catch (e) {
      _showErrorSnackBar('连接服务器时出错: $e');
    }
  }

  Future<void> _disconnectServer(String serverId) async {
    try {
      await _mcpService.disconnectFromServer(serverId);
      _showSuccessSnackBar('服务器已断开连接');
    } catch (e) {
      _showErrorSnackBar('断开服务器连接时出错: $e');
    }
  }

  Future<void> _testConnection(McpServerConfig server) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在测试连接...'),
          ],
        ),
      ),
    );

    try {
      final success = await _mcpService.testConnection(server);
      Navigator.of(context).pop(); // 关闭加载对话框
      
      if (success) {
        _showSuccessSnackBar('连接测试成功');
      } else {
        _showErrorSnackBar('连接测试失败');
      }
    } catch (e) {
      Navigator.of(context).pop(); // 关闭加载对话框
      _showErrorSnackBar('测试连接时出错: $e');
    }
  }

  void _showAddServerDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddServerDialog(),
    ).then((server) {
      if (server != null) {
        McpConfig.addUserServer(server);
        _reloadConfig();
      }
    });
  }

  void _editServer(McpServerConfig server) {
    showDialog(
      context: context,
      builder: (context) => AddServerDialog(editingServer: server),
    ).then((editedServer) {
      if (editedServer != null) {
        McpConfig.updateServer(editedServer);
        _reloadConfig();
      }
    });
  }

  void _showToolDetails(McpToolInfo tool) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('工具详情: ${tool.name}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('工具名称', tool.name),
              _buildInfoRow('描述', tool.description),
              _buildInfoRow('服务器', tool.serverId),
              const SizedBox(height: 16),
              const Text('输入参数模式:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(tool.inputSchema),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _testTool(McpToolInfo tool) {
    showDialog(
      context: context,
      builder: (context) => TestToolDialog(tool: tool, mcpService: _mcpService),
    );
  }
}

// 添加服务器对话框
class AddServerDialog extends StatefulWidget {
  final McpServerConfig? editingServer;

  const AddServerDialog({super.key, this.editingServer});

  @override
  State<AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<AddServerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();
  final _bearerTokenController = TextEditingController();
  final _headersController = TextEditingController();
  final _timeoutController = TextEditingController();
  final _heartbeatController = TextEditingController();
  
  McpServerType _selectedType = McpServerType.sse;
  bool _enableCompression = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.editingServer != null) {
      final server = widget.editingServer!;
      _idController.text = server.id;
      _nameController.text = server.name;
      _descriptionController.text = server.description;
      _urlController.text = server.url;
      _bearerTokenController.text = server.bearerToken ?? '';
      _headersController.text = server.headers.entries.map((e) => '${e.key}:${e.value}').join(',');
      _timeoutController.text = server.timeout?.inSeconds.toString() ?? '';
      _heartbeatController.text = server.heartbeatInterval?.inSeconds.toString() ?? '';
      _selectedType = server.type;
      _enableCompression = server.enableCompression;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _bearerTokenController.dispose();
    _headersController.dispose();
    _timeoutController.dispose();
    _heartbeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.editingServer != null ? '编辑服务器' : '添加服务器'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _idController,
                  decoration: const InputDecoration(labelText: '服务器ID *'),
                  validator: (value) => value?.isEmpty ?? true ? '请输入服务器ID' : null,
                  enabled: widget.editingServer == null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '服务器名称 *'),
                  validator: (value) => value?.isEmpty ?? true ? '请输入服务器名称' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: '描述'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<McpServerType>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: '服务器类型 *'),
                  items: McpServerType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedType = value!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: '服务器URL *'),
                  validator: (value) => value?.isEmpty ?? true ? '请输入服务器URL' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bearerTokenController,
                  decoration: const InputDecoration(labelText: 'Bearer Token (可选)'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _headersController,
                  decoration: const InputDecoration(
                    labelText: '自定义请求头 (可选)',
                    hintText: 'key1:value1,key2:value2',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _timeoutController,
                  decoration: const InputDecoration(labelText: '超时时间 (秒)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _heartbeatController,
                  decoration: const InputDecoration(labelText: '心跳间隔 (秒)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('启用压缩'),
                  value: _enableCompression,
                  onChanged: (value) => setState(() => _enableCompression = value ?? false),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saveServer,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _saveServer() {
    if (!_formKey.currentState!.validate()) return;

    final headers = <String, String>{};
    if (_headersController.text.isNotEmpty) {
      for (final pair in _headersController.text.split(',')) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          headers[parts[0].trim()] = parts[1].trim();
        }
      }
    }

    final server = McpServerConfig(
      id: _idController.text,
      name: _nameController.text,
      description: _descriptionController.text.isEmpty ? '用户自定义服务器' : _descriptionController.text,
      type: _selectedType,
      url: _urlController.text,
      bearerToken: _bearerTokenController.text.isEmpty ? null : _bearerTokenController.text,
      headers: headers,
      timeout: _timeoutController.text.isEmpty ? null : Duration(seconds: int.parse(_timeoutController.text)),
      heartbeatInterval: _heartbeatController.text.isEmpty ? null : Duration(seconds: int.parse(_heartbeatController.text)),
      enableCompression: _enableCompression,
    );

    Navigator.of(context).pop(server);
  }
}

// 测试工具对话框
class TestToolDialog extends StatefulWidget {
  final McpToolInfo tool;
  final McpService mcpService;

  const TestToolDialog({super.key, required this.tool, required this.mcpService});

  @override
  State<TestToolDialog> createState() => _TestToolDialogState();
}

class _TestToolDialogState extends State<TestToolDialog> {
  final _argumentsController = TextEditingController();
  bool _isLoading = false;
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 生成示例参数
    _generateExampleArguments();
  }

  void _generateExampleArguments() {
    final schema = widget.tool.inputSchema;
    if (schema['properties'] is Map) {
      final properties = schema['properties'] as Map;
      final example = <String, dynamic>{};
      
      for (final entry in properties.entries) {
        final prop = entry.value as Map;
        final type = prop['type'] as String?;
        
        switch (type) {
          case 'string':
            example[entry.key] = prop['example'] ?? 'example_value';
            break;
          case 'number':
          case 'integer':
            example[entry.key] = prop['example'] ?? 0;
            break;
          case 'boolean':
            example[entry.key] = prop['example'] ?? false;
            break;
          default:
            example[entry.key] = null;
        }
      }
      
      _argumentsController.text = const JsonEncoder.withIndent('  ').convert(example);
    }
  }

  @override
  void dispose() {
    _argumentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('测试工具: ${widget.tool.name}'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('描述: ${widget.tool.description}'),
            const SizedBox(height: 16),
            const Text('参数 (JSON格式):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _argumentsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '输入JSON格式的参数',
                ),
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            const Text('执行结果:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _error ?? _result ?? '点击"执行"按钮测试工具',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: _error != null ? Colors.red : null,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _executeTool,
          child: const Text('执行'),
        ),
      ],
    );
  }

  Future<void> _executeTool() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final arguments = jsonDecode(_argumentsController.text) as Map<String, dynamic>;
      final result = await widget.mcpService.callTool(widget.tool.serverId, widget.tool.name, arguments);
      
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }
}
