import 'package:flutter/material.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter/services.dart';

class AccessibilityPermissionManager {
  static const MethodChannel _smartChannel = MethodChannel('com.tianli.zhiwenx/smart_recording');
  
  /// 检查无障碍权限是否已授权（同时检查Flutter和原生服务）
  static Future<bool> checkPermission() async {
    try {
      // 检查Flutter无障碍服务权限
      final isFlutterServiceEnabled = await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
      
      // 检查原生智能录制服务状态
      bool isSmartServiceEnabled = false;
      try {
        isSmartServiceEnabled = await _smartChannel.invokeMethod('isServiceEnabled') ?? false;
      } catch (e) {
        // 如果调用失败，认为服务未启用
        isSmartServiceEnabled = false;
      }
      
      // 任意一个服务启用即认为有权限（因为它们本质上是同一个权限）
      return isFlutterServiceEnabled || isSmartServiceEnabled;
    } catch (e) {
      return false;
    }
  }

  /// 显示权限请求对话框
  static Future<bool> showPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(
            Icons.accessibility_new,
            color: Colors.deepPurple,
            size: 48,
          ),
          title: const Text(
            '需要无障碍权限',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '此功能需要无障碍权限才能正常工作：',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('监听应用界面变化')),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('执行自动化操作')),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('录制和回放操作')),
                ],
              ),
              SizedBox(height: 16),
              Text(
                '点击"去设置"将跳转到系统设置页面，请找到"智问X"并开启以下服务之一：',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• 智问X - 智能辅助服务\n• 智问X - 智能操作录制服务',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
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
              onPressed: () async {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('去设置'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// 检查权限并显示对话框（如果需要）
  static Future<bool> checkAndRequestPermission(BuildContext context, {
    String? feature,
  }) async {
    final hasPermission = await checkPermission();
    
    if (hasPermission) {
      return true;
    }

    if (context.mounted) {
      final shouldRequest = await showPermissionDialog(context);
      
      if (shouldRequest && context.mounted) {
        try {
          final granted = await FlutterAccessibilityService.requestAccessibilityPermission();
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  granted ? '权限已授予' : '权限被拒绝，请在系统设置中手动开启',
                ),
                backgroundColor: granted ? Colors.green : Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          
          return granted;
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('权限请求失败: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return false;
        }
      }
    }
    
    return false;
  }

  /// 显示权限状态的Material组件
  static Widget buildPermissionStatusCard({
    required bool isEnabled,
    required String currentAction,
    VoidCallback? onRequestPermission,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEnabled ? Icons.check_circle : Icons.error,
                  color: isEnabled ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '无障碍权限: ${isEnabled ? "已开启" : "未开启"}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isEnabled && onRequestPermission != null)
                  FilledButton.icon(
                    onPressed: onRequestPermission,
                    icon: const Icon(Icons.security, size: 18),
                    label: const Text('开启权限'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '当前状态: $currentAction',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
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
}
