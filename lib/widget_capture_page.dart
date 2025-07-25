import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'automation_rule_engine.dart';
import 'utils/accessibility_permission_manager.dart';
import 'widgets/enhanced_widget_info_card.dart';
import 'global_widget_capture_page.dart';
import 'dart:async';
import 'dart:convert';

class WidgetCapturePage extends StatefulWidget {
  const WidgetCapturePage({super.key});

  @override
  State<WidgetCapturePage> createState() => _WidgetCapturePageState();
}

class _WidgetCapturePageState extends State<WidgetCapturePage> {
  List<WidgetInfo> _widgets = [];
  bool _isCapturing = false;
  String _statusMessage = '准备开始实时抓取';
  Timer? _captureTimer;
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _stopCapture();
    super.dispose();
  }

  Future<void> _startRealTimeCapture() async {
    // 检查无障碍权限
    final hasPermission = await AccessibilityPermissionManager.checkAndRequestPermission(
      context,
      feature: '实时控件抓取',
    );
    
    if (!hasPermission) {
      _showSnackBar('需要无障碍权限才能进行实时控件抓取', Colors.red);
      return;
    }

    setState(() {
      _isCapturing = true;
      _statusMessage = '正在实时抓取屏幕控件...';
    });

    _showCaptureOverlay();

    _captureTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final widgets = await AutomationRuleEngine.getScreenWidgets();
        if (mounted) {
          setState(() {
            _widgets = widgets;
            _statusMessage = '实时抓取中 - 发现 ${widgets.length} 个控件';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusMessage = '抓取失败: $e';
          });
        }
      }
    });
  }

  void _stopCapture() {
    _captureTimer?.cancel();
    _captureTimer = null;
    _hideOverlay();
    
    setState(() {
      _isCapturing = false;
      _statusMessage = '已停止抓取';
    });
  }

  void _showCaptureOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '实时抓取中',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _exportWidgets() {
    if (_widgets.isEmpty) {
      _showSnackBar('没有控件数据可导出', Colors.orange);
      return;
    }

    final jsonString = jsonEncode(_widgets.map((w) => w.toJson()).toList());
    Clipboard.setData(ClipboardData(text: jsonString));
    _showSnackBar('控件数据已复制到剪贴板', Colors.green);
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
        title: const Text('实时控件抓取'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GlobalWidgetCapturePage()),
              );
            },
            icon: const Icon(Icons.open_in_new),
            tooltip: '全局抓取模式',
          ),
          IconButton(
            onPressed: _widgets.isEmpty ? null : _exportWidgets,
            icon: const Icon(Icons.download),
            tooltip: '导出控件数据',
          ),
        ],
      ),
      body: Column(
        children: [
          // 控制面板
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _isCapturing ? Colors.teal : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '控件数: ${_widgets.length}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isCapturing ? _stopCapture : _startRealTimeCapture,
                        icon: Icon(_isCapturing ? Icons.stop : Icons.play_arrow),
                        label: Text(_isCapturing ? '停止抓取' : '开始抓取'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCapturing ? Colors.red : Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 控件列表
          Expanded(
            child: _widgets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.widgets_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isCapturing ? '正在抓取控件...' : '点击开始抓取按钮获取屏幕控件',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _widgets.length,
                    itemBuilder: (context, index) {
                      final widget = _widgets[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            widget.className ?? '未知控件',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            widget.text ?? widget.contentDescription ?? '无文本描述',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow('类名', widget.className),
                                  _buildInfoRow('资源ID', widget.resourceId),
                                  _buildInfoRow('文本', widget.text),
                                  _buildInfoRow('描述', widget.contentDescription),
                                  _buildInfoRow('包名', widget.packageName),
                                  _buildInfoRow('可点击', widget.isClickable ? '是' : '否'),
                                  _buildInfoRow('可编辑', widget.className?.contains('EditText') == true ? '是' : '否'),
                                  _buildInfoRow('位置', 
                                    '(${widget.bounds.left}, ${widget.bounds.top}) - (${widget.bounds.right}, ${widget.bounds.bottom})'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: jsonEncode(widget.toJson())));
                                            _showSnackBar('控件信息已复制', Colors.blue);
                                          },
                                          icon: const Icon(Icons.copy),
                                          label: const Text('复制JSON'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.teal,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}