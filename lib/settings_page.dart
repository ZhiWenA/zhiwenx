import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'home_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _voiceSensitivity = '中';
  String _videoApp = '抖音';
  String _musicApp = '网易云音乐';
  String _appVersion = '加载中...';
  
  int _tapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = 'v${packageInfo.version}';
      });
    } catch (e) {
      setState(() {
        _appVersion = 'v1.0.0';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5),
      body: SafeArea(
        child: Column(
          children: [
            // 头部导航
            _buildHeader(),
            
            // 主要内容
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 高级设置
                    _buildAdvancedSettings(),
                    
                    const SizedBox(height: 24),
                    
                    // 应用信息
                    _buildAppInfo(),
                  ],
                ),
              ),
            ),
            
            // 底部保存按钮
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  // 保存设置
  void _saveSettings() {
    // 在这里添加保存设置到本地存储的逻辑
    // 例如使用 SharedPreferences
    print('保存设置: 语音识别灵敏度=$_voiceSensitivity, 视频应用=$_videoApp, 音乐应用=$_musicApp');
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
    }
   }

   Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              children: [
                Icon(
                  Icons.arrow_back,
                  color: Color(0xFF76A4A5),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  '返回',
                  style: TextStyle(
                    color: Color(0xFF76A4A5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '设置',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D5753),
            ),
          ),
          const SizedBox(width: 64), // 占位符保持居中
        ],
      ),
    );
  }



  Widget _buildAdvancedSettings() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '高级设置',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 语音识别灵敏度
          _buildOptionSetting(
            '语音识别灵敏度',
            _voiceSensitivity,
            ['低', '中', '高'],
            (value) => setState(() => _voiceSensitivity = value),
          ),
          
          const SizedBox(height: 24),
          
          // 常用应用设置
          _buildAppSettings(),
        ],
      ),
    );
  }

  Widget _buildOptionSetting(
    String title,
    String currentValue,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          children: options.map((option) {
            final isSelected = option == currentValue;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => onChanged(option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF76A4A5)
                          : const Color(0xFFF9F7F5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF5D5753),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAppSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '常用应用设置',
              style: TextStyle(fontSize: 14),
            ),
            GestureDetector(
              onTap: () {
                // 编辑应用设置
              },
              child: const Icon(
                Icons.edit,
                color: Color(0xFF76A4A5),
                size: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildAppItem('视频应用', _videoApp, Icons.videocam),
        const SizedBox(height: 12),
        _buildAppItem('音乐应用', _musicApp, Icons.music_note),
      ],
    );
  }

  Widget _buildAppItem(String category, String appName, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF76A4A5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            appName,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFA49D9A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '应用信息',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '当前版本',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                _appVersion,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFA49D9A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 开发者模式入口
          GestureDetector(
            onTap: _handleDeveloperModeTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.developer_mode,
                    color: Colors.orange,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '开发者模式',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      color: const Color(0xFFF9F7F5),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: SizedBox(
              width: 240,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // 保存设置的逻辑
                  _saveSettings();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('设置已保存'),
                      backgroundColor: Color(0xFF76A4A5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF76A4A5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, size: 16),
                    SizedBox(width: 8),
                    Text(
                      '保存设置并返回',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
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