import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../automation_rule_engine.dart';
import '../utils/overlay_permission_manager.dart';

/// 全局控件抓取服务
class GlobalWidgetCaptureService {
  static const MethodChannel _channel = MethodChannel('com.tianli.zhiwenx/global_capture');
  static GlobalWidgetCaptureService? _instance;
  
  bool _isRunning = false;
  Timer? _captureTimer;
  StreamController<List<WidgetInfo>>? _widgetStreamController;
  StreamController<CaptureStatus>? _statusStreamController;
  
  static GlobalWidgetCaptureService get instance {
    _instance ??= GlobalWidgetCaptureService._();
    return _instance!;
  }
  
  GlobalWidgetCaptureService._();
  
  /// 控件流
  Stream<List<WidgetInfo>> get widgetStream {
    _widgetStreamController ??= StreamController<List<WidgetInfo>>.broadcast();
    return _widgetStreamController!.stream;
  }
  
  /// 状态流
  Stream<CaptureStatus> get statusStream {
    _statusStreamController ??= StreamController<CaptureStatus>.broadcast();
    return _statusStreamController!.stream;
  }
  
  bool get isRunning => _isRunning;
  
  /// 启动全局控件抓取
  Future<bool> startGlobalCapture({
    Duration interval = const Duration(seconds: 1),
    bool showOverlay = true,
  }) async {
    if (_isRunning) return true;
    
    try {
      // 检查无障碍权限
      final hasAccessibilityPermission = await _channel.invokeMethod('checkAccessibilityPermission');
      if (!hasAccessibilityPermission) {
        _updateStatus(CaptureStatus.permissionDenied);
        return false;
      }
      
      // 检查悬浮窗权限
      if (showOverlay) {
        final hasOverlayPermission = await OverlayPermissionManager.hasOverlayPermission();
        if (!hasOverlayPermission) {
          _updateStatus(CaptureStatus.permissionDenied);
          return false;
        }
      }
      
      // 启动全局悬浮窗
      if (showOverlay) {
        await _channel.invokeMethod('showGlobalOverlay');
      }
      
      _isRunning = true;
      _updateStatus(CaptureStatus.running);
      
      // 定时抓取控件
      _captureTimer = Timer.periodic(interval, (_) => _captureWidgets());
      
      return true;
    } catch (e) {
      _updateStatus(CaptureStatus.error(message: e.toString()));
      return false;
    }
  }
  
  /// 停止全局控件抓取
  Future<void> stopGlobalCapture() async {
    if (!_isRunning) return;
    
    _captureTimer?.cancel();
    _captureTimer = null;
    _isRunning = false;
    
    try {
      await _channel.invokeMethod('hideGlobalOverlay');
      _updateStatus(CaptureStatus.stopped);
    } catch (e) {
      _updateStatus(CaptureStatus.error(message: e.toString()));
    }
  }
  
  /// 抓取当前屏幕控件
  Future<void> _captureWidgets() async {
    try {
      final result = await _channel.invokeMethod('captureScreenWidgets');
      if (result != null) {
        final List<dynamic> widgets = result;
        final widgetInfos = widgets.map((w) => WidgetInfo.fromJson(Map<String, dynamic>.from(w as Map))).toList();
        _widgetStreamController?.add(widgetInfos);
      }
    } catch (e) {
      _updateStatus(CaptureStatus.error(message: e.toString()));
    }
  }
  
  /// 高亮指定控件
  Future<void> highlightWidget(WidgetInfo widget, {
    Duration duration = const Duration(seconds: 2),
    Color color = Colors.red,
  }) async {
    try {
      await _channel.invokeMethod('highlightWidget', {
        'bounds': {
          'left': widget.bounds.left,
          'top': widget.bounds.top,
          'right': widget.bounds.right,
          'bottom': widget.bounds.bottom,
        },
        'color': color.value,
        'duration': duration.inMilliseconds,
      });
    } catch (e) {
      print('高亮控件失败: $e');
    }
  }
  
  /// 显示控件详情弹窗
  Future<void> showWidgetDetails(WidgetInfo widget) async {
    try {
      await _channel.invokeMethod('showWidgetDetails', {
        'widget': widget.toJson(),
      });
    } catch (e) {
      print('显示控件详情失败: $e');
    }
  }
  
  /// 切换控件选择模式
  Future<void> toggleSelectionMode(bool enabled) async {
    try {
      await _channel.invokeMethod('toggleSelectionMode', {'enabled': enabled});
    } catch (e) {
      print('切换选择模式失败: $e');
    }
  }
  
  /// 更新状态
  void _updateStatus(CaptureStatus status, {String? message}) {
    _statusStreamController?.add(status.copyWith(message: message));
  }
  
  /// 释放资源
  void dispose() {
    stopGlobalCapture();
    _widgetStreamController?.close();
    _statusStreamController?.close();
    _widgetStreamController = null;
    _statusStreamController = null;
  }
}

/// 抓取状态
class CaptureStatus {
  final CaptureState state;
  final String? message;
  final DateTime timestamp;
  
  CaptureStatus({
    required this.state,
    this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  static CaptureStatus get idle => CaptureStatus(state: CaptureState.idle);
  static CaptureStatus get running => CaptureStatus(state: CaptureState.running);
  static CaptureStatus get stopped => CaptureStatus(state: CaptureState.stopped);
  static CaptureStatus get permissionDenied => CaptureStatus(state: CaptureState.permissionDenied);
  
  static CaptureStatus error({String? message}) => CaptureStatus(
    state: CaptureState.error,
    message: message,
  );
  
  CaptureStatus copyWith({
    CaptureState? state,
    String? message,
    DateTime? timestamp,
  }) {
    return CaptureStatus(
      state: state ?? this.state,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

enum CaptureState {
  idle,
  running,
  stopped,
  error,
  permissionDenied,
}
