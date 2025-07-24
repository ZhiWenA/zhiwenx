import 'package:flutter/material.dart';
import 'package:asr_plugin/asr_plugin.dart';
import 'dart:developer';
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

  @override
  void initState() {
    super.initState();
    _initializeConfig();
    _btnOnClick = _startRecognize;
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
    });
  }

  @override
  void dispose() {
    _controller?.release();
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
                      horizontal: 20, 
                      vertical: 12,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _clearResult,
                  icon: const Icon(Icons.clear),
                  label: const Text('清空结果'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20, 
                      vertical: 12,
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
                '提示：测试DEMO\n'
                '识别过程中会显示实时结果，静音3秒后自动停止识别。',
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
