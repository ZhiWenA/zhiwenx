import 'package:flutter/material.dart';
import 'package:zhiwenx/contacts_page.dart';
import 'chat_page.dart';
import 'smart_recording_page.dart';
import 'voice_assistant_page.dart';
import 'voice_wake_page.dart';
import 'automation_rule_page.dart';
import 'global_widget_capture_page.dart';
import 'global_capture_test_page.dart';
import 'action_recording_page.dart';
import 'mcp_config_page.dart';
import 'mcp_test_page.dart';
import 'image_description_page.dart';
import 'pages/url_schemes_page.dart';
import 'pages/url_schemes_mcp_test_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智问X'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 头部区域
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: const Column(
                  children: [
                    Icon(
                      Icons.smart_toy,
                      size: 80,
                      color: Colors.deepPurple,
                    ),
                    SizedBox(height: 20),
                    Text(
                      '智问X',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '测试DEMO',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 功能卡片列表
              _buildFeatureCard(
                context,
                title: '语音助手',
                subtitle: '语音识别 + 语音合成一体化体验',
                icon: Icons.assistant,
                color: Colors.deepPurple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VoiceAssistantPage()),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                context,
                title: 'AI 对话',
                subtitle: '与大模型进行智能对话',
                icon: Icons.chat_bubble_outline,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatPage()),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                context,
                title: '智能录制',
                subtitle: '真实操作录制与跨设备回放',
                icon: Icons.smart_display,
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SmartRecordingPage()),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                context,
                title: '自动化规则',
                subtitle: 'JSON配置驱动的应用自动化操作',
                icon: Icons.rule,
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AutomationRulePage()),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                context,
                title: '全局控件抓取',
                subtitle: '实时抓取屏幕控件信息，辅助规则创建',
                icon: Icons.open_in_new,
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GlobalWidgetCapturePage()),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                context,
                title: 'MCP 配置',
                subtitle: 'Model Context Protocol 服务器配置和管理',
                icon: Icons.extension,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const McpConfigPage()),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                context,
                title: 'MCP 测试',
                subtitle: '测试模型上下文协议功能',
                icon: Icons.psychology,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const McpTestPage()),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                context,
                title: 'URL Schemes 管理',
                subtitle: '管理和配置应用 URL Schemes，支持 MCP 调用',
                icon: Icons.link,
                color: Colors.indigo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UrlSchemesPage()),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                context,
                title: 'URL Schemes MCP 测试',
                subtitle: '测试 URL Schemes MCP Server 功能',
                icon: Icons.api,
                color: Colors.deepPurple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UrlSchemesMcpTestPage()),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                context,
                title: '图片描述',
                subtitle: '基于百度千帆的智能图片理解与分析',
                icon: Icons.image_search,
                color: Colors.cyan,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ImageDescriptionPage()),
                  );
                },
              ),

              const SizedBox(height: 16),
              
              _buildFeatureCard(
                context,
                title: '功能测试',
                subtitle: '测试全局抓取和悬浮窗功能',
                icon: Icons.bug_report,
                color: Colors.deepOrange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GlobalCaptureTestPage()),
                  );
                },
              ),

                            const SizedBox(height: 16),
              
              _buildFeatureCard(
                context,
                title: '联系人信息',
                subtitle: '获取和管理设备联系人信息',
                icon: Icons.contacts,
                color: Colors.indigo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ContactsPage()),
                  );
                },
              ),
              
              
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                context,
                title: '老人语音助手界面',
                subtitle: '专为老年人设计的语音交互界面',
                icon: Icons.elderly,
                color: const Color(0xFF76A4A5),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VoiceWakePage()),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                context,
                title: '智能辅助控制台',
                subtitle: '操作录制、回放与无障碍服务',
                icon: Icons.accessibility_new,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ActionRecordingPage()),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // 底部留白，确保最后一个卡片不会贴底
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }


}
