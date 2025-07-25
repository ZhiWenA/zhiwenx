import 'dart:async';
import 'package:flutter/material.dart';
import 'package:asr_plugin/asr_plugin.dart';
import 'package:tts_plugin/tts_plugin.dart';
import 'dart:developer';
import 'tencent_cloud_config.dart';
import 'voice_recognition_page.dart';
import 'settings_page.dart';
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
  late AnimationController _translationController;
  late Animation<Offset> _translationAnimation;
  late Animation<double> _waveAnimation;
  
  ASRController? _controller;
  TTSController? _ttsController;
  bool _isRecognizing = false;
  bool _isPressing = false;
  String _result = "";
  String? _activeNavItem;
  
  int _tapCount = 0;
  DateTime? _lastTapTime;
  
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
    config.vad_silence_time = 1000;
    config.needvad = 1;
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
    _controller?.stop();
    _ttsController?.stopPlayback();
    super.dispose();
  }

  Future<void> _startRecognition() async {
    if (_isRecognizing || _controller == null) return;
    
    setState(() {
      _isRecognizing = true;
      _result = "";
    });
    
    // 停止脉冲动画，开始波纹动画
    _pulseController.stop();
    _waveController.repeat();
    _micController.forward();
    
    try {
      await for (final data in _controller!.recognize()) {
        _handleRecognitionResult(data);
      }
    } catch (error) {
      log("识别错误: $error");
      _stopRecognition();
    }
  }
  
  void _handleRecognitionResult(ASRData data) {
    if (!mounted) return;
    
    try {
      String recognizedText = "";
      
      switch (data.type) {
        case ASRDataType.SLICE:
          recognizedText = data.res ?? '';
          break;
        case ASRDataType.SEGMENT:
          recognizedText = data.res ?? '';
          break;
        case ASRDataType.SUCCESS:
          recognizedText = data.result ?? '';
          break;
        case ASRDataType.NOTIFY:
          recognizedText = data.info ?? '';
          break;
      }
      
      setState(() {
        _result = recognizedText;
      });
      log("识别结果: $recognizedText");
      
      // 只有在SUCCESS类型时才跳转
      if (data.type == ASRDataType.SUCCESS && recognizedText.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppSelectionPage(recognizedText: recognizedText),
          ),
        );
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
    
    // 如果有识别结果，跳转到应用选择页面
    if (_result.isNotEmpty) {
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
    String itemType = icon == Icons.phone ? 'phone' : 'video';
    
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
    } else if (icon == Icons.videocam) {
      // 视频功能
      await _startVoiceQuery('你要和谁视频聊天？', 'video');
    }
  }

  // 添加状态变量来跟踪当前的语音查询状态
  bool _isVoiceQuerying = false;
  String _currentQueryType = '';
  Timer? _voiceQueryTimer;

  Future<void> _startVoiceQuery(String question, String actionType) async {
    // 取消之前的定时器
    _voiceQueryTimer?.cancel();
    
    // 立即显示录音状态
    setState(() {
      _isVoiceQuerying = true;
      _currentQueryType = actionType;
      _isPressing = true;
      _isRecognizing = true;
    });
    
    // 启动录音动画
    _scaleController.forward();
    _pulseController.stop();
    _waveController.repeat();
    _micController.forward();

    // 播放语音询问
    try {
      await _ttsController?.synthesize(question, null);
    } catch (e) {
      print('TTS播放失败: $e');
    }

    // 等待TTS播放完成后开始录音
    await Future.delayed(const Duration(milliseconds: 1500));

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
        recognizedText = data.res ?? '';
        break;
      case ASRDataType.SEGMENT:
        recognizedText = data.res ?? '';
        break;
      case ASRDataType.SUCCESS:
        recognizedText = data.result ?? '';
        break;
      case ASRDataType.NOTIFY:
        recognizedText = data.info ?? '';
        break;
    }
    
    if (recognizedText.isNotEmpty) {
      setState(() {
        _result = recognizedText;
      });
      
      // 只在SUCCESS类型时处理结果
      if (data.type == ASRDataType.SUCCESS && recognizedText.trim().isNotEmpty) {
        _processVoiceQueryResult(recognizedText, actionType);
      }
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
      await _ttsController?.synthesize('按住语音按钮并轻轻滑动开始录音，或者点击下方的电话和视频按钮进行通话', null);
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
    String recognizedText;
    if (actionType == 'phone') {
      recognizedText = 'phone:$name';
    } else {
      recognizedText = 'video:$name';
    }
    
    // 播放确认信息
    String confirmMessage = '';
    if (actionType == 'phone') {
      confirmMessage = '正在为您查找${name}的电话';
    } else if (actionType == 'video') {
      confirmMessage = '正在为您打开与${name}的视频聊天';
    }
    
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
              // 状态栏
              _buildStatusBar(),
              
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

  Widget _buildStatusBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '9:41',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF070B11),
            ),
          ),
          Row(
            children: [
              Icon(Icons.signal_cellular_4_bar, size: 16, color: Color(0xFF070B11)),
              SizedBox(width: 6),
              Icon(Icons.wifi, size: 16, color: Color(0xFF070B11)),
              SizedBox(width: 6),
              Icon(Icons.battery_3_bar, size: 16, color: Color(0xFF070B11)),
            ],
          ),
        ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isVoiceQuerying 
                  ? (_currentQueryType == 'phone' ? '请说出联系人姓名' : '请说出联系人姓名')
                  : '或点击下方按钮进行通话',
                style: TextStyle(
                  fontSize: 18,
                  color: _isVoiceQuerying ? const Color(0xFFE74C3C) : const Color(0xFFA49D9A),
                ),
              ),
              const SizedBox(width: 8),
              if (!_isVoiceQuerying)
                GestureDetector(
                  onTap: () {
                    // 播放提示音
                  },
                  child: const Icon(
                    Icons.volume_up,
                    color: Color(0xFF76A4A5),
                    size: 20,
                  ),
                ),
              if (_isVoiceQuerying)
                const Icon(
                  Icons.mic,
                  color: Color(0xFFE74C3C),
                  size: 20,
                ),
            ],
          ),
          // 添加滑动提示 - 使用动画和语音
          if (!_isVoiceQuerying)
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
                          color: const Color(0xFF76A4A5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF76A4A5).withOpacity(0.3),
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
                                fontSize: 14,
                                color: const Color(0xFF76A4A5),
                                fontWeight: FontWeight.w500,
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
              color: const Color(0xFF76A4A5).withOpacity(opacity),
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
              color: const Color(0xFF76A4A5).withOpacity(opacity),
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
              color: const Color(0xFF76A4A5).withOpacity(opacity),
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
      bottom: -60,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _result.isNotEmpty ? _result : "正在聆听...",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
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
                  _buildNavItem(Icons.videocam, true, 'video'),
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
              color: isCurrentlyActive ? const Color(0xFFE74C3C).withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: isCurrentlyActive 
                ? Border.all(color: const Color(0xFFE74C3C), width: 2)
                : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
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
}