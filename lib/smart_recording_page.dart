import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/accessibility_permission_manager.dart';

class SmartRecordingPage extends StatefulWidget {
  const SmartRecordingPage({super.key});

  @override
  State<SmartRecordingPage> createState() => _SmartRecordingPageState();
}

class _SmartRecordingPageState extends State<SmartRecordingPage> {
  static const smartRecordingChannel = MethodChannel('com.tianli.zhiwenx/smart_recording');
  static const smartRecordingEventChannel = EventChannel('com.tianli.zhiwenx/smart_recording_events');
  
  // 服务状态
  bool _isServiceEnabled = false;
  bool _isRecording = false;
  bool _isPaused = false;
  int _actionsCount = 0;
  bool _isOverlayShowing = false;
  bool _excludeOwnApp = true;
  
  // 录制文件
  List<String> _recordings = [];
  String? _selectedRecording;
  String _statusMessage = '准备就绪';
  
  // 最近操作
  List<Map<String, dynamic>> _recentActions = [];
  
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _loadRecordings();
    _setupEventListener();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _setupEventListener() {
    _eventSubscription = smartRecordingEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          _handleRecordingEvent(event);
        }
      },
      onError: (error) {
        log('Smart recording event error: $error');
        _showSnackBar('事件监听错误: $error', Colors.red);
      },
    );
  }

  void _handleRecordingEvent(Map<dynamic, dynamic> event) {
    setState(() {
      switch (event['action']) {
        case 'service_connected':
          _isServiceEnabled = true;
          _statusMessage = '智能录制服务已连接，可以开始录制';
          _showSnackBar('智能录制服务已连接', Colors.green);
          break;
          
        case 'action_recorded':
          _actionsCount = event['actionsCount'] ?? 0;
          _statusMessage = '正在录制... 已录制 $_actionsCount 个操作';
          
          // 添加到最近操作列表
          if (event['description'] != null) {
            _recentActions.insert(0, {
              'type': event['actionType'] ?? 'unknown',
              'description': event['description'],
              'packageName': event['packageName'],
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
            
            // 保持最近20个操作
            if (_recentActions.length > 20) {
              _recentActions.removeLast();
            }
          }
          break;
          
        case 'execution_progress':
          int current = (event['currentIndex'] ?? 0) + 1;
          int total = event['totalCount'] ?? 0;
          String currentAction = event['currentAction'] ?? '';
          String description = event['description'] ?? '';
          _statusMessage = '执行中... ($current/$total) - $currentAction\n$description';
          break;
          
        case 'execution_completed':
          _statusMessage = '录制执行完成，共执行 ${event['actionsCount']} 个操作';
          break;
      }
    });
  }

  Future<void> _checkServiceStatus() async {
    try {
      final bool isEnabled = await smartRecordingChannel.invokeMethod('isServiceEnabled');
      final Map<dynamic, dynamic> status = await smartRecordingChannel.invokeMethod('getRecordingStatus');
      
      setState(() {
        _isServiceEnabled = isEnabled;
        _isRecording = status['isRecording'] ?? false;
        _isPaused = status['isPaused'] ?? false;
        _actionsCount = status['actionsCount'] ?? 0;
        _isOverlayShowing = status['isOverlayShowing'] ?? false;
        _excludeOwnApp = status['excludeOwnApp'] ?? true;
      });
    } catch (e) {
      log('检查服务状态失败: $e');
    }
  }

  Future<void> _requestAccessibilityPermission() async {
    try {
      await smartRecordingChannel.invokeMethod('requestAccessibilityPermission');
      _showSnackBar('请在设置中开启智问X智能录制服务', Colors.blue);
      
      // 等待一段时间后重新检查状态
      Timer(const Duration(seconds: 2), () {
        _checkServiceStatus();
      });
    } catch (e) {
      _showSnackBar('请求权限失败: $e', Colors.red);
    }
  }

  Future<void> _startRecording() async {
    // 先检查无障碍权限
    final hasPermission = await AccessibilityPermissionManager.checkAndRequestPermission(
      context,
      feature: '智能录制',
    );
    
    if (!hasPermission) {
      _showSnackBar('需要无障碍权限才能开始录制', Colors.red);
      return;
    }

    if (!_isServiceEnabled) {
      _showSnackBar('请先开启智能录制服务', Colors.orange);
      return;
    }
    
    try {
      await smartRecordingChannel.invokeMethod('startRecording');
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _actionsCount = 0;
        _recentActions.clear();
        _statusMessage = '录制已开始...';
      });
      _showSnackBar('开始录制操作', Colors.green);
    } catch (e) {
      _showSnackBar('开始录制失败: $e', Colors.red);
    }
  }

  Future<void> _stopRecording() async {
    try {
      final String? filename = await smartRecordingChannel.invokeMethod('stopRecording');
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _statusMessage = '录制已停止，共录制 $_actionsCount 个操作';
      });
      
      if (filename != null && filename.isNotEmpty) {
        _showSnackBar('录制已保存: $filename', Colors.green);
        _loadRecordings();
      } else {
        _showSnackBar('录制停止', Colors.blue);
      }
    } catch (e) {
      _showSnackBar('停止录制失败: $e', Colors.red);
    }
  }

  Future<void> _pauseResumeRecording() async {
    try {
      await smartRecordingChannel.invokeMethod('pauseResumeRecording');
      setState(() {
        _isPaused = !_isPaused;
        _statusMessage = _isPaused ? '录制已暂停' : '录制已继续';
      });
      _showSnackBar(_isPaused ? '录制已暂停' : '录制已继续', Colors.blue);
    } catch (e) {
      _showSnackBar('切换录制状态失败: $e', Colors.red);
    }
  }

  Future<void> _saveRecording() async {
    if (_actionsCount == 0) {
      _showSnackBar('没有可保存的录制操作', Colors.orange);
      return;
    }
    
    final TextEditingController controller = TextEditingController();
    
    final String? filename = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存录制'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '文件名',
            hintText: '请输入文件名（可选）',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    
    if (filename != null) {
      try {
        final String? savedFilename = await smartRecordingChannel.invokeMethod('saveRecording', {
          'filename': filename.isEmpty ? null : '$filename.json'
        });
        
        if (savedFilename != null && savedFilename.isNotEmpty) {
          _showSnackBar('录制已保存: $savedFilename', Colors.green);
          _loadRecordings();
        }
      } catch (e) {
        _showSnackBar('保存录制失败: $e', Colors.red);
      }
    }
  }

  Future<void> _loadRecordings() async {
    try {
      final List<dynamic> recordings = await smartRecordingChannel.invokeMethod('getRecordingsList');
      setState(() {
        _recordings = recordings.map((e) => e.toString()).toList();
      });
    } catch (e) {
      log('加载录制列表失败: $e');
    }
  }

  Future<void> _executeRecording(String filename) async {
    // 先检查无障碍权限
    final hasPermission = await AccessibilityPermissionManager.checkAndRequestPermission(
      context,
      feature: '录制回放',
    );
    
    if (!hasPermission) {
      _showSnackBar('需要无障碍权限才能执行录制回放', Colors.red);
      return;
    }

    try {
      await smartRecordingChannel.invokeMethod('executeRecording', {'filename': filename});
      _showSnackBar('开始执行录制: $filename', Colors.blue);
    } catch (e) {
      _showSnackBar('执行录制失败: $e', Colors.red);
    }
  }

  Future<void> _showOverlay() async {
    try {
      await smartRecordingChannel.invokeMethod('showOverlay');
      setState(() {
        _isOverlayShowing = true;
      });
      _showSnackBar('录制控制浮层已显示', Colors.green);
    } catch (e) {
      _showSnackBar('显示浮层失败: $e', Colors.red);
    }
  }

  Future<void> _hideOverlay() async {
    try {
      await smartRecordingChannel.invokeMethod('hideOverlay');
      setState(() {
        _isOverlayShowing = false;
      });
      _showSnackBar('录制控制浮层已隐藏', Colors.green);
    } catch (e) {
      _showSnackBar('隐藏浮层失败: $e', Colors.red);
    }
  }

  Future<void> _toggleExcludeOwnApp() async {
    try {
      final bool newValue = !_excludeOwnApp;
      await smartRecordingChannel.invokeMethod('setExcludeOwnApp', {'exclude': newValue});
      setState(() {
        _excludeOwnApp = newValue;
      });
      _showSnackBar(
        newValue ? '已开启排除自身应用' : '已关闭排除自身应用',
        newValue ? Colors.green : Colors.orange,
      );
    } catch (e) {
      _showSnackBar('设置失败: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能操作录制'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              _checkServiceStatus();
              _loadRecordings();
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新状态',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildServiceStatusCard(),
              const SizedBox(height: 16),
              _buildRecordingControlCard(),
              const SizedBox(height: 16),
              _buildRecordingFilesCard(),
              const SizedBox(height: 16),
              _buildSettingsCard(),
              const SizedBox(height: 16),
              _buildRecentActionsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceStatusCard() {
    return Card(
      elevation: 8,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isServiceEnabled 
                ? [Colors.green.shade400, Colors.green.shade600]
                : [Colors.red.shade400, Colors.red.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isServiceEnabled ? Icons.verified_rounded : Icons.error_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '智能录制服务',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _isServiceEnabled ? "服务运行正常" : "服务未开启",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isServiceEnabled)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FilledButton.icon(
                        onPressed: _requestAccessibilityPermission,
                        icon: const Icon(Icons.settings_accessibility_rounded),
                        label: const Text('开启服务'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '状态信息',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    if (_isServiceEnabled) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatusIndicator(
                            icon: _isRecording ? Icons.fiber_manual_record_rounded : Icons.radio_button_unchecked_rounded,
                            label: '录制状态',
                            value: _isRecording ? (_isPaused ? "暂停中" : "录制中") : "未录制",
                            color: _isRecording ? Colors.red : Colors.grey,
                          ),
                          const SizedBox(width: 24),
                          _buildStatusIndicator(
                            icon: Icons.analytics_rounded,
                            label: '已录制',
                            value: '$_actionsCount 个操作',
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordingControlCard() {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '录制控制',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // 主要控制按钮
            Row(
              children: [
                Expanded(
                  child: _buildControlButton(
                    onPressed: _isServiceEnabled && !_isRecording ? _startRecording : null,
                    icon: Icons.play_circle_outline_rounded,
                    label: '开始录制',
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildControlButton(
                    onPressed: _isServiceEnabled && _isRecording ? _stopRecording : null,
                    icon: Icons.stop_circle_outlined,
                    label: '停止录制',
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 次要控制按钮
            Row(
              children: [
                Expanded(
                  child: _buildControlButton(
                    onPressed: _isServiceEnabled && _isRecording ? _pauseResumeRecording : null,
                    icon: _isPaused ? Icons.play_circle_rounded : Icons.pause_circle_rounded,
                    label: _isPaused ? '继续录制' : '暂停录制',
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildControlButton(
                    onPressed: _isServiceEnabled && _actionsCount > 0 ? _saveRecording : null,
                    icon: Icons.save_rounded,
                    label: '保存录制',
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // 浮层控制
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.picture_in_picture_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '浮层控制',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _buildControlButton(
                        onPressed: _isServiceEnabled ? (_isOverlayShowing ? _hideOverlay : _showOverlay) : null,
                        icon: _isOverlayShowing ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        label: _isOverlayShowing ? '隐藏浮层' : '显示浮层',
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        shadowColor: backgroundColor.withOpacity(0.3),
      ),
    );
  }

  Widget _buildRecordingFilesCard() {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '录制文件',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadRecordings,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: '刷新列表',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_recordings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    style: BorderStyle.solid,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '暂无录制文件',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: _selectedRecording,
                  hint: Row(
                    children: [
                      Icon(
                        Icons.video_file_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text('选择录制文件'),
                    ],
                  ),
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _recordings.map((recording) {
                    return DropdownMenuItem<String>(
                      value: recording,
                      child: Row(
                        children: [
                          Icon(
                            Icons.play_circle_outline_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              recording,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRecording = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedRecording != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isServiceEnabled ? () => _executeRecording(_selectedRecording!) : null,
                    icon: const Icon(Icons.play_circle_rounded, size: 20),
                    label: const Text(
                      '执行录制',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.settings_rounded,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '录制设置',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _excludeOwnApp 
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.block_rounded,
                    color: _excludeOwnApp 
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                title: const Text(
                  '排除自身应用',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('开启后不会录制本应用的操作'),
                value: _excludeOwnApp,
                onChanged: _isServiceEnabled ? (value) => _toggleExcludeOwnApp() : null,
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            
            const SizedBox(height: 24),
            
            _buildInfoSection(
              title: '功能说明',
              icon: Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
              items: [
                '🔍 自动检测应用启动和切换',
                '👆 捕获点击、长按、输入、滚动等操作',
                '🔄 支持跨设备的录制回放',
                '🚫 智能排除系统应用和本应用',
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildInfoSection(
              title: '使用建议',
              icon: Icons.lightbulb_outline_rounded,
              color: Colors.orange,
              items: [
                '📱 录制前请确保回到目标应用主页',
                '🔒 避免录制包含敏感信息的操作',
                '📏 在相同设备型号间回放效果更佳',
                '⚡ 录制时保持设备性能良好',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              item,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.4,
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildRecentActionsCard() {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '最近操作',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_recentActions.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_recentActions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.gesture_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '暂无操作记录',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '开始录制后这里将显示操作历史',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentActions.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  ),
                  itemBuilder: (context, index) {
                    final action = _recentActions[index];
                    final timestamp = DateTime.fromMillisecondsSinceEpoch(action['timestamp']);
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getActionColor(action['type']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _getActionIcon(action['type']),
                      ),
                      title: Text(
                        action['description'] ?? '未知操作',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (action['packageName'] != null && action['packageName'].toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              action['packageName'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getActionColor(action['type']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getActionTypeName(action['type']),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getActionColor(action['type']),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getActionColor(String type) {
    switch (type) {
      case 'app_launch':
        return Colors.blue;
      case 'click':
        return Colors.green;
      case 'long_click':
        return Colors.orange;
      case 'input':
        return Colors.purple;
      case 'scroll':
        return Colors.teal;
      case 'swipe':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _getActionTypeName(String type) {
    switch (type) {
      case 'app_launch':
        return '启动';
      case 'click':
        return '点击';
      case 'long_click':
        return '长按';
      case 'input':
        return '输入';
      case 'scroll':
        return '滚动';
      case 'swipe':
        return '滑动';
      default:
        return '其他';
    }
  }

  Icon _getActionIcon(String type) {
    switch (type) {
      case 'app_launch':
        return const Icon(Icons.rocket_launch_rounded, color: Colors.blue);
      case 'click':
        return const Icon(Icons.touch_app_rounded, color: Colors.green);
      case 'long_click':
        return const Icon(Icons.ads_click_rounded, color: Colors.orange);
      case 'input':
        return const Icon(Icons.keyboard_rounded, color: Colors.purple);
      case 'scroll':
        return const Icon(Icons.swipe_vertical_rounded, color: Colors.teal);
      case 'swipe':
        return const Icon(Icons.swipe_rounded, color: Colors.indigo);
      default:
        return const Icon(Icons.circle_rounded, color: Colors.grey);
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
