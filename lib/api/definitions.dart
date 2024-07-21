import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../api/cache.dart';
import '../translations.i18n.dart';

part 'definitions.g.dart';

@JsonSerializable()
class Track {
  String? id;
  String? title;
  Album? album;
  List<Artist>? artists;
  Duration? duration;
  ImageDetails? albumArt;
  int? trackNumber;
  bool? offline;
  LyricsFull? lyrics;
  bool? favorite;
  int? diskNumber;
  bool? explicit;
  //Date added to playlist / favorites
  int? addedDate;
  Track? fallback;

  List<dynamic>? playbackDetails;
  List<dynamic>? playbackDetailsFallback;

  Track(
      {this.id,
      this.title,
      this.duration,
      this.album,
      this.playbackDetails,
      this.albumArt,
      this.artists,
      this.trackNumber,
      this.offline,
      this.lyrics,
      this.favorite,
      this.diskNumber,
      this.explicit,
      this.addedDate,
      this.fallback,
      this.playbackDetailsFallback});

  String? get artistString =>
      artists?.map<String>((art) => art.name ?? '').join(', ');
  String? get durationString =>
      "${duration?.inMinutes}:${duration?.inSeconds.remainder(60).toString().padLeft(2, '0')}";

  //MediaItem
  MediaItem toMediaItem() => MediaItem(
          title: title ?? '',
          album: album?.title ?? '',
          artist: artists?[0].name,
          displayTitle: title,
          displaySubtitle: artistString,
          displayDescription: album?.title,
          artUri: Uri.parse(albumArt?.full ?? ''),
          duration: duration,
          id: id ?? '',
          extras: {
            'playbackDetails': jsonEncode(playbackDetails),
            'thumb': albumArt?.thumb,
            'lyrics': jsonEncode(lyrics?.toJson()),
            'albumId': album?.id,
            'artists':
                jsonEncode(artists?.map<Map>((art) => art.toJson()).toList()),
            'fallbackId': fallback?.id,
            'playbackDetailsFallback': jsonEncode(playbackDetailsFallback),
          });

  factory Track.fromMediaItem(MediaItem mi) {
    //Load album, artists & originalId (if track is result of fallback).
    //It is stored separately, to save id and other metadata
    Album album = Album(title: mi.album);
    List<Artist> artists = [Artist(name: mi.displaySubtitle ?? mi.artist)];
    album.id = mi.extras?['albumId'];
    if (mi.extras?['artists'] != null) {
      artists = jsonDecode(mi.extras?['artists'])
          .map<Artist>((j) => Artist.fromJson(j))
          .toList();
    }
    List<String>? playbackDetails;
    if (mi.extras?['playbackDetails'] != null) {
      playbackDetails = (jsonDecode(mi.extras?['playbackDetails']) ?? [])
          .map<String>((e) => e.toString())
          .toList();
    }
    Track fallback = Track(id: mi.extras?['fallbackId']);
    List<String>? playbackDetailsFallback;
    if (mi.extras?['playbackDetailsFallback'] != null) {
      playbackDetailsFallback =
          (jsonDecode(mi.extras?['playbackDetailsFallback']) ?? [])
              .map<String>((e) => e.toString())
              .toList();
    }

    return Track(
        title: mi.title.isEmpty ? mi.displayTitle : mi.title,
        artists: artists,
        album: album,
        id: mi.id,
        albumArt: ImageDetails(
            fullUrl: mi.artUri.toString(), thumbUrl: mi.extras?['thumb']),
        duration: mi.duration,
        playbackDetails: playbackDetails,
        lyrics: LyricsFull.fromJson(
            jsonDecode(((mi.extras ?? {})['lyrics']) ?? '{}')),
        fallback: fallback,
        playbackDetailsFallback: playbackDetailsFallback);
  }

  //JSON
  factory Track.fromPrivateJson(Map<dynamic, dynamic> json,
      {bool favorite = false}) {
    String title = json['SNG_TITLE'];
    if (json['VERSION'] != null && json['VERSION'] != '') {
      title = "${json['SNG_TITLE']} ${json['VERSION']}";
    }
    return Track(
      id: json['SNG_ID'].toString(),
      title: title,
      duration: Duration(seconds: int.parse(json['DURATION'])),
      albumArt: ImageDetails.fromPrivateString(json['ALB_PICTURE']),
      album: Album.fromPrivateJson(json),
      artists: (json['ARTISTS'] ?? [json])
          .map<Artist>((dynamic art) => Artist.fromPrivateJson(art))
          .toList(),
      trackNumber: int.parse((json['TRACK_NUMBER'] ?? '0').toString()),
      playbackDetails: [
        json['MD5_ORIGIN'],
        json['MEDIA_VERSION'],
        json['TRACK_TOKEN']
      ],
      lyrics: LyricsFull(id: json['LYRICS_ID']?.toString() ?? ''),
      favorite: favorite,
      diskNumber: int.parse(json['DISK_NUMBER'] ?? '1'),
      explicit: (json['EXPLICIT_LYRICS'].toString() == '1') ? true : false,
      addedDate: json['DATE_ADD'],
      fallback: (json['FALLBACK'] != null)
          ? Track.fromPrivateJson(json['FALLBACK'])
          : null,
      playbackDetailsFallback: (json['FALLBACK'] != null)
          ? [
              json['FALLBACK']['MD5_ORIGIN'],
              json['FALLBACK']?['MEDIA_VERSION'],
              json['FALLBACK']?['TRACK_TOKEN']
            ]
          : null,
    );
  }
  Map<String, dynamic> toSQL({off = false}) => {
        'id': id,
        'title': title,
        'album': album?.id,
        'artists': artists?.map<String>((dynamic a) => a.id).join(','),
        'duration': duration?.inSeconds,
        'albumArt': albumArt?.full,
        'trackNumber': trackNumber,
        'offline': off ? 1 : 0,
        'lyrics': jsonEncode(lyrics?.toJson()),
        'favorite': (favorite ?? false) ? 1 : 0,
        'diskNumber': diskNumber,
        'explicit': (explicit ?? false) ? 1 : 0,
        'fallback': fallback?.id,
        //'favoriteDate': favoriteDate
      };
  factory Track.fromSQL(Map<String, dynamic> data) => Track(
        id: data['trackId'] ?? data['id'], //If loading from downloads table
        title: data['title'],
        album: Album(id: data['album'], title: ''),
        duration: Duration(seconds: data['duration']),
        albumArt: ImageDetails(fullUrl: data['albumArt']),
        trackNumber: data['trackNumber'],
        artists: List<Artist>.generate(data['artists'].split(',').length,
            (i) => Artist(id: data['artists'].split(',')[i])),
        offline: (data['offline'] == 1) ? true : false,
        lyrics: LyricsFull.fromJson(jsonDecode(data['lyrics'])),
        favorite: (data['favorite'] == 1) ? true : false,
        diskNumber: data['diskNumber'],
        explicit: (data['explicit'] == 1) ? true : false,
        fallback: data['fallback'] != null ? Track(id: data['fallback']) : null,
        //favoriteDate: data['favoriteDate']
      );

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
  Map<String, dynamic> toJson() => _$TrackToJson(this);
}

enum AlbumType { ALBUM, SINGLE, FEATURED }

@JsonSerializable()
class Album {
  String? id;
  String? title;
  List<Artist>? artists;
  List<Track>? tracks;
  ImageDetails? art;
  int? fans;
  bool? offline; //If the album is offline, or just saved in db as metadata
  bool? library;
  AlbumType? type;
  String? releaseDate;
  String? favoriteDate;

  Album(
      {this.id,
      this.title,
      this.art,
      this.artists,
      this.tracks,
      this.fans,
      this.offline,
      this.library,
      this.type,
      this.releaseDate,
      this.favoriteDate});

  String? get artistString =>
      artists?.map<String>((art) => art.name ?? '').join(', ');
  Duration get duration =>
      Duration(seconds: tracks!.fold(0, (v, t) => v += t.duration!.inSeconds));
  String get durationString =>
      "${duration.inMinutes}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  String? get fansString => NumberFormat.compact().format(fans);

  //JSON
  factory Album.fromPrivateJson(Map<dynamic, dynamic> json,
      {Map<dynamic, dynamic> songsJson = const {}, bool library = false}) {
    AlbumType type = AlbumType.ALBUM;
    if (json['TYPE'] != null && json['TYPE'].toString() == '0') {
      type = AlbumType.SINGLE;
    }
    if (json['ROLE_ID'] == 5) type = AlbumType.FEATURED;

    return Album(
        id: json['ALB_ID'].toString(),
        title: json['ALB_TITLE'],
        art: ImageDetails.fromPrivateString(json['ALB_PICTURE']),
        artists: (json['ARTISTS'] ?? [])
            .map<Artist>((dynamic art) => Artist.fromPrivateJson(art))
            .toList(),
        tracks: (songsJson['data'] ?? [])
            .map<Track>((dynamic track) => Track.fromPrivateJson(track))
            .toList(),
        fans: json['NB_FAN'],
        library: library,
        type: type,
        releaseDate:
            json['DIGITAL_RELEASE_DATE'] ?? json['PHYSICAL_RELEASE_DATE'],
        favoriteDate: json['DATE_FAVORITE']);
  }
  Map<String, dynamic> toSQL({off = false}) => {
        'id': id,
        'title': title,
        'artists': (artists ?? []).map<String>((dynamic a) => a.id).join(','),
        'tracks': (tracks ?? []).map<String>((dynamic t) => t.id).join(','),
        'art': art?.full ?? '',
        'fans': fans,
        'offline': off ? 1 : 0,
        'library': (library ?? false) ? 1 : 0,
        'type': (type != null) ? AlbumType.values.indexOf(type!) : -1,
        'releaseDate': releaseDate,
        //'favoriteDate': favoriteDate
      };
  factory Album.fromSQL(Map<String, dynamic> data) => Album(
        id: data['id'],
        title: data['title'],
        artists: List<Artist>.generate(data['artists'].split(',').length,
            (i) => Artist(id: data['artists'].split(',')[i])),
        tracks: List<Track>.generate(data['tracks'].split(',').length,
            (i) => Track(id: data['tracks'].split(',')[i])),
        art: ImageDetails(fullUrl: data['art']),
        fans: data['fans'],
        offline: (data['offline'] == 1) ? true : false,
        library: (data['library'] == 1) ? true : false,
        type: AlbumType.values[(data['type'] == -1) ? 0 : data['type']],
        releaseDate: data['releaseDate'],
        //favoriteDate: data['favoriteDate']
      );

  factory Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);
  Map<String, dynamic> toJson() => _$AlbumToJson(this);
}

enum ArtistHighlightType { ALBUM }

@JsonSerializable()
class ArtistHighlight {
  dynamic data;
  ArtistHighlightType? type;
  String? title;

  ArtistHighlight({this.data, this.type, this.title});

  static ArtistHighlight? fromPrivateJson(Map<dynamic, dynamic> json) {
    if (json['ITEM'] == null) return null;
    switch (json['TYPE']) {
      case 'album':
        return ArtistHighlight(
            data: Album.fromPrivateJson(json['ITEM']),
            type: ArtistHighlightType.ALBUM,
            title: json['TITLE']);
    }
    return null;
  }

  //JSON
  factory ArtistHighlight.fromJson(Map<String, dynamic> json) =>
      _$ArtistHighlightFromJson(json);
  Map<String, dynamic> toJson() => _$ArtistHighlightToJson(this);
}

@JsonSerializable()
class Artist {
  String? id;
  String? name;
  List<Album> albums;
  int? albumCount;
  List<Track> topTracks;
  ImageDetails? picture;
  int? fans;
  bool? offline;
  bool? library;
  bool? radio;
  String? favoriteDate;
  ArtistHighlight? highlight;

  Artist(
      {this.id,
      this.name,
      this.albums = const [],
      this.albumCount,
      this.topTracks = const [],
      this.picture,
      this.fans,
      this.offline,
      this.library,
      this.radio,
      this.favoriteDate,
      this.highlight});

  String get fansString => NumberFormat.compact().format(fans);

  //JSON
  factory Artist.fromPrivateJson(Map<dynamic, dynamic> json,
      {Map<dynamic, dynamic> albumsJson = const {},
      Map<dynamic, dynamic> topJson = const {},
      Map<dynamic, dynamic> highlight = const {},
      bool library = false}) {
    //Get wether radio is available
    bool radio = false;
    if (json['SMARTRADIO'] == true || json['SMARTRADIO'] == 1) radio = true;

    return Artist(
        id: json['ART_ID'].toString(),
        name: json['ART_NAME'],
        fans: json['NB_FAN'],
        picture: json['ART_PICTURE'] == null
            ? null
            : ImageDetails.fromPrivateString(json['ART_PICTURE'],
                type: 'artist'),
        albumCount: albumsJson['total'],
        albums: (albumsJson['data'] ?? [])
            .map<Album>((dynamic data) => Album.fromPrivateJson(data))
            .toList(),
        topTracks: (topJson['data'] ?? [])
            .map<Track>((dynamic data) => Track.fromPrivateJson(data))
            .toList(),
        library: library,
        radio: radio,
        favoriteDate: json['DATE_FAVORITE'],
        highlight: ArtistHighlight.fromPrivateJson(highlight));
  }
  Map<String, dynamic> toSQL({off = false}) => {
        'id': id,
        'name': name,
        'albums': albums.map<String>((dynamic a) => a.id).join(','),
        'topTracks': topTracks.map<String>((dynamic t) => t.id).join(','),
        'picture': picture?.full ?? '',
        'fans': fans,
        'albumCount': albumCount ?? albums.length,
        'offline': off ? 1 : 0,
        'library': (library ?? false) ? 1 : 0,
        'radio': (radio ?? false) ? 1 : 0,
        //'favoriteDate': favoriteDate
      };
  factory Artist.fromSQL(Map<String, dynamic> data) => Artist(
        id: data['id'],
        name: data['name'],
        topTracks: List<Track>.generate(data['topTracks'].split(',').length,
            (i) => Track(id: data['topTracks'].split(',')[i])),
        albums: List<Album>.generate(data['albums'].split(',').length,
            (i) => Album(id: data['albums'].split(',')[i], title: '')),
        albumCount: data['albumCount'],
        picture: ImageDetails(fullUrl: data['picture']),
        fans: data['fans'],
        offline: (data['offline'] == 1) ? true : false,
        library: (data['library'] == 1) ? true : false,
        radio: (data['radio'] == 1) ? true : false,
        //favoriteDate: data['favoriteDate']
      );

  factory Artist.fromJson(Map<String, dynamic> json) => _$ArtistFromJson(json);
  Map<String, dynamic> toJson() => _$ArtistToJson(this);
}

@JsonSerializable()
class Playlist {
  String? id;
  String? title;
  List<Track>? tracks;
  ImageDetails? image;
  Duration? duration;
  int? trackCount;
  User? user;
  int? fans;
  bool? library;
  String? description;

  Playlist(
      {this.id,
      this.title,
      this.tracks,
      this.image,
      this.trackCount,
      this.duration,
      this.user,
      this.fans,
      this.library,
      this.description});

  String get durationString =>
      "${duration?.inHours}:${duration?.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration?.inSeconds.remainder(60).toString().padLeft(2, '0')}";

  //JSON
  factory Playlist.fromPrivateJson(Map<dynamic, dynamic> json,
          {Map<dynamic, dynamic> songsJson = const {}, bool library = false}) =>
      Playlist(
          id: json['PLAYLIST_ID'].toString(),
          title: json['TITLE'],
          trackCount: json['NB_SONG'] ?? songsJson['total'],
          image: ImageDetails.fromPrivateString(json['PLAYLIST_PICTURE'],
              type: json['PICTURE_TYPE']),
          fans: json['NB_FAN'],
          duration: Duration(seconds: json['DURATION'] ?? 0),
          description: json['DESCRIPTION'],
          user: User(
              id: json['PARENT_USER_ID'],
              name: json['PARENT_USERNAME'] ?? '',
              picture: ImageDetails.fromPrivateString(
                  json['PARENT_USER_PICTURE'] ?? '',
                  type: 'user')),
          tracks: (songsJson['data'] ?? [])
              .map<Track>((dynamic data) => Track.fromPrivateJson(data))
              .toList(),
          library: library);
  Map<String, dynamic> toSQL() => {
        'id': id,
        'title': title,
        'tracks': tracks?.map<String>((dynamic t) => t.id).join(','),
        'image': image?.full,
        'duration': duration?.inSeconds,
        'userId': user?.id,
        'userName': user?.name,
        'fans': fans,
        'description': description,
        'library': (library ?? false) ? 1 : 0
      };
  factory Playlist.fromSQL(data) => Playlist(
      id: data['id'],
      title: data['title'],
      description: data['description'],
      tracks: List<Track>.generate(data?['tracks']?.split(',')?.length ?? 0,
          (i) => Track(id: data?['tracks']?.split(',')[i])),
      image: ImageDetails(fullUrl: data['image']),
      duration: Duration(seconds: data?['duration'] ?? 0),
      user: User(id: data['userId'], name: data['userName']),
      fans: data['fans'],
      library: (data['library'] == 1) ? true : false);

  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);
  Map<String, dynamic> toJson() => _$PlaylistToJson(this);
}

@JsonSerializable()
class User {
  String? id;
  String? name;
  ImageDetails? picture;

  User({this.id, this.name, this.picture});

  //Mostly handled by playlist

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@JsonSerializable()
class ImageDetails {
  String? fullUrl;
  String? thumbUrl;
  String? type;
  String? imageHash;

  ImageDetails({this.fullUrl, this.thumbUrl, this.type, this.imageHash});

  //Get full/thumb with fallback
  String? get full => fullUrl ?? thumbUrl;
  String? get thumb => thumbUrl ?? fullUrl;

  //Get custom sized image
  String customUrl(String height, String width, {String quality = '80'}) {
    return 'https://e-cdns-images.dzcdn.net/images/$type/$imageHash/${height}x$width-000000-$quality-0-0.jpg';
  }

  //JSON
  factory ImageDetails.fromPrivateString(String imageHash,
          {String type = 'cover'}) =>
      ImageDetails(
          type: type,
          imageHash: imageHash,
          fullUrl:
              'https://e-cdns-images.dzcdn.net/images/$type/$imageHash/1000x1000-000000-80-0-0.jpg',
          thumbUrl:
              'https://e-cdns-images.dzcdn.net/images/$type/$imageHash/140x140-000000-80-0-0.jpg');
  factory ImageDetails.fromPrivateJson(Map<dynamic, dynamic> json) =>
      ImageDetails.fromPrivateString(json['MD5'] ?? json['md5'],
          type: json['TYPE'] ?? json['type']);
  //ImageDetails.fromPrivateString((json['MD5']?.split('-')?.first) ?? json['md5'],
  //type: json['TYPE'] ?? json['type']);

  factory ImageDetails.fromJson(Map<String, dynamic> json) =>
      _$ImageDetailsFromJson(json);
  Map<String, dynamic> toJson() => _$ImageDetailsToJson(this);
}

@JsonSerializable()
class LogoDetails {
  String? fullUrl;
  String? thumbUrl;
  String? type;
  String? imageHash;

  LogoDetails({this.fullUrl, this.thumbUrl, this.type, this.imageHash});

  //Get full/thumb with fallback
  String? get full => fullUrl ?? thumbUrl;
  String? get thumb => thumbUrl ?? fullUrl;

  //Get custom sized logo
  String customUrl(String height,
      {String width = '0', String quality = '100'}) {
    return 'https://e-cdns-images.dzcdn.net/images/$type/$imageHash/${height}x$width-none-$quality-0-0.png';
  }

  //JSON
  factory LogoDetails.fromPrivateString(String imageHash,
          {String type = 'misc'}) =>
      LogoDetails(
          type: type,
          imageHash: imageHash,
          fullUrl:
              'https://e-cdns-images.dzcdn.net/images/$type/$imageHash/208x0-none-100-0-0.png',
          thumbUrl:
              'https://e-cdns-images.dzcdn.net/images/$type/$imageHash/52x0-none-100-0-0.png');
  factory LogoDetails.fromPrivateJson(Map<dynamic, dynamic> json) =>
      LogoDetails.fromPrivateString(
          (json['MD5']?.split('-')?.first) ?? json['md5'],
          type: json['TYPE'] ?? json['type']);

  factory LogoDetails.fromJson(Map<String, dynamic> json) =>
      _$LogoDetailsFromJson(json);
  Map<String, dynamic> toJson() => _$LogoDetailsToJson(this);
}

class SearchResults {
  List<Track>? tracks;
  List<Album>? albums;
  List<Artist>? artists;
  List<Playlist>? playlists;
  List<Show>? shows;
  List<ShowEpisode>? episodes;

  SearchResults(
      {this.tracks,
      this.albums,
      this.artists,
      this.playlists,
      this.shows,
      this.episodes});

  //Check if no search results
  bool get empty {
    return ((tracks == null || tracks!.isEmpty) &&
        (albums == null || albums!.isEmpty) &&
        (artists == null || artists!.isEmpty) &&
        (playlists == null || playlists!.isEmpty) &&
        (shows == null || shows!.isEmpty) &&
        (episodes == null || episodes!.isEmpty));
  }

  factory SearchResults.fromPrivateJson(Map<dynamic, dynamic> json) =>
      SearchResults(
          tracks: json['TRACK']['data']
              .map<Track>((dynamic data) => Track.fromPrivateJson(data))
              .toList(),
          albums: json['ALBUM']['data']
              .map<Album>((dynamic data) => Album.fromPrivateJson(data))
              .toList(),
          artists: json['ARTIST']['data']
              .map<Artist>((dynamic data) => Artist.fromPrivateJson(data))
              .toList(),
          playlists: json['PLAYLIST']['data']
              .map<Playlist>((dynamic data) => Playlist.fromPrivateJson(data))
              .toList(),
          shows: json['SHOW']['data']
              .map<Show>((dynamic data) => Show.fromPrivateJson(data))
              .toList(),
          episodes: json['EPISODE']['data']
              .map<ShowEpisode>(
                  (dynamic data) => ShowEpisode.fromPrivateJson(data))
              .toList());
}

class Lyrics {
  String? id;
  String? writers;
  List<SynchronizedLyric>? syncedLyrics;
  String? errorMessage;
  String? unsyncedLyrics;
  bool? isExplicit;
  String? copyright;

  Lyrics({
    this.id,
    this.writers,
    this.syncedLyrics,
    this.unsyncedLyrics,
    this.errorMessage,
    this.isExplicit,
    this.copyright,
  });

  static error(String? message) => Lyrics(
        id: null,
        writers: null,
        syncedLyrics: [
          SynchronizedLyric(
            offset: const Duration(milliseconds: 0),
            text: 'Lyrics unavailable, empty or failed to load!'.i18n,
          ),
        ],
        errorMessage: message,
      );

  bool isLoaded() =>
      syncedLyrics?.isNotEmpty == true || unsyncedLyrics?.isNotEmpty == true;

  bool isSynced() =>
      syncedLyrics?.isNotEmpty == true && syncedLyrics!.length > 1;

  bool isUnsynced() => !isSynced() && unsyncedLyrics?.isNotEmpty == true;
}

@JsonSerializable()
class LyricsClassic extends Lyrics {
  LyricsClassic({
    super.id,
    super.writers,
    super.syncedLyrics,
    super.errorMessage,
    super.unsyncedLyrics,
  });

  factory LyricsClassic.fromPrivateJson(Map<dynamic, dynamic> json) {
    LyricsClassic l = LyricsClassic(
      id: json['LYRICS_ID'],
      writers: json['LYRICS_WRITERS'],
      syncedLyrics: (json['LYRICS_SYNC_JSON'] ?? [])
          .map<SynchronizedLyric>((l) => SynchronizedLyric.fromPrivateJson(l))
          .toList(),
      unsyncedLyrics: json['LYRICS_TEXT'],
    );
    l.syncedLyrics?.removeWhere((l) => l.offset == null);
    return l;
  }

  factory LyricsClassic.fromJson(Map<String, dynamic> json) =>
      _$LyricsClassicFromJson(json);

  Map<String, dynamic> toJson() => _$LyricsClassicToJson(this);
}

@JsonSerializable()
class LyricsFull extends Lyrics {
  LyricsFull({
    super.id,
    super.writers,
    super.syncedLyrics,
    super.errorMessage,
    super.unsyncedLyrics,
    super.isExplicit,
    super.copyright,
  });

  factory LyricsFull.fromPrivateJson(Map<dynamic, dynamic> json) {
    var lyricsJson = json['track']['lyrics'] ?? {};

    return LyricsFull(
      id: lyricsJson['id'],
      writers: lyricsJson['writers'],
      syncedLyrics: (lyricsJson['synchronizedLines'] ?? [])
          .map<SynchronizedLyric>((l) =>
              SynchronizedLyric.fromPrivateJson(l as Map<dynamic, dynamic>))
          .toList(),
      unsyncedLyrics: lyricsJson['text'],
      isExplicit: json['track']['isExplicit'],
      copyright: lyricsJson['copyright'],
    );
  }

  factory LyricsFull.fromJson(Map<String, dynamic> json) =>
      _$LyricsFullFromJson(json);

  Map<String, dynamic> toJson() => _$LyricsFullToJson(this);
}

@JsonSerializable()
class SynchronizedLyric {
  Duration? offset;
  Duration? duration;
  String? text;
  String? lrcTimestamp;

  SynchronizedLyric({this.offset, this.duration, this.text, this.lrcTimestamp});

  //JSON
  factory SynchronizedLyric.fromPrivateJson(Map<dynamic, dynamic> json) {
    if (json['milliseconds'] == null || json['line'] == null) {
      return SynchronizedLyric(); //Empty lyric
    }
    return SynchronizedLyric(
        offset:
            Duration(milliseconds: int.parse(json['milliseconds'].toString())),
        duration:
            Duration(milliseconds: int.parse(json['duration'].toString())),
        text: json['line'],
        // lrc_timestamp from classic GW API, lrcTimestamp from pipe API
        lrcTimestamp: json['lrcTimestamp'] ?? json['lrc_timestamp']);
  }

  factory SynchronizedLyric.fromJson(Map<String, dynamic> json) =>
      _$SynchronizedLyricFromJson(json);
  Map<String, dynamic> toJson() => _$SynchronizedLyricToJson(this);
}

@JsonSerializable()
class QueueSource {
  String? id;
  String? text;
  String? source;

  QueueSource({this.id, this.text, this.source});

  factory QueueSource.fromJson(Map<String, dynamic> json) =>
      _$QueueSourceFromJson(json);
  Map<String, dynamic> toJson() => _$QueueSourceToJson(this);
}

@JsonSerializable()
class SmartTrackList {
  String? id;
  String? title;
  String? subtitle;
  String? description;
  int? trackCount;
  List<Track>? tracks;
  ImageDetails? cover;
  String? flowType;

  SmartTrackList(
      {this.id,
      this.title,
      this.description,
      this.trackCount,
      this.tracks,
      this.cover,
      this.subtitle,
      this.flowType});

  //JSON
  factory SmartTrackList.fromPrivateJson(Map<dynamic, dynamic> json,
          {Map<dynamic, dynamic> songsJson = const {}}) =>
      SmartTrackList(
          id: json['SMARTTRACKLIST_ID'],
          title: json['TITLE'],
          subtitle: json['SUBTITLE'],
          description: json['DESCRIPTION'],
          trackCount: json['NB_SONG'] ?? (songsJson['total']),
          tracks: (songsJson['data'] ?? [])
              .map<Track>((t) => Track.fromPrivateJson(t))
              .toList(),
          cover: ImageDetails.fromPrivateJson(json['COVER']));

  factory SmartTrackList.fromJson(Map<String, dynamic> json) =>
      _$SmartTrackListFromJson(json);
  Map<String, dynamic> toJson() => _$SmartTrackListToJson(this);
}

@JsonSerializable()
class HomePage {
  List<HomePageSection> sections;

  HomePage({this.sections = const []});

  //Save/Load
  Future<String> _getPath() async {
    Directory d = await getApplicationDocumentsDirectory();
    return p.join(d.path, 'homescreen.json');
  }

  Future exists() async {
    String path = await _getPath();
    return await File(path).exists();
  }

  Future save() async {
    String path = await _getPath();
    await File(path).writeAsString(jsonEncode(toJson()));
  }

  Future<HomePage> load() async {
    String path = await _getPath();
    Map<String, dynamic> data = jsonDecode(await File(path).readAsString());
    return HomePage.fromJson(data);
  }

  Future wipe() async {
    await File(await _getPath()).delete();
  }

  //JSON
  factory HomePage.fromPrivateJson(Map<dynamic, dynamic> json) {
    HomePage hp = HomePage(sections: []);
    //Parse every section
    for (var s in (json['sections'] ?? [])) {
      HomePageSection? section = HomePageSection.fromPrivateJson(s);
      if (section != null) hp.sections.add(section);
    }
    return hp;
  }

  factory HomePage.fromJson(Map<String, dynamic> json) =>
      _$HomePageFromJson(json);
  Map<String, dynamic> toJson() => _$HomePageToJson(this);
}

@JsonSerializable()
class HomePageSection {
  String? title;
  HomePageSectionLayout? layout;

  //For loading more items
  String? pagePath;
  bool? hasMore;

  @JsonKey(fromJson: _homePageItemFromJson, toJson: _homePageItemToJson)
  List<HomePageItem?>? items;

  HomePageSection(
      {this.layout, this.items, this.title, this.pagePath, this.hasMore});

  //JSON
  static HomePageSection? fromPrivateJson(Map<dynamic, dynamic> json) {
    HomePageSection hps = HomePageSection(
        title: json['title'] ?? '',
        items: [],
        pagePath: json['target'],
        hasMore: json['hasMoreItems'] ?? false);

    String layout = json['layout'];
    switch (layout) {
      case 'ads':
        return null;
      case 'horizontal-grid':
        hps.layout = HomePageSectionLayout.ROW;
        break;
      case 'filterable-grid':
        hps.layout = HomePageSectionLayout.ROW;
        break;
      case 'grid':
        hps.layout = HomePageSectionLayout.GRID;
        break;
      default:
        return null;
    }

    //Parse items
    for (var i in (json['items'] ?? [])) {
      HomePageItem? hpi = HomePageItem.fromPrivateJson(i);
      hps.items?.add(hpi);
    }
    return hps;
  }

  factory HomePageSection.fromJson(Map<String, dynamic> json) =>
      _$HomePageSectionFromJson(json);
  Map<String, dynamic> toJson() => _$HomePageSectionToJson(this);

  static _homePageItemFromJson(json) =>
      json.map<HomePageItem>((d) => HomePageItem.fromJson(d)).toList();
  static _homePageItemToJson(items) => items.map((i) => i.toJson()).toList();
}

class HomePageItem {
  HomePageItemType? type;
  dynamic value;

  HomePageItem({this.type, this.value});

  static HomePageItem? fromPrivateJson(Map<dynamic, dynamic> json) {
    String type = json['type'];
    switch (type) {
      case 'flow':
        return HomePageItem(
            type: HomePageItemType.FLOW,
            value: DeezerFlow.fromPrivateJson(json));
      case 'smarttracklist':
        //Smart Track List
        return HomePageItem(
            type: HomePageItemType.SMARTTRACKLIST,
            value: SmartTrackList.fromPrivateJson(json['data']));
      case 'playlist':
        return HomePageItem(
            type: HomePageItemType.PLAYLIST,
            value: Playlist.fromPrivateJson(json['data']));
      case 'artist':
        return HomePageItem(
            type: HomePageItemType.ARTIST,
            value: Artist.fromPrivateJson(json['data']));
      case 'channel':
        return HomePageItem(
            type: HomePageItemType.CHANNEL,
            value: DeezerChannel.fromPrivateJson(json));
      case 'album':
        return HomePageItem(
            type: HomePageItemType.ALBUM,
            value: Album.fromPrivateJson(json['data']));
      case 'show':
        return HomePageItem(
            type: HomePageItemType.SHOW,
            value: Show.fromPrivateJson(json['data']));
      default:
        return null;
    }
  }

  factory HomePageItem.fromJson(Map<String, dynamic> json) {
    String t = json['type'];
    switch (t) {
      case 'FLOW':
        return HomePageItem(
            type: HomePageItemType.FLOW,
            value: DeezerFlow.fromJson(json['value']));
      case 'SMARTTRACKLIST':
        return HomePageItem(
            type: HomePageItemType.SMARTTRACKLIST,
            value: SmartTrackList.fromJson(json['value']));
      case 'PLAYLIST':
        return HomePageItem(
            type: HomePageItemType.PLAYLIST,
            value: Playlist.fromJson(json['value']));
      case 'ARTIST':
        return HomePageItem(
            type: HomePageItemType.ARTIST,
            value: Artist.fromJson(json['value']));
      case 'CHANNEL':
        return HomePageItem(
            type: HomePageItemType.CHANNEL,
            value: DeezerChannel.fromJson(json['value']));
      case 'ALBUM':
        return HomePageItem(
            type: HomePageItemType.ALBUM, value: Album.fromJson(json['value']));
      case 'SHOW':
        return HomePageItem(
            type: HomePageItemType.SHOW,
            value: Show.fromPrivateJson(json['value']));
      default:
        return HomePageItem();
    }
  }

  Map<String, dynamic> toJson() {
    String type = this.type.toString().split('.').last;
    return {'type': type, 'value': value.toJson()};
  }
}

@JsonSerializable()
class DeezerChannel {
  String? id;
  String? target;
  String? title;
  String? logo;
  @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
  Color? backgroundColor;
  ImageDetails? backgroundImage;
  LogoDetails? logoImage;

  DeezerChannel(
      {this.id,
      this.title,
      this.backgroundColor,
      this.target,
      this.backgroundImage,
      this.logo,
      this.logoImage});

  factory DeezerChannel.fromPrivateJson(Map<dynamic, dynamic> json) =>
      DeezerChannel(
          id: json['id'],
          title: json['title'],
          logo: json['data']['logo'],
          backgroundColor: Color(int.parse(
              (json['background_color'] ?? '#000000').replaceFirst('#', 'FF'),
              radix: 16)),
          target: json['target'].replaceFirst('/', ''),
          backgroundImage: ((json['pictures']) == null)
              ? null
              : ImageDetails.fromPrivateJson(json['pictures'][0]),
          logoImage: ((json['logo_image']) == null)
              ? null
              : LogoDetails.fromPrivateJson(json['logo_image']));

  //JSON
  static _colorToJson(Color? c) => c?.value;
  static _colorFromJson(int? v) => Color(v ?? Colors.blue.value);
  factory DeezerChannel.fromJson(Map<String, dynamic> json) =>
      _$DeezerChannelFromJson(json);
  Map<String, dynamic> toJson() => _$DeezerChannelToJson(this);
}

@JsonSerializable()
class DeezerFlow {
  String? id;
  String? target;
  String? title;
  ImageDetails? cover;

  DeezerFlow({this.id, this.title, this.target, this.cover});

  factory DeezerFlow.fromPrivateJson(Map<dynamic, dynamic> json) => DeezerFlow(
      id: json['id'],
      title: json['title'],
      cover: ImageDetails.fromPrivateJson(json['pictures'][0]),
      target: json['target'].replaceFirst('/', ''));

  //JSON
  factory DeezerFlow.fromJson(Map<String, dynamic> json) =>
      _$DeezerFlowFromJson(json);
  Map<String, dynamic> toJson() => _$DeezerFlowToJson(this);
}

enum HomePageItemType {
  FLOW,
  SMARTTRACKLIST,
  PLAYLIST,
  ARTIST,
  CHANNEL,
  ALBUM,
  SHOW
}

enum HomePageSectionLayout { ROW, GRID }

enum RepeatType { NONE, LIST, TRACK }

enum DeezerLinkType { TRACK, ALBUM, ARTIST, PLAYLIST }

class DeezerLinkResponse {
  DeezerLinkType? type;
  String? id;

  DeezerLinkResponse({this.type, this.id});

  //String to DeezerLinkType
  static typeFromString(String t) {
    t = t.toLowerCase().trim();
    if (t == 'album') return DeezerLinkType.ALBUM;
    if (t == 'artist') return DeezerLinkType.ARTIST;
    if (t == 'playlist') return DeezerLinkType.PLAYLIST;
    if (t == 'track') return DeezerLinkType.TRACK;
    return null;
  }
}

//Sorting
enum SortType {
  DEFAULT,
  ALPHABETIC,
  ARTIST,
  ALBUM,
  RELEASE_DATE,
  POPULARITY,
  USER,
  TRACK_COUNT,
  DATE_ADDED
}

enum SortSourceTypes {
  //Library
  TRACKS,
  PLAYLISTS,
  ALBUMS,
  ARTISTS,

  PLAYLIST
}

@JsonSerializable()
class Sorting {
  SortType type;
  bool reverse;

  //For preserving sorting
  String? id;
  SortSourceTypes? sourceType;

  Sorting(
      {this.type = SortType.DEFAULT,
      this.reverse = false,
      this.id,
      this.sourceType});

  //Find index of sorting from cache
  static int? index(SortSourceTypes type, {String? id}) {
    //Find index
    int? index;
    if (id != null) {
      index = cache.sorts.indexWhere((s) => s.sourceType == type && s.id == id);
    } else {
      index = cache.sorts.indexWhere((s) => s.sourceType == type);
    }
    if (index == -1) return null;
    return index;
  }

  factory Sorting.fromJson(Map<String, dynamic> json) =>
      _$SortingFromJson(json);
  Map<String, dynamic> toJson() => _$SortingToJson(this);
}

@JsonSerializable()
class Show {
  String? name;
  String? description;
  ImageDetails? art;
  String? id;

  Show({this.name, this.description, this.art, this.id});

  //JSON
  factory Show.fromPrivateJson(Map<dynamic, dynamic> json) => Show(
      id: json['SHOW_ID'],
      name: json['SHOW_NAME'],
      art: ImageDetails.fromPrivateString(json['SHOW_ART_MD5'], type: 'talk'),
      description: json['SHOW_DESCRIPTION']);

  factory Show.fromJson(Map<String, dynamic> json) => _$ShowFromJson(json);
  Map<String, dynamic> toJson() => _$ShowToJson(this);
}

@JsonSerializable()
class ShowEpisode {
  String? id;
  String? title;
  String? description;
  String? url;
  Duration? duration;
  String? publishedDate;
  //Might not be fully available
  Show? show;

  ShowEpisode(
      {this.id,
      this.title,
      this.description,
      this.url,
      this.duration,
      this.publishedDate,
      this.show});

  String get durationString =>
      "${duration?.inMinutes}:${duration?.inSeconds.remainder(60).toString().padLeft(2, '0')}";

  //Generate MediaItem for playback
  MediaItem toMediaItem(Show show) {
    return MediaItem(
      title: title ?? '',
      displayTitle: title,
      displaySubtitle: show.name,
      album: show.name ?? '',
      id: id ?? '',
      extras: {
        'showUrl': url,
        'show': jsonEncode(show.toJson()),
        'thumb': show.art?.thumb
      },
      displayDescription: description,
      duration: duration,
      artUri: Uri.parse(show.art?.full ?? ''),
    );
  }

  factory ShowEpisode.fromMediaItem(MediaItem mi) {
    return ShowEpisode(
        id: mi.id,
        title: mi.title,
        description: mi.displayDescription,
        url: mi.extras?['showUrl'],
        duration: mi.duration,
        show: Show.fromJson(jsonDecode(mi.extras?['show'] ?? '')));
  }

  //JSON
  factory ShowEpisode.fromPrivateJson(Map<dynamic, dynamic> json) =>
      ShowEpisode(
          id: json['EPISODE_ID'],
          title: json['EPISODE_TITLE'],
          description: json['EPISODE_DESCRIPTION'],
          url: json['EPISODE_DIRECT_STREAM_URL'],
          duration: Duration(seconds: int.parse(json['DURATION'].toString())),
          publishedDate: json['EPISODE_PUBLISHED_TIMESTAMP'],
          show: Show.fromPrivateJson(json));

  factory ShowEpisode.fromJson(Map<String, dynamic> json) =>
      _$ShowEpisodeFromJson(json);
  Map<String, dynamic> toJson() => _$ShowEpisodeToJson(this);
}

class StreamQualityInfo {
  String? format;
  int? size;
  String? source;

  StreamQualityInfo({this.format, this.size, this.source});

  factory StreamQualityInfo.fromJson(Map json) => StreamQualityInfo(
      format: json['format'], size: json['size'], source: json['source']);

  int bitrate(Duration duration) {
    if ((size ?? 0) == 0) return 0;
    int bitrate = (((size! * 8) / 1000) / duration.inSeconds).round();
    //Round to known values
    if (bitrate > 122 && bitrate < 134) return 128;
    if (bitrate > 315 && bitrate < 325) return 320;
    return bitrate;
  }
}
