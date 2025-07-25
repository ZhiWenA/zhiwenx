import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:asr_plugin/asr_plugin.dart';
import 'package:tts_plugin/tts_plugin.dart';
import 'tencent_cloud_config.dart';

/// 语音服务类，统一管理语音识别和语音合成功能
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  // ASR相关
  ASRController? _asrController;
  StreamSubscription<ASRData>? _asrSubscription;
  final StreamController<String> _speechResultController = StreamController<String>.broadcast();
  final StreamController<VoiceState> _voiceStateController = StreamController<VoiceState>.broadcast();
  
  // TTS相关
  final TTSController _ttsController = TTSController.instance;
  StreamSubscription<TTSData>? _ttsSubscription;
  StreamSubscription<String>? _ttsPlayerSubscription;
  
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isInitialized = false;

  // 语音状态枚举
  Stream<String> get speechResultStream => _speechResultController.stream;
  Stream<VoiceState> get voiceStateStream => _voiceStateController.stream;
  
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;

  /// 初始化语音服务
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // 检查腾讯云配置
      if (!TencentCloudConfig.isConfigValid) {
        debugPrint('腾讯云配置无效: ${TencentCloudConfig.configErrorMessage}');
        return false;
      }

      // 初始化ASR配置
      await _initializeASR();
      
      // 初始化TTS配置
      await _initializeTTS();
      
      _isInitialized = true;
      _voiceStateController.add(VoiceState.ready);
      return true;
    } catch (e) {
      debugPrint('语音服务初始化失败: $e');
      _voiceStateController.add(VoiceState.error);
      return false;
    }
  }

  /// 初始化ASR
  Future<void> _initializeASR() async {
    final config = ASRControllerConfig();
    config.appID = TencentCloudConfig.appID;
    config.projectID = TencentCloudConfig.projectID;
    config.secretID = TencentCloudConfig.secretID;
    config.secretKey = TencentCloudConfig.secretKey;
    
    // 设置识别参数
    config.engine_model_type = "16k_zh"; // 中文识别
    config.filter_dirty = 1; // 过滤脏词
    config.filter_modal = 1; // 过滤语气词
    config.filter_punc = 0; // 不过滤标点符号
    config.convert_num_mode = 1; // 数字智能转换
    config.needvad = 1; // 开启人声切分
    config.vad_silence_time = 1000; // 语音断句检测阈值1秒
    config.silence_detect = true; // 开启静音检测
    config.silence_detect_duration = 3000; // 静音检测时长3秒
    
    _asrController = await config.build();
  }

  /// 初始化TTS
  Future<void> _initializeTTS() async {
    final config = TTSControllerConfig();
    config.secretId = TencentCloudConfig.secretID;
    config.secretKey = TencentCloudConfig.secretKey;
    
    // 设置语音合成参数
    config.voiceSpeed = 0; // 正常语速
    config.voiceVolume = 1; // 正常音量
    config.voiceType = 601003; // 智瑜音色
    config.voiceLanguage = 1; // 中文
    config.codec = "mp3"; // 音频格式
    
    _ttsController.config = config;
    
    // 监听TTS播放事件
    _ttsPlayerSubscription = _ttsController.playerEventListener.listen(
      (event) {
        switch (event) {
          case 'playStart':
            _isSpeaking = true;
            _voiceStateController.add(VoiceState.speaking);
            break;
          case 'playComplete':
            _isSpeaking = false;
            _voiceStateController.add(VoiceState.ready);
            break;
        }
      },
      onError: (error) {
        _isSpeaking = false;
        _voiceStateController.add(VoiceState.error);
        debugPrint('TTS播放错误: $error');
      },
    );
  }

  /// 开始语音识别
  Future<void> startListening() async {
    if (!_isInitialized || _isListening || _asrController == null) {
      return;
    }

    try {
      _isListening = true;
      _voiceStateController.add(VoiceState.listening);

      String currentResult = '';
      
      _asrSubscription = _asrController!.recognize().listen(
        (data) {
          switch (data.type) {
            case ASRDataType.SLICE:
              // 实时识别结果
              if (data.res != null && data.res!.isNotEmpty) {
                currentResult = data.res!;
                _speechResultController.add(currentResult);
              }
              break;
            case ASRDataType.SEGMENT:
              // 句子分段结果
              if (data.res != null && data.res!.isNotEmpty) {
                currentResult = data.res!;
                _speechResultController.add(currentResult);
              }
              break;
            case ASRDataType.SUCCESS:
              // 最终识别结果
              if (data.result != null && data.result!.isNotEmpty) {
                _speechResultController.add(data.result!);
              }
              break;
            default:
              break;
          }
        },
        onError: (error) {
          _isListening = false;
          _voiceStateController.add(VoiceState.error);
          debugPrint('语音识别错误: $error');
        },
        onDone: () {
          _isListening = false;
          _voiceStateController.add(VoiceState.ready);
        },
      );
    } catch (e) {
      _isListening = false;
      _voiceStateController.add(VoiceState.error);
      debugPrint('开始语音识别失败: $e');
    }
  }

  /// 停止语音识别
  Future<void> stopListening() async {
    if (!_isListening || _asrController == null) return;

    try {
      await _asrController!.stop();
      await _asrSubscription?.cancel();
      _asrSubscription = null;
      _isListening = false;
      _voiceStateController.add(VoiceState.ready);
    } catch (e) {
      debugPrint('停止语音识别失败: $e');
    }
  }

  /// 语音合成并播放
  Future<void> speak(String text) async {
    if (!_isInitialized || text.trim().isEmpty || _isSpeaking) {
      return;
    }

    try {
      // 如果正在录音，先停止录音
      if (_isListening) {
        await stopListening();
        // 等待一小段时间确保录音完全停止
        await Future.delayed(const Duration(milliseconds: 300));
      }

      _isSpeaking = true;
      _voiceStateController.add(VoiceState.speaking);

      // 监听TTS数据
      _ttsSubscription = _ttsController.listener.listen(
        (data) {
          // TTS数据接收成功，开始播放
          debugPrint('TTS数据接收成功，开始播放');
        },
        onError: (error) {
          _isSpeaking = false;
          _voiceStateController.add(VoiceState.error);
          debugPrint('TTS合成错误: $error');
        },
      );

      // 开始语音合成
      await _ttsController.synthesize(text, DateTime.now().millisecondsSinceEpoch.toString());
      
    } catch (e) {
      _isSpeaking = false;
      _voiceStateController.add(VoiceState.error);
      debugPrint('语音合成失败: $e');
    }
  }

  /// 停止语音播放
  Future<void> stopSpeaking() async {
    if (!_isSpeaking) return;

    try {
      await _ttsController.stopPlayback();
      await _ttsSubscription?.cancel();
      _ttsSubscription = null;
      _isSpeaking = false;
      _voiceStateController.add(VoiceState.ready);
    } catch (e) {
      debugPrint('停止语音播放失败: $e');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await stopListening();
    await stopSpeaking();
    
    await _asrSubscription?.cancel();
    await _ttsSubscription?.cancel();
    await _ttsPlayerSubscription?.cancel();
    
    await _asrController?.release();
    await _ttsController.release();
    
    await _speechResultController.close();
    await _voiceStateController.close();
    
    _isInitialized = false;
  }
}

/// 语音状态枚举
enum VoiceState {
  ready,      // 准备就绪
  listening,  // 正在监听
  speaking,   // 正在播放
  error,      // 错误状态
}
