# 智问X - AI 对话功能说明

## 新增功能

本次更新新增了 AI 对话功能，支持与 OpenAI 格式兼容的大模型进行流式对话。

## 功能特点

1. **流式输出**: 支持实时流式显示 AI 回复，提供更好的用户体验
2. **中文编码修复**: 修复了中文字符乱码问题，确保正确显示中文内容
3. **可配置 API**: 支持自定义 API 端点、密钥和模型
4. **停止生成**: 可以随时停止 AI 生成过程
5. **消息复制**: 长按消息可复制到剪贴板
6. **连接状态**: 实时显示 API 连接状态

## 配置方法

1. 在项目根目录创建 `.env` 文件（或复制 `.env.example` 文件）
2. 配置以下环境变量：

```bash
# OpenAI API 配置
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_BASE_URL=https://api.openai.com
OPENAI_MODEL=gpt-3.5-turbo
```

### 配置说明

- `OPENAI_API_KEY`: 你的 OpenAI API 密钥
- `OPENAI_BASE_URL`: API 基础 URL（可选，默认为 OpenAI 官方地址）
- `OPENAI_MODEL`: 使用的模型（可选，默认为 gpt-3.5-turbo）

### 支持的第三方 API

由于使用标准的 OpenAI API 格式，本应用支持多种兼容的 API 服务：

- OpenAI 官方 API
- Azure OpenAI Service
- 各种 OpenAI 代理服务
- 本地部署的兼容 API（如 LocalAI、Ollama 等）

## 使用方法

1. 启动应用后，在主页点击"AI 对话"
2. 如果 API 未配置，会显示红色警告信息
3. 点击设置按钮查看配置说明
4. 配置完成后，即可开始与 AI 对话

## 主要组件

### 文件结构

```
lib/
├── chat_page.dart          # 对话页面主界面
├── chat_models.dart        # 消息数据模型
├── openai_config.dart      # API 配置管理
├── openai_service.dart     # API 请求服务
└── home_page.dart         # 主页导航
```

### 技术特点

- 使用 Dart Streams 实现流式输出
- UTF-8 编码确保中文正确显示
- 响应式 UI 设计
- 错误处理和重试机制

## 故障排除

### 中文乱码问题
- 确保请求头包含 `charset=utf-8`
- 使用 `utf8.decode(response.bodyBytes)` 解码响应

### 连接失败
- 检查 API Key 是否正确
- 验证 Base URL 是否可访问
- 确认网络连接正常

### 流式输出问题
- 确保 API 支持 Server-Sent Events (SSE)
- 检查 `stream: true` 参数是否正确设置

## 开发说明

如需修改或扩展功能，请注意：

1. 模型类在 `chat_models.dart` 中定义
2. API 配置在 `openai_config.dart` 中管理
3. 网络请求在 `openai_service.dart` 中处理
4. UI 组件在 `chat_page.dart` 中实现

欢迎提出建议和改进意见！
