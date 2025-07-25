import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'chat_models.dart';
import 'enhanced_openai_service_v2.dart';
import 'openai_config.dart';
import 'voice_service.dart';
import 'mcp_config_page.dart';

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
  
  // 语音功能相关
  final VoiceService _voiceService = VoiceService();
  StreamSubscription<String>? _speechResultSubscription;
  StreamSubscription<VoiceState>? _voiceStateSubscription;
  bool _isVoiceEnabled = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _autoPlayResponse = true; // 自动播放AI回复
  String _currentSpeechText = '';

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _addSystemMessage();
    _initializeVoice();
    _initializeEnhancedService();
  }

  // 初始化增强服务
  void _initializeEnhancedService() async {
    try {
      await EnhancedOpenAIService.initialize();
    } catch (e) {
      _showErrorSnackBar('MCP服务初始化失败: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _streamSubscription?.cancel();
    _speechResultSubscription?.cancel();
    _voiceStateSubscription?.cancel();
    _voiceService.dispose();
    super.dispose();
  }

  // 初始化语音功能
  void _initializeVoice() async {
    try {
      final success = await _voiceService.initialize();
      setState(() {
        _isVoiceEnabled = success;
      });
      
      if (success) {
        // 监听语音识别结果
        _speechResultSubscription = _voiceService.speechResultStream.listen((text) {
          setState(() {
            _currentSpeechText = text;
          });
        });
        
        // 监听语音状态变化
        _voiceStateSubscription = _voiceService.voiceStateStream.listen((state) {
          setState(() {
            _isListening = state == VoiceState.listening;
            _isSpeaking = state == VoiceState.speaking;
          });
          
          if (state == VoiceState.error) {
            _showErrorSnackBar('语音功能出现错误');
          }
        });
      }
    } catch (e) {
      _showErrorSnackBar('语音功能初始化失败: $e');
    }
  }

  // 开始语音输入
  void _startVoiceInput() async {
    if (!_isVoiceEnabled) {
      _showErrorSnackBar('语音功能未启用');
      return;
    }
    
    if (_isSpeaking) {
      await _voiceService.stopSpeaking();
    }
    
    setState(() {
      _currentSpeechText = '';
    });
    
    await _voiceService.startListening();
  }

  // 停止语音输入并发送消息
  void _stopVoiceInputAndSend() async {
    if (_isListening) {
      await _voiceService.stopListening();
      
      // 等待一小段时间确保语音识别完成
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_currentSpeechText.trim().isNotEmpty) {
        _messageController.text = _currentSpeechText;
        _sendMessage();
      }
    }
  }

  // 播放AI回复
  void _speakAIResponse(String text) async {
    if (_isVoiceEnabled && _autoPlayResponse && text.trim().isNotEmpty) {
      await _voiceService.speak(text);
    }
  }

  // 停止AI语音播放
  void _stopAISpeaking() async {
    if (_isSpeaking) {
      await _voiceService.stopSpeaking();
    }
  }

  void _checkConnection() async {
    setState(() {
      _isConnected = OpenAIConfig.isConfigured;
    });
    
    if (_isConnected) {
      final connected = await EnhancedOpenAIService.testConnection();
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

    // 停止任何正在进行的语音播放
    if (_isSpeaking) {
      await _voiceService.stopSpeaking();
    }

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
      
      // 使用增强的OpenAI服务
      final stream = EnhancedOpenAIService.sendStreamChatRequest(_messages.sublist(0, _messages.length - 1));
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
          
          // AI回复完成后，自动播放语音
          if (fullContent.trim().isNotEmpty) {
            _speakAIResponse(fullContent);
          }
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
        title: const Text('设置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // API 配置部分
              const Text('API 配置', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('API Key: ${OpenAIConfig.apiKey.isNotEmpty ? '已配置' : '未配置'}'),
              const SizedBox(height: 4),
              Text('Base URL: ${OpenAIConfig.baseUrl}'),
              const SizedBox(height: 4),
              Text('Model: ${OpenAIConfig.model}'),
              const SizedBox(height: 16),
              
              // 语音功能配置部分
              const Text('语音功能', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _isVoiceEnabled ? Icons.check_circle : Icons.error,
                    color: _isVoiceEnabled ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(_isVoiceEnabled ? '语音功能已启用' : '语音功能未启用'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('自动播放AI回复'),
                  Switch(
                    value: _autoPlayResponse,
                    onChanged: (value) {
                      setState(() {
                        _autoPlayResponse = value;
                      });
                      Navigator.of(context).pop();
                      _showSettingsDialog(); // 重新打开对话框以更新状态
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 配置说明
              const Text(
                '配置说明：\n\n'
                'OpenAI API 配置：\n'
                '请在项目根目录创建 .env 文件并配置：\n'
                'OPENAI_API_KEY=your_api_key\n'
                'OPENAI_BASE_URL=https://api.openai.com\n'
                'OPENAI_MODEL=gpt-3.5-turbo\n\n'
                '语音功能配置：\n'
                '请在 .env 文件中配置腾讯云语音服务：\n'
                'TENCENT_APP_ID=your_app_id\n'
                'TENCENT_SECRET_ID=your_secret_id\n'
                'TENCENT_SECRET_KEY=your_secret_key',
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
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
              _initializeVoice();
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
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
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
                
                // AI消息添加语音播放按钮
                if (!isUser && _isVoiceEnabled && message.content.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton(
                      onPressed: () => _speakAIResponse(message.content),
                      icon: Icon(
                        Icons.volume_up,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      tooltip: '播放语音',
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: const EdgeInsets.all(4),
                    ),
                  ),
              ],
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
          // 语音播放控制按钮
          if (_isSpeaking)
            IconButton(
              onPressed: _stopAISpeaking,
              icon: const Icon(Icons.stop),
              tooltip: '停止播放',
            ),
          
          // 语音功能状态指示器
          IconButton(
            onPressed: _isVoiceEnabled ? null : _showSettingsDialog,
            icon: Icon(
              _isVoiceEnabled ? Icons.mic : Icons.mic_off,
              color: _isVoiceEnabled ? Colors.white : Colors.red.shade200,
            ),
            tooltip: _isVoiceEnabled ? '语音功能已启用' : '语音功能未启用，点击查看配置',
          ),
          
          // MCP配置按钮
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const McpConfigPage()),
            ),
            icon: const Icon(Icons.extension),
            tooltip: 'MCP 配置',
          ),
          
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
          if (_isLoading || _isSpeaking)
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isSpeaking ? Colors.green.shade600 : Colors.blue.shade600
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(_isSpeaking ? 'AI 正在播放回复...' : 'AI 正在生成回复...'),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _isSpeaking ? _stopAISpeaking : _stopGeneration,
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
            child: Column(
              children: [
                // 语音识别状态显示
                if (_isListening || _currentSpeechText.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isListening ? Colors.red.shade200 : Colors.blue.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.red : Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isListening ? '正在听取语音...' : _currentSpeechText,
                            style: TextStyle(
                              color: _isListening ? Colors.red.shade700 : Colors.blue.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_isListening)
                          TextButton(
                            onPressed: _stopVoiceInputAndSend,
                            child: const Text('完成'),
                          ),
                      ],
                    ),
                  ),
                
                Row(
                  children: [
                    // 语音输入按钮
                    if (_isVoiceEnabled)
                      Container(
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.red.shade600 : Colors.green.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _isLoading ? null : (_isListening ? _stopVoiceInputAndSend : _startVoiceInput),
                          icon: Icon(
                            _isListening ? Icons.stop : Icons.mic,
                            color: Colors.white,
                          ),
                          tooltip: _isListening ? '停止录音并发送' : '语音输入',
                        ),
                      ),
                    
                    if (_isVoiceEnabled) const SizedBox(width: 8),
                    
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
