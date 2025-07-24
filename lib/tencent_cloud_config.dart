// 腾讯云语音识别配置文件
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TencentCloudConfig {
  static int get appID {
    final appIdStr = dotenv.env['TENCENT_APP_ID'] ?? '';
    return appIdStr.isNotEmpty ? int.tryParse(appIdStr) ?? 0 : 0;
  }
  
  static int get projectID {
    final projectIdStr = dotenv.env['TENCENT_PROJECT_ID'] ?? '0';
    return int.tryParse(projectIdStr) ?? 0;
  }
  
  static String get secretID {
    return dotenv.env['TENCENT_SECRET_ID'] ?? '';
  }
  
  static String get secretKey {
    return dotenv.env['TENCENT_SECRET_KEY'] ?? '';
  }
  
  static bool get isConfigValid {
    return appID != 0 && 
           secretID.isNotEmpty && 
           secretKey.isNotEmpty;
  }
  
  // 获取配置错误信息
  static String get configErrorMessage {
    if (appID == 0) return "请在 .env 文件中设置 TENCENT_APP_ID";
    if (secretID.isEmpty) return "请在 .env 文件中设置 TENCENT_SECRET_ID";
    if (secretKey.isEmpty) return "请在 .env 文件中设置 TENCENT_SECRET_KEY";
    return "配置参数错误";
  }
}

