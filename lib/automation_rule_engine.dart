import 'dart:convert';
import 'dart:developer';
import 'package:flutter/services.dart';

/// 自动化规则引擎 - 支持JSON配置的控件识别和操作
class AutomationRuleEngine {
  static const MethodChannel _channel = MethodChannel('com.tianli.zhiwenx/automation_engine');
  
  /// 执行自动化规则
  static Future<bool> executeRule(AutomationRule rule) async {
    try {
      log('执行自动化规则: ${rule.name}');
      final result = await _channel.invokeMethod('executeRule', {'rule': rule.toJson()});
      return result == true;
    } catch (e) {
      log('执行规则失败: $e');
      return false;
    }
  }

  /// 验证规则是否可执行
  static Future<bool> validateRule(AutomationRule rule) async {
    try {
      final result = await _channel.invokeMethod('validateRule', {'rule': rule.toJson()});
      return result == true;
    } catch (e) {
      log('验证规则失败: $e');
      return false;
    }
  }

  /// 获取当前屏幕的控件信息
  static Future<List<WidgetInfo>> getScreenWidgets() async {
    try {
      final result = await _channel.invokeMethod('getScreenWidgets');
      final List<dynamic> widgets = result ?? [];
      return widgets.map((w) => WidgetInfo.fromJson(w)).toList();
    } catch (e) {
      log('获取控件信息失败: $e');
      return [];
    }
  }

  /// 查找控件
  static Future<WidgetInfo?> findWidget(WidgetSelector selector) async {
    try {
      final result = await _channel.invokeMethod('findWidget', {'selector': selector.toJson()});
      return result != null ? WidgetInfo.fromJson(result) : null;
    } catch (e) {
      log('查找控件失败: $e');
      return null;
    }
  }

  /// 创建预设规则 - 小红书搜索示例
  static AutomationRule createXiaohongshuSearchRule(String keyword) {
    return AutomationRule(
      name: '小红书搜索',
      description: '打开小红书并搜索关键词',
      steps: [
        AutomationStep(
          type: StepType.launchApp,
          description: '启动小红书',
          appPackage: 'com.xingin.xhs', // 小红书包名
          timeout: 5000,
        ),
        AutomationStep(
          type: StepType.waitForElement,
          description: '等待搜索图标出现',
          selector: WidgetSelector(
            byResourceId: 'com.xingin.xhs:id/search_icon',
            byContentDescription: '搜索',
            byText: null,
          ),
          timeout: 10000,
        ),
        AutomationStep(
          type: StepType.click,
          description: '点击搜索图标',
          selector: WidgetSelector(
            byResourceId: 'com.xingin.xhs:id/search_icon',
            byContentDescription: '搜索',
          ),
          timeout: 3000,
        ),
        AutomationStep(
          type: StepType.waitForElement,
          description: '等待搜索框出现',
          selector: WidgetSelector(
            byResourceId: 'com.xingin.xhs:id/search_edit',
            byClassName: 'android.widget.EditText',
          ),
          timeout: 5000,
        ),
        AutomationStep(
          type: StepType.input,
          description: '输入搜索关键词',
          selector: WidgetSelector(
            byResourceId: 'com.xingin.xhs:id/search_edit',
            byClassName: 'android.widget.EditText',
          ),
          inputText: keyword,
          timeout: 3000,
        ),
        AutomationStep(
          type: StepType.keyEvent,
          description: '按回车键执行搜索',
          keyCode: 66, // KEYCODE_ENTER
          timeout: 1000,
        ),
        AutomationStep(
          type: StepType.waitForElement,
          description: '等待搜索结果',
          selector: WidgetSelector(
            byResourceId: 'com.xingin.xhs:id/recycler_view',
            byClassName: 'androidx.recyclerview.widget.RecyclerView',
          ),
          timeout: 10000,
        ),
      ],
    );
  }

  /// 创建通用应用搜索规则
  static AutomationRule createGenericSearchRule({
    required String appName,
    required String appPackage,
    required String keyword,
    required List<WidgetSelector> searchIconSelectors,
    required List<WidgetSelector> searchBoxSelectors,
  }) {
    return AutomationRule(
      name: '$appName搜索',
      description: '打开$appName并搜索关键词',
      steps: [
        AutomationStep(
          type: StepType.launchApp,
          description: '启动$appName',
          appPackage: appPackage,
          timeout: 5000,
        ),
        ...searchIconSelectors.map((selector) => AutomationStep(
          type: StepType.waitForElement,
          description: '等待搜索入口',
          selector: selector,
          timeout: 8000,
        )).take(1),
        ...searchIconSelectors.map((selector) => AutomationStep(
          type: StepType.click,
          description: '点击搜索入口',
          selector: selector,
          timeout: 3000,
        )).take(1),
        ...searchBoxSelectors.map((selector) => AutomationStep(
          type: StepType.waitForElement,
          description: '等待搜索框',
          selector: selector,
          timeout: 5000,
        )).take(1),
        ...searchBoxSelectors.map((selector) => AutomationStep(
          type: StepType.input,
          description: '输入关键词',
          selector: selector,
          inputText: keyword,
          timeout: 3000,
        )).take(1),
        AutomationStep(
          type: StepType.keyEvent,
          description: '执行搜索',
          keyCode: 66, // KEYCODE_ENTER
          timeout: 1000,
        ),
      ],
    );
  }
}

/// 自动化规则
class AutomationRule {
  final String name;
  final String description;
  final List<AutomationStep> steps;
  final Map<String, dynamic>? metadata;

  AutomationRule({
    required this.name,
    required this.description,
    required this.steps,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'steps': steps.map((s) => s.toJson()).toList(),
    'metadata': metadata,
  };

  factory AutomationRule.fromJson(Map<String, dynamic> json) => AutomationRule(
    name: json['name'],
    description: json['description'],
    steps: (json['steps'] as List).map((s) => AutomationStep.fromJson(s)).toList(),
    metadata: json['metadata'],
  );

  /// 从JSON字符串创建规则
  factory AutomationRule.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return AutomationRule.fromJson(json);
  }

  /// 转换为JSON字符串
  String toJsonString() => jsonEncode(toJson());
}

/// 自动化步骤
class AutomationStep {
  final StepType type;
  final String description;
  final WidgetSelector? selector;
  final String? inputText;
  final String? appPackage;
  final int? keyCode;
  final int timeout;
  final Map<String, dynamic>? metadata;

  AutomationStep({
    required this.type,
    required this.description,
    this.selector,
    this.inputText,
    this.appPackage,
    this.keyCode,
    this.timeout = 5000,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'description': description,
    'selector': selector?.toJson(),
    'inputText': inputText,
    'appPackage': appPackage,
    'keyCode': keyCode,
    'timeout': timeout,
    'metadata': metadata,
  };

  factory AutomationStep.fromJson(Map<String, dynamic> json) => AutomationStep(
    type: StepType.values.firstWhere((e) => e.name == json['type']),
    description: json['description'],
    selector: json['selector'] != null ? WidgetSelector.fromJson(json['selector']) : null,
    inputText: json['inputText'],
    appPackage: json['appPackage'],
    keyCode: json['keyCode'],
    timeout: json['timeout'] ?? 5000,
    metadata: json['metadata'],
  );
}

/// 步骤类型
enum StepType {
  launchApp,      // 启动应用
  click,          // 点击
  longClick,      // 长按
  input,          // 输入文本
  scroll,         // 滚动
  swipe,          // 滑动
  keyEvent,       // 按键事件
  waitForElement, // 等待元素出现
  sleep,          // 等待时间
  checkElement,   // 检查元素
  condition,      // 条件判断
}

/// 控件选择器
class WidgetSelector {
  final String? byResourceId;
  final String? byText;
  final String? byContentDescription;
  final String? byClassName;
  final String? byPackageName;
  final bool? isClickable;
  final bool? isEnabled;
  final bool? isSelected;
  final bool? isCheckable;
  final bool? isChecked;
  final bool? isFocusable;
  final bool? isFocused;
  final bool? isScrollable;
  final bool? isLongClickable;
  final bool? isPassword;
  final int? index; // 在父容器中的索引
  final String? xpath; // XPath表达式（未来扩展）

  WidgetSelector({
    this.byResourceId,
    this.byText,
    this.byContentDescription,
    this.byClassName,
    this.byPackageName,
    this.isClickable,
    this.isEnabled,
    this.isSelected,
    this.isCheckable,
    this.isChecked,
    this.isFocusable,
    this.isFocused,
    this.isScrollable,
    this.isLongClickable,
    this.isPassword,
    this.index,
    this.xpath,
  });

  Map<String, dynamic> toJson() => {
    'byResourceId': byResourceId,
    'byText': byText,
    'byContentDescription': byContentDescription,
    'byClassName': byClassName,
    'byPackageName': byPackageName,
    'isClickable': isClickable,
    'isEnabled': isEnabled,
    'isSelected': isSelected,
    'isCheckable': isCheckable,
    'isChecked': isChecked,
    'isFocusable': isFocusable,
    'isFocused': isFocused,
    'isScrollable': isScrollable,
    'isLongClickable': isLongClickable,
    'isPassword': isPassword,
    'index': index,
    'xpath': xpath,
  };

  factory WidgetSelector.fromJson(Map<String, dynamic> json) => WidgetSelector(
    byResourceId: json['byResourceId'],
    byText: json['byText'],
    byContentDescription: json['byContentDescription'],
    byClassName: json['byClassName'],
    byPackageName: json['byPackageName'],
    isClickable: json['isClickable'],
    isEnabled: json['isEnabled'],
    isSelected: json['isSelected'],
    isCheckable: json['isCheckable'],
    isChecked: json['isChecked'],
    isFocusable: json['isFocusable'],
    isFocused: json['isFocused'],
    isScrollable: json['isScrollable'],
    isLongClickable: json['isLongClickable'],
    isPassword: json['isPassword'],
    index: json['index'],
    xpath: json['xpath'],
  );
}

/// 控件信息
class WidgetInfo {
  final String? className;
  final String? text;
  final String? contentDescription;
  final String? resourceId;
  final String? packageName;
  final bool isClickable;
  final bool isEnabled;
  final bool isSelected;
  final bool isCheckable;
  final bool isChecked;
  final bool isFocusable;
  final bool isFocused;
  final bool isScrollable;
  final bool isLongClickable;
  final bool isPassword;
  final WidgetBounds bounds;
  final List<WidgetInfo> children;

  WidgetInfo({
    this.className,
    this.text,
    this.contentDescription,
    this.resourceId,
    this.packageName,
    this.isClickable = false,
    this.isEnabled = true,
    this.isSelected = false,
    this.isCheckable = false,
    this.isChecked = false,
    this.isFocusable = false,
    this.isFocused = false,
    this.isScrollable = false,
    this.isLongClickable = false,
    this.isPassword = false,
    required this.bounds,
    this.children = const [],
  });

  Map<String, dynamic> toJson() => {
    'className': className,
    'text': text,
    'contentDescription': contentDescription,
    'resourceId': resourceId,
    'packageName': packageName,
    'isClickable': isClickable,
    'isEnabled': isEnabled,
    'isSelected': isSelected,
    'isCheckable': isCheckable,
    'isChecked': isChecked,
    'isFocusable': isFocusable,
    'isFocused': isFocused,
    'isScrollable': isScrollable,
    'isLongClickable': isLongClickable,
    'isPassword': isPassword,
    'bounds': bounds.toJson(),
    'children': children.map((c) => c.toJson()).toList(),
  };

  factory WidgetInfo.fromJson(Map<String, dynamic> json) => WidgetInfo(
    className: json['className'],
    text: json['text'],
    contentDescription: json['contentDescription'],
    resourceId: json['resourceId'],
    packageName: json['packageName'],
    isClickable: json['isClickable'] ?? false,
    isEnabled: json['isEnabled'] ?? true,
    isSelected: json['isSelected'] ?? false,
    isCheckable: json['isCheckable'] ?? false,
    isChecked: json['isChecked'] ?? false,
    isFocusable: json['isFocusable'] ?? false,
    isFocused: json['isFocused'] ?? false,
    isScrollable: json['isScrollable'] ?? false,
    isLongClickable: json['isLongClickable'] ?? false,
    isPassword: json['isPassword'] ?? false,
    bounds: WidgetBounds.fromJson(json['bounds']),
    children: (json['children'] as List?)?.map((c) => WidgetInfo.fromJson(c)).toList() ?? [],
  );
}

/// 控件边界
class WidgetBounds {
  final int left;
  final int top;
  final int right;
  final int bottom;

  WidgetBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  int get width => right - left;
  int get height => bottom - top;
  int get centerX => left + width ~/ 2;
  int get centerY => top + height ~/ 2;

  Map<String, dynamic> toJson() => {
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };

  factory WidgetBounds.fromJson(Map<String, dynamic> json) => WidgetBounds(
    left: json['left'],
    top: json['top'],
    right: json['right'],
    bottom: json['bottom'],
  );
}
