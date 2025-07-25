import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'voice_wake_page.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 尝试加载 .env 文件，如果失败则继续运行
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('Warning: Could not load .env file: $e');
    // 继续运行应用，即使.env文件加载失败
  }
  
  // 请求必要权限
  await _requestPermissions();
  
  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  // 请求麦克风权限
  await Permission.microphone.request();
  
  // 请求存储权限（用于音频缓存）
  await Permission.storage.request();
  
  // 请求网络权限（通常自动授予）
  await Permission.phone.request();
  
  // 检查权限状态
  Map<Permission, PermissionStatus> statuses = await [
    Permission.microphone,
    Permission.storage,
  ].request();
  
  // 打印权限状态
  statuses.forEach((permission, status) {
    print('$permission: $status');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智问X - 老人语音助手',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF76A4A5)),
        fontFamily: '-apple-system',
        useMaterial3: true,
      ),
      home: const VoiceWakePage(),
      routes: {
        '/home': (context) => const HomePage(),
      },
    );
  }
}
