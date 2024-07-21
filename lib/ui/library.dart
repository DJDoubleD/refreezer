import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../api/cache.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';
import '../api/importer.dart';
import '../service/audio_service.dart';
import '../settings.dart';
import '../translations.i18n.dart';
import '../ui/details_screens.dart';
import '../ui/downloads_screen.dart';
import '../ui/elements.dart';
import '../ui/error.dart';
import '../ui/importer_screen.dart';
import '../ui/tiles.dart';
import 'menu.dart';
import 'settings_screen.dart';

class LibraryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LibraryAppBar({super.key});

  @override
  Size get preferredSize => AppBar().preferredSize;

  @override
  Widget build(BuildContext context) {
    return FreezerAppBar(
      'Library'.i18n,
      actions: <Widget>[
        IconButton(
          icon: Icon(
            Icons.file_download,
            semanticLabel: 'Download'.i18n,
          ),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const DownloadsScreen()));
          },
        ),
        IconButton(
          icon: Icon(
            Icons.settings,
            semanticLabel: 'Settings'.i18n,
          ),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const SettingsScreen()));
          },
        ),
      ],
    );
  }
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LibraryAppBar(),
      body: ListView(
        children: <Widget>[
          Container(
            height: 4.0,
          ),
          if (!downloadManager.running && downloadManager.queueSize > 0)
            ListTile(
              title: Text('Downloads'.i18n),
              leading:
                  const LeadingIcon(Icons.file_download, color: Colors.grey),
              subtitle: Text(
                  'Downloading is currently stopped, click here to resume.'
                      .i18n),
              onTap: () {
                downloadManager.start();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const DownloadsScreen()));
              },
            ),
          ListTile(
            title: Text('Shuffle'.i18n),
            leading: const LeadingIcon(Icons.shuffle, color: Color(0xffeca704)),
            onTap: () async {
              List<Track> tracks = await deezerAPI.libraryShuffle();
              GetIt.I<AudioPlayerHandler>().playFromTrackList(
                  tracks,
                  tracks[0].id!,
                  QueueSource(
                      id: 'libraryshuffle',
                      source: 'libraryshuffle',
                      text: 'Library shuffle'.i18n));
            },
          ),
          const FreezerDivider(),
          ListTile(
            title: Text('Tracks'.i18n),
            leading:
                const LeadingIcon(Icons.audiotrack, color: Color(0xffbe3266)),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const LibraryTracks()));
            },
          ),
          ListTile(
            title: Text('Albums'.i18n),
            leading: const LeadingIcon(Icons.album, color: Color(0xff4b2e7e)),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const LibraryAlbums()));
            },
          ),
          ListTile(
            title: Text('Artists'.i18n),
            leading: const LeadingIcon(Icons.recent_actors,
                color: Color(0xff384697)),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const LibraryArtists()));
            },
          ),
          ListTile(
            title: Text('Playlists'.i18n),
            leading: const LeadingIcon(Icons.playlist_play,
                color: Color(0xff0880b5)),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const LibraryPlaylists()));
            },
          ),
          const FreezerDivider(),
          ListTile(
            title: Text('History'.i18n),
            leading: const LeadingIcon(Icons.history, color: Color(0xff009a85)),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const HistoryScreen()));
            },
          ),
          const FreezerDivider(),
          ListTile(
            title: Text('Import'.i18n),
            leading: const LeadingIcon(Icons.import_export,
                color: Color(0xff2ba766)),
            subtitle: Text('Import playlists from Spotify'.i18n),
            onTap: () {
              //Show progress
              if (importer.done || importer.busy) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const ImporterStatusScreen()));
                return;
              }

              //Pick importer dialog
              showDialog(
                  context: context,
                  builder: (context) => SimpleDialog(
                        title: Text('Importer'.i18n),
                        children: [
                          ListTile(
                            leading: const Icon(FontAwesome5.spotify),
                            title: Text('Spotify v1'.i18n),
                            subtitle: Text(
                                'Import Spotify playlists up to 100 tracks without any login.'
                                    .i18n),
                            enabled:
                                false, // Spotify reworked embedded playlist. Source format is changed and data no longer contains ISRC.
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) =>
                                      const SpotifyImporterV1()));
                            },
                          ),
                          ListTile(
                            leading: const Icon(FontAwesome5.spotify),
                            title: Text('Spotify v2'.i18n),
                            subtitle: Text(
                                'Import any Spotify playlist, import from own Spotify library. Requires free account.'
                                    .i18n),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) =>
                                      const SpotifyImporterV2()));
                            },
                          )
                        ],
                      ));
            },
          ),
          ExpansionTile(
            title: Text('Statistics'.i18n),
            leading: const LeadingIcon(Icons.insert_chart, color: Colors.grey),
            children: <Widget>[
              FutureBuilder(
                future: downloadManager.getStats(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const ErrorScreen();
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[CircularProgressIndicator()],
                      ),
                    );
                  }
                  List<String> data = snapshot.data!;
                  return Column(
                    children: <Widget>[
                      ListTile(
                        title: Text('Offline tracks'.i18n),
                        leading: const Icon(Icons.audiotrack),
                        trailing: Text(data[0]),
                      ),
                      ListTile(
                        title: Text('Offline albums'.i18n),
                        leading: const Icon(Icons.album),
                        trailing: Text(data[1]),
                      ),
                      ListTile(
                        title: Text('Offline playlists'.i18n),
                        leading: const Icon(Icons.playlist_add),
                        trailing: Text(data[2]),
                      ),
                      ListTile(
                        title: Text('Offline size'.i18n),
                        leading: const Icon(Icons.sd_card),
                        trailing: Text(data[3]),
                      ),
                      ListTile(
                        title: Text('Free space'.i18n),
                        leading: const Icon(Icons.disc_full),
                        trailing: Text(data[4]),
                      ),
                    ],
                  );
                },
              )
            ],
          )
        ],
      ),
    );
  }
}

class LibraryTracks extends StatefulWidget {
  const LibraryTracks({super.key});

  @override
  _LibraryTracksState createState() => _LibraryTracksState();
}

class _LibraryTracksState extends State<LibraryTracks> {
  bool _loading = false;
  bool _loadingTracks = false;
  final ScrollController _scrollController = ScrollController();
  List<Track> tracks = [];
  List<Track> allTracks = [];
  int? trackCount;
  Sorting _sort = Sorting(sourceType: SortSourceTypes.TRACKS);

  Playlist get _playlist => Playlist(id: deezerAPI.favoritesPlaylistId);

  List<Track> get _sorted {
    List<Track> tcopy = List.from(tracks);
    tcopy.sort((a, b) => a.addedDate!.compareTo(b.addedDate!));
    switch (_sort.type) {
      case SortType.ALPHABETIC:
        tcopy.sort((a, b) => a.title!.compareTo(b.title!));
        break;
      case SortType.ARTIST:
        tcopy.sort((a, b) => a.artists![0].name!
            .toLowerCase()
            .compareTo(b.artists![0].name!.toLowerCase()));
        break;
      case SortType.DEFAULT:
      default:
        break;
    }
    //Reverse
    if (_sort.reverse) return tcopy.reversed.toList();
    return tcopy;
  }

  Future _reverse() async {
    if (mounted) setState(() => _sort.reverse = !_sort.reverse);
    //Save sorting in cache
    int? index = Sorting.index(SortSourceTypes.TRACKS);
    if (index != null) {
      cache.sorts[index] = _sort;
    } else {
      cache.sorts.add(_sort);
    }
    await cache.save();

    //Preload for sorting
    if (tracks.length < (trackCount ?? 0)) _loadFull();
  }

  Future _load() async {
    //Already loaded
    if (trackCount != null && (tracks.length >= (trackCount ?? 0))) {
      //Update favorite tracks cache when fully loaded
      if (cache.libraryTracks?.length != trackCount) {
        if (mounted) {
          setState(() {
            cache.libraryTracks = tracks.map((t) => t.id!).toList();
          });
          await cache.save();
        }
      }
      return;
    }

    List<ConnectivityResult> connectivity =
        await Connectivity().checkConnectivity();
    if (connectivity.isNotEmpty &&
        !connectivity.contains(ConnectivityResult.none)) {
      if (mounted) setState(() => _loading = true);
      int pos = tracks.length;

      if (tracks.isEmpty) {
        //Load tracks as a playlist
        Playlist? favPlaylist;
        try {
          favPlaylist =
              await deezerAPI.playlist(deezerAPI.favoritesPlaylistId ?? '');
        } catch (e) {
          if (kDebugMode) {
            print(e);
          }
        }
        //Error loading
        if (favPlaylist == null) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        //Update
        if (mounted) {
          setState(() {
            trackCount = favPlaylist!.trackCount;
            if (tracks.isEmpty) tracks = favPlaylist.tracks!;
            _makeFavorite();
            _loading = false;
          });
        }
        return;
      }

      //Load another page of tracks from deezer
      if (_loadingTracks) return;
      _loadingTracks = true;

      List<Track>? t;
      try {
        t = await deezerAPI.playlistTracksPage(
            deezerAPI.favoritesPlaylistId ?? '', pos);
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
      //On error load offline
      if (t == null) {
        await _loadOffline();
        return;
      }
      if (mounted) {
        setState(() {
          tracks.addAll(t!);
          _makeFavorite();
          _loading = false;
          _loadingTracks = false;
        });
      }
    }
  }

  //Load all tracks
  Future _loadFull() async {
    if (tracks.isEmpty || tracks.length < (trackCount ?? 0)) {
      late Playlist p;
      try {
        p = await deezerAPI.fullPlaylist(deezerAPI.favoritesPlaylistId ?? '');
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
      if (mounted) {
        setState(() {
          tracks = p.tracks!;
          trackCount = p.trackCount;
          _sort = _sort;
        });
      }
    }
  }

  Future _loadOffline() async {
    Playlist? p = await downloadManager
        .getOfflinePlaylist(deezerAPI.favoritesPlaylistId ?? '');
    if (mounted) {
      setState(() {
        tracks = p?.tracks ?? [];
      });
    }
  }

  Future _loadAllOffline() async {
    List<Track> tracks = await downloadManager.allOfflineTracks();
    if (mounted) {
      setState(() {
        allTracks = tracks;
      });
    }
  }

  //Update tracks with favorite true
  void _makeFavorite() {
    for (int i = 0; i < tracks.length; i++) {
      tracks[i].favorite = true;
    }
  }

  @override
  void initState() {
    _scrollController.addListener(() {
      //Load more tracks on scroll
      double off = _scrollController.position.maxScrollExtent * 0.90;
      if (_scrollController.position.pixels > off) _load();
    });

    _load();
    //Load all offline tracks
    _loadAllOffline();

    //Load sorting
    int? index = Sorting.index(SortSourceTypes.TRACKS);
    if (index != null) {
      if (mounted) setState(() => _sort = cache.sorts[index]);
    }

    if (_sort.type != SortType.DEFAULT || _sort.reverse) _loadFull();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: FreezerAppBar(
          'Tracks'.i18n,
          actions: [
            IconButton(
                icon: Icon(
                  _sort.reverse
                      ? FontAwesome5.sort_alpha_up
                      : FontAwesome5.sort_alpha_down,
                  semanticLabel: _sort.reverse
                      ? 'Sort descending'.i18n
                      : 'Sort ascending'.i18n,
                ),
                onPressed: () async {
                  await _reverse();
                }),
            PopupMenuButton(
              color: Theme.of(context).scaffoldBackgroundColor,
              onSelected: (SortType s) async {
                //Preload for sorting
                if (tracks.length < (trackCount ?? 0)) await _loadFull();

                setState(() => _sort.type = s);
                //Save sorting in cache
                int? index = Sorting.index(SortSourceTypes.TRACKS);
                if (index != null) {
                  cache.sorts[index] = _sort;
                } else {
                  cache.sorts.add(_sort);
                }
                await cache.save();
              },
              itemBuilder: (context) => <PopupMenuEntry<SortType>>[
                PopupMenuItem(
                  value: SortType.DEFAULT,
                  child: Text('Default'.i18n, style: popupMenuTextStyle()),
                ),
                PopupMenuItem(
                  value: SortType.ALPHABETIC,
                  child: Text('Alphabetic'.i18n, style: popupMenuTextStyle()),
                ),
                PopupMenuItem(
                  value: SortType.ARTIST,
                  child: Text('Artist'.i18n, style: popupMenuTextStyle()),
                ),
              ],
              child: Icon(
                Icons.sort,
                size: 32.0,
                semanticLabel: 'Sort'.i18n,
              ),
            ),
            Container(width: 8.0),
          ],
        ),
        body: DraggableScrollbar.rrect(
            controller: _scrollController,
            backgroundColor: Theme.of(context).primaryColor,
            child: ListView(
              controller: _scrollController,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    MakePlaylistOffline(_playlist),
                    TextButton(
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.file_download,
                            size: 32.0,
                          ),
                          Container(
                            width: 4,
                          ),
                          Text('Download'.i18n)
                        ],
                      ),
                      onPressed: () async {
                        if (await downloadManager.addOfflinePlaylist(_playlist,
                                private: false) !=
                            false) {
                          MenuSheet().showDownloadStartedToast();
                        }
                      },
                    )
                  ],
                ),
                const FreezerDivider(),
                //Loved tracks
                ...List.generate(tracks.length, (i) {
                  Track t = (tracks.length == (trackCount ?? 0))
                      ? _sorted[i]
                      : tracks[i];
                  return TrackTile(
                    t,
                    onTap: () {
                      GetIt.I<AudioPlayerHandler>().playFromTrackList(
                          (tracks.length == (trackCount ?? 0))
                              ? _sorted
                              : tracks,
                          t.id!,
                          QueueSource(
                              id: deezerAPI.favoritesPlaylistId,
                              text: 'Favorites'.i18n,
                              source: 'playlist'));
                    },
                    onHold: () {
                      MenuSheet m = MenuSheet();
                      m.defaultTrackMenu(t, context: context, onRemove: () {
                        setState(() {
                          tracks.removeWhere((track) => t.id == track.id);
                        });
                      });
                    },
                  );
                }),
                if (_loading)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: CircularProgressIndicator(),
                      )
                    ],
                  ),
                const FreezerDivider(),
                Text(
                  'All offline tracks'.i18n,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Container(
                  height: 8,
                ),
                ...List.generate(allTracks.length, (i) {
                  Track t = allTracks[i];
                  return TrackTile(
                    t,
                    onTap: () {
                      GetIt.I<AudioPlayerHandler>().playFromTrackList(
                          allTracks,
                          t.id!,
                          QueueSource(
                              id: 'allTracks',
                              text: 'All offline tracks'.i18n,
                              source: 'offline'));
                    },
                    onHold: () {
                      MenuSheet m = MenuSheet();
                      m.defaultTrackMenu(t, context: context);
                    },
                  );
                })
              ],
            )));
  }
}

class LibraryAlbums extends StatefulWidget {
  const LibraryAlbums({super.key});

  @override
  _LibraryAlbumsState createState() => _LibraryAlbumsState();
}

class _LibraryAlbumsState extends State<LibraryAlbums> {
  List<Album>? _albums;
  Sorting _sort = Sorting(sourceType: SortSourceTypes.ALBUMS);
  final ScrollController _scrollController = ScrollController();

  List<Album> get _sorted {
    List<Album> albums = List.from(_albums ?? []);
    if (albums.isNotEmpty) {
      albums.sort((a, b) => a.favoriteDate!.compareTo(b.favoriteDate!));
      switch (_sort.type) {
        case SortType.DEFAULT:
          break;
        case SortType.ALPHABETIC:
          albums.sort((a, b) =>
              a.title!.toLowerCase().compareTo(b.title!.toLowerCase()));
          break;
        case SortType.ARTIST:
          albums.sort((a, b) => a.artists![0].name!
              .toLowerCase()
              .compareTo(b.artists![0].name!.toLowerCase()));
          break;
        case SortType.RELEASE_DATE:
          albums.sort((a, b) => DateTime.parse(a.releaseDate!)
              .compareTo(DateTime.parse(b.releaseDate!)));
          break;
        default:
          break;
      }
    }
    //Reverse
    if (_sort.reverse) return albums.reversed.toList();
    return albums;
  }

  Future _load() async {
    if (settings.offlineMode) return;
    try {
      List<Album> albums = await deezerAPI.getAlbums();
      if (mounted) setState(() => _albums = albums);
    } catch (e) {
      Logger.root.severe('Error loading albums: $e', StackTrace);
    }
  }

  @override
  void initState() {
    _load();
    //Load sorting
    int? index = Sorting.index(SortSourceTypes.ALBUMS);
    if (index != null) {
      _sort = cache.sorts[index];
    }

    super.initState();
  }

  Future _reverse() async {
    setState(() => _sort.reverse = !_sort.reverse);
    //Save sorting in cache
    int? index = Sorting.index(SortSourceTypes.ALBUMS);
    if (index != null) {
      cache.sorts[index] = _sort;
    } else {
      cache.sorts.add(_sort);
    }
    await cache.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: FreezerAppBar(
          'Albums'.i18n,
          actions: [
            IconButton(
              icon: Icon(
                _sort.reverse
                    ? FontAwesome5.sort_alpha_up
                    : FontAwesome5.sort_alpha_down,
                semanticLabel: _sort.reverse
                    ? 'Sort descending'.i18n
                    : 'Sort ascending'.i18n,
              ),
              onPressed: () => _reverse(),
            ),
            PopupMenuButton(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Icon(Icons.sort, size: 32.0),
              onSelected: (SortType s) async {
                setState(() => _sort.type = s);
                //Save to cache
                int? index = Sorting.index(SortSourceTypes.ALBUMS);
                if (index == null) {
                  cache.sorts.add(_sort);
                } else {
                  cache.sorts[index] = _sort;
                }
                await cache.save();
              },
              itemBuilder: (context) => <PopupMenuEntry<SortType>>[
                PopupMenuItem(
                  value: SortType.DEFAULT,
                  child: Text('Default'.i18n, style: popupMenuTextStyle()),
                ),
                PopupMenuItem(
                  value: SortType.ALPHABETIC,
                  child: Text('Alphabetic'.i18n, style: popupMenuTextStyle()),
                ),
                PopupMenuItem(
                  value: SortType.ARTIST,
                  child: Text('Artist'.i18n, style: popupMenuTextStyle()),
                ),
                PopupMenuItem(
                  value: SortType.RELEASE_DATE,
                  child: Text('Release date'.i18n, style: popupMenuTextStyle()),
                ),
              ],
            ),
            Container(width: 8.0),
          ],
        ),
        body: DraggableScrollbar.rrect(
          controller: _scrollController,
          backgroundColor: Theme.of(context).primaryColor,
          child: ListView(
            controller: _scrollController,
            children: <Widget>[
              Container(
                height: 8.0,
              ),
              if (!settings.offlineMode && _albums == null)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[CircularProgressIndicator()],
                ),
              if (_albums != null)
                ...List.generate(_albums?.length ?? 0, (int i) {
                  Album a = _sorted[i];
                  return AlbumTile(
                    a,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => AlbumDetails(a)));
                    },
                    onHold: () async {
                      MenuSheet m = MenuSheet();
                      m.defaultAlbumMenu(a, context: context, onRemove: () {
                        setState(() => _albums?.remove(a));
                      });
                    },
                  );
                }),
              FutureBuilder(
                future: downloadManager.getOfflineAlbums(),
                builder: (context, snapshot) {
                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return const SizedBox(
                      height: 0,
                      width: 0,
                    );
                  }

                  List<Album> albums = snapshot.data!;
                  return Column(
                    children: <Widget>[
                      const FreezerDivider(),
                      Text(
                        'Offline albums'.i18n,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 24.0),
                      ),
                      ...List.generate(albums.length, (i) {
                        Album a = albums[i];
                        return AlbumTile(
                          a,
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => AlbumDetails(a)));
                          },
                          onHold: () async {
                            MenuSheet m = MenuSheet();
                            m.defaultAlbumMenu(a, context: context,
                                onRemove: () {
                              setState(() {
                                albums.remove(a);
                                _albums?.remove(a);
                              });
                            });
                          },
                        );
                      })
                    ],
                  );
                },
              )
            ],
          ),
        ));
  }
}

class LibraryArtists extends StatefulWidget {
  const LibraryArtists({super.key});

  @override
  _LibraryArtistsState createState() => _LibraryArtistsState();
}

class _LibraryArtistsState extends State<LibraryArtists> {
  List<Artist> _artists = [];
  Sorting _sort = Sorting(sourceType: SortSourceTypes.ARTISTS);
  bool _loading = true;
  bool _error = false;
  final ScrollController _scrollController = ScrollController();

  List<Artist> get _sorted {
    List<Artist> artists = List.from(_artists);
    if (artists.isNotEmpty) {
      artists.sort((a, b) => a.favoriteDate!.compareTo(b.favoriteDate!));
      switch (_sort.type) {
        case SortType.DEFAULT:
          break;
        case SortType.POPULARITY:
          artists.sort((a, b) => b.fans! - a.fans!);
          break;
        case SortType.ALPHABETIC:
          artists.sort(
              (a, b) => a.name!.toLowerCase().compareTo(b.name!.toLowerCase()));
          break;
        default:
          break;
      }
    }
    //Reverse
    if (_sort.reverse) return artists.reversed.toList();
    return artists;
  }

  //Load data
  Future _load() async {
    if (mounted) setState(() => _loading = true);
    //Fetch
    List<Artist>? data;
    try {
      data = await deezerAPI.getArtists();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    //Update UI
    if (mounted) {
      setState(() {
        if (data != null) {
          _artists = data;
        } else {
          _error = true;
        }
        _loading = false;
      });
    }
  }

  Future _reverse() async {
    setState(() => _sort.reverse = !_sort.reverse);
    //Save sorting in cache
    int? index = Sorting.index(SortSourceTypes.ARTISTS);
    if (index != null) {
      cache.sorts[index] = _sort;
    } else {
      cache.sorts.add(_sort);
    }
    await cache.save();
  }

  @override
  void initState() {
    //Restore sort
    int? index = Sorting.index(SortSourceTypes.ARTISTS);
    if (index != null) {
      _sort = cache.sorts[index];
    }

    _load();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: FreezerAppBar(
          'Artists'.i18n,
          actions: [
            IconButton(
              icon: Icon(
                _sort.reverse
                    ? FontAwesome5.sort_alpha_up
                    : FontAwesome5.sort_alpha_down,
                semanticLabel: _sort.reverse
                    ? 'Sort descending'.i18n
                    : 'Sort ascending'.i18n,
              ),
              onPressed: () => _reverse(),
            ),
            PopupMenuButton(
              color: Theme.of(context).scaffoldBackgroundColor,
              onSelected: (SortType s) async {
                setState(() => _sort.type = s);
                //Save
                int? index = Sorting.index(SortSourceTypes.ARTISTS);
                if (index == null) {
                  cache.sorts.add(_sort);
                } else {
                  cache.sorts[index] = _sort;
                }
                await cache.save();
              },
              itemBuilder: (context) => <PopupMenuEntry<SortType>>[
                PopupMenuItem(
                  value: SortType.DEFAULT,
                  child: Text('Default'.i18n, style: popupMenuTextStyle()),
                ),
                PopupMenuItem(
                  value: SortType.ALPHABETIC,
                  child: Text('Alphabetic'.i18n, style: popupMenuTextStyle()),
                ),
                PopupMenuItem(
                  value: SortType.POPULARITY,
                  child: Text('Popularity'.i18n, style: popupMenuTextStyle()),
                ),
              ],
              child: const Icon(Icons.sort, size: 32.0),
            ),
            Container(width: 8.0),
          ],
        ),
        body: DraggableScrollbar.rrect(
          controller: _scrollController,
          backgroundColor: Theme.of(context).primaryColor,
          child: ListView(
            controller: _scrollController,
            children: <Widget>[
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [CircularProgressIndicator()],
                  ),
                ),
              if (_error) const Center(child: ErrorScreen()),
              if (!_loading && !_error)
                ...List.generate(_artists.length, (i) {
                  Artist a = _sorted[i];
                  return ArtistHorizontalTile(
                    a,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => ArtistDetails(a)));
                    },
                    onHold: () {
                      MenuSheet m = MenuSheet();
                      m.defaultArtistMenu(a, context: context, onRemove: () {
                        setState(() {
                          _artists.remove(a);
                        });
                      });
                    },
                  );
                }),
            ],
          ),
        ));
  }
}

class LibraryPlaylists extends StatefulWidget {
  const LibraryPlaylists({super.key});

  @override
  _LibraryPlaylistsState createState() => _LibraryPlaylistsState();
}

class _LibraryPlaylistsState extends State<LibraryPlaylists> {
  List<Playlist>? _playlists;
  Sorting _sort = Sorting(sourceType: SortSourceTypes.PLAYLISTS);
  final ScrollController _scrollController = ScrollController();
  String _filter = '';

  List<Playlist> get _sorted {
    List<Playlist> playlists = List.from(_playlists!
        .where((p) => p.title!.toLowerCase().contains(_filter.toLowerCase())));
    switch (_sort.type) {
      case SortType.DEFAULT:
        break;
      case SortType.USER:
        playlists.sort((a, b) => (a.user?.name ?? deezerAPI.userName!)
            .toLowerCase()
            .compareTo((b.user?.name ?? deezerAPI.userName!).toLowerCase()));
        break;
      case SortType.TRACK_COUNT:
        playlists.sort((a, b) => b.trackCount! - a.trackCount!);
        break;
      case SortType.ALPHABETIC:
        playlists.sort(
            (a, b) => a.title!.toLowerCase().compareTo(b.title!.toLowerCase()));
        break;
      default:
        break;
    }
    if (_sort.reverse) return playlists.reversed.toList();
    return playlists;
  }

  Future _load() async {
    if (!settings.offlineMode) {
      try {
        List<Playlist> playlists = await deezerAPI.getPlaylists();
        if (mounted) setState(() => _playlists = playlists);
      } catch (e) {
        Logger.root.severe('Error loading playlists: $e');
      }
    }
  }

  Future _reverse() async {
    setState(() => _sort.reverse = !_sort.reverse);
    //Save sorting in cache
    int? index = Sorting.index(SortSourceTypes.PLAYLISTS);
    if (index != null) {
      cache.sorts[index] = _sort;
    } else {
      cache.sorts.add(_sort);
    }
    await cache.save();
  }

  @override
  void initState() {
    //Restore sort
    int? index = Sorting.index(SortSourceTypes.PLAYLISTS);
    if (index != null) {
      _sort = cache.sorts[index];
    }

    _load();
    super.initState();
  }

  Playlist get favoritesPlaylist => Playlist(
      id: deezerAPI.favoritesPlaylistId,
      title: 'Favorites'.i18n,
      user: User(name: deezerAPI.userName),
      image: ImageDetails(thumbUrl: 'assets/favorites_thumb.jpg'),
      tracks: [],
      trackCount: 1,
      duration: const Duration(seconds: 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: FreezerAppBar(
          'Playlists'.i18n,
          actions: [
            IconButton(
              icon: Icon(
                _sort.reverse
                    ? FontAwesome5.sort_alpha_up
                    : FontAwesome5.sort_alpha_down,
                semanticLabel: _sort.reverse
                    ? 'Sort descending'.i18n
                    : 'Sort ascending'.i18n,
              ),
              onPressed: () => _reverse(),
            ),
            PopupMenuButton(
              color: Theme.of(context).scaffoldBackgroundColor,
              onSelected: (SortType s) async {
                setState(() => _sort.type = s);
                //Save to cache
                int? index = Sorting.index(SortSourceTypes.PLAYLISTS);
                if (index == null) {
                  cache.sorts.add(_sort);
                } else {
                  cache.sorts[index] = _sort;
                }

                await cache.save();
              },
              itemBuilder: (context) => <PopupMenuEntry<SortType>>[
                PopupMenuItem(
                  value: SortType.DEFAULT,
                  child: Text('Default'.i18n, style: popupMenuTextStyle()),
                ),
                PopupMenuItem(
                  value: SortType.USER,
                  child: Text('User'.i18n, style: popupMenuTextStyle()),
                ),
                PopupMenuItem(
                  value: SortType.TRACK_COUNT,
                  child: Text('Track count'.i18n, style: popupMenuTextStyle()),
                ),
                PopupMenuItem(
                  value: SortType.ALPHABETIC,
                  child: Text('Alphabetic'.i18n, style: popupMenuTextStyle()),
                ),
              ],
              child: const Icon(Icons.sort, size: 32.0),
            ),
            Container(width: 8.0),
          ],
        ),
        body: DraggableScrollbar.rrect(
          controller: _scrollController,
          backgroundColor: Theme.of(context).primaryColor,
          child: ListView(
            controller: _scrollController,
            children: <Widget>[
              //Search
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                    onChanged: (String s) => setState(() => _filter = s),
                    decoration: InputDecoration(
                      labelText: 'Search'.i18n,
                      fillColor: Theme.of(context).bottomAppBarTheme.color,
                      filled: true,
                      focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey)),
                      enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey)),
                    )),
              ),
              ListTile(
                title: Text('Create new playlist'.i18n),
                leading: const LeadingIcon(Icons.playlist_add,
                    color: Color(0xff009a85)),
                onTap: () async {
                  if (settings.offlineMode) {
                    Fluttertoast.showToast(
                        msg: 'Cannot create playlists in offline mode'.i18n,
                        gravity: ToastGravity.BOTTOM);
                    return;
                  }
                  MenuSheet m = MenuSheet();
                  await m.createPlaylist(context);
                  await _load();
                },
              ),
              const FreezerDivider(),

              if (!settings.offlineMode && _playlists == null)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(),
                  ],
                ),

              //Favorites playlist
              PlaylistTile(
                favoritesPlaylist,
                onTap: () async {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) =>
                          PlaylistDetails(favoritesPlaylist)));
                },
                onHold: () {
                  MenuSheet m = MenuSheet();
                  favoritesPlaylist.library = true;
                  m.defaultPlaylistMenu(favoritesPlaylist, context: context);
                },
              ),

              if (_playlists != null)
                ...List.generate(_sorted.length, (int i) {
                  Playlist p = (_sorted)[i];
                  return PlaylistTile(
                    p,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => PlaylistDetails(p))),
                    onHold: () {
                      MenuSheet m = MenuSheet();
                      m.defaultPlaylistMenu(p, context: context, onRemove: () {
                        setState(() => _playlists!.remove(p));
                      }, onUpdate: () {
                        _load();
                      });
                    },
                  );
                }),

              FutureBuilder(
                future: downloadManager.getOfflinePlaylists(),
                builder: (context, snapshot) {
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const SizedBox(
                      height: 0,
                      width: 0,
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox(
                      height: 0,
                      width: 0,
                    );
                  }

                  List<Playlist> playlists = snapshot.data!;
                  return Column(
                    children: <Widget>[
                      const FreezerDivider(),
                      Text(
                        'Offline playlists'.i18n,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 24.0, fontWeight: FontWeight.bold),
                      ),
                      ...List.generate(playlists.length, (i) {
                        Playlist p = playlists[i];
                        return PlaylistTile(
                          p,
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) => PlaylistDetails(p))),
                          onHold: () {
                            MenuSheet m = MenuSheet();
                            m.defaultPlaylistMenu(p, context: context,
                                onRemove: () {
                              setState(() {
                                playlists.remove(p);
                                _playlists!.remove(p);
                              });
                            });
                          },
                        );
                      })
                    ],
                  );
                },
              )
            ],
          ),
        ));
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar(
        'History'.i18n,
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_sweep,
              semanticLabel: 'Clear all'.i18n,
            ),
            onPressed: () {
              setState(() => cache.history = []);
              cache.save();
            },
          )
        ],
      ),
      body: DraggableScrollbar.rrect(
          controller: _scrollController,
          backgroundColor: Theme.of(context).primaryColor,
          child: ListView.builder(
            controller: _scrollController,
            itemCount: (cache.history).length,
            itemBuilder: (BuildContext context, int i) {
              Track t = cache.history[cache.history.length - i - 1];
              return TrackTile(
                t,
                onTap: () {
                  GetIt.I<AudioPlayerHandler>().playFromTrackList(
                      cache.history.reversed.toList(),
                      t.id!,
                      QueueSource(
                          id: null, text: 'History'.i18n, source: 'history'));
                },
                onHold: () {
                  MenuSheet m = MenuSheet();
                  m.defaultTrackMenu(t, context: context);
                },
              );
            },
          )),
    );
  }
}
