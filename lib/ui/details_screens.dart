// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_it/get_it.dart';

import '../api/cache.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';
import '../service/audio_service.dart';
import '../translations.i18n.dart';
import '../ui/elements.dart';
import '../ui/error.dart';
import '../ui/search.dart';
import 'cached_image.dart';
import 'menu.dart';
import 'tiles.dart';

class AlbumDetails extends StatefulWidget {
  final Album album;
  const AlbumDetails(this.album, {super.key});

  @override
  _AlbumDetailsState createState() => _AlbumDetailsState();
}

class _AlbumDetailsState extends State<AlbumDetails> {
  Album album = Album();
  bool _loading = true;
  bool _error = false;

  Future _loadAlbum() async {
    //Get album from API, if doesn't have tracks
    if ((album.tracks ?? []).isEmpty) {
      try {
        Album a = await deezerAPI.album(album.id ?? '');
        //Preserve library
        a.library = album.library;
        setState(() => album = a);
      } catch (e) {
        setState(() => _error = true);
      }
    }
    setState(() => _loading = false);
  }

  //Get count of CDs in album
  int get cdCount {
    int c = 1;
    for (Track t in (album.tracks ?? [])) {
      if ((t.diskNumber ?? 1) > c) c = t.diskNumber!;
    }
    return c;
  }

  @override
  void initState() {
    album = widget.album;
    _loadAlbum();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: _error
            ? const ErrorScreen()
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: <Widget>[
                      //Album art, title, artists
                      Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              height: 8.0,
                            ),
                            ZoomableImage(
                              url: album.art?.full ?? '',
                              width: MediaQuery.of(context).size.width / 2,
                              rounded: true,
                            ),
                            Container(
                              height: 8,
                            ),
                            Text(
                              album.title ?? '',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              album.artistString ?? '',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: TextStyle(fontSize: 16.0, color: Theme.of(context).primaryColor),
                            ),
                            Container(height: 4.0),
                            if (album.releaseDate != null && album.releaseDate!.length >= 4)
                              Text(
                                album.releaseDate!,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.0, color: Theme.of(context).disabledColor),
                              ),
                            Container(
                              height: 8.0,
                            ),
                          ],
                        ),
                      ),
                      const FreezerDivider(),
                      //Details
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.audiotrack,
                                size: 32.0,
                                semanticLabel: 'Tracks'.i18n,
                              ),
                              const SizedBox(
                                width: 8.0,
                                height: 42.0,
                              ), //Height to adjust card height
                              Text(
                                album.tracks?.length.toString() ?? '0',
                                style: const TextStyle(fontSize: 16.0),
                              )
                            ],
                          ),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.timelapse,
                                size: 32.0,
                                semanticLabel: 'Duration'.i18n,
                              ),
                              Container(
                                width: 8.0,
                              ),
                              Text(
                                album.durationString,
                                style: const TextStyle(fontSize: 16.0),
                              )
                            ],
                          ),
                          Row(
                            children: <Widget>[
                              Icon(Icons.people, size: 32.0, semanticLabel: 'Fans'.i18n),
                              Container(
                                width: 8.0,
                              ),
                              Text(
                                album.fansString ?? '',
                                style: const TextStyle(fontSize: 16.0),
                              )
                            ],
                          ),
                        ],
                      ),
                      const FreezerDivider(),
                      //Options (offline, download...)
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[
                          TextButton(
                            child: Row(
                              children: <Widget>[
                                Icon((album.library ?? false) ? Icons.favorite : Icons.favorite_border, size: 32),
                                Container(
                                  width: 4,
                                ),
                                Text('Library'.i18n)
                              ],
                            ),
                            onPressed: () async {
                              //Add to library
                              if (!(album.library ?? false)) {
                                await deezerAPI.addFavoriteAlbum(album.id ?? '');
                                Fluttertoast.showToast(
                                    msg: 'Added to library'.i18n,
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.BOTTOM);
                                setState(() => album.library = true);
                                return;
                              }
                              //Remove
                              await deezerAPI.removeAlbum(album.id ?? '');
                              Fluttertoast.showToast(
                                  msg: 'Album removed from library!'.i18n,
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM);
                              setState(() => album.library = false);
                            },
                          ),
                          MakeAlbumOffline(album: album),
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
                              if (await downloadManager.addOfflineAlbum(album, private: false) != false) {
                                MenuSheet().showDownloadStartedToast();
                              }
                            },
                          )
                        ],
                      ),
                      const FreezerDivider(),
                      ...List.generate(cdCount, (cdi) {
                        List<Track> tracks = [];
                        if (album.tracks != null) {
                          tracks.addAll(album.tracks!.where((t) => (t.diskNumber ?? 1) == cdi + 1).toList());
                        }
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                'Disk'.i18n.toUpperCase() + ' ${cdi + 1}',
                                style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w300),
                              ),
                            ),
                            ...List.generate(
                                tracks.length,
                                (i) => TrackTile(tracks[i], onTap: () {
                                      GetIt.I<AudioPlayerHandler>().playFromAlbum(album, tracks[i].id ?? '');
                                    }, onHold: () {
                                      MenuSheet m = MenuSheet();
                                      m.defaultTrackMenu(tracks[i], context: context);
                                    }))
                          ],
                        );
                      }),
                    ],
                  ));
  }
}

class MakeAlbumOffline extends StatefulWidget {
  final Album? album;
  const MakeAlbumOffline({super.key, this.album});

  @override
  _MakeAlbumOfflineState createState() => _MakeAlbumOfflineState();
}

class _MakeAlbumOfflineState extends State<MakeAlbumOffline> {
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    downloadManager.checkOffline(album: widget.album).then((v) {
      setState(() {
        _offline = v;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Switch(
          value: _offline,
          onChanged: (v) async {
            if (v) {
              //Add to offline
              await deezerAPI.addFavoriteAlbum(widget.album?.id ?? '');
              await downloadManager.addOfflineAlbum(widget.album ?? Album(), private: true);
              MenuSheet().showDownloadStartedToast();
              setState(() {
                _offline = true;
              });
              return;
            }
            downloadManager.removeOfflineAlbum(widget.album?.id ?? '');
            Fluttertoast.showToast(
                msg: 'Removed album from offline!'.i18n, gravity: ToastGravity.BOTTOM, toastLength: Toast.LENGTH_SHORT);
            setState(() {
              _offline = false;
            });
          },
        ),
        Container(
          width: 4.0,
        ),
        Text(
          'Offline'.i18n,
          style: const TextStyle(fontSize: 16),
        )
      ],
    );
  }
}

class ArtistDetails extends StatefulWidget {
  final Artist artist;
  const ArtistDetails(this.artist, {super.key});

  @override
  _ArtistDetailsState createState() => _ArtistDetailsState();
}

class _ArtistDetailsState extends State<ArtistDetails> {
  Artist artist = Artist();
  bool _loading = true;
  bool _error = false;

  Future _loadArtist() async {
    //Load artist from api if no albums
    if (artist.albums.isEmpty) {
      try {
        Artist a = await deezerAPI.artist(artist.id ?? '');
        setState(() => artist = a);
      } catch (e) {
        setState(() => _error = true);
      }
    }
    setState(() => _loading = false);
  }

  @override
  void initState() {
    artist = widget.artist;
    _loadArtist();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: _error
            ? const ErrorScreen()
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: <Widget>[
                      Container(height: 4.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          ZoomableImage(
                            url: artist.picture?.full ?? '',
                            width: MediaQuery.of(context).size.width / 2 - 8,
                            rounded: true,
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width / 2 - 24,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  artist.name ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 4,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  height: 8.0,
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.people,
                                      size: 32.0,
                                      semanticLabel: 'Fans'.i18n,
                                    ),
                                    Container(
                                      width: 8,
                                    ),
                                    Text(
                                      artist.fansString,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 4.0,
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.album,
                                      size: 32.0,
                                      semanticLabel: 'Albums'.i18n,
                                    ),
                                    Container(
                                      width: 8.0,
                                    ),
                                    Text(
                                      artist.albumCount.toString(),
                                      style: const TextStyle(fontSize: 16),
                                    )
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(height: 4.0),
                      const FreezerDivider(),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[
                          TextButton(
                            child: Row(
                              children: <Widget>[
                                const Icon(Icons.favorite, size: 32),
                                Container(
                                  width: 4,
                                ),
                                Text('Library'.i18n)
                              ],
                            ),
                            onPressed: () async {
                              await deezerAPI.addFavoriteArtist(artist.id ?? '');
                              Fluttertoast.showToast(
                                  msg: 'Added to library'.i18n,
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM);
                            },
                          ),
                          if ((artist.radio ?? false))
                            TextButton(
                              child: Row(
                                children: <Widget>[
                                  const Icon(Icons.radio, size: 32),
                                  Container(
                                    width: 4,
                                  ),
                                  Text('Radio'.i18n)
                                ],
                              ),
                              onPressed: () async {
                                List<Track> tracks = await deezerAPI.smartRadio(artist.id ?? '');
                                if (tracks.isNotEmpty) {
                                  GetIt.I<AudioPlayerHandler>().playFromTrackList(
                                      tracks,
                                      tracks[0].id!,
                                      QueueSource(
                                          id: artist.id, text: 'Radio'.i18n + ' ${artist.name}', source: 'smartradio'));
                                }
                              },
                            )
                        ],
                      ),
                      const FreezerDivider(),
                      Container(
                        height: 12.0,
                      ),
                      //Highlight
                      if (artist.highlight != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                              child: Text(
                                artist.highlight?.title ?? '',
                                textAlign: TextAlign.left,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
                              ),
                            ),
                            if ((artist.highlight?.type ?? '') == ArtistHighlightType.ALBUM)
                              AlbumTile(
                                artist.highlight?.data,
                                onTap: () {
                                  Navigator.of(context).push(
                                      MaterialPageRoute(builder: (context) => AlbumDetails(artist.highlight?.data)));
                                },
                              ),
                            Container(height: 8.0)
                          ],
                        ),
                      //Top tracks
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                        child: Text(
                          'Top Tracks'.i18n,
                          textAlign: TextAlign.left,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
                        ),
                      ),
                      Container(height: 4.0),
                      ...List.generate(5, (i) {
                        if (artist.topTracks.length <= i) {
                          return const SizedBox(
                            height: 0,
                            width: 0,
                          );
                        }
                        Track t = artist.topTracks[i];
                        return TrackTile(
                          t,
                          onTap: () {
                            GetIt.I<AudioPlayerHandler>().playFromTopTracks(artist.topTracks, t.id!, artist);
                          },
                          onHold: () {
                            MenuSheet mi = MenuSheet();
                            mi.defaultTrackMenu(t, context: context);
                          },
                        );
                      }),
                      ListTile(
                          title: Text('Show more tracks'.i18n),
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => TrackListScreen(
                                    artist.topTracks,
                                    QueueSource(
                                        id: artist.id, text: 'Top'.i18n + '${artist.name}', source: 'topTracks'))));
                          }),
                      const FreezerDivider(),
                      //Albums
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text(
                          'Top Albums'.i18n,
                          textAlign: TextAlign.left,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
                        ),
                      ),
                      ...List.generate(artist.albums.length > 10 ? 11 : artist.albums.length + 1, (i) {
                        //Show discography
                        if (i == 10 || i == artist.albums.length) {
                          return ListTile(
                              title: Text('Show all albums'.i18n),
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => DiscographyScreen(
                                          artist: artist,
                                        )));
                              });
                        }
                        //Top albums
                        Album a = artist.albums[i];
                        return AlbumTile(
                          a,
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) => AlbumDetails(a)));
                          },
                          onHold: () {
                            MenuSheet m = MenuSheet();
                            m.defaultAlbumMenu(a, context: context);
                          },
                        );
                      })
                    ],
                  ));
  }
}

class DiscographyScreen extends StatefulWidget {
  final Artist artist;
  const DiscographyScreen({required this.artist, super.key});

  @override
  _DiscographyScreenState createState() => _DiscographyScreenState();
}

class _DiscographyScreenState extends State<DiscographyScreen> {
  late Artist artist;
  bool _loading = false;
  bool _error = false;
  final List<ScrollController> _controllers = [ScrollController(), ScrollController(), ScrollController()];

  Future _load() async {
    if (artist.albums.length >= (artist.albumCount ?? 0) || _loading) return;
    setState(() => _loading = true);

    //Fetch data
    List<Album> data;
    try {
      data = await deezerAPI.discographyPage(artist.id ?? '', start: artist.albums.length);
    } catch (e) {
      setState(() {
        _error = true;
        _loading = false;
      });
      return;
    }

    //Save
    setState(() {
      artist.albums.addAll(data);
      _loading = false;
    });
  }

  //Get album tile
  Widget _tile(Album a) => AlbumTile(
        a,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => AlbumDetails(a))),
        onHold: () {
          MenuSheet m = MenuSheet();
          m.defaultAlbumMenu(a, context: context);
        },
      );

  Widget get _loadingWidget {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [CircularProgressIndicator()],
        ),
      );
    }
    //Error
    if (_error) return const ErrorScreen();
    //Success
    return const SizedBox(
      width: 0,
      height: 0,
    );
  }

  @override
  void initState() {
    artist = widget.artist;

    //Lazy loading scroll
    for (var c in _controllers) {
      c.addListener(() {
        double off = c.position.maxScrollExtent * 0.85;
        if (c.position.pixels > off) _load();
      });
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 3,
        child: Builder(builder: (BuildContext context) {
          final TabController tabController = DefaultTabController.of(context);
          tabController.addListener(() {
            if (!tabController.indexIsChanging) {
              //Load data if empty tabs
              int nSingles = artist.albums.where((a) => a.type == AlbumType.SINGLE).length;
              int nFeatures = artist.albums.where((a) => a.type == AlbumType.FEATURED).length;
              if ((nSingles == 0 || nFeatures == 0) && !_loading) _load();
            }
          });

          return Scaffold(
            appBar: FreezerAppBar(
              'Discography'.i18n,
              bottom: TabBar(
                tabs: [
                  Tab(
                      icon: Icon(
                    Icons.album,
                    semanticLabel: 'Albums'.i18n,
                  )),
                  Tab(icon: Icon(Icons.audiotrack, semanticLabel: 'Singles'.i18n)),
                  Tab(
                      icon: Icon(
                    Icons.recent_actors,
                    semanticLabel: 'Featured'.i18n,
                  ))
                ],
              ),
              height: 100.0,
            ),
            body: TabBarView(
              children: [
                //Albums
                ListView.builder(
                  controller: _controllers[0],
                  itemCount: artist.albums.length + 1,
                  itemBuilder: (context, i) {
                    if (i == artist.albums.length) return _loadingWidget;
                    if (artist.albums[i].type == AlbumType.ALBUM) {
                      return _tile(artist.albums[i]);
                    }
                    return const SizedBox(
                      width: 0,
                      height: 0,
                    );
                  },
                ),
                //Singles
                ListView.builder(
                  controller: _controllers[1],
                  itemCount: artist.albums.length + 1,
                  itemBuilder: (context, i) {
                    if (i == artist.albums.length) return _loadingWidget;
                    if (artist.albums[i].type == AlbumType.SINGLE) {
                      return _tile(artist.albums[i]);
                    }
                    return const SizedBox(
                      width: 0,
                      height: 0,
                    );
                  },
                ),
                //Featured
                ListView.builder(
                  controller: _controllers[2],
                  itemCount: artist.albums.length + 1,
                  itemBuilder: (context, i) {
                    if (i == artist.albums.length) return _loadingWidget;
                    if (artist.albums[i].type == AlbumType.FEATURED) {
                      return _tile(artist.albums[i]);
                    }
                    return const SizedBox(
                      width: 0,
                      height: 0,
                    );
                  },
                ),
              ],
            ),
          );
        }));
  }
}

class PlaylistDetails extends StatefulWidget {
  final Playlist playlist;
  const PlaylistDetails(this.playlist, {super.key});

  @override
  _PlaylistDetailsState createState() => _PlaylistDetailsState();
}

class _PlaylistDetailsState extends State<PlaylistDetails> {
  late Playlist playlist;
  bool _loading = false;
  bool _error = false;
  late Sorting _sort;
  final ScrollController _scrollController = ScrollController();

  //Get sorted playlist
  List<Track> get sorted {
    List<Track> tracks = List.from(playlist.tracks ?? []);
    switch (_sort.type) {
      case SortType.ALPHABETIC:
        tracks.sort((a, b) => a.title!.compareTo(b.title!));
        break;
      case SortType.ARTIST:
        tracks.sort((a, b) => a.artists![0].name!.toLowerCase().compareTo(b.artists![0].name!.toLowerCase()));
        break;
      case SortType.DATE_ADDED:
        tracks.sort((a, b) => (a.addedDate ?? 0) - (b.addedDate ?? 0));
        break;
      case SortType.DEFAULT:
      default:
        break;
    }
    //Reverse
    if (_sort.reverse) return tracks.reversed.toList();
    return tracks;
  }

  //Load tracks from api
  void _loadTracks() async {
    // Got all tracks, return
    if (_loading || playlist.tracks!.length >= (playlist.trackCount ?? playlist.tracks!.length)) return;

    setState(() => _loading = true);
    int pos = playlist.tracks!.length;
    //Get another page of tracks
    List<Track> tracks;
    try {
      tracks = await deezerAPI.playlistTracksPage(playlist.id!, pos, nb: 25);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
      return;
    }

    setState(() {
      playlist.tracks!.addAll(tracks);
      _loading = false;
    });
  }

  //Load cached playlist sorting
  void _restoreSort() async {
    //Find index
    int? index = Sorting.index(SortSourceTypes.PLAYLIST, id: playlist.id);
    if (index == null) return;

    //Preload tracks
    if (playlist.tracks!.length < (playlist.trackCount ?? 0)) {
      playlist = await deezerAPI.fullPlaylist(playlist.id!);
    }
    setState(() => _sort = cache.sorts[index]);
  }

  Future _reverse() async {
    setState(() => _sort.reverse = !_sort.reverse);
    //Save sorting in cache
    int? index = Sorting.index(SortSourceTypes.TRACKS);
    if (index != null) {
      cache.sorts[index] = _sort;
    } else {
      cache.sorts.add(_sort);
    }
    await cache.save();

    //Preload for sorting
    if (playlist.tracks!.length < (playlist.trackCount ?? 0)) {
      playlist = await deezerAPI.fullPlaylist(playlist.id!);
    }
  }

  @override
  void initState() {
    playlist = widget.playlist;
    _sort = Sorting(sourceType: SortSourceTypes.PLAYLIST, id: playlist.id);
    //If scrolled past 90% load next tracks
    _scrollController.addListener(() {
      double off = _scrollController.position.maxScrollExtent * 0.90;
      if (_scrollController.position.pixels > off) {
        _loadTracks();
      }
    });
    // Initial load if no tracks
    if (playlist.tracks!.isEmpty) {
      //Get correct metadata
      setState(() => _loading = true);
      deezerAPI.playlist(playlist.id!, nb: 25).then((Playlist p) {
        setState(() {
          playlist = p;
          _loading = false;
        });
        //Load tracks
        //_load();
      }).catchError((e) {
        if (mounted) setState(() => _error = true);
      });
    }

    _restoreSort();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: DraggableScrollbar.rrect(
      controller: _scrollController,
      backgroundColor: Theme.of(context).primaryColor,
      child: ListView(
        controller: _scrollController,
        children: <Widget>[
          Container(
            height: 4.0,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                CachedImage(
                  url: playlist.image?.full ?? '',
                  height: MediaQuery.of(context).size.width / 2 - 8,
                  rounded: true,
                  fullThumb: true,
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width / 2 - 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        playlist.title ?? '',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                      ),
                      Container(height: 4.0),
                      Text(
                        playlist.user?.name ?? '',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 17.0),
                      ),
                      Container(height: 10.0),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.audiotrack,
                            size: 32.0,
                            semanticLabel: 'Tracks'.i18n,
                          ),
                          Container(
                            width: 8.0,
                          ),
                          Text(
                            (playlist.trackCount ?? playlist.tracks!.length).toString(),
                            style: const TextStyle(fontSize: 16),
                          )
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.timelapse,
                            size: 32.0,
                            semanticLabel: 'Duration'.i18n,
                          ),
                          Container(
                            width: 8.0,
                          ),
                          Text(
                            playlist.durationString,
                            style: const TextStyle(fontSize: 16),
                          )
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          if (playlist.description != null && playlist.description!.isNotEmpty) const FreezerDivider(),
          if (playlist.description != null && playlist.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Text(
                playlist.description!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16.0),
              ),
            ),
          const FreezerDivider(),
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              MakePlaylistOffline(playlist),
              if (playlist.user?.name != deezerAPI.userName)
                IconButton(
                  icon: Icon(
                    (playlist.library ?? false) ? Icons.favorite : Icons.favorite_outline,
                    size: 32,
                    semanticLabel: (playlist.library ?? false) ? 'Unlove'.i18n : 'Love'.i18n,
                  ),
                  onPressed: () async {
                    //Add to library
                    if (!(playlist.library ?? false)) {
                      await deezerAPI.addPlaylist(playlist.id!);
                      Fluttertoast.showToast(
                          msg: 'Added to library'.i18n, toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM);
                      setState(() => playlist.library = true);
                      return;
                    }
                    //Remove
                    await deezerAPI.removePlaylist(playlist.id!);
                    Fluttertoast.showToast(
                        msg: 'Playlist removed from library!'.i18n,
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM);
                    setState(() => playlist.library = false);
                  },
                ),
              IconButton(
                icon: Icon(
                  Icons.file_download,
                  size: 32.0,
                  semanticLabel: 'Download'.i18n,
                ),
                onPressed: () async {
                  if (await downloadManager.addOfflinePlaylist(playlist, private: false) != false) {
                    MenuSheet().showDownloadStartedToast();
                  }
                },
              ),
              PopupMenuButton(
                color: Theme.of(context).scaffoldBackgroundColor,
                onSelected: (SortType s) async {
                  if (playlist.tracks!.length < (playlist.trackCount ?? 0)) {
                    //Preload whole playlist
                    playlist = await deezerAPI.fullPlaylist(playlist.id!);
                  }
                  setState(() => _sort.type = s);

                  //Save sort type to cache
                  int? index = Sorting.index(SortSourceTypes.PLAYLIST, id: playlist.id);
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
                    value: SortType.DATE_ADDED,
                    child: Text('Date added'.i18n, style: popupMenuTextStyle()),
                  ),
                ],
                child: Icon(
                  Icons.sort,
                  size: 32.0,
                  semanticLabel: 'Sort playlist'.i18n,
                ),
              ),
              IconButton(
                icon: Icon(
                  _sort.reverse ? FontAwesome5.sort_alpha_up : FontAwesome5.sort_alpha_down,
                  semanticLabel: _sort.reverse ? 'Sort descending'.i18n : 'Sort ascending'.i18n,
                ),
                onPressed: () => _reverse(),
              ),
              Container(width: 4.0)
            ],
          ),
          const FreezerDivider(),
          ...List.generate(playlist.tracks!.length, (i) {
            Track t = sorted[i];
            return TrackTile(t, onTap: () {
              Playlist p = Playlist(title: playlist.title, id: playlist.id, tracks: sorted);
              GetIt.I<AudioPlayerHandler>().playFromPlaylist(p, t.id!);
            }, onHold: () {
              MenuSheet m = MenuSheet();
              m.defaultTrackMenu(t, context: context, options: [
                (playlist.user?.id == deezerAPI.userId)
                    ? m.removeFromPlaylist(t, playlist, context)
                    : const SizedBox(
                        width: 0,
                        height: 0,
                      )
              ]);
            });
          }),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[CircularProgressIndicator()],
              ),
            ),
          if (_error) const ErrorScreen()
        ],
      ),
    ));
  }
}

class MakePlaylistOffline extends StatefulWidget {
  final Playlist playlist;
  const MakePlaylistOffline(this.playlist, {super.key});

  @override
  _MakePlaylistOfflineState createState() => _MakePlaylistOfflineState();
}

class _MakePlaylistOfflineState extends State<MakePlaylistOffline> {
  late Playlist playlist;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    downloadManager.checkOffline(playlist: widget.playlist).then((v) {
      setState(() {
        _offline = v;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Switch(
          value: _offline,
          onChanged: (v) async {
            if (v) {
              //Add to offline
              if (widget.playlist.user?.id != deezerAPI.userId) {
                await deezerAPI.addPlaylist(widget.playlist.id!);
              }
              downloadManager.addOfflinePlaylist(widget.playlist, private: true);
              MenuSheet().showDownloadStartedToast();
              setState(() {
                _offline = true;
              });
              return;
            }
            downloadManager.removeOfflinePlaylist(widget.playlist.id!);
            Fluttertoast.showToast(
                msg: 'Playlist removed from offline!'.i18n,
                gravity: ToastGravity.BOTTOM,
                toastLength: Toast.LENGTH_SHORT);
            setState(() {
              _offline = false;
            });
          },
        ),
        Container(
          width: 4.0,
        ),
        Text(
          'Offline'.i18n,
          style: const TextStyle(fontSize: 16),
        )
      ],
    );
  }
}

class ShowScreen extends StatefulWidget {
  final Show show;
  const ShowScreen(this.show, {super.key});

  @override
  _ShowScreenState createState() => _ShowScreenState();
}

class _ShowScreenState extends State<ShowScreen> {
  late Show _show;
  bool _loading = true;
  bool _error = false;
  late List<ShowEpisode> _episodes;

  Future _load() async {
    //Fetch
    List<ShowEpisode> e;
    try {
      e = await deezerAPI.allShowEpisodes(_show.id!);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }
    setState(() {
      _episodes = e;
      _loading = false;
    });
  }

  @override
  void initState() {
    _show = widget.show;
    _load();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar(_show.name!),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                CachedImage(
                  url: _show.art?.full ?? '',
                  rounded: true,
                  width: MediaQuery.of(context).size.width / 2 - 16,
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width / 2 - 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(_show.name!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold)),
                      Container(height: 8.0),
                      Text(
                        _show.description ?? '',
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16.0),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          Container(height: 4.0),
          const FreezerDivider(),

          //Error
          if (_error) const ErrorScreen(),

          //Loading
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [CircularProgressIndicator()],
              ),
            ),

          //Data
          if (!_loading && !_error)
            ...List.generate(_episodes.length, (i) {
              ShowEpisode e = _episodes[i];
              return ShowEpisodeTile(
                e,
                trailing: IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    semanticLabel: 'Options'.i18n,
                  ),
                  onPressed: () {
                    MenuSheet m = MenuSheet();
                    m.defaultShowEpisodeMenu(_show, e, context: context);
                  },
                ),
                onTap: () async {
                  await GetIt.I<AudioPlayerHandler>().playShowEpisode(_show, _episodes, index: i);
                },
              );
            })
        ],
      ),
    );
  }
}
