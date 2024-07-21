// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'definitions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Track _$TrackFromJson(Map<String, dynamic> json) => Track(
      id: json['id'] as String?,
      title: json['title'] as String?,
      duration: json['duration'] == null
          ? null
          : Duration(microseconds: (json['duration'] as num).toInt()),
      album: json['album'] == null
          ? null
          : Album.fromJson(json['album'] as Map<String, dynamic>),
      playbackDetails: json['playbackDetails'] as List<dynamic>?,
      albumArt: json['albumArt'] == null
          ? null
          : ImageDetails.fromJson(json['albumArt'] as Map<String, dynamic>),
      artists: (json['artists'] as List<dynamic>?)
          ?.map((e) => Artist.fromJson(e as Map<String, dynamic>))
          .toList(),
      trackNumber: (json['trackNumber'] as num?)?.toInt(),
      offline: json['offline'] as bool?,
      lyrics: json['lyrics'] == null
          ? null
          : LyricsFull.fromJson(json['lyrics'] as Map<String, dynamic>),
      favorite: json['favorite'] as bool?,
      diskNumber: (json['diskNumber'] as num?)?.toInt(),
      explicit: json['explicit'] as bool?,
      addedDate: (json['addedDate'] as num?)?.toInt(),
      fallback: json['fallback'] == null
          ? null
          : Track.fromJson(json['fallback'] as Map<String, dynamic>),
      playbackDetailsFallback:
          json['playbackDetailsFallback'] as List<dynamic>?,
    );

Map<String, dynamic> _$TrackToJson(Track instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'album': instance.album,
      'artists': instance.artists,
      'duration': instance.duration?.inMicroseconds,
      'albumArt': instance.albumArt,
      'trackNumber': instance.trackNumber,
      'offline': instance.offline,
      'lyrics': instance.lyrics,
      'favorite': instance.favorite,
      'diskNumber': instance.diskNumber,
      'explicit': instance.explicit,
      'addedDate': instance.addedDate,
      'fallback': instance.fallback,
      'playbackDetails': instance.playbackDetails,
      'playbackDetailsFallback': instance.playbackDetailsFallback,
    };

Album _$AlbumFromJson(Map<String, dynamic> json) => Album(
      id: json['id'] as String?,
      title: json['title'] as String?,
      art: json['art'] == null
          ? null
          : ImageDetails.fromJson(json['art'] as Map<String, dynamic>),
      artists: (json['artists'] as List<dynamic>?)
          ?.map((e) => Artist.fromJson(e as Map<String, dynamic>))
          .toList(),
      tracks: (json['tracks'] as List<dynamic>?)
          ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList(),
      fans: (json['fans'] as num?)?.toInt(),
      offline: json['offline'] as bool?,
      library: json['library'] as bool?,
      type: $enumDecodeNullable(_$AlbumTypeEnumMap, json['type']),
      releaseDate: json['releaseDate'] as String?,
      favoriteDate: json['favoriteDate'] as String?,
    );

Map<String, dynamic> _$AlbumToJson(Album instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'artists': instance.artists,
      'tracks': instance.tracks,
      'art': instance.art,
      'fans': instance.fans,
      'offline': instance.offline,
      'library': instance.library,
      'type': _$AlbumTypeEnumMap[instance.type],
      'releaseDate': instance.releaseDate,
      'favoriteDate': instance.favoriteDate,
    };

const _$AlbumTypeEnumMap = {
  AlbumType.ALBUM: 'ALBUM',
  AlbumType.SINGLE: 'SINGLE',
  AlbumType.FEATURED: 'FEATURED',
};

ArtistHighlight _$ArtistHighlightFromJson(Map<String, dynamic> json) =>
    ArtistHighlight(
      data: json['data'],
      type: $enumDecodeNullable(_$ArtistHighlightTypeEnumMap, json['type']),
      title: json['title'] as String?,
    );

Map<String, dynamic> _$ArtistHighlightToJson(ArtistHighlight instance) =>
    <String, dynamic>{
      'data': instance.data,
      'type': _$ArtistHighlightTypeEnumMap[instance.type],
      'title': instance.title,
    };

const _$ArtistHighlightTypeEnumMap = {
  ArtistHighlightType.ALBUM: 'ALBUM',
};

Artist _$ArtistFromJson(Map<String, dynamic> json) => Artist(
      id: json['id'] as String?,
      name: json['name'] as String?,
      albums: (json['albums'] as List<dynamic>?)
              ?.map((e) => Album.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      albumCount: (json['albumCount'] as num?)?.toInt(),
      topTracks: (json['topTracks'] as List<dynamic>?)
              ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      picture: json['picture'] == null
          ? null
          : ImageDetails.fromJson(json['picture'] as Map<String, dynamic>),
      fans: (json['fans'] as num?)?.toInt(),
      offline: json['offline'] as bool?,
      library: json['library'] as bool?,
      radio: json['radio'] as bool?,
      favoriteDate: json['favoriteDate'] as String?,
      highlight: json['highlight'] == null
          ? null
          : ArtistHighlight.fromJson(json['highlight'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ArtistToJson(Artist instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'albums': instance.albums,
      'albumCount': instance.albumCount,
      'topTracks': instance.topTracks,
      'picture': instance.picture,
      'fans': instance.fans,
      'offline': instance.offline,
      'library': instance.library,
      'radio': instance.radio,
      'favoriteDate': instance.favoriteDate,
      'highlight': instance.highlight,
    };

Playlist _$PlaylistFromJson(Map<String, dynamic> json) => Playlist(
      id: json['id'] as String?,
      title: json['title'] as String?,
      tracks: (json['tracks'] as List<dynamic>?)
          ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList(),
      image: json['image'] == null
          ? null
          : ImageDetails.fromJson(json['image'] as Map<String, dynamic>),
      trackCount: (json['trackCount'] as num?)?.toInt(),
      duration: json['duration'] == null
          ? null
          : Duration(microseconds: (json['duration'] as num).toInt()),
      user: json['user'] == null
          ? null
          : User.fromJson(json['user'] as Map<String, dynamic>),
      fans: (json['fans'] as num?)?.toInt(),
      library: json['library'] as bool?,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$PlaylistToJson(Playlist instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'tracks': instance.tracks,
      'image': instance.image,
      'duration': instance.duration?.inMicroseconds,
      'trackCount': instance.trackCount,
      'user': instance.user,
      'fans': instance.fans,
      'library': instance.library,
      'description': instance.description,
    };

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id'] as String?,
      name: json['name'] as String?,
      picture: json['picture'] == null
          ? null
          : ImageDetails.fromJson(json['picture'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'picture': instance.picture,
    };

ImageDetails _$ImageDetailsFromJson(Map<String, dynamic> json) => ImageDetails(
      fullUrl: json['fullUrl'] as String?,
      thumbUrl: json['thumbUrl'] as String?,
      type: json['type'] as String?,
      imageHash: json['imageHash'] as String?,
    );

Map<String, dynamic> _$ImageDetailsToJson(ImageDetails instance) =>
    <String, dynamic>{
      'fullUrl': instance.fullUrl,
      'thumbUrl': instance.thumbUrl,
      'type': instance.type,
      'imageHash': instance.imageHash,
    };

LogoDetails _$LogoDetailsFromJson(Map<String, dynamic> json) => LogoDetails(
      fullUrl: json['fullUrl'] as String?,
      thumbUrl: json['thumbUrl'] as String?,
      type: json['type'] as String?,
      imageHash: json['imageHash'] as String?,
    );

Map<String, dynamic> _$LogoDetailsToJson(LogoDetails instance) =>
    <String, dynamic>{
      'fullUrl': instance.fullUrl,
      'thumbUrl': instance.thumbUrl,
      'type': instance.type,
      'imageHash': instance.imageHash,
    };

LyricsClassic _$LyricsClassicFromJson(Map<String, dynamic> json) =>
    LyricsClassic(
      id: json['id'] as String?,
      writers: json['writers'] as String?,
      syncedLyrics: (json['syncedLyrics'] as List<dynamic>?)
          ?.map((e) => SynchronizedLyric.fromJson(e as Map<String, dynamic>))
          .toList(),
      errorMessage: json['errorMessage'] as String?,
      unsyncedLyrics: json['unsyncedLyrics'] as String?,
    )
      ..isExplicit = json['isExplicit'] as bool?
      ..copyright = json['copyright'] as String?;

Map<String, dynamic> _$LyricsClassicToJson(LyricsClassic instance) =>
    <String, dynamic>{
      'id': instance.id,
      'writers': instance.writers,
      'syncedLyrics': instance.syncedLyrics,
      'errorMessage': instance.errorMessage,
      'unsyncedLyrics': instance.unsyncedLyrics,
      'isExplicit': instance.isExplicit,
      'copyright': instance.copyright,
    };

LyricsFull _$LyricsFullFromJson(Map<String, dynamic> json) => LyricsFull(
      id: json['id'] as String?,
      writers: json['writers'] as String?,
      syncedLyrics: (json['syncedLyrics'] as List<dynamic>?)
          ?.map((e) => SynchronizedLyric.fromJson(e as Map<String, dynamic>))
          .toList(),
      errorMessage: json['errorMessage'] as String?,
      unsyncedLyrics: json['unsyncedLyrics'] as String?,
      isExplicit: json['isExplicit'] as bool?,
      copyright: json['copyright'] as String?,
    );

Map<String, dynamic> _$LyricsFullToJson(LyricsFull instance) =>
    <String, dynamic>{
      'id': instance.id,
      'writers': instance.writers,
      'syncedLyrics': instance.syncedLyrics,
      'errorMessage': instance.errorMessage,
      'unsyncedLyrics': instance.unsyncedLyrics,
      'isExplicit': instance.isExplicit,
      'copyright': instance.copyright,
    };

SynchronizedLyric _$SynchronizedLyricFromJson(Map<String, dynamic> json) =>
    SynchronizedLyric(
      offset: json['offset'] == null
          ? null
          : Duration(microseconds: (json['offset'] as num).toInt()),
      duration: json['duration'] == null
          ? null
          : Duration(microseconds: (json['duration'] as num).toInt()),
      text: json['text'] as String?,
      lrcTimestamp: json['lrcTimestamp'] as String?,
    );

Map<String, dynamic> _$SynchronizedLyricToJson(SynchronizedLyric instance) =>
    <String, dynamic>{
      'offset': instance.offset?.inMicroseconds,
      'duration': instance.duration?.inMicroseconds,
      'text': instance.text,
      'lrcTimestamp': instance.lrcTimestamp,
    };

QueueSource _$QueueSourceFromJson(Map<String, dynamic> json) => QueueSource(
      id: json['id'] as String?,
      text: json['text'] as String?,
      source: json['source'] as String?,
    );

Map<String, dynamic> _$QueueSourceToJson(QueueSource instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'source': instance.source,
    };

SmartTrackList _$SmartTrackListFromJson(Map<String, dynamic> json) =>
    SmartTrackList(
      id: json['id'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      trackCount: (json['trackCount'] as num?)?.toInt(),
      tracks: (json['tracks'] as List<dynamic>?)
          ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList(),
      cover: json['cover'] == null
          ? null
          : ImageDetails.fromJson(json['cover'] as Map<String, dynamic>),
      subtitle: json['subtitle'] as String?,
      flowType: json['flowType'] as String?,
    );

Map<String, dynamic> _$SmartTrackListToJson(SmartTrackList instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'subtitle': instance.subtitle,
      'description': instance.description,
      'trackCount': instance.trackCount,
      'tracks': instance.tracks,
      'cover': instance.cover,
      'flowType': instance.flowType,
    };

HomePage _$HomePageFromJson(Map<String, dynamic> json) => HomePage(
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => HomePageSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$HomePageToJson(HomePage instance) => <String, dynamic>{
      'sections': instance.sections,
    };

HomePageSection _$HomePageSectionFromJson(Map<String, dynamic> json) =>
    HomePageSection(
      layout:
          $enumDecodeNullable(_$HomePageSectionLayoutEnumMap, json['layout']),
      items: HomePageSection._homePageItemFromJson(json['items']),
      title: json['title'] as String?,
      pagePath: json['pagePath'] as String?,
      hasMore: json['hasMore'] as bool?,
    );

Map<String, dynamic> _$HomePageSectionToJson(HomePageSection instance) =>
    <String, dynamic>{
      'title': instance.title,
      'layout': _$HomePageSectionLayoutEnumMap[instance.layout],
      'pagePath': instance.pagePath,
      'hasMore': instance.hasMore,
      'items': HomePageSection._homePageItemToJson(instance.items),
    };

const _$HomePageSectionLayoutEnumMap = {
  HomePageSectionLayout.ROW: 'ROW',
  HomePageSectionLayout.GRID: 'GRID',
};

DeezerChannel _$DeezerChannelFromJson(Map<String, dynamic> json) =>
    DeezerChannel(
      id: json['id'] as String?,
      title: json['title'] as String?,
      backgroundColor: DeezerChannel._colorFromJson(
          (json['backgroundColor'] as num?)?.toInt()),
      target: json['target'] as String?,
      backgroundImage: json['backgroundImage'] == null
          ? null
          : ImageDetails.fromJson(
              json['backgroundImage'] as Map<String, dynamic>),
      logo: json['logo'] as String?,
      logoImage: json['logoImage'] == null
          ? null
          : LogoDetails.fromJson(json['logoImage'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DeezerChannelToJson(DeezerChannel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'target': instance.target,
      'title': instance.title,
      'logo': instance.logo,
      'backgroundColor': DeezerChannel._colorToJson(instance.backgroundColor),
      'backgroundImage': instance.backgroundImage,
      'logoImage': instance.logoImage,
    };

DeezerFlow _$DeezerFlowFromJson(Map<String, dynamic> json) => DeezerFlow(
      id: json['id'] as String?,
      title: json['title'] as String?,
      target: json['target'] as String?,
      cover: json['cover'] == null
          ? null
          : ImageDetails.fromJson(json['cover'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DeezerFlowToJson(DeezerFlow instance) =>
    <String, dynamic>{
      'id': instance.id,
      'target': instance.target,
      'title': instance.title,
      'cover': instance.cover,
    };

Sorting _$SortingFromJson(Map<String, dynamic> json) => Sorting(
      type: $enumDecodeNullable(_$SortTypeEnumMap, json['type']) ??
          SortType.DEFAULT,
      reverse: json['reverse'] as bool? ?? false,
      id: json['id'] as String?,
      sourceType:
          $enumDecodeNullable(_$SortSourceTypesEnumMap, json['sourceType']),
    );

Map<String, dynamic> _$SortingToJson(Sorting instance) => <String, dynamic>{
      'type': _$SortTypeEnumMap[instance.type]!,
      'reverse': instance.reverse,
      'id': instance.id,
      'sourceType': _$SortSourceTypesEnumMap[instance.sourceType],
    };

const _$SortTypeEnumMap = {
  SortType.DEFAULT: 'DEFAULT',
  SortType.ALPHABETIC: 'ALPHABETIC',
  SortType.ARTIST: 'ARTIST',
  SortType.ALBUM: 'ALBUM',
  SortType.RELEASE_DATE: 'RELEASE_DATE',
  SortType.POPULARITY: 'POPULARITY',
  SortType.USER: 'USER',
  SortType.TRACK_COUNT: 'TRACK_COUNT',
  SortType.DATE_ADDED: 'DATE_ADDED',
};

const _$SortSourceTypesEnumMap = {
  SortSourceTypes.TRACKS: 'TRACKS',
  SortSourceTypes.PLAYLISTS: 'PLAYLISTS',
  SortSourceTypes.ALBUMS: 'ALBUMS',
  SortSourceTypes.ARTISTS: 'ARTISTS',
  SortSourceTypes.PLAYLIST: 'PLAYLIST',
};

Show _$ShowFromJson(Map<String, dynamic> json) => Show(
      name: json['name'] as String?,
      description: json['description'] as String?,
      art: json['art'] == null
          ? null
          : ImageDetails.fromJson(json['art'] as Map<String, dynamic>),
      id: json['id'] as String?,
    );

Map<String, dynamic> _$ShowToJson(Show instance) => <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'art': instance.art,
      'id': instance.id,
    };

ShowEpisode _$ShowEpisodeFromJson(Map<String, dynamic> json) => ShowEpisode(
      id: json['id'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      url: json['url'] as String?,
      duration: json['duration'] == null
          ? null
          : Duration(microseconds: (json['duration'] as num).toInt()),
      publishedDate: json['publishedDate'] as String?,
      show: json['show'] == null
          ? null
          : Show.fromJson(json['show'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ShowEpisodeToJson(ShowEpisode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'url': instance.url,
      'duration': instance.duration?.inMicroseconds,
      'publishedDate': instance.publishedDate,
      'show': instance.show,
    };
