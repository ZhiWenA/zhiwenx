import 'package:flutter/material.dart';
import 'package:asr_plugin/asr_plugin.dart';
import 'package:tts_plugin/tts_plugin.dart';
import 'dart:developer';
import 'tencent_cloud_config.dart';
import 'app_selection_page.dart';
import 'settings_page.dart';
import 'voice_service.dart';

class VoiceRecognitionPage extends StatefulWidget {
  const VoiceRecognitionPage({super.key});

  @override
  State<VoiceRecognitionPage> createState() => _VoiceRecognitionPageState();
}

class _VoiceRecognitionPageState extends State<VoiceRecognitionPage>
    with TickerProviderStateMixin {
  ASRController? _controller;
  late ASRControllerConfig _config;
  String _result = "";
  bool _isRecognizing = false;
  bool _isPressing = false;
  bool _isCancelling = false;
  double _dragOffset = 0.0;
  
  late AnimationController _waveController;
  late AnimationController _micController;
  late AnimationController _scaleController;
  late Animation<double> _waveAnimation1;
  late Animation<double> _waveAnimation2;
  late Animation<double> _waveAnimation3;
  late Animation<double> _micPulse;
  late Animation<double> _scaleAnimation;
  
  final VoiceService _voiceService = VoiceService();
  final double _cancelThreshold = 100.0; // 下滑取消的阈值

  @override
  void initState() {
    super.initState();
    _initializeConfig();
    _initializeAnimations();
    _initializeVoiceService();
  }
  
  void _initializeVoiceService() async {
    await _voiceService.initialize();
  }

  void _initializeConfig() {
    _config = ASRControllerConfig();
    _config.appID = TencentCloudConfig.appID;
    _config.projectID = TencentCloudConfig.projectID;
    _config.secretID = TencentCloudConfig.secretID;
    _config.secretKey = TencentCloudConfig.secretKey;
    
    _config.engine_model_type = "16k_zh";
    _config.filter_dirty = 1;
    _config.filter_modal = 0;
    _config.filter_punc = 0;
    _config.convert_num_mode = 1;
    _config.needvad = 1;
    _config.word_info = 0;
    _config.is_compress = true;
    _config.silence_detect = true;
    _config.silence_detect_duration = 3000;
    _config.is_save_audio_file = false;
  }

  void _initializeAnimations() {
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _micController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _waveAnimation1 = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
    ));

    _waveAnimation2 = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
    ));

    _waveAnimation3 = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
    ));

    _micPulse = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _micController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  void _startRecognition() async {
    if (_isRecognizing) return;
    
    setState(() {
      _isRecognizing = true;
      _result = "";
    });
    
    // 开始动画
    _waveController.repeat();
    _micController.repeat(reverse: true);

    try {
      _controller = await _config.build();
      
      // 开始识别
      await for (final data in _controller!.recognize()) {
        if (!_isRecognizing) break; // 如果已停止识别，退出循环
        
        String recognizedText = "";
        
        // 根据数据类型获取识别结果
        if (data.type == ASRDataType.SLICE || data.type == ASRDataType.SEGMENT) {
          recognizedText = data.res ?? "";
        } else if (data.type == ASRDataType.SUCCESS) {
          recognizedText = data.result ?? "";
        }
        
        setState(() {
          _result = recognizedText;
        });
        log("识别结果: $recognizedText");
      }
    } catch (error) {
      log("识别错误: $error");
    }
  }

  void _stopRecognition() {
    if (!_isRecognizing) return;
    
    _controller?.stop();
    setState(() {
      _isRecognizing = false;
    });
    
    // 停止动画
    _waveController.stop();
    _micController.stop();
    
    // 如果有识别结果且不是取消状态，跳转到应用选择页面
    if (_result.isNotEmpty && !_isCancelling) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AppSelectionPage(recognizedText: _result),
            ),
          );
        }
      });
    }
  }
  
  void _cancelRecognition() {
    _controller?.stop();
    setState(() {
      _isRecognizing = false;
      _isCancelling = true;
    });
    
    // 停止动画
    _waveController.stop();
    _micController.stop();
    
    // 返回上一页
    Navigator.pop(context);
  }
  
  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isPressing = true;
      _dragOffset = 0.0;
      _isCancelling = false;
    });
    _scaleController.forward();
    _startRecognition();
  }
  
  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dy;
      _isCancelling = _dragOffset > _cancelThreshold;
    });
  }
  
  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isPressing = false;
    });
    _scaleController.reverse();
    
    if (_isCancelling) {
      _cancelRecognition();
    } else {
      _stopRecognition();
    }
  }

  @override
  void dispose() {
    _controller?.stop();
    _waveController.dispose();
    _micController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5),
      body: SafeArea(
        child: Column(
          children: [
            // 状态栏
            _buildStatusBar(),
            
            // 问候语和提示
            _buildGreetingSection(),
            
            // 主要内容区域
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 语音识别动画
                  _buildVoiceAnimation(),
                  
                  const SizedBox(height: 48),
                  
                  // 状态文本
                  _buildStatusText(),
                  
                  const SizedBox(height: 48),
                  
                  // 操作提示
                  _buildInstructionText(),
                ],
              ),
            ),
            
            // 底部导航
            _buildBottomNavigation(),
          ],
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
              color: Color(0xFF5D5753),
            ),
          ),
          Row(
            children: [
              Icon(Icons.signal_cellular_4_bar, size: 16, color: Color(0xFF5D5753)),
              SizedBox(width: 6),
              Icon(Icons.wifi, size: 16, color: Color(0xFF5D5753)),
              SizedBox(width: 6),
              Icon(Icons.battery_3_bar, size: 16, color: Color(0xFF5D5753)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceAnimation() {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.translate(
              offset: Offset(0, _isCancelling ? -_dragOffset * 0.5 : 0),
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
          return Container(
            width: 256 * _waveAnimation1.value,
            height: 256 * _waveAnimation1.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF76A4A5).withValues(alpha:0.2 * (1 - _waveAnimation1.value)),
            ),
          );
        },
      ),
      
      // 中层波纹
      AnimatedBuilder(
        animation: _waveAnimation2,
        builder: (context, child) {
          return Container(
            width: 220 * _waveAnimation2.value,
            height: 220 * _waveAnimation2.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF76A4A5).withValues(alpha:0.2 * (1 - _waveAnimation2.value)),
            ),
          );
        },
      ),
      
      // 内层波纹
      AnimatedBuilder(
        animation: _waveAnimation3,
        builder: (context, child) {
          return Container(
            width: 184 * _waveAnimation3.value,
            height: 184 * _waveAnimation3.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF76A4A5).withValues(alpha:0.2 * (1 - _waveAnimation3.value)),
            ),
          );
        },
      ),
    ];
  }
  
  Widget _buildMicrophoneButton() {
    return AnimatedBuilder(
      animation: _isRecognizing ? _micPulse : const AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        return Transform.scale(
          scale: _isRecognizing ? _micPulse.value : 1.0,
          child: Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              color: _isCancelling ? Colors.red : const Color(0xFF76A4A5),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isCancelling ? Colors.red.withValues(alpha:0.3) : const Color(0xFFB6D2D3),
                shape: BoxShape.circle,
              ),
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isCancelling ? Icons.close : Icons.mic,
                  size: 40,
                  color: _isCancelling ? Colors.red : const Color(0xFF76A4A5),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusText() {
    String statusText;
    if (_isCancelling) {
      statusText = '松开取消';
    } else if (_isRecognizing) {
      statusText = '正在聆听';
    } else {
      statusText = '按住说话';
    }
    
    return Column(
      children: [
        Text(
          statusText,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: _isCancelling ? Colors.red : const Color(0xFF5D5753),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _result.isEmpty ? (_isRecognizing ? '请说话...' : '按住麦克风开始录音') : _result,
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFFA49D9A),
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildGreetingSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            '早上好',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF76A4A5),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '请说出您的需求',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFA49D9A),
                ),
              ),
              const SizedBox(width: 8),
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
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInstructionText() {
    if (_isCancelling) {
      return const Text(
        '向上滑动取消录音',
        style: TextStyle(
          fontSize: 16,
          color: Colors.red,
          fontWeight: FontWeight.w500,
        ),
      );
    } else if (_isRecognizing) {
      return const Text(
        '松开结束录音',
        style: TextStyle(
          fontSize: 16,
          color: Color(0xFF76A4A5),
          fontWeight: FontWeight.w500,
        ),
      );
    } else {
      return const Text(
        '按住麦克风开始录音',
        style: TextStyle(
          fontSize: 16,
          color: Color(0xFFA49D9A),
        ),
      );
    }
  }
  
  Widget _buildBottomNavigation() {
    return Container(
      color: const Color(0xFFF9F7F5),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.phone, false, () {
                  // 电话功能
                }),
                _buildNavItem(Icons.settings, false, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                  );
                }),
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
  
  Widget _buildNavItem(IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
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
              color: isActive ? const Color(0xFF76A4A5) : const Color(0xFF212528),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 24,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF76A4A5) : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}