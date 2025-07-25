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
    
    // 3秒后自动跳转
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _confirmAndOpen();
      }
    });
  }
  


  void _initializeTTSConfig() {
    _ttsConfig = TTSControllerConfig();
    _ttsConfig.secretId = TencentCloudConfig.secretID;
    _ttsConfig.secretKey = TencentCloudConfig.secretKey;
    
    _ttsConfig.voiceSpeed = 0;
    _ttsConfig.voiceVolume = 1;
    _ttsConfig.voiceType = 601003;
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
      message = '即将为您拨打${contactName}的电话';
    } else if (text.startsWith('video:')) {
      String contactName = text.substring(6); // 移除 'video:' 前缀
      message = '即将为您打开与${contactName}的微信视频通话';
    } else {
      message = '即将前往$_selectedApp';
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
    
    // 延迟后返回主页
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    });
  }

  void _cancel() {
    Navigator.pop(context);
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
            
            // 主要内容
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 识别结果显示
                    _buildRecognitionResult(),
                    
                    const SizedBox(height: 32),
                    
                    // 应用选择卡片
                    _buildAppSelectionCard(),
                  ],
                ),
              ),
            ),
            
            // 底部按钮
            _buildBottomButtons(),
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

  Widget _buildRecognitionResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '您说的是：',
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFFA49D9A),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                widget.recognizedText,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D5753),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _playText,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF76A4A5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isSynthesizing ? Icons.stop : Icons.volume_up,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppSelectionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '即将为您打开',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Color(0xFF5D5753),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 应用图标和名称
          Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.red, // 小红书的红色
                ),
                child: const Icon(
                  Icons.book,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedApp,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5D5753),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Text(
            '搜索：${widget.recognizedText}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Color(0xFF76A4A5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      color: const Color(0xFFF9F7F5),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
            child: Column(
              children: [
                // 确认按钮
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _confirmAndOpen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF76A4A5),
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: Colors.black.withValues(alpha:0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '确认并打开',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 取消按钮
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _cancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF9F7F5),
                      foregroundColor: const Color(0xFF5D5753),
                      elevation: 3,
                      shadowColor: Colors.black.withValues(alpha:0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
}