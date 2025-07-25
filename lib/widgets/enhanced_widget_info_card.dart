import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../automation_rule_engine.dart';

/// 增强的控件信息展示组件
class EnhancedWidgetInfoCard extends StatelessWidget {
  final WidgetInfo widget;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onHighlight;
  final VoidCallback? onCreateRule;
  final bool isSelected;
  
  const EnhancedWidgetInfoCard({
    super.key,
    required this.widget,
    required this.index,
    this.onTap,
    this.onHighlight,
    this.onCreateRule,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 8 : 2,
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部信息
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getTypeColor(),
                    child: Icon(
                      _getTypeIcon(),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getDisplayName(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _getSubtitle(),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // 操作按钮
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onHighlight != null)
                        IconButton(
                          onPressed: onHighlight,
                          icon: const Icon(Icons.highlight_alt),
                          tooltip: '高亮显示',
                          iconSize: 20,
                        ),
                      if (onCreateRule != null)
                        IconButton(
                          onPressed: onCreateRule,
                          icon: const Icon(Icons.rule),
                          tooltip: '创建规则',
                          iconSize: 20,
                        ),
                      IconButton(
                        onPressed: () => _copyWidgetInfo(context),
                        icon: const Icon(Icons.copy),
                        tooltip: '复制信息',
                        iconSize: 20,
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // 详细信息
              _buildInfoSection('基本信息', [
                _InfoItem('控件ID', widget.resourceId ?? '无', icon: Icons.fingerprint),
                _InfoItem('类名', widget.className ?? '无', icon: Icons.code),
                _InfoItem('包名', widget.packageName ?? '无', icon: Icons.apps),
              ]),
              
              if (widget.text?.isNotEmpty == true || widget.contentDescription?.isNotEmpty == true)
                _buildInfoSection('内容信息', [
                  if (widget.text?.isNotEmpty == true)
                    _InfoItem('文本', widget.text!, icon: Icons.text_fields),
                  if (widget.contentDescription?.isNotEmpty == true)
                    _InfoItem('描述', widget.contentDescription!, icon: Icons.description),
                ]),
              
              _buildInfoSection('属性信息', [
                _InfoItem('可点击', widget.isClickable ? '是' : '否', 
                  icon: widget.isClickable ? Icons.touch_app : Icons.block),
                _InfoItem('可编辑', _isEditable() ? '是' : '否',
                  icon: _isEditable() ? Icons.edit : Icons.visibility),
                _InfoItem('可滚动', widget.isScrollable ? '是' : '否',
                  icon: widget.isScrollable ? Icons.swap_vert : Icons.lock),
              ]),
              
              _buildInfoSection('位置信息', [
                _InfoItem('坐标', '(${widget.bounds.left}, ${widget.bounds.top})',
                  icon: Icons.place),
                _InfoItem('尺寸', '${widget.bounds.width} × ${widget.bounds.height}',
                  icon: Icons.aspect_ratio),
              ]),
              
              // 快捷操作
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showSelectorDialog(context),
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('生成选择器'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportAsJson(context),
                      icon: const Icon(Icons.code, size: 16),
                      label: const Text('导出JSON'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoSection(String title, List<_InfoItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.deepPurple,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _buildInfoRow(item)),
        const SizedBox(height: 12),
      ],
    );
  }
  
  Widget _buildInfoRow(_InfoItem item) {
    if (item.value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              '${item.label}:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getDisplayName() {
    if (widget.text?.isNotEmpty == true) {
      return widget.text!;
    }
    if (widget.contentDescription?.isNotEmpty == true) {
      return widget.contentDescription!;
    }
    if (widget.resourceId?.isNotEmpty == true) {
      final parts = widget.resourceId!.split('/');
      return parts.isNotEmpty ? parts.last : widget.resourceId!;
    }
    return widget.className ?? '未知控件';
  }
  
  String _getSubtitle() {
    final parts = <String>[];
    if (widget.className?.isNotEmpty == true) {
      parts.add(widget.className!.split('.').last);
    }
    if (widget.isClickable) parts.add('可点击');
    if (_isEditable()) parts.add('可编辑');
    if (widget.isScrollable) parts.add('可滚动');
    return parts.isEmpty ? '控件 #${index + 1}' : parts.join(' • ');
  }
  
  Color _getTypeColor() {
    if (_isEditable()) return Colors.orange;
    if (widget.isClickable) return Colors.blue;
    if (widget.isScrollable) return Colors.green;
    return Colors.grey;
  }
  
  IconData _getTypeIcon() {
    if (_isEditable()) return Icons.edit;
    if (widget.isClickable) return Icons.touch_app;
    if (widget.isScrollable) return Icons.swap_vert;
    return Icons.widgets;
  }
  
  bool _isEditable() {
    return widget.className?.contains('EditText') == true ||
           widget.className?.contains('TextField') == true;
  }
  
  void _copyWidgetInfo(BuildContext context) {
    final info = '''
控件信息:
- 名称: ${_getDisplayName()}
- 类名: ${widget.className ?? '无'}
- 资源ID: ${widget.resourceId ?? '无'}
- 文本: ${widget.text ?? '无'}
- 描述: ${widget.contentDescription ?? '无'}
- 包名: ${widget.packageName ?? '无'}
- 可点击: ${widget.isClickable ? '是' : '否'}
- 可编辑: ${_isEditable() ? '是' : '否'}
- 位置: (${widget.bounds.left}, ${widget.bounds.top}) - (${widget.bounds.right}, ${widget.bounds.bottom})
    ''';
    
    Clipboard.setData(ClipboardData(text: info));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('控件信息已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  void _showSelectorDialog(BuildContext context) {
    final selectors = _generateSelectors();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('生成的选择器'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '为控件生成的可用选择器:',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ...selectors.map((selector) => ListTile(
                title: Text(selector.description),
                subtitle: Text(selector.code, style: const TextStyle(fontFamily: 'monospace')),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: selector.code));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('选择器代码已复制')),
                    );
                  },
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  
  void _exportAsJson(BuildContext context) {
    final json = jsonEncode(widget.toJson());
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON数据已复制到剪贴板')),
    );
  }
  
  List<_SelectorInfo> _generateSelectors() {
    final selectors = <_SelectorInfo>[];
    
    if (widget.resourceId?.isNotEmpty == true) {
      selectors.add(_SelectorInfo(
        '资源ID选择器',
        'WidgetSelector(byResourceId: "${widget.resourceId}")',
      ));
    }
    
    if (widget.text?.isNotEmpty == true) {
      selectors.add(_SelectorInfo(
        '文本选择器',
        'WidgetSelector(byText: "${widget.text}")',
      ));
    }
    
    if (widget.contentDescription?.isNotEmpty == true) {
      selectors.add(_SelectorInfo(
        '描述选择器',
        'WidgetSelector(byContentDescription: "${widget.contentDescription}")',
      ));
    }
    
    if (widget.className?.isNotEmpty == true) {
      selectors.add(_SelectorInfo(
        '类名选择器',
        'WidgetSelector(byClassName: "${widget.className}")',
      ));
    }
    
    // 组合选择器
    if (widget.resourceId?.isNotEmpty == true && widget.text?.isNotEmpty == true) {
      selectors.add(_SelectorInfo(
        '组合选择器 (ID + 文本)',
        'WidgetSelector(byResourceId: "${widget.resourceId}", byText: "${widget.text}")',
      ));
    }
    
    return selectors;
  }
}

class _InfoItem {
  final String label;
  final String value;
  final IconData icon;
  
  const _InfoItem(this.label, this.value, {required this.icon});
}

class _SelectorInfo {
  final String description;
  final String code;
  
  const _SelectorInfo(this.description, this.code);
}
