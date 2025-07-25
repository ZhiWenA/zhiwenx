/// URL Scheme 配置项
class UrlSchemeItem {
  final String id;
  final String name;
  final String description;
  final String scheme;
  final String urlTemplate;
  final Map<String, ParameterConfig> parameters;
  final String? category;
  final bool enabled;

  const UrlSchemeItem({
    required this.id,
    required this.name,
    required this.description,
    required this.scheme,
    required this.urlTemplate,
    required this.parameters,
    this.category,
    this.enabled = true,
  });

  factory UrlSchemeItem.fromJson(Map<String, dynamic> json) {
    return UrlSchemeItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      scheme: json['scheme'] as String,
      urlTemplate: json['url_template'] as String,
      parameters: (json['parameters'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(
                key,
                ParameterConfig.fromJson(value as Map<String, dynamic>),
              )),
      category: json['category'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'scheme': scheme,
      'url_template': urlTemplate,
      'parameters': parameters.map((key, value) => MapEntry(key, value.toJson())),
      if (category != null) 'category': category,
      'enabled': enabled,
    };
  }

  /// 根据参数生成实际的 URL
  String generateUrl(Map<String, dynamic> params) {
    String url = urlTemplate;
    
    for (final entry in parameters.entries) {
      final paramName = entry.key;
      final paramConfig = entry.value;
      
      String value;
      if (params.containsKey(paramName)) {
        value = params[paramName].toString();
      } else if (paramConfig.defaultValue != null) {
        value = paramConfig.defaultValue!;
      } else if (paramConfig.required) {
        throw ArgumentError('Required parameter "$paramName" is missing');
      } else {
        continue;
      }
      
      // URL 编码处理
      if (paramConfig.urlEncode) {
        value = Uri.encodeComponent(value);
      }
      
      // 替换模板中的占位符
      url = url.replaceAll('{$paramName}', value);
    }
    
    return url;
  }

  UrlSchemeItem copyWith({
    String? id,
    String? name,
    String? description,
    String? scheme,
    String? urlTemplate,
    Map<String, ParameterConfig>? parameters,
    String? category,
    bool? enabled,
  }) {
    return UrlSchemeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      scheme: scheme ?? this.scheme,
      urlTemplate: urlTemplate ?? this.urlTemplate,
      parameters: parameters ?? this.parameters,
      category: category ?? this.category,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// 参数配置
class ParameterConfig {
  final String name;
  final String description;
  final String type;
  final bool required;
  final String? defaultValue;
  final bool urlEncode;
  final List<String>? enumValues;
  final String? pattern;
  final dynamic min;
  final dynamic max;

  const ParameterConfig({
    required this.name,
    required this.description,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.urlEncode = true,
    this.enumValues,
    this.pattern,
    this.min,
    this.max,
  });

  factory ParameterConfig.fromJson(Map<String, dynamic> json) {
    return ParameterConfig(
      name: json['name'] as String,
      description: json['description'] as String,
      type: json['type'] as String,
      required: json['required'] as bool? ?? false,
      defaultValue: json['default_value'] as String?,
      urlEncode: json['url_encode'] as bool? ?? true,
      enumValues: (json['enum_values'] as List<dynamic>?)?.cast<String>(),
      pattern: json['pattern'] as String?,
      min: json['min'],
      max: json['max'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'type': type,
      'required': required,
      if (defaultValue != null) 'default_value': defaultValue,
      'url_encode': urlEncode,
      if (enumValues != null) 'enum_values': enumValues,
      if (pattern != null) 'pattern': pattern,
      if (min != null) 'min': min,
      if (max != null) 'max': max,
    };
  }

  /// 验证参数值
  bool validateValue(dynamic value) {
    if (value == null) {
      return !required;
    }

    switch (type) {
      case 'string':
        if (value is! String) return false;
        if (pattern != null) {
          return RegExp(pattern!).hasMatch(value);
        }
        if (enumValues != null) {
          return enumValues!.contains(value);
        }
        return true;
      
      case 'number':
        final num? numValue = value is num ? value : num.tryParse(value.toString());
        if (numValue == null) return false;
        if (min != null && numValue < min) return false;
        if (max != null && numValue > max) return false;
        return true;
      
      case 'integer':
        final int? intValue = value is int ? value : int.tryParse(value.toString());
        if (intValue == null) return false;
        if (min != null && intValue < min) return false;
        if (max != null && intValue > max) return false;
        return true;
      
      case 'boolean':
        return value is bool || value.toString().toLowerCase() == 'true' || value.toString().toLowerCase() == 'false';
      
      default:
        return true;
    }
  }
}

/// URL Schemes 配置集合
class UrlSchemesConfig {
  final String version;
  final List<UrlSchemeItem> schemes;
  final Map<String, dynamic> metadata;

  const UrlSchemesConfig({
    required this.version,
    required this.schemes,
    this.metadata = const {},
  });

  factory UrlSchemesConfig.fromJson(Map<String, dynamic> json) {
    return UrlSchemesConfig(
      version: json['version'] as String,
      schemes: (json['schemes'] as List<dynamic>)
          .map((e) => UrlSchemeItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'schemes': schemes.map((e) => e.toJson()).toList(),
      'metadata': metadata,
    };
  }

  /// 根据 ID 查找 scheme
  UrlSchemeItem? findSchemeById(String id) {
    try {
      return schemes.firstWhere((scheme) => scheme.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 根据类别获取 schemes
  List<UrlSchemeItem> getSchemesByCategory(String category) {
    return schemes.where((scheme) => scheme.category == category && scheme.enabled).toList();
  }

  /// 获取所有启用的 schemes
  List<UrlSchemeItem> getEnabledSchemes() {
    return schemes.where((scheme) => scheme.enabled).toList();
  }

  /// 获取所有类别
  List<String> getCategories() {
    return schemes
        .where((scheme) => scheme.category != null)
        .map((scheme) => scheme.category!)
        .toSet()
        .toList();
  }

  UrlSchemesConfig copyWith({
    String? version,
    List<UrlSchemeItem>? schemes,
    Map<String, dynamic>? metadata,
  }) {
    return UrlSchemesConfig(
      version: version ?? this.version,
      schemes: schemes ?? this.schemes,
      metadata: metadata ?? this.metadata,
    );
  }
}
