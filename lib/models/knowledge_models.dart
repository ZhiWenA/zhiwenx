class KnowledgeUploadResponse {
  final int code;
  final dynamic data;
  final String msg;

  KnowledgeUploadResponse({
    required this.code,
    this.data,
    required this.msg,
  });

  factory KnowledgeUploadResponse.fromJson(Map<String, dynamic> json) {
    return KnowledgeUploadResponse(
      code: json['code'] as int,
      data: json['data'],
      msg: json['msg'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'data': data,
      'msg': msg,
    };
  }
}

class KnowledgeSearchRequest {
  final String content;
  final int? topN;

  KnowledgeSearchRequest({
    required this.content,
    this.topN,
  });

  factory KnowledgeSearchRequest.fromJson(Map<String, dynamic> json) {
    return KnowledgeSearchRequest(
      content: json['content'] as String,
      topN: json['topN'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      if (topN != null) 'topN': topN,
    };
  }
}

class KnowledgeSearchResult {
  final int id;
  final String content;
  final String summary;
  final String title;
  final double score;
  final String url;

  KnowledgeSearchResult({
    required this.id,
    required this.content,
    required this.summary,
    required this.title,
    required this.score,
    required this.url,
  });

  factory KnowledgeSearchResult.fromJson(Map<String, dynamic> json) {
    return KnowledgeSearchResult(
      id: json['id'] as int,
      content: json['content'] as String,
      summary: json['summary'] as String,
      title: json['title'] as String,
      score: (json['score'] as num).toDouble(),
      url: json['url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'summary': summary,
      'title': title,
      'score': score,
      'url': url,
    };
  }
}

class KnowledgeSearchResponse {
  final int code;
  final List<KnowledgeSearchResult>? data;
  final String msg;

  KnowledgeSearchResponse({
    required this.code,
    this.data,
    required this.msg,
  });

  factory KnowledgeSearchResponse.fromJson(Map<String, dynamic> json) {
    return KnowledgeSearchResponse(
      code: json['code'] as int,
      data: json['data'] != null
          ? (json['data'] as List)
              .map((item) => KnowledgeSearchResult.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      msg: json['msg'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'data': data?.map((item) => item.toJson()).toList(),
      'msg': msg,
    };
  }
}
