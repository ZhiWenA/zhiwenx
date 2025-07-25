import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/overlay_permission_manager.dart';
import 'services/global_widget_capture_service.dart';

/// 全局抓取功能测试页面
class GlobalCaptureTestPage extends StatefulWidget {
  const GlobalCaptureTestPage({super.key});

  @override
  State<GlobalCaptureTestPage> createState() => _GlobalCaptureTestPageState();
}

class _GlobalCaptureTestPageState extends State<GlobalCaptureTestPage> {
  final GlobalWidgetCaptureService _captureService = GlobalWidgetCaptureService.instance;
  String _statusText = '准备测试';
  bool _hasOverlayPermission = false;
  bool _hasAccessibilityPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final overlayPermission = await OverlayPermissionManager.hasOverlayPermission();
      
      final accessibilityPermission = await MethodChannel('com.tianli.zhiwenx/global_capture')
          .invokeMethod('checkAccessibilityPermission');
      
      setState(() {
        _hasOverlayPermission = overlayPermission;
        _hasAccessibilityPermission = accessibilityPermission ?? false;
        _statusText = '权限检查完成';
      });
    } catch (e) {
      setState(() {
        _statusText = '权限检查失败: $e';
      });
    }
  }

  Future<void> _requestOverlayPermission() async {
    try {
      final granted = await OverlayPermissionManager.requestOverlayPermission();
      setState(() {
        _hasOverlayPermission = granted;
        _statusText = granted ? '悬浮窗权限已获取' : '悬浮窗权限被拒绝';
      });
    } catch (e) {
      setState(() {
        _statusText = '请求悬浮窗权限失败: $e';
      });
    }
  }

  Future<void> _testGlobalCapture() async {
    try {
      setState(() {
        _statusText = '正在测试全局抓取...';
      });

      final success = await _captureService.startGlobalCapture(
        interval: const Duration(seconds: 2),
        showOverlay: true,
      );

      setState(() {
        _statusText = success ? '全局抓取启动成功' : '全局抓取启动失败';
      });

      if (success) {
        // 等待3秒后停止
        await Future.delayed(const Duration(seconds: 3));
        await _captureService.stopGlobalCapture();
        setState(() {
          _statusText = '全局抓取已停止';
        });
      }
    } catch (e) {
      setState(() {
        _statusText = '测试全局抓取失败: $e';
      });
    }
  }

  Future<void> _testFloatingWindow() async {
    try {
      setState(() {
        _statusText = '正在测试悬浮窗...';
      });

      final success = await OverlayPermissionManager.showFloatingWindow(
        title: '测试悬浮窗',
        content: '这是一个测试悬浮窗',
        x: 100,
        y: 200,
        width: 300,
        height: 150,
      );

      setState(() {
        _statusText = success ? '悬浮窗显示成功' : '悬浮窗显示失败';
      });

      if (success) {
        // 等待3秒后隐藏
        await Future.delayed(const Duration(seconds: 3));
        await OverlayPermissionManager.hideFloatingWindow();
        setState(() {
          _statusText = '悬浮窗已隐藏';
        });
      }
    } catch (e) {
      setState(() {
        _statusText = '测试悬浮窗失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('全局抓取功能测试'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态显示
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '当前状态',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_statusText),
                    const SizedBox(height: 16),
                    const Text(
                      '权限状态:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _hasOverlayPermission ? Icons.check_circle : Icons.cancel,
                          color: _hasOverlayPermission ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text('悬浮窗权限'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _hasAccessibilityPermission ? Icons.check_circle : Icons.cancel,
                          color: _hasAccessibilityPermission ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text('无障碍权限'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 测试按钮
            const Text(
              '测试功能',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _checkPermissions,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新权限状态'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _hasOverlayPermission ? null : _requestOverlayPermission,
                icon: const Icon(Icons.security),
                label: Text(_hasOverlayPermission ? '悬浮窗权限已获取' : '请求悬浮窗权限'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasOverlayPermission ? Colors.green : Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _hasOverlayPermission ? _testFloatingWindow : null,
                icon: const Icon(Icons.picture_in_picture),
                label: const Text('测试悬浮窗'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_hasOverlayPermission && _hasAccessibilityPermission) 
                    ? _testGlobalCapture 
                    : null,
                icon: const Icon(Icons.widgets),
                label: const Text('测试全局抓取'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 说明文本
            Card(
              color: Colors.yellow.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          '使用说明',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. 首先需要获取悬浮窗权限和无障碍权限\n'
                      '2. 测试悬浮窗功能是否正常\n'
                      '3. 测试全局控件抓取功能\n'
                      '4. 如果测试失败，请检查Android端的实现',
                      style: TextStyle(fontSize: 12),
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
}
