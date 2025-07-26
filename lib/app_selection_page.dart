import 'package:flutter/material.dart';
import 'package:tts_plugin/tts_plugin.dart';
import 'dart:developer';
import 'tencent_cloud_config.dart';
import 'services/url_schemes_service.dart';

class AppSelectionPage extends StatefulWidget {
  final String recognizedText;
  
  const AppSelectionPage({super.key, required this.recognizedText});

  @override
  State<AppSelectionPage> createState() => _AppSelectionPageState();
}

class _AppSelectionPageState extends State<AppSelectionPage> {
  late TTSControllerConfig _ttsConfig;
  bool _isSynthesizing = false;
  String _selectedApp = "小红书";
  String _selectedSchemeId = "xiaohongshu_search";
  final UrlSchemesService _urlSchemesService = UrlSchemesService();

  @override
  void initState() {
    super.initState();
    _initializeTTSConfig();
    _setupTTSListener();
    _initializeUrlSchemes();
    _determineApp();
    _autoPlayAndJump();
  }
  
  Future<void> _initializeUrlSchemes() async {
    try {
      await _urlSchemesService.initialize();
    } catch (e) {
      log('Failed to initialize URL schemes service: $e');
    }
  }
  
  void _autoPlayAndJump() {
    // 自动播报
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _playAutoMessage();
      }
    });
    
    // 移除自动跳转，让用户手动选择
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
        if (mounted) {
          setState(() {
            _isSynthesizing = false;
          });
        }
        log("TTS合成完成，音频数据大小: ${data.data.length} bytes");
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isSynthesizing = false;
          });
        }
        log("TTS错误: $error");
      },
    );
  }

  void _determineApp() {
    // 检查是否是电话或视频通话请求
    final text = widget.recognizedText.toLowerCase();
    
    if (text.startsWith('phone:')) {
      _selectedApp = "电话";
      _selectedSchemeId = "phone_call";
    } else if (text.startsWith('video:')) {
      _selectedApp = "微信";
      _selectedSchemeId = "wechat_video";
    } else {
      // 原有的应用匹配逻辑
      if (text.contains('菜') || text.contains('做') || text.contains('食谱')) {
        _selectedApp = "小红书";
        _selectedSchemeId = "xiaohongshu_search";
      } else if (text.contains('视频') || text.contains('电影')) {
        _selectedApp = "抖音";
        _selectedSchemeId = "douyin_search";
      } else if (text.contains('音乐') || text.contains('歌')) {
        _selectedApp = "网易云音乐";
        _selectedSchemeId = "netease_music_search";
      }
    }
  }

  void _playText() {
    if (_isSynthesizing) return;
    
    setState(() {
      _isSynthesizing = true;
    });
    
    TTSController.instance.synthesize(widget.recognizedText, null);
  }
  
  void _playAutoMessage() {
    if (_isSynthesizing) return;
    
    setState(() {
      _isSynthesizing = true;
    });
    
    String message = '';
    final text = widget.recognizedText.toLowerCase();
    
    if (text.startsWith('phone:')) {
      String contactName = text.substring(6); // 移除 'phone:' 前缀
      message = '是否要拨打${contactName}的电话？';
    } else if (text.startsWith('video:')) {
      String contactName = text.substring(6); // 移除 'video:' 前缀
      message = '是否要打开与${contactName}的微信视频通话？';
    } else {
      message = '是否要打开$_selectedApp搜索${widget.recognizedText}？';
    }
    
    TTSController.instance.synthesize(message, null);
  }

  void _confirmAndOpen() async {
    try {
      // 提取搜索关键词
      String keyword = widget.recognizedText;
      
      // 处理特殊格式的文本
      if (keyword.startsWith('phone:') || keyword.startsWith('video:')) {
        keyword = keyword.substring(6); // 移除前缀
      }
      
      // 使用 URL Schemes 服务启动应用
      final success = await _urlSchemesService.launchUrlScheme(_selectedSchemeId, {
        'keyword': keyword,
      });
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('成功启动$_selectedApp'),
              backgroundColor: const Color(0xFF76A4A5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('启动$_selectedApp失败，可能应用未安装'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      log('Failed to launch URL scheme: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('启动应用时发生错误: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
    
    // 成功启动应用后返回主页
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    });
  }

  void _cancel() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 主要确认文本
              _buildConfirmationText(),
              
              const SizedBox(height: 80),
              
              // 底部按钮
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationText() {
    String confirmationText = '';
    final text = widget.recognizedText.toLowerCase();
    
    if (text.startsWith('phone:')) {
      String contactName = text.substring(6);
      confirmationText = '是否要拨打${contactName}的电话？';
    } else if (text.startsWith('video:')) {
      String contactName = text.substring(6);
      confirmationText = '是否要打开与${contactName}的微信视频通话？';
    } else {
      confirmationText = '是否要打开$_selectedApp搜索${widget.recognizedText}？';
    }
    
    return Column(
      children: [
        Text(
          confirmationText,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5D5753),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // 取消按钮（打叉）
        Expanded(
          child: SizedBox(
            height: 80,
            child: ElevatedButton(
              onPressed: _cancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Icon(
                Icons.close,
                size: 40,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 24),
        
        // 确认按钮（打勾）
        Expanded(
          child: SizedBox(
            height: 80,
            child: ElevatedButton(
              onPressed: _confirmAndOpen,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Icon(
                Icons.check,
                size: 40,
              ),
            ),
          ),
        ),
      ],
    );
  }
}