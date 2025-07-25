import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:flutter_accessibility_service/constants.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'utils/accessibility_permission_manager.dart';
import 'dart:developer';

/// 无障碍浮层覆盖入口点
@pragma("vm:entry-point")
void accessibilityOverlay() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AccessibilityOverlayWidget(),
    ),
  );
}

class AccessibilityOverlayWidget extends StatelessWidget {
  const AccessibilityOverlayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha:0.8),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.accessibility_new,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            const Text(
              '智问X辅助',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () async {
                    await FlutterAccessibilityService.hideOverlayWindow();
                  },
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await FlutterAccessibilityService.performGlobalAction(
                      GlobalAction.globalActionBack,
                    );
                  },
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await FlutterAccessibilityService.performGlobalAction(
                      GlobalAction.globalActionHome,
                    );
                  },
                  icon: const Icon(
                    Icons.home,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ActionRecordingPage extends StatefulWidget {
  const ActionRecordingPage({super.key});

  @override
  State<ActionRecordingPage> createState() => _ActionRecordingPageState();
}

class _ActionRecordingPageState extends State<ActionRecordingPage> {
  static const platform = MethodChannel('com.tianli.zhiwenx/floating_window');
  static const actionPlatform = MethodChannel('com.tianli.zhiwenx/action_recording');
  static const eventChannel = EventChannel('com.tianli.zhiwenx/floating_window_events');
  static const actionEventChannel = EventChannel('com.tianli.zhiwenx/action_recording_events');
  
  // 操作录制相关状态
  bool _hasOverlayPermission = false;
  bool _isFloatingWindowVisible = false;
  bool _isRecording = false;
  bool _isPaused = false;
  int _actionsCount = 0;
  List<String> _recordings = [];
  String? _selectedRecording;
  String _statusMessage = '准备就绪';
  
  // 无障碍服务相关状态
  StreamSubscription<AccessibilityEvent>? _subscription;
  final List<AccessibilityEvent> _events = [];
  bool _isServiceEnabled = false;
  bool _isListening = false;
  bool _safeMode = true; // 安全模式开关
  String _currentAction = "等待中...";
  
  @override
  void initState() {
    super.initState();
    _checkOverlayPermission();
    _loadRecordings();
    _setupEventListeners();
    _checkAccessibilityPermission();
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
  
  void _setupEventListeners() {
    // 悬浮窗事件监听
    eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        switch (event['action']) {
          case 'floating_window_hidden':
            setState(() {
              _isFloatingWindowVisible = false;
            });
            break;
          case 'recording_state_changed':
            setState(() {
              _isRecording = event['isRecording'] ?? false;
            });
            break;
        }
      }
    });
    
    // 操作录制事件监听
    actionEventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        switch (event['action']) {
          case 'recording_started':
            setState(() {
              _statusMessage = '录制已开始';
              _actionsCount = 0;
            });
            break;
          case 'recording_stopped':
            setState(() {
              _statusMessage = '录制已停止，共录制 ${event['actionsCount']} 个操作';
              _actionsCount = event['actionsCount'] ?? 0;
            });
            _loadRecordings();
            break;
          case 'action_recorded':
            setState(() {
              _actionsCount = event['actionsCount'] ?? 0;
              _statusMessage = '正在录制... 已录制 $_actionsCount 个操作';
            });
            break;
          case 'recording_paused':
            setState(() {
              _isPaused = event['isPaused'] ?? false;
              _statusMessage = _isPaused ? '录制已暂停' : '录制已继续';
            });
            break;
          case 'recording_saved':
            setState(() {
              _statusMessage = '录制已保存: ${event['filename']}';
            });
            _loadRecordings();
            break;
          case 'recording_loaded':
            setState(() {
              _statusMessage = '录制已加载: ${event['filename']}，共 ${event['actionsCount']} 个操作';
            });
            break;
          case 'recording_execution_started':
            setState(() {
              _statusMessage = '开始执行录制，共 ${event['actionsCount']} 个操作';
            });
            break;
          case 'recording_execution_progress':
            setState(() {
              int current = event['currentIndex'] + 1;
              int total = event['totalCount'];
              _statusMessage = '执行中... ($current/$total) - ${event['currentAction']}';
            });
            break;
          case 'recording_execution_completed':
            setState(() {
              _statusMessage = '录制执行完成';
            });
            break;
          case 'execute_click':
            // 这里可以添加实际的点击执行逻辑
            _executeClick(event['x'], event['y']);
            break;
          case 'execute_input':
            // 这里可以添加实际的输入执行逻辑
            _executeInput(event['text']);
            break;
          case 'execute_scroll':
            // 这里可以添加实际的滚动执行逻辑
            _executeScroll(event['direction'], event['distance']);
            break;
          case 'execute_swipe':
            // 这里可以添加实际的滑动执行逻辑
            _executeSwipe(event['startX'], event['startY'], event['endX'], event['endY']);
            break;
        }
      }
    });
  }
  
  Future<void> _checkOverlayPermission() async {
    try {
      final bool hasPermission = await platform.invokeMethod('checkOverlayPermission');
      setState(() {
        _hasOverlayPermission = hasPermission;
      });
    } catch (e) {
      print('检查悬浮窗权限失败: $e');
    }
  }
  
  Future<void> _requestOverlayPermission() async {
    try {
      await platform.invokeMethod('requestOverlayPermission');
      // 延迟检查权限状态
      Future.delayed(const Duration(seconds: 2), () {
        _checkOverlayPermission();
      });
    } catch (e) {
      print('请求悬浮窗权限失败: $e');
    }
  }
  
  Future<void> _showFloatingWindow() async {
    if (!_hasOverlayPermission) {
      await _requestOverlayPermission();
      return;
    }
    
    try {
      await platform.invokeMethod('showFloatingWindow');
      setState(() {
        _isFloatingWindowVisible = true;
      });
    } catch (e) {
      print('显示悬浮窗失败: $e');
    }
  }
  
  Future<void> _hideFloatingWindow() async {
    try {
      await platform.invokeMethod('hideFloatingWindow');
      setState(() {
        _isFloatingWindowVisible = false;
      });
    } catch (e) {
      print('隐藏悬浮窗失败: $e');
    }
  }
  
  Future<void> _startRecording() async {
    // 先检查无障碍权限
    final hasPermission = await AccessibilityPermissionManager.checkAndRequestPermission(
      context,
      feature: '操作录制',
    );
    
    if (!hasPermission) {
      _showSnackBar('需要无障碍权限才能开始录制', Colors.red);
      return;
    }

    try {
      await actionPlatform.invokeMethod('startRecording');
    } catch (e) {
      print('开始录制失败: $e');
    }
  }
  
  Future<void> _stopRecording() async {
    try {
      await actionPlatform.invokeMethod('stopRecording');
    } catch (e) {
      print('停止录制失败: $e');
    }
  }
  
  Future<void> _pauseResumeRecording() async {
    try {
      await actionPlatform.invokeMethod('pauseResumeRecording');
    } catch (e) {
      print('暂停/继续录制失败: $e');
    }
  }
  
  Future<void> _saveRecording(String filename) async {
    try {
      await actionPlatform.invokeMethod('saveRecording', {'filename': filename});
    } catch (e) {
      print('保存录制失败: $e');
    }
  }
  
  Future<void> _loadRecording(String filename) async {
    try {
      await actionPlatform.invokeMethod('loadRecording', {'filename': filename});
    } catch (e) {
      print('加载录制失败: $e');
    }
  }
  
  Future<void> _executeRecording(String? filename) async {
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
      if (filename != null) {
        await actionPlatform.invokeMethod('executeRecording', {'filename': filename});
      } else {
        await actionPlatform.invokeMethod('executeRecording');
      }
    } catch (e) {
      print('执行录制失败: $e');
    }
  }
  
  Future<void> _loadRecordings() async {
    try {
      final List<dynamic> recordings = await actionPlatform.invokeMethod('getRecordingsList');
      setState(() {
        _recordings = recordings.map((e) => e.toString()).toList();
      });
    } catch (e) {
      print('加载录制列表失败: $e');
    }
  }
  
  Future<void> _recordAction(Map<String, dynamic> action) async {
    try {
      await actionPlatform.invokeMethod('recordAction', {'action': jsonEncode(action)});
    } catch (e) {
      print('录制操作失败: $e');
    }
  }
  
  // 执行操作的方法（这些是示例，实际需要与无障碍服务配合）
  void _executeClick(int x, int y) {
    print('执行点击: ($x, $y)');
    // 这里需要调用无障碍服务来执行实际的点击
  }
  
  void _executeInput(String text) {
    print('执行输入: $text');
    // 这里需要调用无障碍服务来执行实际的输入
  }
  
  void _executeScroll(String? direction, int? distance) {
    print('执行滚动: $direction, 距离: $distance');
    // 这里需要调用无障碍服务来执行实际的滚动
  }
  
  void _executeSwipe(int startX, int startY, int endX, int endY) {
    print('执行滑动: ($startX, $startY) -> ($endX, $endY)');
    // 这里需要调用无障碍服务来执行实际的滑动
  }
  
  // 无障碍服务相关方法
  Future<void> _checkAccessibilityPermission() async {
    final isEnabled = await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
    setState(() {
      _isServiceEnabled = isEnabled;
    });
  }

  Future<void> _requestAccessibilityPermission() async {
    final granted = await FlutterAccessibilityService.requestAccessibilityPermission();
    setState(() {
      _isServiceEnabled = granted;
    });
    
    if (granted) {
      _showSnackBar('无障碍权限已授予', Colors.green);
    } else {
      _showSnackBar('无障碍权限被拒绝', Colors.red);
    }
  }

  void _startAccessibilityStream() {
    if (!_isServiceEnabled) {
      _showSnackBar('请先开启无障碍权限', Colors.orange);
      return;
    }

    _subscription = FlutterAccessibilityService.accessStream.listen(
      (event) {
        setState(() {
          _events.insert(0, event);
          if (_events.length > 50) {
            _events.removeLast();
          }
          _currentAction = "监听到事件: ${event.packageName}";
        });
        
        // 处理特定应用的自动化逻辑
        _handleAutomation(event);
      },
      onError: (error) {
        log('Accessibility stream error: $error');
        _showSnackBar('监听出错: $error', Colors.red);
      },
    );

    setState(() {
      _isListening = true;
      _currentAction = "正在监听无障碍事件...";
    });
  }

  void _stopAccessibilityStream() {
    _subscription?.cancel();
    setState(() {
      _isListening = false;
      _currentAction = "已停止监听";
    });
  }

  void _clearEvents() {
    setState(() {
      _events.clear();
      _currentAction = "事件列表已清空";
    });
  }

  Future<void> _performGlobalAction(GlobalAction action) async {
    if (_safeMode) {
      final safeActions = [
        GlobalAction.globalActionBack,
        GlobalAction.globalActionHome,
        GlobalAction.globalActionRecents,
        GlobalAction.globalActionTakeScreenshot,
        GlobalAction.globalActionNotifications,
        GlobalAction.globalActionQuickSettings,
      ];
      
      if (!safeActions.contains(action)) {
        _showSnackBar('安全模式下不允许此操作，请关闭安全模式后重试', Colors.orange);
        return;
      }
    }

    try {
      await FlutterAccessibilityService.performGlobalAction(action);
      _showSnackBar('全局动作已执行: ${action.toString()}', Colors.blue);
    } catch (e) {
      _showSnackBar('执行失败: $e', Colors.red);
    }
  }

  Future<void> _showOverlay() async {
    try {
      await FlutterAccessibilityService.showOverlayWindow();
      _showSnackBar('浮层已显示', Colors.green);
    } catch (e) {
      _showSnackBar('显示浮层失败: $e', Colors.red);
    }
  }

  Future<void> _hideOverlay() async {
    try {
      await FlutterAccessibilityService.hideOverlayWindow();
      _showSnackBar('浮层已隐藏', Colors.green);
    } catch (e) {
      _showSnackBar('隐藏浮层失败: $e', Colors.red);
    }
  }

  void _handleAutomation(AccessibilityEvent event) {
    if (_safeMode) {
      return;
    }
    
    if (event.packageName?.contains('tencent.mm') == true) {
      _handleWeChatEvent(event);
    }
    
    if (event.packageName?.contains('browser') == true || 
        event.packageName?.contains('chrome') == true) {
      _handleBrowserEvent(event);
    }
  }

  void _handleWeChatEvent(AccessibilityEvent event) {
    // 微信相关的自动化处理
    log('检测到微信事件: ${event.eventType}');
  }

  void _handleBrowserEvent(AccessibilityEvent event) {
    // 浏览器相关的自动化处理
    log('检测到浏览器事件: ${event.eventType}');
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _showSaveDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存录制'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '文件名',
            hintText: '请输入文件名（不含扩展名）',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final filename = controller.text.trim();
              if (filename.isNotEmpty) {
                _saveRecording('$filename.json');
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
  
  void _showTestActionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('测试录制操作'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                _recordAction({
                  'type': 'click',
                  'x': 100,
                  'y': 200,
                  'description': '测试点击'
                });
                Navigator.pop(context);
              },
              child: const Text('录制点击操作'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                _recordAction({
                  'type': 'input',
                  'text': '测试输入文本',
                  'description': '测试输入'
                });
                Navigator.pop(context);
              },
              child: const Text('录制输入操作'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                _recordAction({
                  'type': 'scroll',
                  'scrollDirection': 'down',
                  'scrollDistance': 500,
                  'description': '测试滚动'
                });
                Navigator.pop(context);
              },
              child: const Text('录制滚动操作'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  
  IconData _getEventIcon(EventType? eventType) {
    switch (eventType) {
      case EventType.typeViewClicked:
        return Icons.touch_app;
      case EventType.typeViewFocused:
        return Icons.center_focus_strong;
      case EventType.typeViewTextChanged:
        return Icons.edit;
      case EventType.typeWindowStateChanged:
        return Icons.window;
      case EventType.typeWindowContentChanged:
        return Icons.content_copy;
      case EventType.typeNotificationStateChanged:
        return Icons.notifications;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('智能辅助控制台'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                icon: Icon(Icons.videocam),
                text: '操作录制',
              ),
              Tab(
                icon: Icon(Icons.accessibility),
                text: '无障碍服务',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRecordingTab(),
            _buildAccessibilityTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 权限状态卡片
          _buildPermissionCard(),
          const SizedBox(height: 16),
          
          // 悬浮窗控制卡片
          _buildFloatingWindowCard(),
          const SizedBox(height: 16),
          
          // 录制控制卡片
          _buildRecordingControlCard(),
          const SizedBox(height: 16),
          
          // 录制文件管理卡片
          _buildRecordingFileCard(),
          const SizedBox(height: 16),
          
          // 状态信息卡片
          _buildStatusCard(),
        ],
      ),
    );
  }

  Widget _buildAccessibilityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 无障碍权限状态卡片
          _buildAccessibilityPermissionCard(),
          const SizedBox(height: 16),
          
          // 无障碍控制按钮
          _buildAccessibilityControlCard(),
          const SizedBox(height: 16),
          
          // 全局动作按钮
          _buildGlobalActionsCard(),
          const SizedBox(height: 16),
          
          // 事件日志
          _buildEventLogCard(),
        ],
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '权限状态',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _hasOverlayPermission ? Icons.check_circle : Icons.error,
                  color: _hasOverlayPermission ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(_hasOverlayPermission ? '悬浮窗权限已获取' : '需要悬浮窗权限'),
              ],
            ),
            if (!_hasOverlayPermission) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _requestOverlayPermission,
                child: const Text('申请悬浮窗权限'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingWindowCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '悬浮窗控制',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _hasOverlayPermission ? _showFloatingWindow : null,
                    child: const Text('显示悬浮窗'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isFloatingWindowVisible ? _hideFloatingWindow : null,
                    child: const Text('隐藏悬浮窗'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isFloatingWindowVisible ? '悬浮窗已显示' : '悬浮窗已隐藏',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingControlCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '录制控制',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: !_isRecording ? _startRecording : null,
                    child: const Text('开始录制'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRecording ? _stopRecording : null,
                    child: const Text('停止录制'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRecording ? _pauseResumeRecording : null,
                    child: Text(_isPaused ? '继续录制' : '暂停录制'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _actionsCount > 0 ? _showSaveDialog : null,
                    child: const Text('保存录制'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isRecording ? _showTestActionsDialog : null,
              child: const Text('测试录制操作'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingFileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '录制文件',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: _loadRecordings,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_recordings.isEmpty)
              const Text('暂无录制文件')
            else
              DropdownButton<String>(
                value: _selectedRecording,
                hint: const Text('选择录制文件'),
                isExpanded: true,
                items: _recordings.map((recording) {
                  return DropdownMenuItem<String>(
                    value: recording,
                    child: Text(recording),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRecording = value;
                  });
                },
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedRecording != null ? () => _loadRecording(_selectedRecording!) : null,
                    child: const Text('加载录制'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedRecording != null ? () => _executeRecording(_selectedRecording!) : null,
                    child: const Text('执行录制'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '状态信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(_statusMessage),
            if (_isRecording) ...[
              const SizedBox(height: 8),
              Text('已录制操作数: $_actionsCount'),
              Text('录制状态: ${_isPaused ? "已暂停" : "录制中"}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibilityPermissionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isServiceEnabled ? Icons.check_circle : Icons.error,
                  color: _isServiceEnabled ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  '无障碍权限: ${_isServiceEnabled ? "已开启" : "未开启"}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('当前状态: $_currentAction'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _safeMode ? Icons.security : Icons.warning,
                  color: _safeMode ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text('安全模式: ${_safeMode ? "已开启" : "已关闭"}'),
                const Spacer(),
                Switch(
                  value: _safeMode,
                  onChanged: (value) {
                    setState(() {
                      _safeMode = value;
                    });
                    _showSnackBar(
                      _safeMode ? '已开启安全模式，不会拦截用户操作' : '已关闭安全模式，请谨慎使用',
                      _safeMode ? Colors.green : Colors.orange,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibilityControlCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '控制操作',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isServiceEnabled ? null : _requestAccessibilityPermission,
                  icon: const Icon(Icons.security),
                  label: const Text('申请权限'),
                ),
                ElevatedButton.icon(
                  onPressed: _isListening ? _stopAccessibilityStream : _startAccessibilityStream,
                  icon: Icon(_isListening ? Icons.stop : Icons.play_arrow),
                  label: Text(_isListening ? '停止监听' : '开始监听'),
                ),
                ElevatedButton.icon(
                  onPressed: _clearEvents,
                  icon: const Icon(Icons.clear),
                  label: const Text('清空日志'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '全局动作',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _performGlobalAction(GlobalAction.globalActionBack),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('返回'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _performGlobalAction(GlobalAction.globalActionHome),
                  icon: const Icon(Icons.home),
                  label: const Text('主页'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _performGlobalAction(GlobalAction.globalActionRecents),
                  icon: const Icon(Icons.recent_actors),
                  label: const Text('最近'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _performGlobalAction(GlobalAction.globalActionTakeScreenshot),
                  icon: const Icon(Icons.screenshot),
                  label: const Text('截图'),
                ),
                ElevatedButton.icon(
                  onPressed: _showOverlay,
                  icon: const Icon(Icons.picture_in_picture),
                  label: const Text('显示浮层'),
                ),
                ElevatedButton.icon(
                  onPressed: _hideOverlay,
                  icon: const Icon(Icons.picture_in_picture_alt),
                  label: const Text('隐藏浮层'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventLogCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '无障碍事件日志',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: _events.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无事件\n开始监听后将显示无障碍事件',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            _getEventIcon(event.eventType),
                            size: 20,
                            color: Colors.deepPurple,
                          ),
                          title: Text(
                            event.packageName ?? '未知应用',
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '事件: ${event.eventType?.toString().split('.').last ?? "未知"}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (event.text?.isNotEmpty == true)
                                Text(
                                  '文本: ${event.text}',
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          trailing: Text(
                            '${event.eventTime?.hour.toString().padLeft(2, '0')}:${event.eventTime?.minute.toString().padLeft(2, '0')}:${event.eventTime?.second.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
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
}
