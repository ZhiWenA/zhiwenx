import 'package:flutter/material.dart';
import '../automation_rule_engine.dart';

class AutomationTestPage extends StatefulWidget {
  const AutomationTestPage({super.key});

  @override
  State<AutomationTestPage> createState() => _AutomationTestPageState();
}

class _AutomationTestPageState extends State<AutomationTestPage> {
  String _testResult = '准备测试自动化功能...';
  bool _isTesting = false;

  Future<void> _testBasicFunctions() async {
    setState(() {
      _isTesting = true;
      _testResult = '开始测试基础功能...';
    });

    try {
      // 测试1: 获取屏幕控件
      setState(() {
        _testResult = '测试1: 获取屏幕控件信息...';
      });
      
      final widgets = await AutomationRuleEngine.getScreenWidgets();
      setState(() {
        _testResult = '测试1 完成: 获取到 ${widgets.length} 个控件';
      });
      
      await Future.delayed(const Duration(seconds: 2));
      
      // 测试2: 查找特定控件
      setState(() {
        _testResult = '测试2: 查找特定控件...';
      });
      
      final widget = await AutomationRuleEngine.findWidget(
        WidgetSelector(byText: '自动化规则')
      );
      
      setState(() {
        _testResult = '测试2 完成: ${widget != null ? '找到控件' : '未找到控件'}';
      });
      
      await Future.delayed(const Duration(seconds: 2));
      
      // 测试3: 验证规则
      setState(() {
        _testResult = '测试3: 验证规则有效性...';
      });
      
      final testRule = AutomationRule(
        name: '测试规则',
        description: '测试规则描述',
        steps: [
          AutomationStep(
            type: StepType.sleep,
            description: '等待1秒',
            timeout: 1000,
          ),
        ],
      );
      
      final isValid = await AutomationRuleEngine.validateRule(testRule);
      setState(() {
        _testResult = '测试3 完成: 规则${isValid ? '有效' : '无效'}';
      });
      
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _testResult = '所有测试完成！\n\n测试结果:\n✓ 控件获取: ${widgets.length} 个\n✓ 控件查找: ${widget != null ? '成功' : '失败'}\n✓ 规则验证: ${isValid ? '成功' : '失败'}';
      });
      
    } catch (e) {
      setState(() {
        _testResult = '测试出错: $e';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  Future<void> _testSimpleRule() async {
    setState(() {
      _isTesting = true;
      _testResult = '测试简单自动化规则...';
    });

    try {
      // 创建一个简单的规则：等待2秒
      final simpleRule = AutomationRule(
        name: '简单测试规则',
        description: '等待2秒钟的简单测试',
        steps: [
          AutomationStep(
            type: StepType.sleep,
            description: '等待2秒',
            timeout: 2000,
          ),
        ],
      );
      
      setState(() {
        _testResult = '开始执行简单规则: ${simpleRule.name}';
      });
      
      final success = await AutomationRuleEngine.executeRule(simpleRule);
      
      setState(() {
        _testResult = '简单规则执行${success ? '成功' : '失败'}！';
      });
      
    } catch (e) {
      setState(() {
        _testResult = '简单规则执行出错: $e';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自动化功能测试'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '测试自动化规则引擎功能',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 20),
            
            const Text(
              '请确保已开启无障碍服务权限',
              style: TextStyle(
                fontSize: 16,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),
            
            // 测试按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTesting ? null : _testBasicFunctions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('测试基础功能'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTesting ? null : _testSimpleRule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('测试简单规则'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 30),
            
            // 结果显示区域
            Container(
              width: double.infinity,
              height: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.terminal,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '测试结果',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_isTesting)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        _testResult,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 说明文字
            const Text(
              '说明：',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• 基础功能测试：检查控件获取、查找和规则验证功能\n'
              '• 简单规则测试：执行一个基本的等待规则\n'
              '• 如果测试失败，请检查无障碍服务是否已启用',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
