// 腾讯云语音识别配置文件
class TencentCloudConfig {
  static int get appID {
    final appIdStr = const String.fromEnvironment('TENCENT_APP_ID');
    return appIdStr.isNotEmpty ? int.tryParse(appIdStr) ?? 0 : 0;
  }
  
  static int get projectID {
    final projectIdStr = const String.fromEnvironment('TENCENT_PROJECT_ID', defaultValue: '0');
    return int.tryParse(projectIdStr) ?? 0;
  }
  
  static String get secretID {
    return const String.fromEnvironment('TENCENT_SECRET_ID', defaultValue: '');
  }
  
  static String get secretKey {
    return const String.fromEnvironment('TENCENT_SECRET_KEY', defaultValue: '');
  }
  
  static bool get isConfigValid {
    return appID != 0 && 
           secretID.isNotEmpty && 
           secretKey.isNotEmpty;
  }
  
  // 获取配置错误信息
  static String get configErrorMessage {
    if (appID == 0) return "请设置环境变量 TENCENT_APP_ID";
    if (secretID.isEmpty) return "请设置环境变量 TENCENT_SECRET_ID";
    if (secretKey.isEmpty) return "请设置环境变量 TENCENT_SECRET_KEY";
    return "配置参数错误";
  }
}

