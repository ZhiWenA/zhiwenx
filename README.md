# 声启 🎙️

> 专为不识字老人设计的"赛博盲杖"，一款通过AI让老人只需语言描述需求即可自动规划任务并执行的手机语音助手

## 🌟 项目简介

“声启“是一个智能语音助手，通过集成语音识别、AI决策和平台知识库技术，为用户提供智能化的应用推荐、启动和操作服务。本应用专门为不识字老人设计，**消除了文字障碍**，让老人也能享受数字便利，降低技术门槛，简单说话即可完成复杂操作。

## 🎯 核心功能

### 🎤 智能语音识别
- 基于腾讯云ASR的实时语音识别
- 支持识别方言
- 自定义ASR插件，提供本地语音处理能力

### 🧠 AI智能决策
- 通过LLM进行语义理解和决策
- 基于MCP (Model Context Protocol) 的智能决策算法
- 智能推荐算法，包含规则匹配、关键词匹配、内容类型匹配

### 📚 平台知识库
- 包含11个主流平台的详细信息
- 归类不同任务最合适的平台
- 智能推荐置信度评估

### 🚀 自动应用启动
- 支持一键启动和智能操作

## 🏪 支持的平台

### 📱 社交媒体
- **小红书**：美食攻略、旅游指南、购物分享、生活方式
- **抖音**：娱乐视频、音乐、舞蹈、搞笑内容
- **B站**：学习教程、科技资讯、游戏攻略、动漫

### 🛒 电商购物
- **淘宝**：日常购物、商品比价、优惠券
- **京东**：电子产品、品质商品、快速配送

### 🏠 生活服务
- **微信**：社交通讯、扫码支付、小程序
- **支付宝**：移动支付、生活缴费、金融服务

### 🗺️ 地图导航
- **高德地图**：实时导航、路况查询、POI搜索
- **百度地图**：地点搜索、路线规划、街景查看

### 🎵 音乐娱乐
- **QQ音乐**：流行音乐、歌单推荐、K歌
- **网易云音乐**：独立音乐、音乐社区、个性化推荐

## 💡 使用场景

- 📞 **文盲老人想要给亲人打视频电话**
- 🔍 **不识字老人想搜索观看某类内容**
- 🛍️ **老人想要购买生活用品**
- 🚗 **老人需要导航到某个地方**
- 🎶 **老人想要听音乐或娱乐**

## 🔧 技术栈

### 前端技术
- **Flutter 3.0+**：跨平台移动应用开发框架
- **Dart 2.17+**：编程语言

### 语音技术
- **腾讯云ASR**：实时语音识别服务
- **腾讯云TTS**：文本转语音合成
- **自定义ASR插件**：本地语音处理插件
- **自定义TTS插件**：本地语音合成插件

### AI技术
- **MCP (Model Context Protocol)**：模型上下文协议
- **智能决策算法**：多重评分机制的推荐系统
- **知识库系统**：本地化平台信息存储和检索

## 🚀 智能决策流程

```
用户语音输入 → ASR识别 → 知识库查询 → 平台推荐 → 增强AI提示 → 工具选择 → 应用启动
```

### 使用示例

1. **"我想看美食攻略"** → 推荐小红书（置信度：0.95）
2. **"搜索好玩的视频"** → 推荐抖音（置信度：0.90）
3. **"找一些学习资料"** → 推荐B站（置信度：0.85）
4. **"买个手机"** → 推荐京东（置信度：0.88）
5. **"导航到北京"** → 推荐高德地图（置信度：0.92）

## 📦 安装和使用

### 环境要求
- Flutter 3.0+
- Dart 2.17+
- iOS 12.0+ / Android 6.0+

### 安装步骤

1. **克隆项目**
```bash
git clone https://github.com/your-username/tingjiian.git
cd tingjiian
```

2. **安装依赖**
```bash
flutter pub get
```

3. **配置环境变量**
```bash
cp .env.example .env
# 编辑 .env 文件，添加您的API密钥
```

4. **运行应用**
```bash
flutter run
```

### 配置说明

在 `.env` 文件中配置以下参数：

```env
# 腾讯云配置
TENCENT_SECRET_ID=your_secret_id
TENCENT_SECRET_KEY=your_secret_key

# OpenAI配置
OPENAI_API_KEY=your_openai_api_key

# 百度AI配置
BAIDU_API_KEY=your_baidu_api_key
BAIDU_SECRET_KEY=your_baidu_secret_key
```

## 🏗️ 项目架构

### 核心模块

- **语音识别模块** (`voice_service.dart`)
- **AI决策模块** (`enhanced_openai_service.dart`)
- **平台知识库** (`services/platform_knowledge_service.dart`)
- **MCP服务** (`mcp_service.dart`)
- **自动化规则引擎** (`automation_rule_engine.dart`)

### 数据文件

- `platform_content_knowledge.json`：平台知识库配置
- `automation_rules_examples.json`：自动化规则示例

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 👥 开发者

### Shuaikx
📮 邮箱：shuaikx828@gmail.com

### Coin
📮 邮箱：coinshuka@163.com

### Tianli
📮 邮箱：wutianli@tianli0.top

## 🚀 更多项目

1. **洪墨AI** - 适用于CMS系统的一站式AI解决方案：[https://ai.zhheo.com/](https://ai.zhheo.com/)
2. **轻松AI写作** - 像cursor一样补全！：[https://zhikuu.com/](https://zhikuu.com/)

## 🙏 致谢

- 感谢腾讯云提供的语音识别和合成服务
- 感谢OpenAI提供的AI能力支持
- 感谢Flutter团队提供的优秀跨平台框架

## 📞 联系我们

- 问题反馈：[Issues](https://github.com/your-username/tingjiian/issues)
- 邮箱：coinshuka@163.com

---

**让科技更有温度，让老人不再被数字时代抛下。** 🌟

我们的愿景是帮助老人融入数字社会，享受科技带来的便利。
