import 'package:flutter/material.dart';
import 'package:asr_plugin/asr_plugin.dart';
import 'package:tts_plugin/tts_plugin.dart';
import 'dart:developer';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'tencent_cloud_config.dart';

class SpeechRecognitionPage extends StatefulWidget {
  const SpeechRecognitionPage({super.key});

  @override
  State<SpeechRecognitionPage> createState() => _SpeechRecognitionPageState();
}

class _SpeechRecognitionPageState extends State<SpeechRecognitionPage> {
  ASRController? _controller;
  late ASRControllerConfig _config;
  String _result = "";
  List<String> _sentences = [];
  bool _isRecognizing = false;
  String _status = "准备就绪";
  VoidCallback? _btnOnClick;

  // TTS相关字段
  late TTSControllerConfig _ttsConfig;
  bool _isSynthesizing = false;
  String _ttsStatus = "TTS准备就绪";
  String? _audioFilePath;

  @override
  void initState() {
    super.initState();
    _initializeConfig();
    _initializeTTSConfig();
    _btnOnClick = _startRecognize;
    _setupTTSListener();
  }

  void _initializeConfig() {
    _config = ASRControllerConfig();
    _config.appID = TencentCloudConfig.appID;
    _config.projectID = TencentCloudConfig.projectID;
    _config.secretID = TencentCloudConfig.secretID;
    _config.secretKey = TencentCloudConfig.secretKey;
    
    // 识别引擎配置
    _config.engine_model_type = "16k_zh"; // 中文识别引擎
    _config.filter_dirty = 1; // 过滤脏词
    _config.filter_modal = 0; // 不过滤语气词
    _config.filter_punc = 0; // 不过滤标点符号
    _config.convert_num_mode = 1; // 阿拉伯数字智能转换
    _config.needvad = 1; // 启用人声切分
    _config.word_info = 0; // 不显示词级别时间戳
    
    // 压缩和静音检测配置
    _config.is_compress = true; // 启用音频压缩
    _config.silence_detect = true; // 启用静音检测
    _config.silence_detect_duration = 3000; // 静音检测时长3秒
    _config.is_save_audio_file = false; // 不保存音频文件
  }

  void _initializeTTSConfig() {
    _ttsConfig = TTSControllerConfig();
    _ttsConfig.secretId = TencentCloudConfig.secretID;
    _ttsConfig.secretKey = TencentCloudConfig.secretKey;
    
    _ttsConfig.voiceSpeed = 0; // 正常语速
    _ttsConfig.voiceVolume = 1; // 最大音量
    _ttsConfig.voiceType = 1001; // 智逍遥，情感男声
    _ttsConfig.voiceLanguage = 1; // 中文
    _ttsConfig.codec = "mp3"; // MP3编码
    _ttsConfig.connectTimeout = 10 * 1000; // 10秒连接超时
    _ttsConfig.readTimeout = 20 * 1000; // 20秒读取超时
    
    // 设置TTS配置
    TTSController.instance.config = _ttsConfig;
    
    log("TTS配置初始化完成 - SecretId: ${_ttsConfig.secretId.substring(0, 8)}..., VoiceType: ${_ttsConfig.voiceType}");
  }

  void _setupTTSListener() {
    TTSController.instance.listener.listen(
      (TTSData data) async {
        try {
          final dir = await getTemporaryDirectory();
          final file = await File(
            "${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.${_ttsConfig.codec}"
          ).writeAsBytes(data.data);
          
          setState(() {
            _audioFilePath = file.absolute.path;
            _isSynthesizing = false;
            _ttsStatus = "语音合成完成";
          });
          
          log("TTS合成完成，文件路径: ${file.absolute.path}");
          
          // 显示成功提示
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('语音合成成功！'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          log("保存TTS音频文件异常: ${e.toString()}");
          setState(() {
            _isSynthesizing = false;
            _ttsStatus = "保存音频文件失败";
          });
        }
      },
      onError: (error) {
        if (error is TTSError) {
          String errorMsg = "TTS错误";
          
          switch (error.code) {
            case -104:
              errorMsg = "服务器响应错误，请检查网络连接和配置";
              break;
            case -101:
              errorMsg = "认证失败，请检查SecretId和SecretKey";
              break;
            case -102:
              errorMsg = "请求参数错误";
              break;
            case -103:
              errorMsg = "服务器内部错误";
              break;
            default:
              errorMsg = "TTS错误(${error.code}): ${error.message}";
          }
          
          log("TTS错误 - 错误码: ${error.code}, 错误信息: ${error.message}, 服务端信息: ${error.serverMessage ?? '无'}");
          setState(() {
            _isSynthesizing = false;
            _ttsStatus = errorMsg;
          });
          
          // 显示错误提示
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMsg),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } else {
          log("TTS未知异常: ${error.toString()}");
          setState(() {
            _isSynthesizing = false;
            _ttsStatus = "TTS发生未知错误";
          });
        }
      },
    );
  }

  Future<void> _startRecognize() async {
    if (!TencentCloudConfig.isConfigValid) {
      setState(() {
        _result = TencentCloudConfig.configErrorMessage;
        _status = "配置错误";
      });
      return;
    }

    try {
      if (_controller != null) {
        await _controller?.release();
      }
      
      setState(() {
        _isRecognizing = true;
        _status = "正在初始化...";
        _result = "";
        _sentences = [];
      });

      // 重新初始化配置以确保参数正确
      _initializeConfig();
      
      log("开始构建 ASR 控制器...");
      _controller = await _config.build();
      log("ASR 控制器构建成功");
      
      setState(() {
        _btnOnClick = _stopRecognize;
        _status = "正在识别中...";
      });

      await for (final data in _controller!.recognize()) {
        switch (data.type) {
          case ASRDataType.SLICE:
          case ASRDataType.SEGMENT:
            var id = data.id!;
            var res = data.res!;
            
            // 确保_sentences列表有足够的长度
            if (id >= _sentences.length) {
              for (var i = _sentences.length; i <= id; i++) {
                _sentences.add("");
              }
            }
            _sentences[id] = res;
            
            setState(() {
              _result = _sentences.map((e) => e).join("");
              _status = "正在识别中... (实时结果)";
            });
            break;
            
          case ASRDataType.SUCCESS:
            setState(() {
              _btnOnClick = _startRecognize;
              _result = data.result ?? _result;
              _sentences = [];
              _isRecognizing = false;
              _status = "识别完成";
            });
            break;
            
          case ASRDataType.NOTIFY:
            log("通知信息: ${data.info}");
            break;
        }
      }
    } on ASRError catch (e) {
      setState(() {
        _btnOnClick = _startRecognize;
        _result = "错误码：${e.code}\n错误信息: ${e.message}\n详细信息: ${e.resp ?? '无'}";
        _isRecognizing = false;
        _status = "识别错误";
      });
    } catch (e) {
      log("识别异常: ${e.toString()}");
      setState(() {
        _btnOnClick = _startRecognize;
        _result = "发生未知错误: ${e.toString()}";
        _isRecognizing = false;
        _status = "识别异常";
      });
    }
  }

  Future<void> _stopRecognize() async {
    try {
      await _controller?.stop();
      setState(() {
        _btnOnClick = _startRecognize;
        _isRecognizing = false;
        _status = "已停止识别";
      });
    } catch (e) {
      log("停止识别异常: ${e.toString()}");
    }
  }

  void _clearResult() {
    setState(() {
      _result = "";
      _sentences = [];
      _status = "准备就绪";
      _audioFilePath = null;
      _ttsStatus = "TTS准备就绪";
    });
  }

  Future<void> _synthesizeText() async {
    if (!TencentCloudConfig.isConfigValid) {
      setState(() {
        _ttsStatus = TencentCloudConfig.configErrorMessage;
      });
      return;
    }

    if (_result.isEmpty) {
      setState(() {
        _ttsStatus = "没有可播报的内容";
      });
      return;
    }

    // 清洗和验证文本
    String textToSynthesize = _cleanTextForTTS(_result);
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

      // 重新设置配置以确保参数正确
      _initializeTTSConfig();
      
      log("开始TTS合成，文本: $textToSynthesize");
      await TTSController.instance.synthesize(textToSynthesize, null);
    } catch (e) {
      log("TTS合成异常: ${e.toString()}");
      setState(() {
        _isSynthesizing = false;
        _ttsStatus = "语音合成失败: ${e.toString()}";
      });
    }
  }

  // 清洗文本，移除可能导致TTS失败的字符
  String _cleanTextForTTS(String text) {
    if (text.isEmpty) return text;
    
    // 移除多余的空格和换行符
    String cleanedText = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // 限制文本长度（腾讯云TTS单次请求建议不超过150字符）
    if (cleanedText.length > 150) {
      cleanedText = cleanedText.substring(0, 150);
    }
    
    // 如果文本过短或只包含标点符号，添加一些内容
    if (cleanedText.length < 2 || RegExp(r'^[。，、；：！？\s]*$').hasMatch(cleanedText)) {
      cleanedText = "语音识别结果：$cleanedText";
    }
    
    log("TTS文本清洗：原文本[$text] -> 清洗后[$cleanedText]");
    return cleanedText;
  }

  Future<void> _cancelTTS() async {
    try {
      await TTSController.instance.cancel();
      setState(() {
        _isSynthesizing = false;
        _ttsStatus = "已取消语音合成";
      });
      log("TTS合成已取消");
    } catch (e) {
      log("取消TTS合成异常: ${e.toString()}");
    }
  }

  Future<void> _testTTS() async {
    if (!TencentCloudConfig.isConfigValid) {
      setState(() {
        _ttsStatus = TencentCloudConfig.configErrorMessage;
      });
      return;
    }

    try {
      setState(() {
        _isSynthesizing = true;
        _ttsStatus = "正在测试语音合成...";
      });

      // 重新设置配置以确保参数正确
      _initializeTTSConfig();
      
      const testText = "你好，这是腾讯云语音合成测试。";
      log("开始TTS测试，文本: $testText");
      await TTSController.instance.synthesize(testText, null);
    } catch (e) {
      log("TTS测试异常: ${e.toString()}");
      setState(() {
        _isSynthesizing = false;
        _ttsStatus = "TTS测试失败: ${e.toString()}";
      });
    }
  }

  @override
  void dispose() {
    _controller?.release();
    TTSController.instance.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('实时语音识别DEMO'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearResult,
            tooltip: '清空结果',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 状态显示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: _isRecognizing 
                    ? Colors.green.withValues(alpha:0.1)
                    : Colors.grey.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: _isRecognizing ? Colors.green : Colors.grey,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isRecognizing ? Icons.mic : Icons.mic_off,
                    color: _isRecognizing ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _status,
                    style: TextStyle(
                      color: _isRecognizing ? Colors.green : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isRecognizing) ...[
                    const Spacer(),
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // TTS状态显示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: _isSynthesizing 
                    ? Colors.blue.withValues(alpha:0.1)
                    : Colors.grey.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: _isSynthesizing ? Colors.blue : Colors.grey,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSynthesizing ? Icons.volume_up : Icons.volume_off,
                    color: _isSynthesizing ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _ttsStatus,
                      style: TextStyle(
                        color: _isSynthesizing ? Colors.blue : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_isSynthesizing) ...[
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _btnOnClick,
                  icon: Icon(_isRecognizing ? Icons.stop : Icons.mic),
                  label: Text(_isRecognizing ? '停止识别' : '开始识别'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecognizing ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 12,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isSynthesizing 
                      ? _cancelTTS 
                      : (_result.isNotEmpty ? _synthesizeText : null),
                  icon: Icon(_isSynthesizing ? Icons.stop : Icons.volume_up),
                  label: Text(_isSynthesizing ? '停止播报' : '语音播报'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSynthesizing ? Colors.red : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 辅助按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _clearResult,
                  icon: const Icon(Icons.clear),
                  label: const Text('清空结果'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, 
                      vertical: 10,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: !_isSynthesizing ? _testTTS : null,
                  icon: const Icon(Icons.play_circle),
                  label: const Text('测试TTS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, 
                      vertical: 10,
                    ),
                  ),
                ),
                if (_audioFilePath != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      // 这里可以添加播放音频文件的功能
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('音频文件已保存: $_audioFilePath')),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('播放音频'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, 
                        vertical: 10,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // 结果显示区域
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '识别结果：',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        _result.isEmpty ? '暂无识别结果，请点击"开始识别"按钮开始语音识别...' : _result,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: _result.isEmpty ? Colors.grey[500] : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 提示信息
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.orange.withValues(alpha:0.3)),
              ),
              child: const Text(
                '功能说明：\n'
                '• 语音识别：识别过程中会显示实时结果，静音3秒后自动停止识别\n'
                '• 语音播报：对识别结果进行语音合成并播报\n'
                '• 音频保存：合成的语音会保存为MP3文件',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
