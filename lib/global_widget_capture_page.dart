import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'automation_rule_engine.dart';
import 'services/global_widget_capture_service.dart';
import 'widgets/enhanced_widget_info_card.dart';
import 'utils/accessibility_permission_manager.dart';
import 'utils/overlay_permission_manager.dart';

/// 全局控件抓取页面 - 支持全局悬浮窗和智能选择
class GlobalWidgetCapturePage extends StatefulWidget {
  const GlobalWidgetCapturePage({super.key});

  @override
  State<GlobalWidgetCapturePage> createState() => _GlobalWidgetCapturePageState();
}

class _GlobalWidgetCapturePageState extends State<GlobalWidgetCapturePage> {
  late GlobalWidgetCaptureService _captureService;
  List<WidgetInfo> _widgets = [];
  CaptureStatus _status = CaptureStatus.idle;
  StreamSubscription? _widgetSubscription;
  StreamSubscription? _statusSubscription;
  
  // 选择模式
  bool _selectionMode = false;
  int? _selectedIndex;
  
  // 过滤选项
  bool _showClickableOnly = false;
  bool _showEditableOnly = false;
  String _searchText = '';
  
  @override
  void initState() {
    super.initState();
    _captureService = GlobalWidgetCaptureService.instance;
    _setupStreams();
  }

  @override
  void dispose() {
    _widgetSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _setupStreams() {
    _widgetSubscription = _captureService.widgetStream.listen((widgets) {
      if (mounted) {
        setState(() {
          _widgets = widgets;
        });
      }
    });

    _statusSubscription = _captureService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _status = status;
        });
        
        if (status.state == CaptureState.error) {
          _showSnackBar(status.message ?? '发生未知错误', Colors.red);
        }
      }
    });
  }

  List<WidgetInfo> get _filteredWidgets {
    var filtered = _widgets.where((widget) {
      // 搜索过滤
      if (_searchText.isNotEmpty) {
        final searchLower = _searchText.toLowerCase();
        final text = widget.text?.toLowerCase() ?? '';
        final desc = widget.contentDescription?.toLowerCase() ?? '';
        final className = widget.className?.toLowerCase() ?? '';
        final resourceId = widget.resourceId?.toLowerCase() ?? '';
        
        if (!text.contains(searchLower) && 
            !desc.contains(searchLower) && 
            !className.contains(searchLower) && 
            !resourceId.contains(searchLower)) {
          return false;
        }
      }
      
      // 可点击过滤
      if (_showClickableOnly && !widget.isClickable) {
        return false;
      }
      
      // 可编辑过滤
      if (_showEditableOnly && 
          !(widget.className?.contains('EditText') == true || 
            widget.className?.contains('TextField') == true)) {
        return false;
      }
      
      return true;
    }).toList();
    
    // 按优先级排序：可点击 > 可编辑 > 有文本 > 其他
    filtered.sort((a, b) {
      int scoreA = _getWidgetScore(a);
      int scoreB = _getWidgetScore(b);
      return scoreB.compareTo(scoreA);
    });
    
    return filtered;
  }
  
  int _getWidgetScore(WidgetInfo widget) {
    int score = 0;
    if (widget.isClickable) score += 100;
    if (widget.className?.contains('EditText') == true) score += 80;
    if (widget.text?.isNotEmpty == true) score += 50;
    if (widget.contentDescription?.isNotEmpty == true) score += 30;
    if (widget.resourceId?.isNotEmpty == true) score += 20;
    return score;
  }

  Future<void> _startCapture() async {
    // 检查无障碍权限
    final hasAccessibilityPermission = await AccessibilityPermissionManager.checkAndRequestPermission(
      context,
      feature: '全局控件抓取',
    );
    
    if (!hasAccessibilityPermission) {
      _showSnackBar('需要无障碍权限才能进行全局控件抓取', Colors.red);
      return;
    }

    // 检查悬浮窗权限
    final hasOverlayPermission = await OverlayPermissionManager.checkAndRequestPermission(
      context,
      feature: '全局控件抓取',
    );
    
    if (!hasOverlayPermission) {
      _showSnackBar('需要悬浮窗权限才能显示全局界面', Colors.red);
      return;
    }

    final success = await _captureService.startGlobalCapture(
      interval: const Duration(milliseconds: 1500),
      showOverlay: true,
    );

    if (!success) {
      _showSnackBar('启动全局抓取失败', Colors.red);
    } else {
      _showSnackBar('全局抓取已启动，您现在可以切换到其他应用查看控件', Colors.green);
    }
  }

  Future<void> _stopCapture() async {
    await _captureService.stopGlobalCapture();
    setState(() {
      _selectedIndex = null;
      _selectionMode = false;
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedIndex = null;
      }
    });
    
    _captureService.toggleSelectionMode(_selectionMode);
  }

  Future<void> _highlightWidget(WidgetInfo widget) async {
    await _captureService.highlightWidget(
      widget, 
      duration: const Duration(seconds: 3),
      color: Colors.red,
    );
  }

  void _createRuleFromWidget(WidgetInfo widget) {
    showDialog(
      context: context,
      builder: (context) => _RuleCreationDialog(widget: widget),
    );
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
    final filteredWidgets = _filteredWidgets;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('全局控件抓取'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _selectionMode ? null : () => _showFilterDialog(),
            icon: const Icon(Icons.filter_list),
            tooltip: '过滤设置',
          ),
          IconButton(
            onPressed: _captureService.isRunning ? _toggleSelectionMode : null,
            icon: Icon(_selectionMode ? Icons.touch_app : Icons.mouse),
            tooltip: _selectionMode ? '退出选择模式' : '进入选择模式',
          ),
        ],
      ),
      body: Column(
        children: [
          // 状态栏和控制面板
          _buildControlPanel(),
          
          // 搜索栏
          if (_captureService.isRunning) _buildSearchBar(),
          
          // 控件列表
          Expanded(
            child: _buildWidgetList(filteredWidgets),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureService.isRunning ? _stopCapture : _startCapture,
        backgroundColor: _captureService.isRunning ? Colors.red : Colors.teal,
        child: Icon(_captureService.isRunning ? Icons.stop : Icons.play_arrow),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
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
              Icon(
                _getStatusIcon(),
                color: _getStatusColor(),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getStatusText(),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${_widgets.length} 个控件',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (_selectionMode) ...[
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
                      '选择模式已开启：点击控件卡片进行选择和操作',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: (value) => setState(() => _searchText = value),
        decoration: InputDecoration(
          hintText: '搜索控件 (文本、描述、类名、资源ID)',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  onPressed: () => setState(() => _searchText = ''),
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  Widget _buildWidgetList(List<WidgetInfo> widgets) {
    if (!_captureService.isRunning) {
      return _buildEmptyState(
        icon: Icons.play_circle_outline,
        title: '点击开始按钮启动全局抓取',
        subtitle: '启动后可以实时查看屏幕上的所有控件信息',
      );
    }

    if (widgets.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off,
        title: _widgets.isEmpty ? '正在抓取控件...' : '没有找到匹配的控件',
        subtitle: _widgets.isEmpty ? '请稍候' : '尝试调整搜索条件或过滤设置',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widgets.length,
      itemBuilder: (context, index) {
        final widget = widgets[index];
        final originalIndex = _widgets.indexOf(widget);
        
        return EnhancedWidgetInfoCard(
          widget: widget,
          index: originalIndex,
          isSelected: _selectedIndex == originalIndex,
          onTap: _selectionMode 
              ? () => setState(() => _selectedIndex = originalIndex)
              : null,
          onHighlight: () => _highlightWidget(widget),
          onCreateRule: () => _createRuleFromWidget(widget),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_status.state) {
      case CaptureState.running:
        return Icons.wifi_tethering;
      case CaptureState.stopped:
        return Icons.stop;
      case CaptureState.error:
        return Icons.error_outline;
      case CaptureState.permissionDenied:
        return Icons.block;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Color _getStatusColor() {
    switch (_status.state) {
      case CaptureState.running:
        return Colors.green;
      case CaptureState.stopped:
        return Colors.orange;
      case CaptureState.error:
        return Colors.red;
      case CaptureState.permissionDenied:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (_status.state) {
      case CaptureState.running:
        return '全局抓取运行中';
      case CaptureState.stopped:
        return '已停止抓取';
      case CaptureState.error:
        return _status.message ?? '发生错误';
      case CaptureState.permissionDenied:
        return '权限被拒绝';
      default:
        return '准备就绪';
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('过滤设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('仅显示可点击控件'),
              value: _showClickableOnly,
              onChanged: (value) => setState(() => _showClickableOnly = value ?? false),
            ),
            CheckboxListTile(
              title: const Text('仅显示可编辑控件'),
              value: _showEditableOnly,
              onChanged: (value) => setState(() => _showEditableOnly = value ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _showClickableOnly = false;
                _showEditableOnly = false;
              });
              Navigator.of(context).pop();
            },
            child: const Text('重置'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

/// 规则创建对话框
class _RuleCreationDialog extends StatefulWidget {
  final WidgetInfo widget;

  const _RuleCreationDialog({required this.widget});

  @override
  State<_RuleCreationDialog> createState() => _RuleCreationDialogState();
}

class _RuleCreationDialogState extends State<_RuleCreationDialog> {
  final _nameController = TextEditingController();
  final _appNameController = TextEditingController();
  String _actionType = 'click';

  @override
  void initState() {
    super.initState();
    _nameController.text = '自动${_getActionName()}${_getWidgetName()}';
    _appNameController.text = widget.widget.packageName?.split('.').last ?? '未知应用';
  }

  String _getWidgetName() {
    if (widget.widget.text?.isNotEmpty == true) {
      return widget.widget.text!;
    }
    if (widget.widget.contentDescription?.isNotEmpty == true) {
      return widget.widget.contentDescription!;
    }
    return '控件';
  }

  String _getActionName() {
    switch (_actionType) {
      case 'click':
        return '点击';
      case 'input':
        return '输入';
      case 'scroll':
        return '滚动';
      default:
        return '操作';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建自动化规则'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '规则名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _appNameController,
              decoration: const InputDecoration(
                labelText: '应用名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _actionType,
              decoration: const InputDecoration(
                labelText: '操作类型',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'click', child: Text('点击')),
                DropdownMenuItem(value: 'input', child: Text('输入文本')),
                DropdownMenuItem(value: 'scroll', child: Text('滚动')),
              ],
              onChanged: (value) => setState(() {
                _actionType = value ?? 'click';
                _nameController.text = '自动${_getActionName()}${_getWidgetName()}';
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _createRule,
          child: const Text('创建规则'),
        ),
      ],
    );
  }

  void _createRule() {
    // 这里应该创建规则并导航到自动化规则页面
    // 暂时只显示成功消息
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('规则创建功能开发中...'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
