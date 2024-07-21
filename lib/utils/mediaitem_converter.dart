import 'package:audio_service/audio_service.dart';

// Separate converter since MediaItem.toJson() MediaItem.fromJson() are removed in audio_service v0.18+
class MediaItemConverter {
  static MediaItem mediaItemFromMap(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'],
      album: json['album'],
      title: json['title'],
      artist: json['artist'],
      genre: json['genre'],
      duration: Duration(milliseconds: json['duration']),
      artUri: json['artUri'] != null ? Uri.parse(json['artUri']) : null,
      artHeaders: Map<String, String>.from(json['artHeaders'] ?? {}),
      playable: json['playable'],
      displayTitle: json['displayTitle'],
      displaySubtitle: json['displaySubtitle'],
      displayDescription: json['displayDescription'],
      rating: null,
      extras: Map<String, dynamic>.from(json['extras']),
    );
  }

  static Map<String, dynamic> mediaItemToMap(MediaItem mi) => <String, dynamic>{
        'id': mi.id,
        'title': mi.title,
        'album': mi.album,
        'artist': mi.artist,
        'genre': mi.genre,
        'duration': mi.duration?.inMilliseconds,
        'artUri': mi.artUri?.toString(),
        'playable': mi.playable,
        'displayTitle': mi.displayTitle,
        'displaySubtitle': mi.displaySubtitle,
        'displayDescription': mi.displayDescription,
        'rating': null,
        'extras': mi.extras,
      };
}
