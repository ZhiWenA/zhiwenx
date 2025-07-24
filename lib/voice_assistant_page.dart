import 'package:flutter/material.dart';
import 'package:asr_plugin/asr_plugin.dart';
import 'package:tts_plugin/tts_plugin.dart';
import 'dart:developer';
import 'tencent_cloud_config.dart';

class VoiceAssistantPage extends StatefulWidget {
  const VoiceAssistantPage({super.key});

  @override
  State<VoiceAssistantPage> createState() => _VoiceAssistantPageState();
}

class _VoiceAssistantPageState extends State<VoiceAssistantPage>
    with TickerProviderStateMixin {
  // ASR相关字段
  ASRController? _controller;
  late ASRControllerConfig _config;
  String _result = "";
  List<String> _sentences = [];
  bool _isRecognizing = false;
  String _asrStatus = "准备就绪";
  VoidCallback? _btnOnClick;

  // TTS相关字段
  late TTSControllerConfig _ttsConfig;
  bool _isSynthesizing = false;
  String _ttsStatus = "TTS准备就绪";
  bool _isPlaying = false;

  // 文本输入控制器
  final TextEditingController _textController = TextEditingController();

  // 动画控制器
  late AnimationController _waveAnimationController;
  late AnimationController _ttsAnimationController;
  late Animation<double> _waveAnimation;
  late Animation<double> _ttsAnimation;

  // Tab控制器
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _initializeConfig();
    _initializeTTSConfig();
    _btnOnClick = _startRecognize;
    _setupTTSListener();
    _initializeAnimations();
    _textController.text = "这是一个语音助手测试，可以进行语音识别和语音合成。";
    _tabController = TabController(length: 2, vsync: this);
  }

  void _initializeAnimations() {
    _waveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _ttsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveAnimationController,
      curve: Curves.easeInOut,
    ));

    _ttsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _ttsAnimationController,
      curve: Curves.elasticOut,
    ));
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

  void _initializeTTSConfig() {
    _ttsConfig = TTSControllerConfig();
    _ttsConfig.secretId = TencentCloudConfig.secretID;
    _ttsConfig.secretKey = TencentCloudConfig.secretKey;
    
    _ttsConfig.voiceSpeed = 0;
    _ttsConfig.voiceVolume = 1;
    _ttsConfig.voiceType = 1001;
    _ttsConfig.voiceLanguage = 1;
    _ttsConfig.codec = "mp3";
    _ttsConfig.connectTimeout = 10 * 1000;
    _ttsConfig.readTimeout = 20 * 1000;
    
    TTSController.instance.config = _ttsConfig;
  }

  void _setupTTSListener() {
    TTSController.instance.listener.listen(
      (TTSData data) {
        setState(() {
          _isSynthesizing = false;
          _ttsStatus = "语音合成完成，正在播放...";
        });
        _ttsAnimationController.stop();
        log("TTS合成完成，音频数据大小: ${data.data.length} bytes");
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('语音合成成功，正在播放！'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
      onError: (error) {
        _ttsAnimationController.stop();
        if (error is TTSError) {
          String errorMsg = _getTTSErrorMessage(error);
          setState(() {
            _isSynthesizing = false;
            _ttsStatus = errorMsg;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(errorMsg)),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      },
    );

    TTSController.instance.playerEventListener.listen(
      (String event) {
        setState(() {
          if (event == "playStart") {
            _isPlaying = true;
            _ttsStatus = "正在播放...";
          } else if (event == "playComplete") {
            _isPlaying = false;
            _ttsStatus = "播放完成";
          }
        });
      },
      onError: (error) {
        setState(() {
          _isPlaying = false;
          _ttsStatus = "播放错误: $error";
        });
      },
    );
  }

  String _getTTSErrorMessage(TTSError error) {
    if (error.code == 1006) {
      return "音频播放失败，请检查设备音量";
    } else if (error.code >= 5000 && error.code <= 5999) {
      return "网络错误，请检查网络连接";
    } else if (error.serverMessage != null) {
      return "服务器错误: ${error.serverMessage}";
    } else {
      return "TTS错误 (${error.code}): ${error.message}";
    }
  }

  Future<void> _startRecognize() async {
    if (!TencentCloudConfig.isConfigValid) {
      setState(() {
        _result = TencentCloudConfig.configErrorMessage;
        _asrStatus = "配置错误";
      });
      return;
    }

    try {
      if (_controller != null) {
        await _controller?.release();
      }
      
      setState(() {
        _isRecognizing = true;
        _asrStatus = "正在初始化...";
        _result = "";
        _sentences = [];
      });

      _waveAnimationController.repeat();
      _initializeConfig();
      
      _controller = await _config.build();
      
      setState(() {
        _btnOnClick = _stopRecognize;
        _asrStatus = "正在识别中...";
      });

      await for (final data in _controller!.recognize()) {
        switch (data.type) {
          case ASRDataType.SLICE:
          case ASRDataType.SEGMENT:
            var id = data.id!;
            var res = data.res!;
            
            if (id >= _sentences.length) {
              for (var i = _sentences.length; i <= id; i++) {
                _sentences.add("");
              }
            }
            _sentences[id] = res;
            
            setState(() {
              _result = _sentences.map((e) => e).join("");
              _asrStatus = "正在识别中... (实时结果)";
            });
            break;
            
          case ASRDataType.SUCCESS:
            _waveAnimationController.stop();
            setState(() {
              _btnOnClick = _startRecognize;
              _result = data.result ?? _result;
              _sentences = [];
              _isRecognizing = false;
              _asrStatus = "识别完成";
            });
            break;
            
          case ASRDataType.NOTIFY:
            log("通知信息: ${data.info}");
            break;
        }
      }
    } on ASRError catch (e) {
      _waveAnimationController.stop();
      setState(() {
        _btnOnClick = _startRecognize;
        _result = "错误码：${e.code}\n错误信息: ${e.message}\n详细信息: ${e.resp ?? '无'}";
        _isRecognizing = false;
        _asrStatus = "识别错误";
      });
    } catch (e) {
      _waveAnimationController.stop();
      setState(() {
        _btnOnClick = _startRecognize;
        _result = "发生未知错误: ${e.toString()}";
        _isRecognizing = false;
        _asrStatus = "识别异常";
      });
    }
  }

  Future<void> _stopRecognize() async {
    try {
      await _controller?.stop();
      _waveAnimationController.stop();
      setState(() {
        _btnOnClick = _startRecognize;
        _isRecognizing = false;
        _asrStatus = "已停止识别";
      });
    } catch (e) {
      log("停止识别异常: ${e.toString()}");
    }
  }

  Future<void> _synthesizeText(String text) async {
    if (!TencentCloudConfig.isConfigValid) {
      setState(() {
        _ttsStatus = TencentCloudConfig.configErrorMessage;
      });
      return;
    }

    if (text.isEmpty) {
      setState(() {
        _ttsStatus = "没有可播报的内容";
      });
      return;
    }

    String textToSynthesize = _cleanTextForTTS(text);
    if (textToSynthesize.isEmpty) {
      setState(() {
        _ttsStatus = "文本内容无效，无法合成";
      });
      return;
    }

    try {
      setState(() {
        _isSynthesizing = true;
        _ttsStatus = "正在合成语音...";
      });

      _ttsAnimationController.repeat();
      _initializeTTSConfig();
      
      await TTSController.instance.synthesize(textToSynthesize, null);
    } catch (e) {
      _ttsAnimationController.stop();
      setState(() {
        _isSynthesizing = false;
        _ttsStatus = "语音合成失败: ${e.toString()}";
      });
    }
  }

  String _cleanTextForTTS(String text) {
    if (text.isEmpty) return text;
    
    String cleanedText = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    if (cleanedText.length > 150) {
      cleanedText = cleanedText.substring(0, 150);
    }
    
    if (cleanedText.length < 2 || RegExp(r'^[。，、；：！？\s]*$').hasMatch(cleanedText)) {
      cleanedText = "语音识别结果：$cleanedText";
    }
    
    return cleanedText;
  }

  void _clearAll() {
    setState(() {
      _result = "";
      _sentences = [];
      _asrStatus = "准备就绪";
      _ttsStatus = "TTS准备就绪";
      _isPlaying = false;
      _textController.clear();
    });
  }

  @override
  void dispose() {
    _controller?.release();
    TTSController.instance.release();
    _waveAnimationController.dispose();
    _ttsAnimationController.dispose();
    _textController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语音助手'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearAll,
            tooltip: '清空所有',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.mic), text: '语音识别'),
            Tab(icon: Icon(Icons.volume_up), text: '语音合成'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2196F3),
              Color(0xFFF5F5F5),
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildASRTab(),
            _buildTTSTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildASRTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 状态卡片
          _buildStatusCard(
            icon: _isRecognizing ? Icons.mic : Icons.mic_off,
            title: "语音识别",
            status: _asrStatus,
            isActive: _isRecognizing,
            color: Colors.green,
            animation: _waveAnimation,
          ),
          
          const SizedBox(height: 20),
          
          // 控制按钮
          _buildASRControls(),
          
          const SizedBox(height: 20),
          
          // 结果显示
          Expanded(
            child: _buildResultCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildTTSTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // TTS状态卡片
          _buildStatusCard(
            icon: _isSynthesizing ? Icons.volume_up : Icons.volume_off,
            title: "语音合成",
            status: _ttsStatus,
            isActive: _isSynthesizing,
            color: Colors.blue,
            animation: _ttsAnimation,
          ),
          
          const SizedBox(height: 20),
          
          // 文本输入
          _buildTextInput(),
          
          const SizedBox(height: 20),
          
          // TTS控制按钮
          _buildTTSControls(),
          
          const SizedBox(height: 20),
          
          // 快捷文本按钮
          _buildQuickTextButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String status,
    required bool isActive,
    required Color color,
    required Animation<double> animation,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isActive ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? color : Colors.grey,
                    width: 3,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: isActive ? color : Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                status,
                style: TextStyle(
                  fontSize: 14,
                  color: isActive ? color : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              if (isActive) ...[
                const SizedBox(height: 16),
                Transform.scale(
                  scale: 0.8 + (animation.value * 0.4),
                  child: Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildASRControls() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _btnOnClick,
            icon: Icon(_isRecognizing ? Icons.stop : Icons.mic),
            label: Text(_isRecognizing ? '停止识别' : '开始识别'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRecognizing ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _result.isNotEmpty ? () => _synthesizeText(_result) : null,
            icon: const Icon(Icons.volume_up),
            label: const Text('播报结果'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTTSControls() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSynthesizing
                    ? null
                    : (_textController.text.isNotEmpty
                        ? () => _synthesizeText(_textController.text)
                        : null),
                icon: _isSynthesizing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isSynthesizing ? '合成中...' : '合成播放'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isPlaying
                    ? () async {
                        await TTSController.instance.stopPlayback();
                      }
                    : null,
                icon: const Icon(Icons.stop),
                label: const Text('停止播放'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _textController,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: '请输入要合成的文本...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
          hintStyle: TextStyle(color: Colors.grey[500]),
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildQuickTextButtons() {
    final quickTexts = [
      '你好，欢迎使用语音助手！',
      '语音识别测试成功。',
      '这是一个语音合成示例。',
      '今天天气不错！',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '快捷文本:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickTexts.map((text) => 
            ElevatedButton(
              onPressed: () {
                _textController.text = text;
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.blue),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(text, style: const TextStyle(fontSize: 12)),
            ),
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                '识别结果',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (_result.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    // 复制功能可以在这里实现
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('结果已复制到剪贴板')),
                    );
                  },
                ),
            ],
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                _result.isEmpty ? '暂无识别结果，请点击"开始识别"按钮开始语音识别...' : _result,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: _result.isEmpty ? Colors.grey[500] : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
