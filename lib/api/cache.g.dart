// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Cache _$CacheFromJson(Map<String, dynamic> json) => Cache(
      libraryTracks: (json['libraryTracks'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    )
      ..history = (json['history'] as List<dynamic>?)
              ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
              .toList() ??
          []
      ..sorts = (json['sorts'] as List<dynamic>?)
              ?.map((e) => Sorting.fromJson(e as Map<String, dynamic>))
              .toList() ??
          []
      ..searchHistory =
          Cache._searchHistoryFromJson(json['searchHistory2'] as List?)
      ..threadsWarning = json['threadsWarning'] as bool? ?? false
      ..lastUpdateCheck = (json['lastUpdateCheck'] as num?)?.toInt() ?? 0;

Map<String, dynamic> _$CacheToJson(Cache instance) => <String, dynamic>{
      'libraryTracks': instance.libraryTracks,
      'history': instance.history,
      'sorts': instance.sorts,
      'searchHistory2': Cache._searchHistoryToJson(instance.searchHistory),
      'threadsWarning': instance.threadsWarning,
      'lastUpdateCheck': instance.lastUpdateCheck,
    };

SearchHistoryItem _$SearchHistoryItemFromJson(Map<String, dynamic> json) =>
    SearchHistoryItem(
      json['data'],
      $enumDecode(_$SearchHistoryItemTypeEnumMap, json['type']),
    );

Map<String, dynamic> _$SearchHistoryItemToJson(SearchHistoryItem instance) =>
    <String, dynamic>{
      'data': instance.data,
      'type': _$SearchHistoryItemTypeEnumMap[instance.type]!,
    };

const _$SearchHistoryItemTypeEnumMap = {
  SearchHistoryItemType.TRACK: 'TRACK',
  SearchHistoryItemType.ALBUM: 'ALBUM',
  SearchHistoryItemType.ARTIST: 'ARTIST',
  SearchHistoryItemType.PLAYLIST: 'PLAYLIST',
};
