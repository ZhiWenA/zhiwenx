import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 平台内容知识库服务
/// 用于根据用户查询内容智能推荐最适合的应用平台
class PlatformKnowledgeService {
  static PlatformKnowledgeService? _instance;
  static PlatformKnowledgeService get instance => _instance ??= PlatformKnowledgeService._();
  
  PlatformKnowledgeService._();
  
  Map<String, dynamic>? _knowledgeBase;
  bool _isInitialized = false;
  
  /// 初始化知识库
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/knowledge/platform_content_knowledge.json'
      );
      _knowledgeBase = json.decode(jsonString);
      _isInitialized = true;
      debugPrint('Platform knowledge base initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize platform knowledge base: $e');
      _knowledgeBase = null;
    }
  }
  
  /// 检查是否已初始化
  bool get isInitialized => _isInitialized && _knowledgeBase != null;
  
  /// 根据用户查询推荐最适合的平台
  PlatformRecommendation? recommendPlatform(String userQuery) {
    if (!isInitialized) {
      debugPrint('Platform knowledge base not initialized');
      return null;
    }
    
    final query = userQuery.toLowerCase();
    final platforms = _knowledgeBase!['platforms'] as Map<String, dynamic>;
    final decisionRules = _knowledgeBase!['decision_rules'] as Map<String, dynamic>;
    
    // 1. 首先尝试规则匹配
    final ruleMatch = _matchByRules(query, decisionRules);
    if (ruleMatch != null) {
      return ruleMatch;
    }
    
    // 2. 关键词匹配
    final keywordMatch = _matchByKeywords(query, platforms);
    if (keywordMatch != null) {
      return keywordMatch;
    }
    
    // 3. 内容类型匹配
    final contentMatch = _matchByContent(query, platforms);
    if (contentMatch != null) {
      return contentMatch;
    }
    
    // 4. 降级策略
    return _getFallbackRecommendation(decisionRules);
  }
  
  /// 规则匹配
  PlatformRecommendation? _matchByRules(String query, Map<String, dynamic> decisionRules) {
    final contentMatching = decisionRules['content_matching'] as Map<String, dynamic>;
    final rules = contentMatching['rules'] as List<dynamic>;
    
    for (final rule in rules) {
      final ruleMap = rule as Map<String, dynamic>;
      final condition = ruleMap['condition'] as String;
      final platform = ruleMap['platform'] as String;
      final confidence = (ruleMap['confidence'] as num).toDouble();
      
      // 简单的关键词匹配逻辑
      if (_matchesCondition(query, condition)) {
        return PlatformRecommendation(
          platformId: platform,
          confidence: confidence,
          reason: '规则匹配: $condition',
          matchType: MatchType.rule,
        );
      }
    }
    
    return null;
  }
  
  /// 关键词匹配
  PlatformRecommendation? _matchByKeywords(String query, Map<String, dynamic> platforms) {
    double bestScore = 0.0;
    String? bestPlatform;
    List<String> matchedKeywords = [];
    
    for (final entry in platforms.entries) {
      final platformId = entry.key;
      final platformData = entry.value as Map<String, dynamic>;
      final keywords = (platformData['keywords'] as List<dynamic>)
          .map((k) => k.toString().toLowerCase())
          .toList();
      
      final matches = keywords.where((keyword) => query.contains(keyword)).toList();
      final score = matches.length / keywords.length;
      
      if (score > bestScore && matches.isNotEmpty) {
        bestScore = score;
        bestPlatform = platformId;
        matchedKeywords = matches;
      }
    }
    
    if (bestPlatform != null && bestScore > 0.1) {
      return PlatformRecommendation(
        platformId: bestPlatform,
        confidence: (bestScore * 0.8).clamp(0.0, 1.0), // 关键词匹配置信度稍低
        reason: '关键词匹配: ${matchedKeywords.join(", ")}',
        matchType: MatchType.keyword,
      );
    }
    
    return null;
  }
  
  /// 内容类型匹配
  PlatformRecommendation? _matchByContent(String query, Map<String, dynamic> platforms) {
    double bestScore = 0.0;
    String? bestPlatform;
    List<String> matchedContent = [];
    
    for (final entry in platforms.entries) {
      final platformId = entry.key;
      final platformData = entry.value as Map<String, dynamic>;
      final suitableContent = (platformData['suitable_content'] as List<dynamic>)
          .map((c) => c.toString().toLowerCase())
          .toList();
      
      final matches = suitableContent.where((content) => 
          query.contains(content) || _semanticMatch(query, content)
      ).toList();
      final score = matches.length / suitableContent.length;
      
      if (score > bestScore && matches.isNotEmpty) {
        bestScore = score;
        bestPlatform = platformId;
        matchedContent = matches;
      }
    }
    
    if (bestPlatform != null && bestScore > 0.05) {
      return PlatformRecommendation(
        platformId: bestPlatform,
        confidence: (bestScore * 0.6).clamp(0.0, 1.0), // 内容匹配置信度更低
        reason: '内容类型匹配: ${matchedContent.join(", ")}',
        matchType: MatchType.content,
      );
    }
    
    return null;
  }
  
  /// 降级策略
  PlatformRecommendation _getFallbackRecommendation(Map<String, dynamic> decisionRules) {
    final fallbackStrategy = decisionRules['fallback_strategy'] as Map<String, dynamic>;
    final defaultPlatforms = (fallbackStrategy['default_platforms'] as List<dynamic>)
        .map((p) => p.toString())
        .toList();
    
    return PlatformRecommendation(
      platformId: defaultPlatforms.first,
      confidence: 0.3,
      reason: '默认推荐策略',
      matchType: MatchType.fallback,
    );
  }
  
  /// 检查是否匹配条件
  bool _matchesCondition(String query, String condition) {
    // 提取条件中的关键词
    final keywords = _extractKeywordsFromCondition(condition);
    return keywords.any((keyword) => query.contains(keyword));
  }
  
  /// 从条件中提取关键词
  List<String> _extractKeywordsFromCondition(String condition) {
    // 简单的关键词提取逻辑
    final regex = RegExp(r'([\u4e00-\u9fa5]+)');
    final matches = regex.allMatches(condition);
    return matches.map((match) => match.group(0)!.toLowerCase()).toList();
  }
  
  /// 语义匹配（简单实现）
  bool _semanticMatch(String query, String content) {
    // 简单的语义匹配，可以后续扩展为更复杂的算法
    final queryWords = query.split('');
    final contentWords = content.split('');
    
    int commonChars = 0;
    for (final char in queryWords) {
      if (contentWords.contains(char)) {
        commonChars++;
      }
    }
    
    return commonChars >= 2; // 至少有2个相同字符
  }
  
  /// 获取平台信息
  PlatformInfo? getPlatformInfo(String platformId) {
    if (!isInitialized) return null;
    
    final platforms = _knowledgeBase!['platforms'] as Map<String, dynamic>;
    final platformData = platforms[platformId] as Map<String, dynamic>?;
    
    if (platformData == null) return null;
    
    return PlatformInfo(
      id: platformId,
      name: platformData['name'] as String,
      category: platformData['category'] as String,
      suitableContent: (platformData['suitable_content'] as List<dynamic>)
          .map((c) => c.toString())
          .toList(),
      keywords: (platformData['keywords'] as List<dynamic>)
          .map((k) => k.toString())
          .toList(),
      useCases: (platformData['use_cases'] as List<dynamic>)
          .map((u) => u.toString())
          .toList(),
    );
  }
  
  /// 获取所有平台列表
  List<String> getAllPlatformIds() {
    if (!isInitialized) return [];
    
    final platforms = _knowledgeBase!['platforms'] as Map<String, dynamic>;
    return platforms.keys.toList();
  }
  
  /// 根据类别获取平台
  List<String> getPlatformsByCategory(String category) {
    if (!isInitialized) return [];
    
    final platforms = _knowledgeBase!['platforms'] as Map<String, dynamic>;
    return platforms.entries
        .where((entry) => (entry.value as Map<String, dynamic>)['category'] == category)
        .map((entry) => entry.key)
        .toList();
  }
}

/// 平台推荐结果
class PlatformRecommendation {
  final String platformId;
  final double confidence;
  final String reason;
  final MatchType matchType;
  
  const PlatformRecommendation({
    required this.platformId,
    required this.confidence,
    required this.reason,
    required this.matchType,
  });
  
  @override
  String toString() {
    return 'PlatformRecommendation(platformId: $platformId, confidence: $confidence, reason: $reason, matchType: $matchType)';
  }
}

/// 匹配类型
enum MatchType {
  rule,      // 规则匹配
  keyword,   // 关键词匹配
  content,   // 内容类型匹配
  fallback,  // 降级策略
}

/// 平台信息
class PlatformInfo {
  final String id;
  final String name;
  final String category;
  final List<String> suitableContent;
  final List<String> keywords;
  final List<String> useCases;
  
  const PlatformInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.suitableContent,
    required this.keywords,
    required this.useCases,
  });
  
  @override
  String toString() {
    return 'PlatformInfo(id: $id, name: $name, category: $category)';
  }
}