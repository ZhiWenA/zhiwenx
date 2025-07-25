import 'dart:async';
import 'package:flutter/material.dart';
import 'package:asr_plugin/asr_plugin.dart';
import 'package:tts_plugin/tts_plugin.dart';
import 'dart:developer';
import 'tencent_cloud_config.dart';
import 'voice_recognition_page.dart';
import 'settings_page.dart';
import 'app_selection_page.dart';
import 'home_page.dart';

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
  late AnimationController _translationController;
  late Animation<Offset> _translationAnimation;
  late Animation<double> _waveAnimation;
  
  ASRController? _controller;
  TTSController? _ttsController;
  bool _isRecognizing = false;
  bool _isPressing = false;
  String _result = "";
  bool _hasValidResult = false; // 标记是否有有效的识别结果
  String? _activeNavItem;
  
  int _tapCount = 0;
  DateTime? _lastTapTime;
  Timer? _resetTimer;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeASR();
    _initializeTTS();
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
  }

  @override
  void dispose() {
    _waveController.dispose();
    _micController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    _voiceQueryTimer?.cancel();
    _resetTimer?.cancel();
    _controller?.stop();
    _ttsController?.stopPlayback();
    super.dispose();
  }
  
  void _handleDeveloperModeTap() {
    final now = DateTime.now();
    
    // 如果距离上次点击超过2秒，重置计数
    if (_lastTapTime == null || now.difference(_lastTapTime!).inSeconds > 2) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    
    _lastTapTime = now;
    
    // 取消之前的重置定时器
    _resetTimer?.cancel();
    
    if (_tapCount >= 3) {
      // 连续点击三次，进入开发者模式
      _tapCount = 0;
      _lastTapTime = null;
      
      // 显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔧 进入开发者模式'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.orange,
        ),
      );
      
      // 延迟一下再跳转，让用户看到提示
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      });
    } else {
      // 显示当前点击次数提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('开发者模式 $_tapCount/3'),
          duration: const Duration(milliseconds: 800),
          backgroundColor: Colors.grey,
        ),
      );
      
      // 设置2秒后重置计数的定时器
      _resetTimer = Timer(const Duration(seconds: 2), () {
        _tapCount = 0;
        _lastTapTime = null;
      });
    }
  }

  Future<void> _startRecognition() async {
    if (_isRecognizing || _controller == null) return;
    
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
      if (error is ASRError) {
        print("[DEBUG] ASR错误码: ${error.code}");
        print("[DEBUG] ASR错误消息: ${error.message}");
        print("[DEBUG] ASR服务端响应: ${error.resp}");
      } else if (error is Exception) {
        print("[DEBUG] 异常信息: ${error.toString()}");
      }
      // 显示错误信息但不标记为有效结果
      if (mounted) {
        setState(() {
          _result = "识别出错，请重试";
          _hasValidResult = false;
        });
      }
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
          // 最终结果，准备跳转
          recognizedText = data.result ?? '';
          if (recognizedText.isNotEmpty) {
            setState(() {
              _result = recognizedText;
              _hasValidResult = true; // 标记为有效结果
            });
            log("最终识别: $recognizedText");
            
            // 延迟一下让用户看到最终结果，然后跳转
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppSelectionPage(recognizedText: recognizedText),
                  ),
                );
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
    
    // 只有在有有效识别结果时才跳转到应用选择页面
    if (_hasValidResult && _result.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AppSelectionPage(recognizedText: _result),
            ),
          );
        }
      });
    }
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
    setState(() {
      _isPressing = true;
    });
    _scaleController.forward();
    await _startRecognition();
  }
  
  void _onTapUp(TapUpDetails details) async {
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

  void _handleNavItemTap(IconData icon) async {
    String itemType = 'phone';
    
    if (_isVoiceQuerying) {
      // 如果正在录音且点击的是同一个按钮，则取消录音
      if (_currentQueryType == itemType) {
        await _cancelVoiceQuery();
        return;
      }
      return; // 防止重复点击不同按钮
    }
    
    if (icon == Icons.phone) {
      // 电话功能
      await _startVoiceQuery('你要给谁打电话？', 'phone');
    }
  }

  // 添加状态变量来跟踪当前的语音查询状态
  bool _isVoiceQuerying = false;
  String _currentQueryType = '';
  Timer? _voiceQueryTimer;

  Future<void> _startVoiceQuery(String question, String actionType) async {
    // 取消之前的定时器
    _voiceQueryTimer?.cancel();
    
    // 显示准备状态（还未开始录音）
    setState(() {
      _isVoiceQuerying = true;
      _currentQueryType = actionType;
      _isPressing = false;
      _isRecognizing = false;
    });
    
    // 播放语音询问
    try {
      await _ttsController?.synthesize(question, null);
    } catch (e) {
      print('TTS播放失败: $e');
    }

    // 等待TTS播放完成，增加延迟确保回音消失
    await Future.delayed(const Duration(milliseconds: 3000));
    
    // TTS播放完成后，开始真正的录音状态
    setState(() {
      _isPressing = true;
      _isRecognizing = true;
    });
    
    // 启动录音动画
    _scaleController.forward();
    _pulseController.stop();
    _waveController.repeat();
    _micController.forward();

    // 设置5秒定时器
    _voiceQueryTimer = Timer(const Duration(seconds: 5), () async {
      if (_isRecognizing && mounted) {
        await _stopVoiceQuery();
        // 处理录音结果并跳转
        if (_result.trim().isNotEmpty) {
          _processVoiceQueryResult(_result, actionType);
        }
      }
    });

    try {
      await for (final data in _controller!.recognize()) {
        if (mounted) {
          _handleVoiceQueryResult(data, actionType);
        }
      }
    } catch (e) {
      print('语音识别错误: $e');
      _voiceQueryTimer?.cancel();
      if (mounted) {
        setState(() {
          _isRecognizing = false;
          _isPressing = false;
        });
      }
      _scaleController.reverse();
      _waveController.stop();
      _micController.reverse();
      _pulseController.repeat(reverse: true);
    }
  }

  void _handleVoiceQueryResult(ASRData data, String actionType) {
    String recognizedText = '';
    
    switch (data.type) {
      case ASRDataType.SLICE:
        // 实时识别结果，立即显示
        recognizedText = data.res ?? '';
        if (recognizedText.isNotEmpty) {
          setState(() {
            _result = recognizedText;
          });
          log("语音查询实时识别: $recognizedText");
        }
        break;
      case ASRDataType.SEGMENT:
        // 分段结果，更新显示
        recognizedText = data.res ?? '';
        if (recognizedText.isNotEmpty) {
          setState(() {
            _result = recognizedText;
          });
          log("语音查询分段识别: $recognizedText");
        }
        break;
      case ASRDataType.SUCCESS:
        // 最终结果，处理查询
        recognizedText = data.result ?? '';
        if (recognizedText.isNotEmpty) {
          setState(() {
            _result = recognizedText;
          });
          log("语音查询最终识别: $recognizedText");
          
          // 处理最终结果
          if (recognizedText.trim().isNotEmpty) {
            _processVoiceQueryResult(recognizedText, actionType);
          }
        }
        break;
      case ASRDataType.NOTIFY:
        recognizedText = data.info ?? '';
        if (recognizedText.isNotEmpty) {
          log("语音查询通知: $recognizedText");
        }
        break;
    }
  }

  Future<void> _stopVoiceQuery() async {
    _voiceQueryTimer?.cancel();
    await _controller?.stop();
    if (mounted) {
      setState(() {
        _isRecognizing = false;
        _isPressing = false;
        _isVoiceQuerying = false;
        _currentQueryType = '';
      });
    }
    
    _scaleController.reverse();
    _waveController.stop();
    _micController.reverse();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _cancelVoiceQuery() async {
    _voiceQueryTimer?.cancel();
    
    if (mounted) {
      setState(() {
         _isVoiceQuerying = false;
         _currentQueryType = '';
         _activeNavItem = null;
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
      await _ttsController?.synthesize('按住语音按钮并轻轻滑动开始录音，或者点击下方的电话按钮进行通话', null);
    } catch (e) {
      print('TTS播放失败: $e');
    }
  }

  void _processVoiceQueryResult(String name, String actionType) async {
    await _stopVoiceQuery();
    
    if (name.trim().isEmpty) {
      return;
    }
    
    // 构造传递给AppSelectionPage的文本格式
    String recognizedText = 'phone:$name';
    
    // 播放确认信息
    String confirmMessage = '正在为您查找${name}的电话';
    
    try {
      await _ttsController?.synthesize(confirmMessage, null);
    } catch (e) {
      print('TTS播放失败: $e');
    }
    
    // 重置语音查询状态
    setState(() {
      _isVoiceQuerying = false;
      _currentQueryType = '';
    });
    
    // 模拟跳转到相应应用
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AppSelectionPage(
            recognizedText: recognizedText,
          ),
        ),
      );
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
          Text(
            _isVoiceQuerying ? '正在录音中...' : '请说出您的需求',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: _isVoiceQuerying ? const Color(0xFFE74C3C) : const Color(0xFF76A4A5),
            ),
          ),
          const SizedBox(height: 8),
          if (_isVoiceQuerying)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentQueryType == 'phone' ? '请说出联系人姓名' : '请说出联系人姓名',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFFE74C3C),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.mic,
                  color: Color(0xFFE74C3C),
                  size: 20,
                ),
              ],
            ),
          
          // 实时识别结果显示区域
          if (_isRecognizing || _isVoiceQuerying)
            Container(
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
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE74C3C),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "您说的话",
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFFE74C3C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _result.isNotEmpty ? _result : "请开始说话，我正在聆听...",
                    style: TextStyle(
                      fontSize: 18,
                      color: _result.isNotEmpty ? const Color(0xFF2C3E50) : const Color(0xFF95A5A6),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          
          // 添加滑动提示 - 使用动画和语音
          if (!_isVoiceQuerying && !_isRecognizing)
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
        ],
      ),
    );
  }

  Widget _buildVoiceButton() {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
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
                    // 外层波纹 - 只在录音时显示
                    if (_isRecognizing) ..._buildWaveAnimations(),
                    
                    // 中心麦克风按钮
                    _buildMicrophoneButton(),
                    
                    // 状态提示
                    if (_isRecognizing) _buildStatusHint(),
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
              color: const Color(0xFF76A4A5).withValues(alpha:opacity),
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
              color: const Color(0xFF76A4A5).withValues(alpha:opacity),
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
              color: const Color(0xFF76A4A5).withValues(alpha:opacity),
            ),
          );
        },
      ),
    ];
  }
  
  Widget _buildMicrophoneButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isRecognizing ? 1.0 : _pulseAnimation.value.clamp(0.9, 1.2),
          child: Container(
            width: 256,
            height: 256,
            decoration: BoxDecoration(
              color: _isRecognizing ? const Color(0xFF5A9B9C) : const Color(0xFF76A4A5),
              shape: BoxShape.circle,
            ),
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isRecognizing ? const Color(0xFF8BB5B6) : const Color(0xFFB6D2D3),
                shape: BoxShape.circle,
              ),
              child: Container(
                margin: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic,
                  size: 56,
                  color: _isRecognizing ? const Color(0xFF5A9B9C) : const Color(0xFF76A4A5),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatusHint() {
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
                    color: const Color(0xFFE74C3C),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "实时识别",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha:0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _result.isNotEmpty ? _result : "正在聆听您的声音...",
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
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(Icons.phone, true, 'phone'),
                  _buildSettingsNavItem(),
                ],
              ),
          ),
          Container(
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

  Widget _buildNavItem(IconData icon, bool isActive, String itemType) {
    bool isCurrentlyActive = _isVoiceQuerying && _currentQueryType == itemType;
    
    return GestureDetector(
      onTap: () => _handleNavItemTap(icon),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isCurrentlyActive ? const Color(0xFFE74C3C).withValues(alpha:0.1) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: isCurrentlyActive 
                ? Border.all(color: const Color(0xFFE74C3C), width: 2)
                : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.1),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 30,
              color: isCurrentlyActive 
                ? const Color(0xFFE74C3C)
                : (isActive ? const Color(0xFF76A4A5) : const Color(0xFF212528)),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 24,
            height: 6,
            decoration: BoxDecoration(
              color: isCurrentlyActive 
                ? const Color(0xFFE74C3C)
                : (isActive ? const Color(0xFF76A4A5) : Colors.transparent),
              borderRadius: BorderRadius.circular(3),
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