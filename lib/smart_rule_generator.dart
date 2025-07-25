import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'automation_rule_engine.dart';

/// 智能规则生成器
class SmartRuleGenerator extends StatefulWidget {
  final WidgetInfo? selectedWidget;
  final Function(AutomationRule)? onRuleCreated;

  const SmartRuleGenerator({
    super.key,
    this.selectedWidget,
    this.onRuleCreated,
  });

  @override
  State<SmartRuleGenerator> createState() => _SmartRuleGeneratorState();
}

class _SmartRuleGeneratorState extends State<SmartRuleGenerator> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _appNameController = TextEditingController();
  final _packageController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  RuleType _ruleType = RuleType.search;
  List<AutomationStep> _steps = [];
  String _keyword = '';
  
  @override
  void initState() {
    super.initState();
    if (widget.selectedWidget != null) {
      _initializeFromWidget();
    } else {
      _initializeEmpty();
    }
  }

  void _initializeFromWidget() {
    final widget = this.widget.selectedWidget!;
    _packageController.text = widget.packageName ?? '';
    _appNameController.text = widget.packageName?.split('.').last ?? '';
    
    if (widget.isClickable) {
      _ruleType = RuleType.click;
      _nameController.text = '点击${_getWidgetDisplayName(widget)}';
      _descriptionController.text = '自动点击${_getWidgetDisplayName(widget)}控件';
    } else if (_isEditableWidget(widget)) {
      _ruleType = RuleType.input;
      _nameController.text = '输入到${_getWidgetDisplayName(widget)}';
      _descriptionController.text = '自动在${_getWidgetDisplayName(widget)}输入框中输入文本';
    } else {
      _ruleType = RuleType.search;
      _nameController.text = '搜索${_getWidgetDisplayName(widget)}';
      _descriptionController.text = '自动搜索相关内容';
    }
    
    _generateStepsFromWidget(widget);
  }

  void _initializeEmpty() {
    _nameController.text = '新建自动化规则';
    _descriptionController.text = '描述你的自动化规则';
    _generateDefaultSteps();
  }

  String _getWidgetDisplayName(WidgetInfo widget) {
    if (widget.text?.isNotEmpty == true) return widget.text!;
    if (widget.contentDescription?.isNotEmpty == true) return widget.contentDescription!;
    if (widget.resourceId?.isNotEmpty == true) {
      final parts = widget.resourceId!.split('/');
      return parts.isNotEmpty ? parts.last : widget.resourceId!;
    }
    return '控件';
  }

  bool _isEditableWidget(WidgetInfo widget) {
    return widget.className?.contains('EditText') == true ||
           widget.className?.contains('TextField') == true;
  }

  void _generateStepsFromWidget(WidgetInfo widget) {
    _steps.clear();
    
    // 添加启动应用步骤
    if (widget.packageName?.isNotEmpty == true) {
      _steps.add(AutomationStep(
        type: StepType.launchApp,
        description: '启动${_appNameController.text}',
        appPackage: widget.packageName!,
        timeout: 5000,
      ));
    }
    
    // 根据控件类型添加相应步骤
    if (widget.isClickable) {
      _steps.add(AutomationStep(
        type: StepType.waitForElement,
        description: '等待${_getWidgetDisplayName(widget)}出现',
        selector: _createBestSelector(widget),
        timeout: 10000,
      ));
      
      _steps.add(AutomationStep(
        type: StepType.click,
        description: '点击${_getWidgetDisplayName(widget)}',
        selector: _createBestSelector(widget),
        timeout: 3000,
      ));
    } else if (_isEditableWidget(widget)) {
      _steps.add(AutomationStep(
        type: StepType.waitForElement,
        description: '等待输入框出现',
        selector: _createBestSelector(widget),
        timeout: 10000,
      ));
      
      _steps.add(AutomationStep(
        type: StepType.input,
        description: '输入文本',
        selector: _createBestSelector(widget),
        inputText: _keyword,
        timeout: 3000,
      ));
    }
  }

  void _generateDefaultSteps() {
    _steps = [
      AutomationStep(
        type: StepType.launchApp,
        description: '启动应用',
        appPackage: _packageController.text,
        timeout: 5000,
      ),
    ];
  }

  WidgetSelector _createBestSelector(WidgetInfo widget) {
    // 优先使用资源ID
    if (widget.resourceId?.isNotEmpty == true) {
      return WidgetSelector(byResourceId: widget.resourceId);
    }
    
    // 其次使用文本
    if (widget.text?.isNotEmpty == true) {
      return WidgetSelector(byText: widget.text);
    }
    
    // 再使用内容描述
    if (widget.contentDescription?.isNotEmpty == true) {
      return WidgetSelector(byContentDescription: widget.contentDescription);
    }
    
    // 最后使用类名
    return WidgetSelector(byClassName: widget.className);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能规则生成器'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _generateRule,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('生成规则'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 基本信息
            _buildSection(
              title: '基本信息',
              icon: Icons.info_outline,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '规则名称',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  validator: (value) => value?.isEmpty == true ? '请输入规则名称' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '规则描述',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            
            // 应用信息
            _buildSection(
              title: '目标应用',
              icon: Icons.apps,
              children: [
                TextFormField(
                  controller: _appNameController,
                  decoration: const InputDecoration(
                    labelText: '应用名称',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.app_registration),
                    hintText: '例如：抖音',
                  ),
                  validator: (value) => value?.isEmpty == true ? '请输入应用名称' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _packageController,
                  decoration: const InputDecoration(
                    labelText: '应用包名',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.code),
                    hintText: '例如：com.ss.android.ugc.aweme',
                  ),
                  validator: (value) => value?.isEmpty == true ? '请输入应用包名' : null,
                ),
              ],
            ),
            
            // 规则类型
            _buildSection(
              title: '规则类型',
              icon: Icons.category,
              children: [
                DropdownButtonFormField<RuleType>(
                  value: _ruleType,
                  decoration: const InputDecoration(
                    labelText: '选择规则类型',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.rule),
                  ),
                  items: RuleType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(_getRuleTypeIcon(type)),
                        const SizedBox(width: 8),
                        Text(_getRuleTypeName(type)),
                      ],
                    ),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      _ruleType = value ?? RuleType.search;
                      _updateStepsForType();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _getRuleTypeDescription(_ruleType),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            
            // 额外参数
            if (_ruleType == RuleType.search || _ruleType == RuleType.input)
              _buildSection(
                title: '输入内容',
                icon: Icons.keyboard,
                children: [
                  TextFormField(
                    onChanged: (value) => _keyword = value,
                    decoration: InputDecoration(
                      labelText: _ruleType == RuleType.search ? '搜索关键词' : '输入文本',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.text_fields),
                      hintText: _ruleType == RuleType.search ? '例如：AdventureX' : '要输入的文本',
                    ),
                  ),
                ],
              ),
            
            // 执行步骤预览
            _buildSection(
              title: '执行步骤预览',
              icon: Icons.list,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: _steps.asMap().entries.map((entry) {
                      final index = entry.key;
                      final step = entry.value;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.deepPurple,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(step.description),
                        subtitle: Text(
                          '类型: ${step.type.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editStep(index),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addStep,
                        icon: const Icon(Icons.add),
                        label: const Text('添加步骤'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testRule,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('测试规则'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  void _updateStepsForType() {
    if (widget.selectedWidget != null) {
      _generateStepsFromWidget(widget.selectedWidget!);
    } else {
      _generateDefaultSteps();
      
      // 根据类型添加相应步骤
      if (_ruleType == RuleType.search) {
        _steps.addAll([
          AutomationStep(
            type: StepType.waitForElement,
            description: '等待搜索图标出现',
            selector: WidgetSelector(byContentDescription: '搜索'),
            timeout: 10000,
          ),
          AutomationStep(
            type: StepType.click,
            description: '点击搜索图标',
            selector: WidgetSelector(byContentDescription: '搜索'),
            timeout: 3000,
          ),
          AutomationStep(
            type: StepType.waitForElement,
            description: '等待搜索框出现',
            selector: WidgetSelector(byClassName: 'android.widget.EditText'),
            timeout: 5000,
          ),
          AutomationStep(
            type: StepType.input,
            description: '输入搜索关键词',
            selector: WidgetSelector(byClassName: 'android.widget.EditText'),
            inputText: _keyword,
            timeout: 3000,
          ),
        ]);
      } else if (_ruleType == RuleType.click) {
        _steps.add(AutomationStep(
          type: StepType.click,
          description: '点击指定控件',
          selector: WidgetSelector(byContentDescription: ''),
          timeout: 3000,
        ));
      } else if (_ruleType == RuleType.input) {
        _steps.add(AutomationStep(
          type: StepType.input,
          description: '输入文本',
          selector: WidgetSelector(byClassName: 'android.widget.EditText'),
          inputText: _keyword,
          timeout: 3000,
        ));
      }
    }
    setState(() {});
  }

  IconData _getRuleTypeIcon(RuleType type) {
    switch (type) {
      case RuleType.search:
        return Icons.search;
      case RuleType.click:
        return Icons.touch_app;
      case RuleType.input:
        return Icons.keyboard;
      case RuleType.scroll:
        return Icons.swap_vert;
      case RuleType.custom:
        return Icons.settings;
    }
  }

  String _getRuleTypeName(RuleType type) {
    switch (type) {
      case RuleType.search:
        return '搜索规则';
      case RuleType.click:
        return '点击规则';
      case RuleType.input:
        return '输入规则';
      case RuleType.scroll:
        return '滚动规则';
      case RuleType.custom:
        return '自定义规则';
    }
  }

  String _getRuleTypeDescription(RuleType type) {
    switch (type) {
      case RuleType.search:
        return '自动在应用中搜索指定关键词';
      case RuleType.click:
        return '自动点击指定的控件';
      case RuleType.input:
        return '在指定输入框中输入文本';
      case RuleType.scroll:
        return '自动滚动页面';
      case RuleType.custom:
        return '自定义复杂的自动化流程';
    }
  }

  void _addStep() {
    // 实现添加步骤的逻辑
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('添加步骤'),
        content: Text('步骤编辑功能开发中...'),
      ),
    );
  }

  void _editStep(int index) {
    // 实现编辑步骤的逻辑
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑步骤 ${index + 1}'),
        content: const Text('步骤编辑功能开发中...'),
      ),
    );
  }

  void _testRule() {
    if (!_formKey.currentState!.validate()) return;
    
    // 实现测试规则的逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('规则测试功能开发中...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _generateRule() {
    if (!_formKey.currentState!.validate()) return;
    
    final rule = AutomationRule(
      name: _nameController.text,
      description: _descriptionController.text,
      steps: _steps,
    );
    
    if (widget.onRuleCreated != null) {
      widget.onRuleCreated!(rule);
    }
    
    // 复制到剪贴板
    Clipboard.setData(ClipboardData(text: rule.toJsonString()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('规则已生成并复制到剪贴板'),
        backgroundColor: Colors.green,
      ),
    );
    
    Navigator.of(context).pop(rule);
  }
}

enum RuleType {
  search,
  click,
  input,
  scroll,
  custom,
}
