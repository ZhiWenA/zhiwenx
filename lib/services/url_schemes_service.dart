import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../models/url_scheme_config.dart';

/// URL Schemes 服务
class UrlSchemesService {
  static const String _configFileName = 'url_schemes_config.json';
  UrlSchemesConfig? _config;
  
  /// 单例实例
  static final UrlSchemesService _instance = UrlSchemesService._internal();
  factory UrlSchemesService() => _instance;
  UrlSchemesService._internal();

  /// 获取配置
  UrlSchemesConfig? get config => _config;

  /// 初始化服务，加载配置
  Future<void> initialize() async {
    try {
      await _loadConfig();
    } catch (e) {
      debugPrint('Failed to load URL schemes config: $e');
      // 如果加载失败，使用默认配置
      _config = _getDefaultConfig();
    }
  }

  /// 加载配置文件
  Future<void> _loadConfig() async {
    try {
      // 尝试从 assets 加载
      final String configJson = await rootBundle.loadString('assets/config/$_configFileName');
      final Map<String, dynamic> configMap = json.decode(configJson);
      _config = UrlSchemesConfig.fromJson(configMap);
    } catch (e) {
      // 如果 assets 中没有，尝试从本地文件加载
      await _loadFromLocalFile();
    }
  }

  /// 从本地文件加载配置
  Future<void> _loadFromLocalFile() async {
    try {
      final String documentsPath = await _getDocumentsPath();
      final File configFile = File('$documentsPath/$_configFileName');
      
      if (await configFile.exists()) {
        final String configJson = await configFile.readAsString();
        final Map<String, dynamic> configMap = json.decode(configJson);
        _config = UrlSchemesConfig.fromJson(configMap);
      } else {
        throw FileSystemException('Config file not found');
      }
    } catch (e) {
      throw Exception('Failed to load config from local file: $e');
    }
  }

  /// 保存配置到本地文件
  Future<void> saveConfig(UrlSchemesConfig config) async {
    try {
      _config = config;
      final String documentsPath = await _getDocumentsPath();
      final File configFile = File('$documentsPath/$_configFileName');
      
      final String configJson = const JsonEncoder.withIndent('  ').convert(config.toJson());
      await configFile.writeAsString(configJson);
    } catch (e) {
      throw Exception('Failed to save config: $e');
    }
  }

  /// 获取文档目录路径
  Future<String> _getDocumentsPath() async {
    if (kIsWeb) {
      return '/web_storage';
    }
    
    try {
      // 使用 path_provider 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      debugPrint('Failed to get documents directory: $e');
      // 降级到平台特定路径
      if (Platform.isAndroid) {
        return '/data/data/com.tianli.zhiwenx/files';
      } else if (Platform.isIOS) {
        return Directory.systemTemp.path;
      } else {
        return Directory.current.path;
      }
    }
  }

  /// 获取默认配置
  UrlSchemesConfig _getDefaultConfig() {
    return UrlSchemesConfig(
      version: '1.0.0',
      schemes: [
        UrlSchemeItem(
          id: 'xiaohongshu_search',
          name: '小红书搜索',
          description: '在小红书中搜索指定关键词',
          scheme: 'xhsdiscover',
          urlTemplate: 'xhsdiscover://search/result?keyword={keyword}',
          category: 'social',
          parameters: {
            'keyword': ParameterConfig(
              name: 'keyword',
              description: '搜索关键词',
              type: 'string',
              required: true,
              urlEncode: true,
            ),
          },
        ),
        UrlSchemeItem(
          id: 'wechat_scan',
          name: '微信扫一扫',
          description: '打开微信扫一扫功能',
          scheme: 'weixin',
          urlTemplate: 'weixin://scanqrcode',
          category: 'social',
          parameters: {},
        ),
        UrlSchemeItem(
          id: 'alipay_scan',
          name: '支付宝扫一扫',
          description: '打开支付宝扫一扫功能',
          scheme: 'alipays',
          urlTemplate: 'alipays://platformapi/startapp?saId=10000007',
          category: 'payment',
          parameters: {},
        ),
        UrlSchemeItem(
          id: 'taobao_search',
          name: '淘宝搜索',
          description: '在淘宝中搜索商品',
          scheme: 'taobao',
          urlTemplate: 'taobao://s.taobao.com?q={keyword}',
          category: 'shopping',
          parameters: {
            'keyword': ParameterConfig(
              name: 'keyword',
              description: '搜索关键词',
              type: 'string',
              required: true,
              urlEncode: true,
            ),
          },
        ),
        UrlSchemeItem(
          id: 'douyin_search',
          name: '抖音搜索',
          description: '在抖音中搜索内容',
          scheme: 'snssdk1128',
          urlTemplate: 'snssdk1128://search?keyword={keyword}',
          category: 'social',
          parameters: {
            'keyword': ParameterConfig(
              name: 'keyword',
              description: '搜索关键词',
              type: 'string',
              required: true,
              urlEncode: true,
            ),
          },
        ),
        UrlSchemeItem(
          id: 'bilibili_search',
          name: 'B站搜索',
          description: '在B站中搜索视频',
          scheme: 'bilibili',
          urlTemplate: 'bilibili://search?keyword={keyword}',
          category: 'video',
          parameters: {
            'keyword': ParameterConfig(
              name: 'keyword',
              description: '搜索关键词',
              type: 'string',
              required: true,
              urlEncode: true,
            ),
          },
        ),
        UrlSchemeItem(
          id: 'amap_navigation',
          name: '高德地图导航',
          description: '使用高德地图导航到指定位置',
          scheme: 'iosamap',
          urlTemplate: 'iosamap://navi?sourceApplication=zhiwenx&poiname={poiname}&lat={lat}&lon={lon}&dev=0&style=2',
          category: 'navigation',
          parameters: {
            'poiname': ParameterConfig(
              name: 'poiname',
              description: '目的地名称',
              type: 'string',
              required: true,
              urlEncode: true,
            ),
            'lat': ParameterConfig(
              name: 'lat',
              description: '纬度',
              type: 'number',
              required: true,
              urlEncode: false,
            ),
            'lon': ParameterConfig(
              name: 'lon',
              description: '经度',
              type: 'number',
              required: true,
              urlEncode: false,
            ),
          },
        ),
      ],
      metadata: {
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// 执行 URL Scheme
  Future<bool> launchUrlScheme(String schemeId, Map<String, dynamic> parameters) async {
    final scheme = _config?.findSchemeById(schemeId);
    if (scheme == null) {
      throw ArgumentError('URL scheme with id "$schemeId" not found');
    }

    if (!scheme.enabled) {
      throw StateError('URL scheme "$schemeId" is disabled');
    }

    // 验证参数
    for (final entry in scheme.parameters.entries) {
      final paramName = entry.key;
      final paramConfig = entry.value;
      final value = parameters[paramName];

      if (!paramConfig.validateValue(value)) {
        throw ArgumentError('Invalid value for parameter "$paramName": $value');
      }
    }

    try {
      final url = scheme.generateUrl(parameters);
      return await _launchUrl(url);
    } catch (e) {
      throw Exception('Failed to launch URL scheme: $e');
    }
  }

  /// 启动 URL
  Future<bool> _launchUrl(String url) async {
    try {
      debugPrint('Attempting to launch URL: $url');
      
      // 使用 url_launcher 包启动 URL
      final uri = Uri.parse(url);
      final result = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      debugPrint('Launch result: $result');
      return result;
    } catch (e) {
      debugPrint('Failed to launch URL: $url, error: $e');
      return false;
    }
  }

  /// 获取所有可用的 URL Schemes
  List<UrlSchemeItem> getAllSchemes() {
    return _config?.getEnabledSchemes() ?? [];
  }

  /// 根据类别获取 URL Schemes
  List<UrlSchemeItem> getSchemesByCategory(String category) {
    return _config?.getSchemesByCategory(category) ?? [];
  }

  /// 获取所有类别
  List<String> getCategories() {
    return _config?.getCategories() ?? [];
  }

  /// 添加新的 URL Scheme
  Future<void> addScheme(UrlSchemeItem scheme) async {
    if (_config == null) return;

    final updatedSchemes = List<UrlSchemeItem>.from(_config!.schemes);
    updatedSchemes.add(scheme);

    final updatedConfig = _config!.copyWith(
      schemes: updatedSchemes,
      metadata: {
        ..._config!.metadata,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );

    await saveConfig(updatedConfig);
  }

  /// 更新 URL Scheme
  Future<void> updateScheme(String schemeId, UrlSchemeItem updatedScheme) async {
    if (_config == null) return;

    final schemeIndex = _config!.schemes.indexWhere((s) => s.id == schemeId);
    if (schemeIndex == -1) {
      throw ArgumentError('URL scheme with id "$schemeId" not found');
    }

    final updatedSchemes = List<UrlSchemeItem>.from(_config!.schemes);
    updatedSchemes[schemeIndex] = updatedScheme;

    final updatedConfig = _config!.copyWith(
      schemes: updatedSchemes,
      metadata: {
        ..._config!.metadata,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );

    await saveConfig(updatedConfig);
  }

  /// 删除 URL Scheme
  Future<void> removeScheme(String schemeId) async {
    if (_config == null) return;

    final updatedSchemes = _config!.schemes.where((s) => s.id != schemeId).toList();

    final updatedConfig = _config!.copyWith(
      schemes: updatedSchemes,
      metadata: {
        ..._config!.metadata,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );

    await saveConfig(updatedConfig);
  }

  /// 启用/禁用 URL Scheme
  Future<void> toggleScheme(String schemeId, bool enabled) async {
    if (_config == null) return;

    final schemeIndex = _config!.schemes.indexWhere((s) => s.id == schemeId);
    if (schemeIndex == -1) {
      throw ArgumentError('URL scheme with id "$schemeId" not found');
    }

    final scheme = _config!.schemes[schemeIndex];
    final updatedScheme = scheme.copyWith(enabled: enabled);

    await updateScheme(schemeId, updatedScheme);
  }
}
