import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'home_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _volume = 0.7;
  double _brightness = 0.6;
  String _fontSize = '大';
  String _voiceSensitivity = '中';
  String _videoApp = '抖音';
  String _musicApp = '网易云音乐';
  
  int _tapCount = 0;
  DateTime? _lastTapTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5),
      body: SafeArea(
        child: Column(
          children: [
            // 状态栏
            _buildStatusBar(),
            
            // 头部导航
            _buildHeader(),
            
            // 主要内容
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 基本设置
                    _buildBasicSettings(),
                    
                    const SizedBox(height: 24),
                    
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

  Widget _buildDeveloperModeEntry() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: GestureDetector(
        onTap: _handleDeveloperModeTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.developer_mode,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
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
    );
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

   // 设置系统音量
    void _setSystemVolume(double volume) {
      try {
        // 在实际应用中，这里会调用原生代码来设置系统音量
        // 静默设置，不显示提醒
        print('音量设置为: ${(volume * 100).round()}%');
      } catch (e) {
        print('设置音量失败: $e');
      }
    }

   // 设置系统亮度
    void _setSystemBrightness(double brightness) {
      try {
        // 在实际应用中，这里会调用原生代码来设置系统亮度
        // 静默设置，不显示提醒
        print('亮度设置为: ${(brightness * 100).round()}%');
      } catch (e) {
        print('设置亮度失败: $e');
      }
    }

   // 设置系统字体大小
   void _setSystemFontSize(String fontSize) {
     try {
       // 在实际应用中，这里会调用原生代码来设置系统字体大小
       // 目前显示设置反馈
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('字体大小已设置为: $fontSize'),
           duration: const Duration(milliseconds: 800),
           backgroundColor: const Color(0xFF76A4A5),
         ),
       );
     } catch (e) {
       print('设置字体大小失败: $e');
     }
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



  Widget _buildBasicSettings() {
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
            '基本设置',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 音量设置
          _buildSliderSetting(
            '音量',
            _volume,
            Icons.volume_down,
            Icons.volume_up,
            (value) {
              setState(() => _volume = value);
              _setSystemVolume(value);
            },
          ),
          
          const SizedBox(height: 24),
          
          // 屏幕亮度设置
          _buildSliderSetting(
            '屏幕亮度',
            _brightness,
            Icons.brightness_low,
            Icons.brightness_high,
            (value) {
              setState(() => _brightness = value);
              _setSystemBrightness(value);
            },
          ),
          
          const SizedBox(height: 24),
          
          // 字体大小设置
          _buildOptionSetting(
            '字体大小',
            _fontSize,
            ['标准', '大', '特大'],
            (value) {
              setState(() => _fontSize = value);
              _setSystemFontSize(value);
            },
          ),
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

  Widget _buildSliderSetting(
    String title,
    double value,
    IconData lowIcon,
    IconData highIcon,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14),
            ),
            Row(
              children: [
                Icon(
                  lowIcon,
                  color: const Color(0xFF76A4A5),
                  size: 16,
                ),
                const SizedBox(width: 16),
                Icon(
                  highIcon,
                  color: const Color(0xFF76A4A5),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF76A4A5),
            inactiveTrackColor: const Color(0xFFB6D2D3).withValues(alpha:0.5),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
            min: 0.0,
            max: 1.0,
          ),
        ),
      ],
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '当前版本',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                'v1.0.3',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFA49D9A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('正在检查更新...'),
                  backgroundColor: Color(0xFF76A4A5),
                ),
              );
            },
            child: const Row(
              children: [
                Text(
                  '检查更新',
                  style: TextStyle(
                    color: Color(0xFF76A4A5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  color: Color(0xFF76A4A5),
                  size: 16,
                ),
              ],
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
          // 开发者模式入口
          _buildDeveloperModeEntry(),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: SizedBox(
              width: 240,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
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