// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'knowledge_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KnowledgeUploadResponse _$KnowledgeUploadResponseFromJson(
  Map<String, dynamic> json,
) => KnowledgeUploadResponse(
  code: (json['code'] as num).toInt(),
  data: json['data'],
  msg: json['msg'] as String,
);

Map<String, dynamic> _$KnowledgeUploadResponseToJson(
  KnowledgeUploadResponse instance,
) => <String, dynamic>{
  'code': instance.code,
  'data': instance.data,
  'msg': instance.msg,
};

KnowledgeSearchRequest _$KnowledgeSearchRequestFromJson(
  Map<String, dynamic> json,
) => KnowledgeSearchRequest(
  content: json['content'] as String,
  topN: (json['topN'] as num?)?.toInt(),
);

Map<String, dynamic> _$KnowledgeSearchRequestToJson(
  KnowledgeSearchRequest instance,
) => <String, dynamic>{'content': instance.content, 'topN': instance.topN};

KnowledgeSearchResult _$KnowledgeSearchResultFromJson(
  Map<String, dynamic> json,
) => KnowledgeSearchResult(
  id: (json['id'] as num).toInt(),
  content: json['content'] as String,
  summary: json['summary'] as String,
  title: json['title'] as String,
  score: (json['score'] as num).toDouble(),
  url: json['url'] as String,
);

Map<String, dynamic> _$KnowledgeSearchResultToJson(
  KnowledgeSearchResult instance,
) => <String, dynamic>{
  'id': instance.id,
  'content': instance.content,
  'summary': instance.summary,
  'title': instance.title,
  'score': instance.score,
  'url': instance.url,
};

KnowledgeSearchResponse _$KnowledgeSearchResponseFromJson(
  Map<String, dynamic> json,
) => KnowledgeSearchResponse(
  code: (json['code'] as num).toInt(),
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => KnowledgeSearchResult.fromJson(e as Map<String, dynamic>))
      .toList(),
  msg: json['msg'] as String,
);

Map<String, dynamic> _$KnowledgeSearchResponseToJson(
  KnowledgeSearchResponse instance,
) => <String, dynamic>{
  'code': instance.code,
  'data': instance.data,
  'msg': instance.msg,
};
