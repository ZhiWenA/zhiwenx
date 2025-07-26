// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:asr_plugin/asr_plugin.dart';
import 'package:tts_plugin/tts_plugin.dart';
import 'dart:developer';
import 'tencent_cloud_config.dart';
import 'settings_page.dart';
import 'chat_models.dart';
import 'enhanced_openai_service_v2.dart';
import 'openai_config.dart';
import 'services/platform_knowledge_service.dart';
import 'services/knowledge_service.dart';
import 'app_selection_page.dart';


class VoiceWakePage extends StatefulWidget {
  const VoiceWakePage({super.key});

  @override
  State<VoiceWakePage> createState() => _VoiceWakePageState();
}

class _VoiceWakePageState extends State<VoiceWakePage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // 语音识别相关
  late AnimationController _waveController;
  late AnimationController _micController;
  late AnimationController _scaleController;
  late Animation<double> _waveAnimation1;
  late Animation<double> _waveAnimation2;
  late Animation<double> _waveAnimation3;
  late Animation<double> _scaleAnimation;
  
  ASRController? _controller;
  TTSController? _ttsController;
  bool _isRecognizing = false;
  // ignore: unused_field
  bool _isPressing = false;
  String _result = "";
  bool _hasValidResult = false; // 标记是否有有效的识别结果
  // ignore: unused_field
  String? _activeNavItem;
  bool _isTTSPlaying = false; // 添加TTS播放状态标记
  
  // AI对话相关
  final List<ChatMessage> _messages = [];
  bool _isAIResponding = false;
  bool _isConnected = false;
  StreamSubscription<String>? _aiStreamSubscription;
  String _aiResponse = "";
  bool _autoPlayAIResponse = true;
  
  int _tapCount = 0;
  DateTime? _lastTapTime;
  Timer? _resetTimer;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeASR();
    _initializeTTS();
    _checkAIConnection();
    _initializeAIService();
    _initializePlatformKnowledge();
    _addSystemMessage();
  }

  // 初始化平台知识库
  void _initializePlatformKnowledge() async {
    try {
      print('开始初始化平台知识库...');
      await PlatformKnowledgeService.instance.initialize();
      print('平台知识库初始化成功，isInitialized: ${PlatformKnowledgeService.instance.isInitialized}');
      
      // 测试推荐功能
      final testRecommendation = PlatformKnowledgeService.instance.recommendPlatform('我想看美食攻略');
      print('测试推荐结果: $testRecommendation');
    } catch (e) {
      print('平台知识库初始化失败: $e');
    }
  }

  // 检查AI连接状态
  void _checkAIConnection() async {
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

  // 初始化AI服务
  void _initializeAIService() async {
    try {
      await EnhancedOpenAIService.initialize();
    } catch (e) {
      print('AI服务初始化失败: $e');
    }
  }

  // 添加系统消息
  void _addSystemMessage() {
    // 系统消息现在在_sendToAI方法中动态添加，这里保留空实现以保持兼容性
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
    
    // 语音识别动画
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _micController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _waveAnimation1 = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOut),
    );
    
    _waveAnimation2 = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    
    _waveAnimation3 = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }
  
  Future<void> _initializeASR() async {
    final config = ASRControllerConfig();
    config.appID = TencentCloudConfig.appID;
    config.secretID = TencentCloudConfig.secretID;
    config.secretKey = TencentCloudConfig.secretKey;
    config.engine_model_type = "16k_zh";
    config.filter_dirty = 1;
    config.filter_modal = 2;
    config.filter_punc = 1;
    config.convert_num_mode = 1;
    config.hotword_id = "";
    config.customization_id = "";
    config.vad_silence_time = 1000; // 设置为1秒
    config.needvad = 0; // 禁用VAD，让用户手动控制录音停止
    config.word_info = 0;
    
    _controller = await config.build();
  }

  Future<void> _initializeTTS() async {
    _ttsController = TTSController.instance;
    // 配置TTS
    final config = TTSControllerConfig();
    config.secretId = TencentCloudConfig.secretID;
    config.secretKey = TencentCloudConfig.secretKey;
    config.voiceSpeed = 0;
    config.voiceVolume = 1;
    config.voiceType = 1001;
    config.voiceLanguage = 1;
    config.codec = "mp3";
    _ttsController?.config = config;
    
    // 监听TTS播放状态
    _ttsController?.playerEventListener.listen(
      (event) {
        if (mounted) {
          setState(() {
            if (event == "playStart") {
              _isTTSPlaying = true;
            } else if (event == "playComplete") {
              _isTTSPlaying = false;
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isTTSPlaying = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _micController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    _voiceQueryTimer?.cancel();
    _resetTimer?.cancel();
    _aiStreamSubscription?.cancel();
    _controller?.stop();
    _ttsController?.stopPlayback();
    super.dispose();
  }
  

  Future<void> _startRecognition() async {
    if (_isRecognizing || _controller == null) return;
    
    // 如果TTS正在播放，先停止播放
    if (_isTTSPlaying) {
      try {
        await _ttsController?.stopPlayback();
        setState(() {
          _isTTSPlaying = false;
        });
        // 等待一小段时间确保TTS完全停止
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        print('停止TTS播放失败: $e');
      }
    }
    
    // 检查腾讯云配置是否有效
    print("[DEBUG] 检查配置: appID=${TencentCloudConfig.appID}, secretID=${TencentCloudConfig.secretID.isNotEmpty ? '已设置' : '未设置'}, secretKey=${TencentCloudConfig.secretKey.isNotEmpty ? '已设置' : '未设置'}");
    if (!TencentCloudConfig.isConfigValid) {
      print("[DEBUG] 配置无效: ${TencentCloudConfig.configErrorMessage}");
      setState(() {
        _result = "配置错误: ${TencentCloudConfig.configErrorMessage}";
        _hasValidResult = false;
      });
      return;
    }
    print("[DEBUG] 配置有效，开始识别");
    
    setState(() {
      _isRecognizing = true;
      _result = "";
      _hasValidResult = false; // 重置有效结果标志
    });
    
    // 停止脉冲动画，开始波纹动画
    _pulseController.stop();
    _waveController.repeat();
    _micController.forward();
    
    try {
      print("[DEBUG] 开始调用_controller!.recognize()");
      await for (final data in _controller!.recognize()) {
        print("[DEBUG] 收到识别数据: ${data.type}");
        if (mounted) {
          _handleRecognitionResult(data);
        }
      }
      print("[DEBUG] 识别流程正常结束");
    } catch (error) {
      print("[DEBUG] 识别错误详情: $error");
      print("[DEBUG] 错误类型: ${error.runtimeType}");
      _onASRError(error);
    }
  }
  
  void _onASRError(dynamic error) {
    if (mounted) {
      String errorMessage = "识别出错，请重试";
      
      if (error is ASRError) {
        print("[DEBUG] ASR错误码: ${error.code}");
        print("[DEBUG] ASR错误消息: ${error.message}");
        print("[DEBUG] ASR服务端响应: ${error.resp}");
        
        // 根据错误码提供更友好的错误信息
        switch (error.code) {
          case 4001:
            errorMessage = "网络连接失败，请检查网络";
            break;
          case 4002:
            errorMessage = "认证失败，请检查配置";
            break;
          case 4003:
            errorMessage = "请求过于频繁，请稍后重试";
            break;
          case 4004:
            errorMessage = "音频格式不支持";
            break;
          case 4005:
            errorMessage = "音频时长过短，请重新录音";
            break;
          case 4006:
            errorMessage = "音频时长过长，请缩短录音";
            break;
          case 4007:
            errorMessage = "音频质量过低，请在安静环境录音";
            break;
          case 5000:
            errorMessage = "服务器内部错误，请稍后重试";
            break;
          default:
            if (error.code >= 4000 && error.code < 5000) {
              errorMessage = "请求参数错误，请重试";
            } else if (error.code >= 5000) {
              errorMessage = "服务器错误，请稍后重试";
            }
            break;
        }
      } else if (error is Exception) {
        print("[DEBUG] 异常信息: ${error.toString()}");
        if (error.toString().contains('timeout')) {
          errorMessage = "录音超时，请重新尝试";
        } else if (error.toString().contains('permission')) {
          errorMessage = "缺少麦克风权限";
        }
      }
      
      setState(() {
        _result = errorMessage;
        _hasValidResult = false;
      });
      
      // 播放错误提示音
      _playErrorFeedback();
    }
  }
  
  // 播放错误反馈音
  void _playErrorFeedback() async {
    try {
      await _ttsController?.synthesize('抱歉，出现了问题，请重新尝试', null);
    } catch (e) {
      print('错误提示音播放失败: $e');
    }
  }
  
  void _handleRecognitionResult(ASRData data) {
    if (!mounted) return;
    
    try {
      String recognizedText = "";
      
      switch (data.type) {
        case ASRDataType.SLICE:
          // 实时识别结果，立即显示
          recognizedText = data.res ?? '';
          if (recognizedText.isNotEmpty) {
            setState(() {
              _result = recognizedText;
              _hasValidResult = true; // 标记为有效结果
            });
            log("实时识别: $recognizedText");
          }
          break;
        case ASRDataType.SEGMENT:
          // 分段结果，更新显示
          recognizedText = data.res ?? '';
          if (recognizedText.isNotEmpty) {
            setState(() {
              _result = recognizedText;
              _hasValidResult = true; // 标记为有效结果
            });
            log("分段识别: $recognizedText");
          }
          break;
        case ASRDataType.SUCCESS:
          // 最终结果，发送给AI
          recognizedText = data.result ?? '';
          if (recognizedText.isNotEmpty) {
            setState(() {
              _result = recognizedText;
              _hasValidResult = true; // 标记为有效结果
            });
            log("最终识别: $recognizedText");
            
            // 延迟一下让用户看到最终结果，然后发送给AI
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                _sendToAI(recognizedText);
              }
            });
          }
          break;
        case ASRDataType.NOTIFY:
          recognizedText = data.info ?? '';
          if (recognizedText.isNotEmpty) {
            log("通知信息: $recognizedText");
          }
          break;
      }
    } catch (error) {
      log("识别错误: $error");
    }
  }
  
  Future<void> _stopRecognition() async {
    if (!_isRecognizing) return;
    
    await _controller?.stop();
    setState(() {
      _isRecognizing = false;
    });
    
    // 停止动画，恢复脉冲
    _waveController.stop();
    _micController.reverse();
    _pulseController.repeat(reverse: true);
    
    // 只有在有有效识别结果时才发送给AI
    if (_hasValidResult && _result.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _sendToAI(_result);
        }
      });
    } else if (!_hasValidResult && _result.isNotEmpty) {
      // 如果是错误信息，延迟清空
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) {
          setState(() {
            _result = "";
          });
        }
      });
    }
  }

  // 发送消息给AI
  Future<void> _sendToAI(String userMessage) async {
    if (userMessage.trim().isEmpty || _isAIResponding || !_isConnected) {
      return;
    }

    // 添加用户消息到对话历史
    final userChatMessage = ChatMessage.user(userMessage);
    setState(() {
      _messages.add(userChatMessage);
      _isAIResponding = true;
      _aiResponse = "";
    });

    // 启动AI响应动画
    _pulseController.stop();
    _waveController.repeat();

    try {
      // 取消之前的AI流订阅
      await _aiStreamSubscription?.cancel();
      
      // 1. 首先尝试知识库查询
       String knowledgeResult = "";
       
       // 1.1 尝试知识库查询
       if (KnowledgeService.isConfigured()) {
         try {
           final searchResult = await KnowledgeService.searchKnowledge(content: userMessage);
           if (searchResult.code == 200 && searchResult.data != null && searchResult.data!.isNotEmpty) {
             knowledgeResult = searchResult.data!.first.content;
             print('知识库查询成功: $knowledgeResult');
           }
         } catch (e) {
           print('知识库查询失败: $e');
         }
       }
       
       // 2. 使用平台知识库推荐最适合的应用
       if (PlatformKnowledgeService.instance.isInitialized) {
         final recommendation = PlatformKnowledgeService.instance.recommendPlatform(userMessage);
         if (recommendation != null && recommendation.confidence > 0.1) {
           // 有效推荐，直接启用语音确认机制，避免AI生成冗长回答
           await _handlePlatformRecommendationWithConfirmation(recommendation, userMessage);
           return; // 直接返回，不继续AI对话流程
         }
       }
       
       // 3. 创建简化的系统提示，只包含知识库结果
       String enhancedSystemPrompt = '''
你是一个简洁的智能语音助手，专门帮助用户快速找到合适的应用程序。

**核心原则**：
- 简洁回应，直接推荐应用
- 不要提供详细解释或教程
- 只需确认用户需求并推荐合适的应用工具

**回应格式**：
"我可以帮您用[应用名称]搜索[内容]，请确认是否继续？"''';

       // 如果有知识库结果，添加到系统提示中
       if (knowledgeResult.isNotEmpty) {
         enhancedSystemPrompt += '''

**参考信息**：
$knowledgeResult''';
       }
       
       enhancedSystemPrompt += '''

**可用工具**：
- xiaohongshu_search: 搜索小红书内容（适合攻略、美食、旅游、购物等）
- douyin_search: 搜索抖音内容（适合娱乐、短视频、音乐等）
- bilibili_search: 搜索B站内容（适合学习、科技、游戏、动漫等）
- taobao_search: 搜索淘宝商品（适合购物、商品对比等）
- wechat_scan: 打开微信扫一扫
- alipay_scan: 打开支付宝扫一扫
- amap_navigation: 使用高德地图导航

请根据用户的具体需求选择最合适的工具。''';
       
       // 创建优化的消息列表，包含增强的系统提示
       List<ChatMessage> enhancedMessages = [
         ChatMessage.system(enhancedSystemPrompt),
         ...(_messages.length > 10 ? _messages.sublist(_messages.length - 10) : _messages),
         userChatMessage,
       ];
      
      // 使用增强的OpenAI服务
      final stream = EnhancedOpenAIService.sendStreamChatRequest(enhancedMessages);
      String fullContent = '';
      
      _aiStreamSubscription = stream.listen(
        (chunk) {
          fullContent += chunk;
          setState(() {
            _aiResponse = fullContent;
          });
        },
        onError: (error) {
          print('AI响应错误: ${error.toString()}');
          String errorMessage = "抱歉，AI服务暂时不可用，请稍后再试。";
          
          // 根据错误类型提供更具体的错误信息
          if (error.toString().contains('timeout')) {
            errorMessage = "AI响应超时，请重新尝试";
          } else if (error.toString().contains('401')) {
            errorMessage = "AI服务认证失败，请检查配置";
          } else if (error.toString().contains('429')) {
            errorMessage = "请求过于频繁，请稍后重试";
          } else if (error.toString().contains('network')) {
            errorMessage = "网络连接异常，请检查网络";
          }
          
          setState(() {
            _aiResponse = errorMessage;
            _isAIResponding = false;
          });
          // 停止动画
          _waveController.stop();
          _pulseController.repeat(reverse: true);
        },
        onDone: () {
          setState(() {
            _isAIResponding = false;
          });
          
          // 停止动画
          _waveController.stop();
          _pulseController.repeat(reverse: true);
          
          // 添加AI回复到对话历史
          if (fullContent.trim().isNotEmpty) {
            _messages.add(ChatMessage.assistant(fullContent));
            
            // 自动播放AI回复
            if (_autoPlayAIResponse) {
              _playAIResponse(fullContent);
            }
          }
        },
      );
    } catch (e) {
      print('发送AI请求失败: ${e.toString()}');
      String errorMessage = "抱歉，AI服务暂时不可用，请稍后再试。";
      
      if (e.toString().contains('connection')) {
        errorMessage = "网络连接失败，请检查网络设置";
      } else if (e.toString().contains('config')) {
        errorMessage = "AI服务配置错误，请检查设置";
      }
      
      setState(() {
        _aiResponse = errorMessage;
        _isAIResponding = false;
      });
      // 停止动画
      _waveController.stop();
      _pulseController.repeat(reverse: true);
    }
  }

  // 播放AI回复
  Future<void> _playAIResponse(String text) async {
    if (text.trim().isNotEmpty) {
      try {
        // 优化TTS文本，移除特殊字符和过长内容
        String ttsText = _optimizeTextForTTS(text);
        await _ttsController?.synthesize(ttsText, null);
      } catch (e) {
        print('TTS播放失败: $e');
      }
    }
  }
  
  // 优化TTS文本
  String _optimizeTextForTTS(String text) {
    // 移除markdown格式
    String optimized = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1');
    optimized = optimized.replaceAll(RegExp(r'\*([^*]+)\*'), r'\1');
    optimized = optimized.replaceAll(RegExp(r'`([^`]+)`'), r'\1');
    
    // 移除多余的换行和空格
    optimized = optimized.replaceAll(RegExp(r'\n+'), ' ');
    optimized = optimized.replaceAll(RegExp(r'\s+'), ' ');
    optimized = optimized.trim();
    
    // 限制长度，避免TTS播放时间过长
    if (optimized.length > 200) {
      // 尝试在句号处截断
      int lastPeriod = optimized.lastIndexOf('。', 200);
      if (lastPeriod > 100) {
        optimized = optimized.substring(0, lastPeriod + 1);
      } else {
        optimized = optimized.substring(0, 200) + '...';
      }
    }
    
    return optimized;
  }
  
  Future<void> _cancelRecognition() async {
    await _controller?.stop();
    setState(() {
      _isRecognizing = false;
      _result = "";
      _hasValidResult = false; // 重置有效结果标志
    });
    
    // 停止动画，恢复脉冲
    _waveController.stop();
    _micController.reverse();
    _pulseController.repeat(reverse: true);
  }
  
  void _onTapDown(TapDownDetails details) async {
    if (_isAIResponding) {
      // 如果AI正在回复，点击取消
      await _cancelVoiceQuery();
      return;
    }
    
    // 添加触觉反馈
    HapticFeedback.lightImpact();
    
    setState(() {
      _isPressing = true;
    });
    _scaleController.forward();
    await _startRecognition();
  }
  
  void _onTapUp(TapUpDetails details) async {
    // 添加触觉反馈
    HapticFeedback.lightImpact();
    
    setState(() {
      _isPressing = false;
    });
    _scaleController.reverse();
    await _stopRecognition();
  }
  
  void _onTapCancel() async {
    setState(() {
      _isPressing = false;
    });
    _scaleController.reverse();
    await _cancelRecognition();
  }

  void _onScreenTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTapTime = now;

    if (_tapCount >= 5) {
      _tapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SettingsPage(),
        ),
      );
    }
  }





  Timer? _voiceQueryTimer;

  Future<void> _cancelVoiceQuery() async {
    _voiceQueryTimer?.cancel();
    
    if (mounted) {
      setState(() {
         _isRecognizing = false;
         _isPressing = false;
         _result = ''; // 清空识别结果
       });
    }
    
    // 停止录音
    await _controller?.stop();
    
    // 停止动画，恢复脉冲
    _waveController.stop();
    _micController.reverse();
    _scaleController.reverse();
    _pulseController.repeat(reverse: true);
    
    // 播放取消提示
    try {
      await _ttsController?.synthesize('已取消操作', null);
    } catch (e) {
      print('TTS播放失败: $e');
    }
  }

  // 播放操作提示语音
  void _playInstructionVoice() async {
    try {
      await _ttsController?.synthesize('按住语音按钮开始录音，AI将智能理解您的需求并提供帮助', null);
    } catch (e) {
      print('TTS播放失败: $e');
    }
  }

  // 处理平台推荐的图形化确认机制
  Future<void> _handlePlatformRecommendationWithConfirmation(
    PlatformRecommendation recommendation, 
    String userQuery
  ) async {
    final platformInfo = PlatformKnowledgeService.instance.getPlatformInfo(recommendation.platformId);
    if (platformInfo == null) return;

    // 停止当前动画
    _waveController.stop();
    _pulseController.repeat(reverse: true);
    
    setState(() {
      _isAIResponding = false;
    });

    // 跳转到图形化确认界面
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AppSelectionPage(recognizedText: userQuery),
        ),
      );
    }
  }

  // 开始确认录音
  Future<void> _startConfirmationRecognition(
    PlatformRecommendation recommendation,
    String userQuery,
    String platformName
  ) async {
    if (_isRecognizing) return;

    setState(() {
      _isRecognizing = true;
      _result = "";
      _hasValidResult = false;
    });

    // 启动动画
    _pulseController.stop();
    _waveController.repeat();
    _micController.forward();

    try {
       String finalResult = "";
       await for (final data in _controller!.recognize()) {
         if (mounted) {
           switch (data.type) {
             case ASRDataType.SLICE:
             case ASRDataType.SEGMENT:
               String recognizedText = data.res ?? '';
               if (recognizedText.isNotEmpty) {
                 setState(() {
                   _result = recognizedText;
                   _hasValidResult = true;
                 });
               }
               break;
             case ASRDataType.SUCCESS:
               finalResult = data.result ?? '';
               if (finalResult.isNotEmpty) {
                 setState(() {
                   _isRecognizing = false;
                   _result = finalResult;
                 });
                 
                 // 停止动画
                 _waveController.stop();
                 _micController.reverse();
                 _pulseController.repeat(reverse: true);
                 
                 // 分析用户确认结果
                 await _processConfirmationResult(finalResult, recommendation, userQuery, platformName);
                 return;
               }
               break;
             case ASRDataType.NOTIFY:
               // 处理通知信息
               if (data.info?.contains('error') == true) {
                 print('确认录音错误: ${data.info}');
                 setState(() {
                   _isRecognizing = false;
                 });
                 _waveController.stop();
                 _micController.reverse();
                 _pulseController.repeat(reverse: true);
                 return;
               }
               break;
           }
         }
       }
    } catch (e) {
      print('启动确认录音失败: $e');
      setState(() {
        _isRecognizing = false;
      });
    }
  }

  // 处理确认结果
  Future<void> _processConfirmationResult(
    String confirmationResult,
    PlatformRecommendation recommendation,
    String userQuery,
    String platformName
  ) async {
    String result = confirmationResult.toLowerCase().trim();
    
    // 判断用户是否确认
    bool isConfirmed = result.contains('是') || 
                      result.contains('好') || 
                      result.contains('确认') || 
                      result.contains('可以') || 
                      result.contains('行') ||
                      result.contains('对') ||
                      result.contains('嗯');
    
    bool isRejected = result.contains('不') || 
                     result.contains('否') || 
                     result.contains('取消') ||
                     result.contains('算了');

    if (isConfirmed) {
      // 用户确认，执行应用启动
      await _executeAppLaunch(recommendation.platformId, userQuery);
    } else if (isRejected) {
      // 用户拒绝，播放取消提示
      try {
        await _ttsController?.synthesize('好的，已取消操作', null);
      } catch (e) {
        print('TTS播放失败: $e');
      }
    } else {
      // 无法识别用户意图，默认执行
      try {
        await _ttsController?.synthesize('为您打开$platformName', null);
        await Future.delayed(const Duration(milliseconds: 1500));
        await _executeAppLaunch(recommendation.platformId, userQuery);
      } catch (e) {
        print('TTS播放失败: $e');
        await _executeAppLaunch(recommendation.platformId, userQuery);
      }
    }
  }

  // 执行应用启动
  Future<void> _executeAppLaunch(String platformId, String query) async {
    try {
      // 根据平台ID调用相应的工具
      String toolName = '';
      switch (platformId) {
        case 'xiaohongshu':
          toolName = 'xiaohongshu_search';
          break;
        case 'douyin':
          toolName = 'douyin_search';
          break;
        case 'bilibili':
          toolName = 'bilibili_search';
          break;
        case 'taobao':
          toolName = 'taobao_search';
          break;
        case 'wechat':
          toolName = 'wechat_scan';
          break;
        case 'alipay':
          toolName = 'alipay_scan';
          break;
        case 'amap':
          toolName = 'amap_navigation';
          break;
        default:
          print('未知的平台ID: $platformId');
          return;
      }

      // 使用EnhancedOpenAIService调用工具
      final toolCallMessage = ChatMessage.system(
        '请使用$toolName工具搜索"$query"'
      );
      
      final stream = EnhancedOpenAIService.sendStreamChatRequest([toolCallMessage]);
      
      // 监听工具调用结果
      stream.listen(
        (chunk) {
          print('工具调用响应: $chunk');
        },
        onError: (error) {
          print('工具调用失败: $error');
        },
        onDone: () {
          print('工具调用完成');
        },
      );
      
    } catch (e) {
      print('执行应用启动失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: GestureDetector(
        onTap: _onScreenTap,
        child: SafeArea(
          child: Column(
            children: [
              // 问候语和提示
              _buildGreetingSection(),
              
              // 主要语音按钮区域
              Expanded(
                child: Center(
                  child: _buildVoiceButton(),
                ),
              ),
              
              // 底部导航
              _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildGreetingSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 状态显示 - 使用动画切换
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildStatusIndicator(),
          ),
          const SizedBox(height: 8),
          
          // AI回复展示区域已隐藏
          // if (_isAIResponding || _aiResponse.isNotEmpty)
          //   AnimatedContainer(...),
          
          // 实时识别结果显示区域
          if (_isRecognizing && !_isAIResponding)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              constraints: const BoxConstraints(
                minHeight: 60,
                maxWidth: 320,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE74C3C).withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.mic,
                          size: 14,
                          color: const Color(0xFFE74C3C),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "实时识别",
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFFE74C3C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE74C3C),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 18,
                      color: _result.isNotEmpty ? const Color(0xFF2C3E50) : const Color(0xFF95A5A6),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    child: Text(
                      _result.isNotEmpty ? _result : "请开始说话，我正在聆听...",
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          
          // 错误信息显示
          if (!_hasValidResult && _result.isNotEmpty && !_isRecognizing)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              constraints: const BoxConstraints(
                maxWidth: 320,
              ),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _result,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // 添加滑动提示 - 使用动画和语音
          if (!_isRecognizing && !_isAIResponding)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: _playInstructionVoice,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseAnimation.value * 0.1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF76A4A5).withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF76A4A5).withValues(alpha:0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.volume_up,
                              size: 16,
                              color: const Color(0xFF76A4A5),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '按住说话',
                              style: TextStyle(
                                fontSize: 20,
                                color: const Color(0xFF76A4A5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            
          // 连接状态指示器
          if (!_isConnected)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'AI服务未连接',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildStatusIndicator() {
    if (_isRecognizing) {
      return Container(
        key: const ValueKey('recording'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE74C3C).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "正在录音中...",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE74C3C),
              ),
            ),
          ],
        ),
      );
    } else if (_isAIResponding) {
      return Container(
        key: const ValueKey('thinking'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3498DB).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF3498DB).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF3498DB)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "AI正在思考...",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3498DB),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        key: const ValueKey('ready'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF76A4A5).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF76A4A5).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          "请说出您的需求",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF76A4A5),
          ),
        ),
      );
    }
  }

  Widget _buildVoiceButton() {
    return GestureDetector(
      onTapDown: _isAIResponding ? null : _onTapDown,
      onTapUp: _isAIResponding ? null : _onTapUp,
      onTapCancel: _isAIResponding ? null : _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value.clamp(0.8, 1.2),
            child: Transform.translate(
              offset: Offset.zero,
              child: SizedBox(
                width: 256,
                height: 256,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 外层波纹 - 录音或AI响应时显示
                    if (_isRecognizing || _isAIResponding) ..._buildWaveAnimations(),
                    
                    // 中心麦克风按钮
                    _buildMicrophoneButton(),
                    
                    // 状态提示
                    if (_isRecognizing || _isAIResponding) _buildStatusHint(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  List<Widget> _buildWaveAnimations() {
    // AI响应时使用蓝色波纹，录音时使用绿色波纹
    Color waveColor = _isAIResponding ? const Color(0xFF3498DB) : const Color(0xFF76A4A5);
    
    return [
      // 外层波纹
      AnimatedBuilder(
        animation: _waveAnimation1,
        builder: (context, child) {
          final size = 256.0 * _waveAnimation1.value.clamp(1.0, 1.5);
          final opacity = (0.2 * (1 - _waveAnimation1.value)).clamp(0.0, 1.0);
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: waveColor.withValues(alpha:opacity),
            ),
          );
        },
      ),
      
      // 中层波纹
      AnimatedBuilder(
        animation: _waveAnimation2,
        builder: (context, child) {
          final size = 220.0 * _waveAnimation2.value.clamp(1.0, 1.3);
          final opacity = (0.2 * (1 - _waveAnimation2.value)).clamp(0.0, 1.0);
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: waveColor.withValues(alpha:opacity),
            ),
          );
        },
      ),
      
      // 内层波纹
      AnimatedBuilder(
        animation: _waveAnimation3,
        builder: (context, child) {
          final size = 184.0 * _waveAnimation3.value.clamp(1.0, 1.1);
          final opacity = (0.2 * (1 - _waveAnimation3.value)).clamp(0.0, 1.0);
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: waveColor.withValues(alpha:opacity),
            ),
          );
        },
      ),
    ];
  }
  
  Widget _buildMicrophoneButton() {
    Color buttonColor = _isAIResponding ? const Color(0xFF3498DB) : 
                       _isRecognizing ? const Color(0xFF5A9B9C) : const Color(0xFF76A4A5);
    Color innerColor = _isAIResponding ? const Color(0xFF5DADE2) :
                      _isRecognizing ? const Color(0xFF8BB5B6) : const Color(0xFFB6D2D3);
    IconData iconData = _isAIResponding ? Icons.psychology : Icons.mic;
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Transform.scale(
            scale: (_isRecognizing || _isAIResponding) ? 1.0 : _pulseAnimation.value.clamp(0.9, 1.2),
            child: Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                color: buttonColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: buttonColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: innerColor,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      iconData,
                      key: ValueKey(iconData),
                      size: 56,
                      color: buttonColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatusHint() {
    String statusText = _isAIResponding ? 
      (_aiResponse.isNotEmpty ? _aiResponse : "AI正在思考中...") :
      (_result.isNotEmpty ? _result : "正在聆听您的声音...");
    
    String statusLabel = _isAIResponding ? "AI回复" : "实时识别";
    Color statusColor = _isAIResponding ? const Color(0xFF3498DB) : const Color(0xFFE74C3C);
    
    return Positioned(
      bottom: -80,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha:0.8),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha:0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (_isAIResponding) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      color: const Color(0xFFF9F7F5),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSettingsNavItem(),
                ],
              ),
          ),
          SizedBox(
            height: 34,
            child: Center(
              child: Container(
                width: 134,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFA49D9A),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildSettingsNavItem() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        );
      },
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF76A4A5).withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF76A4A5).withValues(alpha:0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.1),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.settings,
              size: 30,
              color: Color(0xFF76A4A5),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 24,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF76A4A5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}