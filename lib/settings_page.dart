import 'package:flutter/material.dart';

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
                    // 设置入口提示
                    _buildInfoCard(),
                    
                    const SizedBox(height: 24),
                    
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

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Color(0xFF76A4A5),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '设置入口',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '在主界面连续点击五次进入设置界面',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFA49D9A),
            ),
          ),
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
            (value) => setState(() => _volume = value),
          ),
          
          const SizedBox(height: 24),
          
          // 屏幕亮度设置
          _buildSliderSetting(
            '屏幕亮度',
            _brightness,
            Icons.brightness_low,
            Icons.brightness_high,
            (value) => setState(() => _brightness = value),
          ),
          
          const SizedBox(height: 24),
          
          // 字体大小设置
          _buildOptionSetting(
            '字体大小',
            _fontSize,
            ['标准', '大', '特大'],
            (value) => setState(() => _fontSize = value),
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
            inactiveTrackColor: const Color(0xFFB6D2D3).withOpacity(0.5),
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