import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:flutter_accessibility_service/constants.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'utils/accessibility_permission_manager.dart';

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
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部图标和标题
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.accessibility_new,
                  color: Colors.deepPurple,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '智问X辅助',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // 按钮行
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: Icons.close,
                    color: Colors.red,
                    onPressed: () async {
                      await FlutterAccessibilityService.hideOverlayWindow();
                    },
                    tooltip: '关闭',
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(
                    icon: Icons.arrow_back,
                    color: Colors.blue,
                    onPressed: () async {
                      await FlutterAccessibilityService.performGlobalAction(
                        GlobalAction.globalActionBack,
                      );
                    },
                    tooltip: '返回',
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(
                    icon: Icons.home,
                    color: Colors.green,
                    onPressed: () async {
                      await FlutterAccessibilityService.performGlobalAction(
                        GlobalAction.globalActionHome,
                      );
                    },
                    tooltip: '主页',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Material(
      color: color.withValues(alpha:0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class AccessibilityAssistantPage extends StatefulWidget {
  const AccessibilityAssistantPage({super.key});

  @override
  State<AccessibilityAssistantPage> createState() => _AccessibilityAssistantPageState();
}

class _AccessibilityAssistantPageState extends State<AccessibilityAssistantPage> {
  StreamSubscription<AccessibilityEvent>? _subscription;
  final List<AccessibilityEvent> _events = [];
  bool _isServiceEnabled = false;
  bool _isListening = false;
  bool _safeMode = true; // 安全模式开关
  String _currentAction = "等待中...";

  @override
  void initState() {
    super.initState();
    _checkAccessibilityPermission();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAccessibilityPermission() async {
    final isEnabled = await AccessibilityPermissionManager.checkPermission();
    setState(() {
      _isServiceEnabled = isEnabled;
    });
  }

  Future<void> _requestAccessibilityPermission() async {
    final granted = await AccessibilityPermissionManager.checkAndRequestPermission(
      context,
      feature: '无障碍辅助',
    );
    setState(() {
      _isServiceEnabled = granted;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('无障碍辅助'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 权限状态卡片
            AccessibilityPermissionManager.buildPermissionStatusCard(
              isEnabled: _isServiceEnabled,
              currentAction: _currentAction,
              onRequestPermission: _isServiceEnabled ? null : _requestAccessibilityPermission,
            ),
            
            const SizedBox(height: 16),
            
            // 安全模式控制卡片
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      _safeMode ? Icons.security : Icons.warning,
                      color: _safeMode ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '安全模式: ${_safeMode ? "已开启" : "已关闭"}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _safeMode ? '限制危险操作，保护用户体验' : '允许所有操作，请谨慎使用',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
              ),
            ),
            
            // 控制按钮
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '监听控制',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _isListening ? _stopAccessibilityStream : _startAccessibilityStream,
                          icon: Icon(_isListening ? Icons.stop : Icons.play_arrow),
                          label: Text(_isListening ? '停止监听' : '开始监听'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _isListening ? Colors.red : Colors.green,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _clearEvents,
                          icon: const Icon(Icons.clear),
                          label: const Text('清空日志'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 全局动作按钮
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '全局动作',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _performGlobalAction(GlobalAction.globalActionBack),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('返回'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _performGlobalAction(GlobalAction.globalActionHome),
                          icon: const Icon(Icons.home),
                          label: const Text('主页'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _performGlobalAction(GlobalAction.globalActionRecents),
                          icon: const Icon(Icons.recent_actors),
                          label: const Text('最近'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _performGlobalAction(GlobalAction.globalActionTakeScreenshot),
                          icon: const Icon(Icons.screenshot),
                          label: const Text('截图'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showOverlay,
                          icon: const Icon(Icons.picture_in_picture),
                          label: const Text('显示浮层'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _hideOverlay,
                          icon: const Icon(Icons.picture_in_picture_alt),
                          label: const Text('隐藏浮层'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 事件列表
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_note, color: Colors.deepPurple),
                      const SizedBox(width: 8),
                      const Text(
                        '无障碍事件日志',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_events.isNotEmpty)
                        Chip(
                          label: Text('${_events.length}'),
                          backgroundColor: Colors.deepPurple.withValues(alpha:0.1),
                          labelStyle: const TextStyle(color: Colors.deepPurple),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Card(
                      elevation: 2,
                      child: _events.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.event_busy,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '暂无事件',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '开始监听后将显示无障碍事件',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _events.length,
                              itemBuilder: (context, index) {
                                final event = _events[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.withValues(alpha:0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Icon(
                                        _getEventIcon(event.eventType),
                                        size: 20,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                    title: Text(
                                      event.packageName ?? '未知应用',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
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
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${event.eventTime?.hour.toString().padLeft(2, '0')}:${event.eventTime?.minute.toString().padLeft(2, '0')}:${event.eventTime?.second.toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
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
          ],
        ),
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
}
