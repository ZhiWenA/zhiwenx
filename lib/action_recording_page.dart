import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

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
  
  bool _hasOverlayPermission = false;
  bool _isFloatingWindowVisible = false;
  bool _isRecording = false;
  bool _isPaused = false;
  int _actionsCount = 0;
  List<String> _recordings = [];
  String? _selectedRecording;
  String _statusMessage = '准备就绪';
  
  @override
  void initState() {
    super.initState();
    _checkOverlayPermission();
    _loadRecordings();
    _setupEventListeners();
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('操作录制'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 权限状态卡片
            Card(
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
            ),
            
            const SizedBox(height: 16),
            
            // 悬浮窗控制卡片
            Card(
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
            ),
            
            const SizedBox(height: 16),
            
            // 录制控制卡片
            Card(
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
            ),
            
            const SizedBox(height: 16),
            
            // 录制文件管理卡片
            Card(
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
            ),
            
            const SizedBox(height: 16),
            
            // 状态信息卡片
            Card(
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
            ),
          ],
        ),
      ),
    );
  }
}
