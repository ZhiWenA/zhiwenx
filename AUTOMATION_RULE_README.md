# 自动化规则引擎使用指南

## 概述

自动化规则引擎是智问X项目的一个强大功能，它允许您通过JSON配置文件定义应用操作流程，实现跨应用的自动化操作。比如自动打开小红书搜索"AdventureX"关键词。

## 功能特性

- 🤖 **JSON配置驱动**: 通过简单的JSON配置定义复杂的操作流程
- 📱 **跨应用支持**: 支持启动和操作任意已安装的Android应用
- 🔍 **智能控件识别**: 基于多种属性（ID、文本、类名等）识别界面控件
- ⏱️ **超时处理**: 每个步骤都有超时保护，避免无限等待
- 📊 **实时反馈**: 提供执行进度和状态反馈
- 🛠️ **可视化调试**: 支持查看当前屏幕的所有控件信息

## 核心概念

### 1. 自动化规则 (AutomationRule)
一个完整的操作流程，包含：
- **name**: 规则名称
- **description**: 规则描述
- **steps**: 操作步骤列表
- **metadata**: 可选的元数据

### 2. 操作步骤 (AutomationStep)
单个操作动作，包含：
- **type**: 步骤类型（见下方步骤类型列表）
- **description**: 步骤描述
- **selector**: 控件选择器（某些步骤需要）
- **timeout**: 超时时间（毫秒）
- **其他参数**: 根据步骤类型的特定参数

### 3. 控件选择器 (WidgetSelector)
用于定位界面控件的条件组合：
- **byResourceId**: 根据资源ID查找
- **byText**: 根据文本内容查找
- **byContentDescription**: 根据内容描述查找
- **byClassName**: 根据类名查找
- **isClickable**: 是否可点击
- 更多属性...

## 支持的步骤类型

| 类型 | 描述 | 必需参数 | 可选参数 |
|------|------|----------|----------|
| `launchApp` | 启动应用 | `appPackage` | `timeout` |
| `click` | 点击控件 | `selector` | `timeout` |
| `longClick` | 长按控件 | `selector` | `timeout` |
| `input` | 输入文本 | `selector`, `inputText` | `timeout` |
| `scroll` | 滚动页面 | `selector` | `direction`, `timeout` |
| `swipe` | 滑动手势 | `startX`, `startY`, `endX`, `endY` | `duration`, `timeout` |
| `keyEvent` | 按键事件 | `keyCode` | `timeout` |
| `waitForElement` | 等待元素出现 | `selector` | `timeout` |
| `sleep` | 等待时间 | - | `timeout` |
| `checkElement` | 检查元素存在 | `selector` | `timeout` |

## 使用方法

### 1. 预设规则使用

应用内置了几个常用的预设规则：

```dart
// 小红书搜索示例
final rule = AutomationRuleEngine.createXiaohongshuSearchRule('AdventureX');
await AutomationRuleEngine.executeRule(rule);
```

### 2. 自定义规则创建

#### 方式一：使用代码创建

```dart
final customRule = AutomationRuleEngine.createGenericSearchRule(
  appName: '京东',
  appPackage: 'com.jingdong.app.mall',
  keyword: 'AdventureX',
  searchIconSelectors: [
    WidgetSelector(byResourceId: 'com.jd.lib.search.view:id/search_icon'),
    WidgetSelector(byContentDescription: '搜索'),
  ],
  searchBoxSelectors: [
    WidgetSelector(byClassName: 'android.widget.EditText'),
  ],
);
```

#### 方式二：JSON配置导入

```json
{
  "name": "京东搜索AdventureX",
  "description": "打开京东并搜索商品",
  "steps": [
    {
      "type": "launchApp",
      "description": "启动京东",
      "appPackage": "com.jingdong.app.mall",
      "timeout": 5000
    },
    {
      "type": "waitForElement",
      "description": "等待搜索框",
      "selector": {
        "byText": "搜索"
      },
      "timeout": 10000
    },
    {
      "type": "click",
      "description": "点击搜索框",
      "selector": {
        "byText": "搜索"
      },
      "timeout": 3000
    },
    {
      "type": "input",
      "description": "输入商品名",
      "inputText": "AdventureX",
      "timeout": 3000
    },
    {
      "type": "keyEvent",
      "description": "执行搜索",
      "keyCode": 66,
      "timeout": 1000
    }
  ]
}
```

### 3. 控件识别和调试

使用"查看当前屏幕控件"功能来获取界面元素信息：

```dart
// 获取屏幕控件信息
final widgets = await AutomationRuleEngine.getScreenWidgets();

// 查找特定控件
final widget = await AutomationRuleEngine.findWidget(
  WidgetSelector(byText: '搜索')
);
```

## 实际应用示例

### 示例1：小红书搜索流程

```json
{
  "name": "小红书搜索AdventureX",
  "description": "自动在小红书中搜索AdventureX内容",
  "steps": [
    {
      "type": "launchApp",
      "description": "启动小红书",
      "appPackage": "com.xingin.xhs",
      "timeout": 5000
    },
    {
      "type": "waitForElement",
      "description": "等待首页加载",
      "selector": {
        "byResourceId": "com.xingin.xhs:id/search_icon"
      },
      "timeout": 10000
    },
    {
      "type": "click",
      "description": "点击搜索图标",
      "selector": {
        "byResourceId": "com.xingin.xhs:id/search_icon"
      },
      "timeout": 3000
    },
    {
      "type": "waitForElement",
      "description": "等待搜索页面",
      "selector": {
        "byClassName": "android.widget.EditText"
      },
      "timeout": 5000
    },
    {
      "type": "input",
      "description": "输入搜索关键词",
      "inputText": "AdventureX",
      "timeout": 3000
    },
    {
      "type": "keyEvent",
      "description": "执行搜索",
      "keyCode": 66,
      "timeout": 1000
    }
  ]
}
```

### 示例2：通用电商搜索模板

这个模板可以适配大多数电商应用：

```json
{
  "name": "通用电商搜索",
  "description": "适用于大多数电商应用的搜索流程",
  "steps": [
    {
      "type": "launchApp",
      "description": "启动应用",
      "appPackage": "com.example.ecommerce",
      "timeout": 5000
    },
    {
      "type": "waitForElement",
      "description": "等待首页",
      "selector": {
        "byClassName": "android.view.ViewGroup"
      },
      "timeout": 8000
    },
    {
      "type": "click",
      "description": "点击搜索入口",
      "selector": {
        "byText": "搜索"
      },
      "timeout": 3000
    },
    {
      "type": "input",
      "description": "输入商品关键词",
      "inputText": "AdventureX",
      "timeout": 3000
    },
    {
      "type": "keyEvent",
      "description": "提交搜索",
      "keyCode": 66,
      "timeout": 1000
    }
  ]
}
```

## 最佳实践

### 1. 控件选择器优先级

推荐的选择器优先级（从高到低）：
1. `byResourceId` - 最稳定，应用更新时不易变化
2. `byContentDescription` - 较稳定，用户体验相关
3. `byText` - 可能因本地化改变
4. `byClassName` - 最不稳定，但通用性好

### 2. 超时时间设置

- 应用启动：5-10秒
- 页面等待：5-15秒
- 简单操作：1-3秒
- 网络请求：10-30秒

### 3. 错误处理

```json
{
  "type": "waitForElement",
  "description": "等待登录按钮（可能需要登录）",
  "selector": {
    "byText": "登录"
  },
  "timeout": 3000,
  "optional": true
}
```

### 4. 多选择器兜底

```json
{
  "type": "click",
  "description": "点击搜索（多种可能的选择器）",
  "selectors": [
    {
      "byResourceId": "com.app:id/search_button"
    },
    {
      "byContentDescription": "搜索"
    },
    {
      "byText": "搜索"
    }
  ],
  "timeout": 5000
}
```

## 调试技巧

### 1. 使用屏幕控件查看器

在自动化规则页面点击"眼睛"图标，可以查看当前屏幕的所有控件信息，包括：
- 控件类名
- 文本内容
- 资源ID
- 位置信息
- 各种属性

### 2. 分步执行调试

将复杂的规则拆分成多个小规则，逐步验证每个步骤。

### 3. 日志查看

Android日志中会输出详细的执行信息：
```bash
adb logcat | grep "SmartAccessibilityService"
```

### 4. 常见问题排查

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| 找不到控件 | 选择器不正确 | 使用控件查看器确认选择器 |
| 应用启动失败 | 包名错误或应用未安装 | 检查包名和应用安装状态 |
| 点击无效果 | 控件不可点击或被遮挡 | 检查控件状态或使用坐标点击 |
| 输入失败 | 输入框未聚焦 | 先点击输入框再输入 |

## 扩展开发

### 添加新的步骤类型

1. 在Dart端的`StepType`枚举中添加新类型
2. 在Android端的`executeAutomationSteps`方法中添加处理逻辑
3. 更新相关的数据模型

### 自定义控件选择器

可以扩展`WidgetSelector`类，添加更多的选择条件：
- XPath表达式支持
- 正则表达式匹配
- 位置范围选择
- 父子关系判断

## 注意事项

1. **权限要求**: 需要无障碍服务权限
2. **兼容性**: 不同Android版本和应用版本可能有差异
3. **性能影响**: 避免创建过于复杂的规则
4. **隐私保护**: 不要在规则中硬编码敏感信息
5. **应用更新**: 应用UI更新可能导致规则失效

## 常用应用包名参考

| 应用名称 | 包名 |
|---------|------|
| 小红书 | `com.xingin.xhs` |
| 抖音 | `com.ss.android.ugc.aweme` |
| 淘宝 | `com.taobao.taobao` |
| 京东 | `com.jingdong.app.mall` |
| 微博 | `com.sina.weibo` |
| 微信 | `com.tencent.mm` |
| QQ | `com.tencent.mobileqq` |
| 美团 | `com.sankuai.meituan` |
| 支付宝 | `com.eg.android.AlipayGphone` |

通过这个自动化规则引擎，您可以轻松实现复杂的跨应用操作流程，大大提高移动设备的使用效率。
