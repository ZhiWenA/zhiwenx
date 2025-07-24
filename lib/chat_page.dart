import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'chat_models.dart';
import 'openai_service.dart';
import 'openai_config.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isConnected = false;
  StreamSubscription<String>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _addSystemMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _checkConnection() async {
    setState(() {
      _isConnected = OpenAIConfig.isConfigured;
    });
    
    if (_isConnected) {
      final connected = await OpenAIService.testConnection();
      setState(() {
        _isConnected = connected;
      });
    }
  }

  void _addSystemMessage() {
    _messages.add(ChatMessage.system('你是一个有用的AI助手，请用中文回答问题。'));
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // 添加用户消息
    final userMessage = ChatMessage.user(text);
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // 添加一个空的助手消息，用于流式更新
    final assistantMessage = ChatMessage.assistant('');
    setState(() {
      _messages.add(assistantMessage);
    });

    try {
      // 取消之前的流订阅
      await _streamSubscription?.cancel();
      
      final stream = OpenAIService.sendStreamChatRequest(_messages.sublist(0, _messages.length - 1));
      String fullContent = '';
      
      _streamSubscription = stream.listen(
        (chunk) {
          fullContent += chunk;
          setState(() {
            // 更新最后一条消息的内容
            _messages[_messages.length - 1] = ChatMessage.assistant(fullContent);
          });
          _scrollToBottom();
        },
        onError: (error) {
          _showErrorSnackBar('发送失败: ${error.toString()}');
          // 移除空的助手消息
          setState(() {
            _messages.removeLast();
            _isLoading = false;
          });
        },
        onDone: () {
          setState(() {
            _isLoading = false;
          });
          _scrollToBottom();
        },
      );
    } catch (e) {
      _showErrorSnackBar('发送失败: ${e.toString()}');
      // 移除空的助手消息
      setState(() {
        _messages.removeLast();
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _stopGeneration() {
    _streamSubscription?.cancel();
    setState(() {
      _isLoading = false;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _addSystemMessage();
    });
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API 配置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API Key: ${OpenAIConfig.apiKey.isNotEmpty ? '已配置' : '未配置'}'),
            const SizedBox(height: 8),
            Text('Base URL: ${OpenAIConfig.baseUrl}'),
            const SizedBox(height: 8),
            Text('Model: ${OpenAIConfig.model}'),
            const SizedBox(height: 16),
            const Text(
              '请在项目根目录创建 .env 文件并配置以下内容：\n\n'
              'OPENAI_API_KEY=your_api_key\n'
              'OPENAI_BASE_URL=https://api.openai.com\n'
              'OPENAI_MODEL=gpt-3.5-turbo',
              style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _checkConnection();
            },
            child: const Text('重新检测'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isUser = message.role == 'user';
    final isSystem = message.role == 'system';
    
    if (isSystem) return const SizedBox.shrink(); // 不显示系统消息

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              child: Icon(
                Icons.smart_toy,
                size: 16,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUser ? Colors.blue.shade500 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isUser ? Colors.white : Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green.shade100,
              child: Icon(
                Icons.person,
                size: 16,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 对话'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showSettingsDialog,
            icon: Icon(
              Icons.settings,
              color: _isConnected ? Colors.white : Colors.red.shade200,
            ),
          ),
          IconButton(
            onPressed: _clearChat,
            icon: const Icon(Icons.clear_all),
          ),
          if (_isLoading)
            IconButton(
              onPressed: _stopGeneration,
              icon: const Icon(Icons.stop),
              tooltip: '停止生成',
            ),
        ],
      ),
      body: Column(
        children: [
          // 连接状态指示器
          if (!_isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'API 未配置或连接失败，请点击设置按钮查看配置说明',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          
          // 聊天消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index], index);
              },
            ),
          ),
          
          // 加载指示器
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('AI 正在生成回复...'),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _stopGeneration,
                    child: const Text('停止'),
                  ),
                ],
              ),
            ),
          
          // 输入区域
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
