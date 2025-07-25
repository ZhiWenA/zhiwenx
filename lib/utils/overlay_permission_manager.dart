import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 悬浮窗权限管理器
class OverlayPermissionManager {
  static const MethodChannel _channel = MethodChannel('com.tianli.zhiwenx/overlay_permission');

  /// 检查是否有悬浮窗权限
  static Future<bool> hasOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod('hasOverlayPermission');
      return result == true;
    } catch (e) {
      print('检查悬浮窗权限失败: $e');
      return false;
    }
  }

  /// 请求悬浮窗权限
  static Future<bool> requestOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod('requestOverlayPermission');
      return result == true;
    } catch (e) {
      print('请求悬浮窗权限失败: $e');
      return false;
    }
  }

  /// 检查并请求悬浮窗权限（带用户提示）
  static Future<bool> checkAndRequestPermission(
    BuildContext context, {
    required String feature,
  }) async {
    // 先检查是否已有权限
    if (await hasOverlayPermission()) {
      return true;
    }

    // 显示权限说明对话框
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要悬浮窗权限'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$feature功能需要悬浮窗权限来正常工作。'),
            const SizedBox(height: 12),
            const Text(
              '悬浮窗权限用于：',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text('• 显示全局控件抓取界面'),
            const Text('• 实时显示抓取状态'),
            const Text('• 提供快捷操作按钮'),
            const Text('• 跨应用显示控件信息'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '我们承诺只在必要时使用此权限，不会影响您的正常使用。',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('授予权限'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) {
      return false;
    }

    // 请求权限
    final granted = await requestOverlayPermission();
    
    if (!granted) {
      // 权限被拒绝，显示说明
      _showPermissionDeniedDialog(context, feature);
    }

    return granted;
  }

  /// 显示权限被拒绝的对话框
  static void _showPermissionDeniedDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('权限被拒绝'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('无法获取悬浮窗权限，$feature功能将无法正常使用。'),
            const SizedBox(height: 12),
            const Text(
              '您可以在手机设置中手动开启：',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text('1. 打开手机设置'),
            const Text('2. 找到"应用管理"或"应用权限"'),
            const Text('3. 找到智问X应用'),
            const Text('4. 开启"悬浮窗"或"显示在其他应用上层"权限'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  /// 打开应用设置页面
  static Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (e) {
      print('打开应用设置失败: $e');
    }
  }

  /// 显示悬浮窗
  static Future<bool> showFloatingWindow({
    required String title,
    required String content,
    int? x,
    int? y,
    int? width,
    int? height,
  }) async {
    try {
      final result = await _channel.invokeMethod('showFloatingWindow', {
        'title': title,
        'content': content,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      });
      return result == true;
    } catch (e) {
      print('显示悬浮窗失败: $e');
      return false;
    }
  }

  /// 隐藏悬浮窗
  static Future<void> hideFloatingWindow() async {
    try {
      await _channel.invokeMethod('hideFloatingWindow');
    } catch (e) {
      print('隐藏悬浮窗失败: $e');
    }
  }

  /// 更新悬浮窗内容
  static Future<void> updateFloatingWindow({
    String? title,
    String? content,
  }) async {
    try {
      await _channel.invokeMethod('updateFloatingWindow', {
        if (title != null) 'title': title,
        if (content != null) 'content': content,
      });
    } catch (e) {
      print('更新悬浮窗失败: $e');
    }
  }
}
