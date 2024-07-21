import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:fluttericon/typicons_icons.dart';
import 'package:get_it/get_it.dart';

import '../api/cache.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';
import '../service/audio_service.dart';
import '../translations.i18n.dart';
import '../ui/details_screens.dart';
import '../ui/elements.dart';
import '../ui/home_screen.dart';
import '../ui/menu.dart';
import '../utils/navigator_keys.dart';
import './error.dart';
import './tiles.dart';
import 'downloads_screen.dart';
import 'settings_screen.dart';

openScreenByURL(String url) async {
  DeezerLinkResponse? res = await deezerAPI.parseLink(url);
  if (res == null || res.type == null) return;

  switch (res.type!) {
    case DeezerLinkType.TRACK:
      Track t = await deezerAPI.track(res.id!);
      MenuSheet()
          .defaultTrackMenu(t, context: mainNavigatorKey.currentContext!);
      break;
    case DeezerLinkType.ALBUM:
      Album a = await deezerAPI.album(res.id!);
      mainNavigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (context) => AlbumDetails(a)));
      break;
    case DeezerLinkType.ARTIST:
      Artist a = await deezerAPI.artist(res.id!);
      mainNavigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (context) => ArtistDetails(a)));
      break;
    case DeezerLinkType.PLAYLIST:
      Playlist p = await deezerAPI.playlist(res.id!);
      mainNavigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (context) => PlaylistDetails(p)));
      break;
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String? _query;
  bool _offline = false;
  bool _loading = false;
  final TextEditingController _controller = TextEditingController();
  FocusNode _keyboardListenerFocusNode = FocusNode();
  FocusNode _textFieldFocusNode = FocusNode();
  List _suggestions = [];
  bool _cancel = false;
  bool _showCards = true;

  void _submit(BuildContext context, {String? query}) async {
    if (query != null) {
      _query = query;
    }

    //URL
    if (_query != null && _query!.startsWith('http')) {
      setState(() => _loading = true);
      try {
        await openScreenByURL(_query!);
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
      setState(() => _loading = false);
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
              _query ?? '',
              offline: _offline,
            )));
  }

  @override
  void initState() {
    _cancel = false;
    //Check for connectivity and enable offline mode
    Connectivity().checkConnectivity().then((res) {
      if (res.isEmpty || res.contains(ConnectivityResult.none)) {
        setState(() {
          _offline = true;
        });
      }
    });

    super.initState();
  }

  //Load search suggestions
  Future<List?> _loadSuggestions() async {
    if (_query == null || _query!.length < 2 || _query!.startsWith('http')) {
      return null;
    }
    String q = _query!;
    await Future.delayed(const Duration(milliseconds: 300));
    if (q != _query) return null;
    //Load
    late List sugg;
    try {
      sugg = await deezerAPI.searchSuggestions(_query!);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }

    if (!_cancel) setState(() => _suggestions = sugg);
    return sugg;
  }

  Widget _removeHistoryItemWidget(int index) {
    return IconButton(
        icon: Icon(
          Icons.close,
          semanticLabel: 'Remove'.i18n,
        ),
        onPressed: () async {
          cache.searchHistory?.removeAt(index);
          setState(() {});
          await cache.save();
        });
  }

  @override
  void dispose() {
    _cancel = true;
    _textFieldFocusNode.dispose();
    _keyboardListenerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar(
        'Search'.i18n,
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
      ),
      body: FocusScope(
        child: ListView(
          children: <Widget>[
            Container(height: 4.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                      child: Stack(
                    alignment: const Alignment(1.0, 0.0),
                    children: [
                      KeyboardListener(
                        focusNode: _keyboardListenerFocusNode = FocusNode(),
                        onKeyEvent: (event) {
                          // For Android TV: quit search textfield
                          /*if (event is KeyUpEvent) {
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowDown) {
                              _textFieldFocusNode.unfocus();
                            }
                          }*/
                        },
                        child: TextField(
                          onChanged: (String s) {
                            setState(() {
                              _showCards = false;
                              _query = s;
                            });
                            _loadSuggestions();
                          },
                          onTap: () {
                            setState(() => _showCards = false);
                          },
                          focusNode: _textFieldFocusNode = FocusNode(),
                          decoration: InputDecoration(
                            labelText: 'Search or paste URL'.i18n,
                            fillColor:
                                Theme.of(context).bottomAppBarTheme.color,
                            filled: true,
                            focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey)),
                            enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey)),
                          ),
                          controller: _controller,
                          onSubmitted: (String s) {
                            _submit(context, query: s);
                            _textFieldFocusNode.unfocus();
                          },
                        ),
                      ),
                      Focus(
                          canRequestFocus:
                              false, // Focus is moving to cross, and hangs out there,
                          descendantsAreFocusable:
                              false, // so we disable focusing on it at all
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 40.0,
                                child: IconButton(
                                  splashRadius: 20.0,
                                  icon: Icon(
                                    Icons.clear,
                                    semanticLabel: 'Clear'.i18n,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _suggestions = [];
                                      _query = '';
                                    });
                                    _controller.clear();
                                  },
                                ),
                              ),
                            ],
                          ))
                    ],
                  )),
                ],
              ),
            ),
            Container(height: 8.0),
            ListTile(
              title: Text('Offline search'.i18n),
              leading: const Icon(Icons.offline_pin),
              trailing: Switch(
                value: _offline,
                onChanged: (v) {
                  setState(() => _offline = !_offline);
                },
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            const FreezerDivider(),

            //"Browse" Cards
            if (_showCards) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Text(
                  'Quick access',
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SearchBrowseCard(
                    color: const Color(0xff11b192),
                    text: 'Flow'.i18n,
                    icon: const Icon(Typicons.waves),
                    onTap: () async {
                      // No channel for Flow...
                      await GetIt.I<AudioPlayerHandler>()
                          .playFromSmartTrackList(SmartTrackList(id: 'flow'));
                    },
                  ),
                  SearchBrowseCard(
                    color: const Color(0xff7c42bb),
                    text: 'Shows'.i18n,
                    icon: const Icon(FontAwesome5.podcast),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: FreezerAppBar('Shows'.i18n),
                        body: SingleChildScrollView(
                            child: HomePageScreen(
                                channel: DeezerChannel(target: 'shows'))),
                      ),
                    )),
                  )
                ],
              ),
              Container(height: 4.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SearchBrowseCard(
                    color: const Color(0xffff555d),
                    icon: const Icon(FontAwesome5.chart_line),
                    text: 'Charts'.i18n,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: FreezerAppBar('Charts'.i18n),
                        body: SingleChildScrollView(
                            child: HomePageScreen(
                                channel:
                                    DeezerChannel(target: 'channels/charts'))),
                      ),
                    )),
                  ),
                  SearchBrowseCard(
                    color: const Color(0xff2c4ea7),
                    text: 'Browse'.i18n,
                    icon: Image.asset('assets/browse_icon.png', width: 26.0),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: FreezerAppBar('Browse'.i18n),
                        body: SingleChildScrollView(
                            child: HomePageScreen(
                                channel:
                                    DeezerChannel(target: 'channels/explore'))),
                      ),
                    )),
                  )
                ],
              )
            ],

            //History
            if (!_showCards &&
                (cache.searchHistory?.length ?? 0) > 0 &&
                (_query ?? '').length < 2)
              ...List.generate(
                  cache.searchHistory!.length > 10
                      ? 10
                      : cache.searchHistory!.length, (int i) {
                dynamic data = cache.searchHistory![i].data;
                switch (cache.searchHistory![i].type) {
                  case SearchHistoryItemType.TRACK:
                    return TrackTile(
                      data,
                      onTap: () {
                        List<Track> queue = cache.searchHistory!
                            .where((h) => h.type == SearchHistoryItemType.TRACK)
                            .map<Track>((t) => t.data)
                            .toList();
                        GetIt.I<AudioPlayerHandler>().playFromTrackList(
                            queue,
                            data.id,
                            QueueSource(
                                text: 'Search history'.i18n,
                                source: 'searchhistory',
                                id: 'searchhistory'));
                      },
                      onHold: () {
                        MenuSheet m = MenuSheet();
                        m.defaultTrackMenu(data, context: context);
                      },
                      trailing: _removeHistoryItemWidget(i),
                    );
                  case SearchHistoryItemType.ALBUM:
                    return AlbumTile(
                      data,
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => AlbumDetails(data)));
                      },
                      onHold: () {
                        MenuSheet m = MenuSheet();
                        m.defaultAlbumMenu(data, context: context);
                      },
                      trailing: _removeHistoryItemWidget(i),
                    );
                  case SearchHistoryItemType.ARTIST:
                    return ArtistHorizontalTile(
                      data,
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => ArtistDetails(data)));
                      },
                      onHold: () {
                        MenuSheet m = MenuSheet();
                        m.defaultArtistMenu(data, context: context);
                      },
                      trailing: _removeHistoryItemWidget(i),
                    );
                  case SearchHistoryItemType.PLAYLIST:
                    return PlaylistTile(
                      data,
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => PlaylistDetails(data)));
                      },
                      onHold: () {
                        MenuSheet m = MenuSheet();
                        m.defaultPlaylistMenu(data, context: context);
                      },
                      trailing: _removeHistoryItemWidget(i),
                    );
                  default:
                    return Container();
                }
              }),

            //Clear history
            if (cache.searchHistory != null && cache.searchHistory!.length > 2)
              ListTile(
                title: Text('Clear search history'.i18n),
                leading: const Icon(Icons.clear_all),
                onTap: () {
                  cache.searchHistory = [];
                  cache.save();
                  setState(() {});
                },
              ),

            //Suggestions
            ...List.generate(
                _suggestions.length,
                (i) => ListTile(
                      title: Text(_suggestions[i]),
                      leading: const Icon(Icons.search),
                      onTap: () {
                        setState(() => _query = _suggestions[i]);
                        _submit(context);
                      },
                    ))
          ],
        ),
      ),
    );
  }
}

class SearchBrowseCard extends StatelessWidget {
  final Color color;
  final Widget? icon;
  final VoidCallback onTap;
  final String text;
  const SearchBrowseCard(
      {super.key,
      required this.color,
      required this.onTap,
      required this.text,
      this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: MediaQuery.of(context).size.width / 2 - 32,
            height: 75,
            child: Center(
                child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) icon!,
                if (icon != null) Container(width: 8.0),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: (color.computeLuminance() > 0.5)
                          ? Colors.black
                          : Colors.white),
                ),
              ],
            )),
          ),
        ));
  }
}

class SearchResultsScreen extends StatelessWidget {
  final String query;
  final bool? offline;

  const SearchResultsScreen(this.query, {super.key, this.offline});

  Future _search() async {
    if (offline ?? false) {
      return await downloadManager.search(query);
    }
    return await deezerAPI.search(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: FreezerAppBar('Search Results'.i18n),
        body: FutureBuilder(
          future: _search(),
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) return const ErrorScreen();

            SearchResults results = snapshot.data;

            if (results.empty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.warning,
                      size: 64,
                    ),
                    Text('No results!'.i18n)
                  ],
                ),
              );
            }

            //Tracks
            List<Widget> tracks = [];
            if (results.tracks != null && results.tracks!.isNotEmpty) {
              tracks = [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  child: Text(
                    'Tracks'.i18n,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                        fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                ),
                ...List.generate(3, (i) {
                  if (results.tracks!.length <= i) {
                    return const SizedBox(
                      width: 0,
                      height: 0,
                    );
                  }
                  Track t = results.tracks![i];
                  return TrackTile(
                    t,
                    onTap: () {
                      cache.addToSearchHistory(t);
                      GetIt.I<AudioPlayerHandler>().playFromTrackList(
                          results.tracks!,
                          t.id ?? '',
                          QueueSource(
                              text: 'Search'.i18n,
                              id: query,
                              source: 'search'));
                    },
                    onHold: () {
                      MenuSheet m = MenuSheet();
                      m.defaultTrackMenu(t, context: context);
                    },
                  );
                }),
                ListTile(
                  title: Text('Show all tracks'.i18n),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => TrackListScreen(
                            results.tracks!,
                            QueueSource(
                                id: query,
                                source: 'search',
                                text: 'Search'.i18n))));
                  },
                ),
                const FreezerDivider()
              ];
            }

            //Albums
            List<Widget> albums = [];
            if (results.albums != null && results.albums!.isNotEmpty) {
              albums = [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  child: Text(
                    'Albums'.i18n,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                        fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                ),
                ...List.generate(3, (i) {
                  if (results.albums!.length <= i) {
                    return const SizedBox(
                      height: 0,
                      width: 0,
                    );
                  }
                  Album a = results.albums![i];
                  return AlbumTile(
                    a,
                    onHold: () {
                      MenuSheet m = MenuSheet();
                      m.defaultAlbumMenu(a, context: context);
                    },
                    onTap: () {
                      cache.addToSearchHistory(a);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => AlbumDetails(a)));
                    },
                  );
                }),
                ListTile(
                  title: Text('Show all albums'.i18n),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            AlbumListScreen(results.albums!)));
                  },
                ),
                const FreezerDivider()
              ];
            }

            //Artists
            List<Widget> artists = [];
            if (results.artists != null && results.artists!.isNotEmpty) {
              artists = [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 4.0, horizontal: 16.0),
                  child: Text(
                    'Artists'.i18n,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                        fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(height: 4),
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(results.artists!.length, (int i) {
                        Artist a = results.artists![i];
                        return ArtistTile(
                          a,
                          onTap: () {
                            cache.addToSearchHistory(a);
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => ArtistDetails(a)));
                          },
                          onHold: () {
                            MenuSheet m = MenuSheet();
                            m.defaultArtistMenu(a, context: context);
                          },
                        );
                      }),
                    )),
                const FreezerDivider()
              ];
            }

            //Playlists
            List<Widget> playlists = [];
            if (results.playlists != null && results.playlists!.isNotEmpty) {
              playlists = [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 4.0, horizontal: 16.0),
                  child: Text(
                    'Playlists'.i18n,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                        fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                ),
                ...List.generate(3, (i) {
                  if (results.playlists!.length <= i) {
                    return const SizedBox(
                      height: 0,
                      width: 0,
                    );
                  }
                  Playlist p = results.playlists![i];
                  return PlaylistTile(
                    p,
                    onTap: () {
                      cache.addToSearchHistory(p);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => PlaylistDetails(p)));
                    },
                    onHold: () {
                      MenuSheet m = MenuSheet();
                      m.defaultPlaylistMenu(p, context: context);
                    },
                  );
                }),
                ListTile(
                  title: Text('Show all playlists'.i18n),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            SearchResultPlaylists(results.playlists!)));
                  },
                ),
                const FreezerDivider()
              ];
            }

            //Shows
            List<Widget> shows = [];
            if (results.shows != null && results.shows!.isNotEmpty) {
              shows = [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 4.0, horizontal: 16.0),
                  child: Text(
                    'Shows'.i18n,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                        fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                ),
                ...List.generate(3, (i) {
                  if (results.shows!.length <= i) {
                    return const SizedBox(
                      height: 0,
                      width: 0,
                    );
                  }
                  Show s = results.shows![i];
                  return ShowTile(
                    s,
                    onTap: () async {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => ShowScreen(s)));
                    },
                  );
                }),
                ListTile(
                  title: Text('Show all shows'.i18n),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => ShowListScreen(results.shows!)));
                  },
                ),
                const FreezerDivider()
              ];
            }

            //Episodes
            List<Widget> episodes = [];
            if (results.episodes != null && results.episodes!.isNotEmpty) {
              episodes = [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 4.0, horizontal: 16.0),
                  child: Text(
                    'Episodes'.i18n,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                        fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                ),
                ...List.generate(3, (i) {
                  if (results.episodes!.length <= i) {
                    return const SizedBox(
                      height: 0,
                      width: 0,
                    );
                  }
                  ShowEpisode e = results.episodes![i];
                  return ShowEpisodeTile(
                    e,
                    trailing: IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        semanticLabel: 'Options'.i18n,
                      ),
                      onPressed: () {
                        MenuSheet m = MenuSheet();
                        m.defaultShowEpisodeMenu(e.show!, e, context: context);
                      },
                    ),
                    onTap: () async {
                      //Load entire show, then play
                      List<ShowEpisode> episodes =
                          await deezerAPI.allShowEpisodes(e.show!.id ?? '');
                      await GetIt.I<AudioPlayerHandler>().playShowEpisode(
                          e.show!, episodes,
                          index: episodes.indexWhere((ep) => e.id == ep.id));
                    },
                  );
                }),
                ListTile(
                    title: Text('Show all episodes'.i18n),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) =>
                              EpisodeListScreen(results.episodes!)));
                    })
              ];
            }

            return ListView(
              children: <Widget>[
                Container(
                  height: 8.0,
                ),
                ...tracks,
                Container(
                  height: 8.0,
                ),
                ...albums,
                Container(
                  height: 8.0,
                ),
                ...artists,
                Container(
                  height: 8.0,
                ),
                ...playlists,
                Container(
                  height: 8.0,
                ),
                ...shows,
                Container(
                  height: 8.0,
                ),
                ...episodes
              ],
            );
          },
        ));
  }
}

//List all tracks
class TrackListScreen extends StatelessWidget {
  final QueueSource queueSource;
  final List<Track> tracks;

  const TrackListScreen(this.tracks, this.queueSource, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Tracks'.i18n),
      body: ListView.builder(
        itemCount: tracks.length,
        itemBuilder: (BuildContext context, int i) {
          Track t = tracks[i];
          return TrackTile(
            t,
            onTap: () {
              GetIt.I<AudioPlayerHandler>()
                  .playFromTrackList(tracks, t.id ?? '', queueSource);
            },
            onHold: () {
              MenuSheet m = MenuSheet();
              m.defaultTrackMenu(t, context: context);
            },
          );
        },
      ),
    );
  }
}

//List all albums
class AlbumListScreen extends StatelessWidget {
  final List<Album> albums;
  const AlbumListScreen(this.albums, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Albums'.i18n),
      body: ListView.builder(
        itemCount: albums.length,
        itemBuilder: (context, i) {
          Album a = albums[i];
          return AlbumTile(
            a,
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => AlbumDetails(a)));
            },
            onHold: () {
              MenuSheet m = MenuSheet();
              m.defaultAlbumMenu(a, context: context);
            },
          );
        },
      ),
    );
  }
}

class SearchResultPlaylists extends StatelessWidget {
  final List<Playlist> playlists;
  const SearchResultPlaylists(this.playlists, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Playlists'.i18n),
      body: ListView.builder(
        itemCount: playlists.length,
        itemBuilder: (context, i) {
          Playlist p = playlists[i];
          return PlaylistTile(
            p,
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => PlaylistDetails(p)));
            },
            onHold: () {
              MenuSheet m = MenuSheet();
              m.defaultPlaylistMenu(p, context: context);
            },
          );
        },
      ),
    );
  }
}

class ShowListScreen extends StatelessWidget {
  final List<Show> shows;
  const ShowListScreen(this.shows, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Shows'.i18n),
      body: ListView.builder(
        itemCount: shows.length,
        itemBuilder: (context, i) {
          Show s = shows[i];
          return ShowTile(
            s,
            onTap: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (context) => ShowScreen(s)));
            },
          );
        },
      ),
    );
  }
}

class EpisodeListScreen extends StatelessWidget {
  final List<ShowEpisode> episodes;
  const EpisodeListScreen(this.episodes, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: FreezerAppBar('Episodes'.i18n),
        body: ListView.builder(
          itemCount: episodes.length,
          itemBuilder: (context, i) {
            ShowEpisode e = episodes[i];
            return ShowEpisodeTile(
              e,
              trailing: IconButton(
                icon: Icon(
                  Icons.more_vert,
                  semanticLabel: 'Options'.i18n,
                ),
                onPressed: () {
                  MenuSheet m = MenuSheet();
                  m.defaultShowEpisodeMenu(e.show!, e, context: context);
                },
              ),
              onTap: () async {
                //Load entire show, then play
                List<ShowEpisode> episodes =
                    await deezerAPI.allShowEpisodes(e.show!.id ?? '');
                await GetIt.I<AudioPlayerHandler>().playShowEpisode(
                    e.show!, episodes,
                    index: episodes.indexWhere((ep) => e.id == ep.id));
              },
            );
          },
        ));
  }
}
