import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:flutter_accessibility_service/constants.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:asr_plugin/asr_plugin.dart';
import 'tencent_cloud_config.dart';

class VoiceControlledAccessibilityPage extends StatefulWidget {
  const VoiceControlledAccessibilityPage({super.key});

  @override
  State<VoiceControlledAccessibilityPage> createState() => _VoiceControlledAccessibilityPageState();
}

class _VoiceControlledAccessibilityPageState extends State<VoiceControlledAccessibilityPage> {
  StreamSubscription<AccessibilityEvent>? _accessibilitySubscription;
  ASRController? _asrController;
  late ASRControllerConfig _asrConfig;
  
  bool _isAccessibilityEnabled = false;
  bool _isListening = false;
  bool _isRecognizing = false;
  bool _safeMode = true; // 安全模式开关
  String _recognitionResult = "";
  String _systemFeedback = "系统就绪，请说出指令";
  
  final List<String> _commandHistory = [];
  final List<AccessibilityEvent> _recentEvents = [];

  // 语音指令映射
  final Map<String, Function> _voiceCommands = {};

  @override
  void initState() {
    super.initState();
    _initializeASR();
    _initializeVoiceCommands();
    _checkAccessibilityPermission();
  }

  @override
  void dispose() {
    _accessibilitySubscription?.cancel();
    _asrController?.stop();
    super.dispose();
  }

  void _initializeASR() {
    _asrConfig = ASRControllerConfig();
    _asrConfig.appID = TencentCloudConfig.appID;
    _asrConfig.projectID = TencentCloudConfig.projectID;
    _asrConfig.secretID = TencentCloudConfig.secretID;
    _asrConfig.secretKey = TencentCloudConfig.secretKey;
    
    _asrConfig.engine_model_type = "16k_zh";
    _asrConfig.filter_dirty = 1;
    _asrConfig.filter_modal = 0;
    _asrConfig.filter_punc = 0;
    _asrConfig.convert_num_mode = 1;
    _asrConfig.needvad = 1;
    _asrConfig.silence_detect = true;
    _asrConfig.silence_detect_duration = 2000;
  }

  void _initializeVoiceCommands() {
    _voiceCommands.addAll({
      // 基础导航指令
      '返回': () => _performGlobalAction(GlobalAction.globalActionBack),
      '回到主页': () => _performGlobalAction(GlobalAction.globalActionHome),
      '主页': () => _performGlobalAction(GlobalAction.globalActionHome),
      '最近任务': () => _performGlobalAction(GlobalAction.globalActionRecents),
      '截图': () => _performGlobalAction(GlobalAction.globalActionTakeScreenshot),
      
      // 通知相关
      '打开通知': () => _performGlobalAction(GlobalAction.globalActionNotifications),
      '快速设置': () => _performGlobalAction(GlobalAction.globalActionQuickSettings),
      
      // 电源相关
      '锁屏': () => _performGlobalAction(GlobalAction.globalActionLockScreen),
      '电源菜单': () => _performGlobalAction(GlobalAction.globalActionPowerDialog),
      
      // 辅助功能
      '显示浮层': _showOverlay,
      '隐藏浮层': _hideOverlay,
      '开始监听': _startAccessibilityStream,
      '停止监听': _stopAccessibilityStream,
      
      // 应用控制
      '点击': _performClickOnCurrentFocus,
      '长按': _performLongClickOnCurrentFocus,
      '向上滑动': _scrollUp,
      '向下滑动': _scrollDown,
      '向左滑动': _scrollLeft,
      '向右滑动': _scrollRight,
    });
  }

  Future<void> _checkAccessibilityPermission() async {
    final isEnabled = await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
    setState(() {
      _isAccessibilityEnabled = isEnabled;
    });
  }

  Future<void> _requestAccessibilityPermission() async {
    final granted = await FlutterAccessibilityService.requestAccessibilityPermission();
    setState(() {
      _isAccessibilityEnabled = granted;
    });
    
    if (granted) {
      _updateFeedback('无障碍权限已授予');
    } else {
      _updateFeedback('无障碍权限被拒绝');
    }
  }

  void _startVoiceRecognition() async {
    if (!_isAccessibilityEnabled) {
      _updateFeedback('请先开启无障碍权限');
      return;
    }

    if (!TencentCloudConfig.isConfigValid) {
      _updateFeedback('语音识别配置错误');
      return;
    }

    try {
      if (_asrController != null) {
        await _asrController?.release();
      }
      
      setState(() {
        _isRecognizing = true;
        _recognitionResult = "";
      });
      _updateFeedback('正在初始化语音识别...');

      _asrController = await _asrConfig.build();
      _updateFeedback('开始语音识别，请说话...');

      await for (final data in _asrController!.recognize()) {
        switch (data.type) {
          case ASRDataType.SLICE:
          case ASRDataType.SEGMENT:
            setState(() {
              _recognitionResult = data.res ?? "";
            });
            break;
          case ASRDataType.SUCCESS:
            setState(() {
              _isRecognizing = false;
              _recognitionResult = data.res ?? "";
            });
            if (_recognitionResult.isNotEmpty) {
              _processVoiceCommand(_recognitionResult);
            }
            break;
          case ASRDataType.NOTIFY:
            setState(() {
              _isRecognizing = false;
            });
            _updateFeedback('识别通知: ${data.res}');
            break;
        }
      }
    } catch (e) {
      setState(() {
        _isRecognizing = false;
      });
      _updateFeedback('语音识别失败: $e');
    }
  }

  void _stopVoiceRecognition() async {
    await _asrController?.release();
    setState(() {
      _isRecognizing = false;
    });
    _updateFeedback('语音识别已停止');
  }

  void _processVoiceCommand(String command) {
    setState(() {
      _commandHistory.insert(0, command);
      if (_commandHistory.length > 20) {
        _commandHistory.removeLast();
      }
    });

    // 查找匹配的语音指令
    String? matchedKey;
    for (String key in _voiceCommands.keys) {
      if (command.contains(key)) {
        matchedKey = key;
        break;
      }
    }

    if (matchedKey != null) {
      _updateFeedback('执行指令: $matchedKey');
      _voiceCommands[matchedKey]!();
    } else {
      // 尝试智能解析指令
      _processIntelligentCommand(command);
    }
  }

  void _processIntelligentCommand(String command) {
    // 智能指令处理
    if (command.contains('打开') || command.contains('启动')) {
      String appName = _extractAppName(command);
      if (appName.isNotEmpty) {
        _updateFeedback('尝试打开应用: $appName');
        _openApp(appName);
      } else {
        _updateFeedback('未识别到要打开的应用名称');
      }
    } else if (command.contains('搜索')) {
      String searchText = _extractSearchText(command);
      if (searchText.isNotEmpty) {
        _updateFeedback('搜索: $searchText');
        _performSearch(searchText);
      } else {
        _updateFeedback('未识别到搜索内容');
      }
    } else if (command.contains('输入') || command.contains('写')) {
      String inputText = _extractInputText(command);
      if (inputText.isNotEmpty) {
        _updateFeedback('输入文本: $inputText');
        _inputText(inputText);
      } else {
        _updateFeedback('未识别到要输入的文本');
      }
    } else {
      _updateFeedback('未识别的指令: $command');
    }
  }

  String _extractAppName(String command) {
    // 提取应用名称的简单实现
    final patterns = ['打开', '启动', '开启'];
    for (String pattern in patterns) {
      int index = command.indexOf(pattern);
      if (index != -1) {
        return command.substring(index + pattern.length).trim();
      }
    }
    return '';
  }

  String _extractSearchText(String command) {
    final patterns = ['搜索'];
    for (String pattern in patterns) {
      int index = command.indexOf(pattern);
      if (index != -1) {
        return command.substring(index + pattern.length).trim();
      }
    }
    return '';
  }

  String _extractInputText(String command) {
    final patterns = ['输入', '写'];
    for (String pattern in patterns) {
      int index = command.indexOf(pattern);
      if (index != -1) {
        return command.substring(index + pattern.length).trim();
      }
    }
    return '';
  }

  void _startAccessibilityStream() {
    if (!_isAccessibilityEnabled) {
      _updateFeedback('请先开启无障碍权限');
      return;
    }

    _accessibilitySubscription = FlutterAccessibilityService.accessStream.listen(
      (event) {
        setState(() {
          _recentEvents.insert(0, event);
          if (_recentEvents.length > 10) {
            _recentEvents.removeLast();
          }
        });
      },
      onError: (error) {
        _updateFeedback('监听出错: $error');
      },
    );

    setState(() {
      _isListening = true;
    });
    _updateFeedback('开始监听无障碍事件');
  }

  void _stopAccessibilityStream() {
    _accessibilitySubscription?.cancel();
    setState(() {
      _isListening = false;
    });
    _updateFeedback('停止监听无障碍事件');
  }

  Future<void> _performGlobalAction(GlobalAction action) async {
    if (_safeMode) {
      // 在安全模式下，只允许基本的导航操作
      final safeActions = [
        GlobalAction.globalActionBack,
        GlobalAction.globalActionHome,
        GlobalAction.globalActionRecents,
        GlobalAction.globalActionTakeScreenshot,
        GlobalAction.globalActionNotifications,
        GlobalAction.globalActionQuickSettings,
      ];
      
      if (!safeActions.contains(action)) {
        _updateFeedback('安全模式下不允许此操作');
        return;
      }
    }

    try {
      await FlutterAccessibilityService.performGlobalAction(action);
      _updateFeedback('全局动作已执行');
    } catch (e) {
      _updateFeedback('执行失败: $e');
    }
  }

  Future<void> _showOverlay() async {
    try {
      await FlutterAccessibilityService.showOverlayWindow();
      _updateFeedback('浮层已显示');
    } catch (e) {
      _updateFeedback('显示浮层失败: $e');
    }
  }

  Future<void> _hideOverlay() async {
    try {
      await FlutterAccessibilityService.hideOverlayWindow();
      _updateFeedback('浮层已隐藏');
    } catch (e) {
      _updateFeedback('隐藏浮层失败: $e');
    }
  }

  void _performClickOnCurrentFocus() {
    if (_safeMode) {
      _updateFeedback('安全模式下不允许自动点击操作');
      return;
    }
    
    if (_recentEvents.isNotEmpty) {
      final event = _recentEvents.first;
      if (event.nodeId != null) {
        FlutterAccessibilityService.performAction(
          event,
          NodeAction.actionClick,
        );
        _updateFeedback('执行点击操作');
      }
    } else {
      _updateFeedback('没有可点击的元素');
    }
  }

  void _performLongClickOnCurrentFocus() {
    if (_safeMode) {
      _updateFeedback('安全模式下不允许自动长按操作');
      return;
    }
    
    if (_recentEvents.isNotEmpty) {
      final event = _recentEvents.first;
      if (event.nodeId != null) {
        FlutterAccessibilityService.performAction(
          event,
          NodeAction.actionLongClick,
        );
        _updateFeedback('执行长按操作');
      }
    } else {
      _updateFeedback('没有可长按的元素');
    }
  }

  void _scrollUp() {
    if (_safeMode) {
      _updateFeedback('安全模式下不允许自动滑动操作');
      return;
    }
    
    if (_recentEvents.isNotEmpty) {
      final event = _recentEvents.first;
      FlutterAccessibilityService.performAction(
        event,
        NodeAction.actionScrollBackward,
      );
      _updateFeedback('向上滑动');
    }
  }

  void _scrollDown() {
    if (_safeMode) {
      _updateFeedback('安全模式下不允许自动滑动操作');
      return;
    }
    
    if (_recentEvents.isNotEmpty) {
      final event = _recentEvents.first;
      FlutterAccessibilityService.performAction(
        event,
        NodeAction.actionScrollForward,
      );
      _updateFeedback('向下滑动');
    }
  }

  void _scrollLeft() {
    // 实现向左滑动逻辑
    _updateFeedback('向左滑动（待实现）');
  }

  void _scrollRight() {
    // 实现向右滑动逻辑
    _updateFeedback('向右滑动（待实现）');
  }

  void _openApp(String appName) {
    // 实现打开应用的逻辑
    _updateFeedback('打开应用功能待实现: $appName');
  }

  void _performSearch(String searchText) {
    // 实现搜索功能
    if (_recentEvents.isNotEmpty) {
      // 查找搜索框并输入文本
      _updateFeedback('搜索功能待完善: $searchText');
    }
  }

  void _inputText(String text) {
    if (_safeMode) {
      _updateFeedback('安全模式下不允许自动输入操作');
      return;
    }
    
    if (_recentEvents.isNotEmpty) {
      final event = _recentEvents.first;
      FlutterAccessibilityService.performAction(
        event,
        NodeAction.actionSetText,
        text,
      );
      _updateFeedback('输入文本: $text');
    } else {
      _updateFeedback('没有可输入的文本框');
    }
  }

  void _updateFeedback(String message) {
    setState(() {
      _systemFeedback = message;
    });
    log(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语音控制辅助'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 权限和状态卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isAccessibilityEnabled ? Icons.check_circle : Icons.error,
                          color: _isAccessibilityEnabled ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '无障碍权限: ${_isAccessibilityEnabled ? "已开启" : "未开启"}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isRecognizing ? Icons.mic : Icons.mic_off,
                          color: _isRecognizing ? Colors.red : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text('语音识别: ${_isRecognizing ? "正在识别" : "未开启"}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isListening ? Icons.hearing : Icons.hearing_disabled,
                          color: _isListening ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text('事件监听: ${_isListening ? "正在监听" : "未开启"}'),
                      ],
                    ),
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
                            _updateFeedback(_safeMode ? '已开启安全模式' : '已关闭安全模式，请谨慎使用');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 系统反馈
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '系统反馈:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_systemFeedback),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 当前识别结果
            if (_recognitionResult.isNotEmpty)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '识别结果:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_recognitionResult),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 控制按钮
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isAccessibilityEnabled ? null : _requestAccessibilityPermission,
                  icon: const Icon(Icons.security),
                  label: const Text('申请权限'),
                ),
                ElevatedButton.icon(
                  onPressed: _isRecognizing ? _stopVoiceRecognition : _startVoiceRecognition,
                  icon: Icon(_isRecognizing ? Icons.stop : Icons.mic),
                  label: Text(_isRecognizing ? '停止识别' : '开始语音控制'),
                ),
                ElevatedButton.icon(
                  onPressed: _isListening ? _stopAccessibilityStream : _startAccessibilityStream,
                  icon: Icon(_isListening ? Icons.hearing_disabled : Icons.hearing),
                  label: Text(_isListening ? '停止监听' : '开始监听'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 语音指令帮助
            const Text(
              '支持的语音指令:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_safeMode) 
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.security, color: Colors.green, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '安全模式已开启：只允许基础导航操作，不会干扰您的正常使用',
                                  style: TextStyle(fontSize: 12, color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Text('基础操作:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Text('• "返回" - 返回上一页'),
                      const Text('• "主页" - 回到主屏幕'),
                      const Text('• "最近任务" - 显示最近应用'),
                      const Text('• "截图" - 截取屏幕'),
                      const SizedBox(height: 8),
                      if (!_safeMode) ...[
                        const Text('触控操作 (需关闭安全模式):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        const Text('• "向上滑动" - 页面向上滚动'),
                        const Text('• "向下滑动" - 页面向下滚动'),
                        const Text('• "点击" - 点击当前焦点元素'),
                        const Text('• "长按" - 长按当前焦点元素'),
                        const SizedBox(height: 8),
                        const Text('智能操作 (需关闭安全模式):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        const Text('• "打开微信" - 打开指定应用'),
                        const Text('• "搜索天气" - 执行搜索操作'),
                        const Text('• "输入你好" - 在文本框输入内容'),
                        const SizedBox(height: 8),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: const Text(
                            '触控和智能操作已禁用（安全模式）\n如需使用高级功能，请关闭安全模式',
                            style: TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                      if (_commandHistory.isNotEmpty) ...[
                        const Text('最近指令:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ...(_commandHistory.take(5).map((cmd) => Text('• $cmd'))),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
