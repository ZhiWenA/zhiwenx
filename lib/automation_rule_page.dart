import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'automation_rule_engine.dart';
import 'automation_test_page.dart';
import 'utils/accessibility_permission_manager.dart';
import 'widget_capture_page.dart';

class AutomationRulePage extends StatefulWidget {
  const AutomationRulePage({super.key});

  @override
  State<AutomationRulePage> createState() => _AutomationRulePageState();
}

class _AutomationRulePageState extends State<AutomationRulePage> {
  List<AutomationRule> _rules = [];
  bool _isLoading = false;
  String _statusMessage = '准备就绪';

  @override
  void initState() {
    super.initState();
    _loadPresetRules();
  }

  void _loadPresetRules() {
    setState(() {
      _rules = [
        // 小红书搜索示例
        AutomationRuleEngine.createXiaohongshuSearchRule('AdventureX'),
        
        // 抖音搜索示例
        AutomationRuleEngine.createGenericSearchRule(
          appName: '抖音',
          appPackage: 'com.ss.android.ugc.aweme',
          keyword: 'AdventureX',
          searchIconSelectors: [
            WidgetSelector(byResourceId: 'com.ss.android.ugc.aweme:id/search_icon'),
            WidgetSelector(byContentDescription: '搜索'),
            WidgetSelector(byText: '搜索'),
          ],
          searchBoxSelectors: [
            WidgetSelector(byResourceId: 'com.ss.android.ugc.aweme:id/search_edit'),
            WidgetSelector(byClassName: 'android.widget.EditText'),
          ],
        ),
        
        // 微博搜索示例
        AutomationRuleEngine.createGenericSearchRule(
          appName: '微博',
          appPackage: 'com.sina.weibo',
          keyword: 'AdventureX',
          searchIconSelectors: [
            WidgetSelector(byResourceId: 'com.sina.weibo:id/search_icon'),
            WidgetSelector(byContentDescription: '搜索'),
          ],
          searchBoxSelectors: [
            WidgetSelector(byResourceId: 'com.sina.weibo:id/search_edit'),
            WidgetSelector(byClassName: 'android.widget.EditText'),
          ],
        ),
        
        // 淘宝搜索示例
        AutomationRuleEngine.createGenericSearchRule(
          appName: '淘宝',
          appPackage: 'com.taobao.taobao',
          keyword: 'AdventureX',
          searchIconSelectors: [
            WidgetSelector(byResourceId: 'com.taobao.taobao:id/home_searchedit'),
            WidgetSelector(byText: '搜索'),
          ],
          searchBoxSelectors: [
            WidgetSelector(byResourceId: 'com.taobao.taobao:id/searchEdit'),
            WidgetSelector(byClassName: 'android.widget.EditText'),
          ],
        ),
      ];
    });
  }

  Future<void> _executeRule(AutomationRule rule) async {
    // 先检查无障碍权限
    final hasPermission = await AccessibilityPermissionManager.checkAndRequestPermission(
      context,
      feature: '自动化规则执行',
    );
    
    if (!hasPermission) {
      _showSnackBar('需要无障碍权限才能执行自动化规则', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '正在执行规则: ${rule.name}';
    });

    try {
      // 先验证规则
      bool isValid = await AutomationRuleEngine.validateRule(rule);
      if (!isValid) {
        _showSnackBar('规则验证失败，请检查应用是否已安装', Colors.orange);
        return;
      }

      // 执行规则
      bool success = await AutomationRuleEngine.executeRule(rule);
      if (success) {
        setState(() {
          _statusMessage = '规则执行成功: ${rule.name}';
        });
        _showSnackBar('规则执行成功', Colors.green);
      } else {
        setState(() {
          _statusMessage = '规则执行失败: ${rule.name}';
        });
        _showSnackBar('规则执行失败', Colors.red);
      }
    } catch (e) {
      setState(() {
        _statusMessage = '执行出错: $e';
      });
      _showSnackBar('执行出错: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showRuleDetails(AutomationRule rule) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(rule.name),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('描述: ${rule.description}'),
              const SizedBox(height: 16),
              const Text('执行步骤:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: rule.steps.length,
                  itemBuilder: (context, index) {
                    final step = rule.steps[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.deepPurple,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.description,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '类型: ${step.type.name}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
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
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: rule.toJsonString()));
              Navigator.of(context).pop();
              _showSnackBar('规则JSON已复制到剪贴板', Colors.blue);
            },
            child: const Text('复制JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _executeRule(rule);
            },
            child: const Text('执行'),
          ),
        ],
      ),
    );
  }

  Future<void> _createCustomRule() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController packageController = TextEditingController();
    final TextEditingController keywordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建自定义规则'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '应用名称',
                hintText: '例如：京东',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: packageController,
              decoration: const InputDecoration(
                labelText: '应用包名',
                hintText: '例如：com.jingdong.app.mall',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keywordController,
              decoration: const InputDecoration(
                labelText: '搜索关键词',
                hintText: '例如：AdventureX',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  packageController.text.isNotEmpty &&
                  keywordController.text.isNotEmpty) {
                final rule = AutomationRuleEngine.createGenericSearchRule(
                  appName: nameController.text,
                  appPackage: packageController.text,
                  keyword: keywordController.text,
                  searchIconSelectors: [
                    WidgetSelector(byContentDescription: '搜索'),
                    WidgetSelector(byText: '搜索'),
                    WidgetSelector(byClassName: 'android.widget.ImageView'),
                  ],
                  searchBoxSelectors: [
                    WidgetSelector(byClassName: 'android.widget.EditText'),
                    WidgetSelector(byContentDescription: '搜索框'),
                  ],
                );
                
                setState(() {
                  _rules.add(rule);
                });
                
                Navigator.of(context).pop();
                _showSnackBar('自定义规则已创建', Colors.green);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  Future<void> _importRuleFromJson() async {
    final TextEditingController jsonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入JSON规则'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: jsonController,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'JSON规则',
              hintText: '粘贴JSON格式的自动化规则',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final rule = AutomationRule.fromJsonString(jsonController.text);
                setState(() {
                  _rules.add(rule);
                });
                Navigator.of(context).pop();
                _showSnackBar('规则导入成功', Colors.green);
              } catch (e) {
                _showSnackBar('JSON格式错误: $e', Colors.red);
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('自动化规则'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AutomationTestPage()),
              );
            },
            icon: const Icon(Icons.bug_report),
            tooltip: '功能测试',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WidgetCapturePage()),
              );
            },
            icon: const Icon(Icons.widgets),
            tooltip: '实时控件抓取',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'create':
                  _createCustomRule();
                  break;
                case 'import':
                  _importRuleFromJson();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'create',
                child: Row(
                  children: [
                    Icon(Icons.add),
                    SizedBox(width: 8),
                    Text('创建规则'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload),
                    SizedBox(width: 8),
                    Text('导入JSON'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 状态栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (_isLoading) const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _isLoading ? Colors.blue : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '共 ${_rules.length} 条规则',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // 规则列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rules.length,
              itemBuilder: (context, index) {
                final rule = _rules[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _showRuleDetails(rule),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.smart_toy,
                                color: Colors.deepPurple,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  rule.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _isLoading ? null : () => _executeRule(rule),
                                icon: _isLoading 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.play_arrow),
                                tooltip: '执行规则',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            rule.description,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${rule.steps.length} 个步骤',
                                  style: TextStyle(
                                    color: Colors.deepPurple,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '点击查看详情',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
