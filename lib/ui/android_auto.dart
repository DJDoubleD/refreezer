import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../service/audio_service.dart';
import '../translations.i18n.dart';

class AndroidAuto {
  // Prefix for "playable" MediaItem
  static const prefix = '_aa_';

  // Get media items for parent id
  Future<List<MediaItem>> getScreen(String parentId) async {
    if (kDebugMode) {
      print(parentId);
    }

    // Homescreen
    if (parentId == 'root') return homeScreen();

    // Playlists screen
    if (parentId == 'playlists') {
      // Fetch
      List<Playlist> playlists = await deezerAPI.getPlaylists();

      List<MediaItem> out = playlists.map<MediaItem>((p) {
        return MediaItem(
          id: '${prefix}playlist${p.id}',
          title: p.title ?? '',
          album: '',
          displayTitle: p.title,
          displaySubtitle: '${p.trackCount} ${'Tracks'.i18n}',
          playable: true,
          artUri: Uri.tryParse(p.image?.thumb ?? ''),
        );
      }).toList();
      return out;
    }

    // Albums screen
    if (parentId == 'albums') {
      List<Album> albums = await deezerAPI.getAlbums();

      List<MediaItem> out = albums.map<MediaItem>((a) {
        return MediaItem(
          id: '${prefix}album${a.id}',
          title: a.title ?? '',
          album: a.title ?? '',
          displayTitle: a.title,
          displaySubtitle: a.artistString,
          playable: true,
          artUri: Uri.tryParse(a.art?.thumb ?? ''),
        );
      }).toList();
      return out;
    }

    // Artists screen
    if (parentId == 'artists') {
      List<Artist> artists = await deezerAPI.getArtists();

      List<MediaItem> out = artists.map<MediaItem>((a) {
        return MediaItem(
          id: '${prefix}albums${a.id}',
          title: a.name ?? '',
          album: '',
          displayTitle: a.name,
          playable: false,
          artUri: Uri.tryParse(a.picture?.thumb ?? ''),
        );
      }).toList();
      return out;
    }

    // Artist screen (albums, etc)
    if (parentId.startsWith('${prefix}albums')) {
      String artistId = parentId.replaceFirst('${prefix}albums', '');
      List<Album> albums = await deezerAPI.discographyPage(artistId);

      List<MediaItem> out = albums.map<MediaItem>((a) {
        return MediaItem(
          id: '${prefix}album${a.id}',
          title: a.title ?? '',
          album: a.title ?? '',
          displayTitle: a.title,
          displaySubtitle: a.artistString,
          playable: true,
          artUri: Uri.tryParse(a.art?.thumb ?? ''),
        );
      }).toList();
      return out;
    }

    // Homescreen
    if (parentId == 'homescreen') {
      try {
        HomePage hp = await deezerAPI.homePage();
        List<MediaItem> out = [];
        for (HomePageSection section in hp.sections) {
          for (int i = 0; i < (section.items?.length ?? 0); i++) {
            if (i == 5) break;

            // Check type
            var item = section.items![i];
            var data = item?.value;
            switch (item?.type) {
              case HomePageItemType.PLAYLIST:
                out.add(MediaItem(
                  id: '${prefix}playlist${data.id}',
                  title: data.title,
                  album: '',
                  displayTitle: data.title,
                  playable: true,
                  artUri: Uri.tryParse(data.image.thumb),
                ));
                break;

              case HomePageItemType.ALBUM:
                out.add(MediaItem(
                  id: '${prefix}album${data.id}',
                  title: data.title,
                  album: data.title,
                  displayTitle: data.title,
                  displaySubtitle: data.artistString,
                  playable: true,
                  artUri: Uri.tryParse(data.art.thumb),
                ));
                break;

              case HomePageItemType.ARTIST:
                out.add(MediaItem(
                  id: '${prefix}albums${data.id}',
                  title: data.name,
                  album: '',
                  displayTitle: data.name,
                  playable: false,
                  artUri: Uri.tryParse(data.picture.thumb),
                ));
                break;

              case HomePageItemType.SMARTTRACKLIST:
                out.add(MediaItem(
                  id: '${prefix}stl${data.id}',
                  title: data.title,
                  album: '',
                  displayTitle: data.title,
                  displaySubtitle: data.subtitle,
                  playable: true,
                  artUri: Uri.tryParse(data.cover.thumb),
                ));
                break;

              default:
                break;
            }
          }
        }

        return out;
      } catch (error) {
        return [];
      }
    }

    return [];
  }

  // Load virtual mediaItem
  Future<void> playItem(String id) async {
    if (kDebugMode) {
      print(id);
    }

    // Play flow
    if (id == 'flow' || id == '${prefix}stlflow') {
      await GetIt.I<AudioPlayerHandler>()
          .playFromSmartTrackList(SmartTrackList(id: 'flow', title: 'Flow'.i18n));
      return;
    }
    // Play library tracks
    if (id == '${prefix}tracks') {
      // Load tracks
      Playlist? favPlaylist;
      try {
        favPlaylist = await deezerAPI.fullPlaylist(deezerAPI.favoritesPlaylistId ?? '');
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
      if ((favPlaylist?.tracks?.length ?? 0) == 0) return;

      await GetIt.I<AudioPlayerHandler>().playFromTrackList(
          favPlaylist!.tracks!, favPlaylist.tracks![0].id ?? '',
          QueueSource(id: 'allTracks', text: 'All offline tracks'.i18n, source: 'offline'));
      return;
    }
    // Play playlists
    if (id.startsWith('${prefix}playlist')) {
      Playlist p = await deezerAPI.fullPlaylist(id.replaceFirst('${prefix}playlist', ''));
      await GetIt.I<AudioPlayerHandler>().playFromPlaylist(p, p.tracks?[0].id ?? '');
      return;
    }
    // Play albums
    if (id.startsWith('${prefix}album')) {
      Album a = await deezerAPI.album(id.replaceFirst('${prefix}album', ''));
      await GetIt.I<AudioPlayerHandler>().playFromAlbum(a, a.tracks?[0].id ?? '');
      return;
    }
    // Play smart track list
    if (id.startsWith('${prefix}stl')) {
      SmartTrackList stl = await deezerAPI.smartTrackList(id.replaceFirst('${prefix}stl', ''));
      await GetIt.I<AudioPlayerHandler>().playFromSmartTrackList(stl);
      return;
    }
  }

  // Homescreen items
  List<MediaItem> homeScreen() {
    return [
      MediaItem(
        id: '${prefix}flow',
        title: 'Flow'.i18n,
        album: 'Flow'.i18n,
        displayTitle: 'Flow'.i18n,
        playable: true,
      ),
      MediaItem(
        id: 'homescreen',
        title: 'Home'.i18n,
        album: '',
        displayTitle: 'Home'.i18n,
        playable: false,
      ),
      MediaItem(
        id: '${prefix}tracks',
        title: 'Loved tracks'.i18n,
        album: '',
        displayTitle: 'Loved tracks'.i18n,
        playable: true,
      ),
      MediaItem(
        id: 'playlists',
        title: 'Playlists'.i18n,
        album: '',
        displayTitle: 'Playlists'.i18n,
        playable: false,
      ),
      MediaItem(
        id: 'albums',
        title: 'Albums'.i18n,
        album: '',
        displayTitle: 'Albums'.i18n,
        playable: false,
      ),
      MediaItem(
        id: 'artists',
        title: 'Artists'.i18n,
        album: '',
        displayTitle: 'Artists'.i18n,
        playable: false,
      ),
    ];
  }
}
