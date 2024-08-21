import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spotify/spotify.dart' as spotify;
import 'package:url_launcher/url_launcher_string.dart';

import '../api/importer.dart';
import '../api/spotify.dart';
import '../settings.dart';
import '../translations.i18n.dart';
import '../ui/elements.dart';
import '../ui/menu.dart';

class SpotifyImporterV1 extends StatefulWidget {
  const SpotifyImporterV1({super.key});

  @override
  _SpotifyImporterV1State createState() => _SpotifyImporterV1State();
}

class _SpotifyImporterV1State extends State<SpotifyImporterV1> {
  late String _url;
  bool _error = false;
  bool _loading = false;
  SpotifyPlaylist? _data;

  //Load URL
  Future _load() async {
    setState(() {
      _error = false;
      _loading = true;
    });
    try {
      String uri = await SpotifyScrapper.resolveUrl(_url);

      //Error/NonPlaylist
      if (uri.split(':')[1] != 'playlist') {
        throw Exception();
      }
      //Load
      SpotifyPlaylist data = await SpotifyScrapper.playlist(uri);
      setState(() => _data = data);
      return;
    } catch (e, st) {
      if (kDebugMode) {
        print('$e, $st');
      }
      setState(() {
        _error = true;
        _loading = false;
      });
      return;
    }
  }

  //Start importing
  Future _start() async {
    if (_data != null) {
      List<ImporterTrack>? tracks = _data!.toImporter();
      await importer.start(_data!.name!, _data!.description, tracks);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Importer'.i18n),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text(
                'Currently supporting only Spotify, with 100 tracks limit'
                    .i18n),
            subtitle: Text('Due to API limitations'.i18n),
            leading: const Icon(
              Icons.warning,
              color: Colors.deepOrangeAccent,
            ),
          ),
          const FreezerDivider(),
          Container(
            height: 16.0,
          ),
          Text(
            'Enter your playlist link below'.i18n,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20.0),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    onChanged: (String s) => _url = s,
                    onSubmitted: (String s) {
                      _url = s;
                      _load();
                    },
                    decoration: const InputDecoration(hintText: 'URL'),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.search,
                    semanticLabel: 'Search'.i18n,
                  ),
                  onPressed: () => _load(),
                )
              ],
            ),
          ),
          Container(
            height: 8.0,
          ),

          if (_data == null && _loading)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[CircularProgressIndicator()],
            ),
          if (_error)
            ListTile(
              title: Text('Error loading URL!'.i18n),
              leading: const Icon(
                Icons.error,
                color: Colors.red,
              ),
            ),
          //Playlist
          if (_data != null) ...[
            const FreezerDivider(),
            ListTile(
                title: Text(_data!.name!),
                subtitle: Text((_data!.description ?? '') == ''
                    ? '${_data!.tracks?.length} tracks'
                    : _data!.description!),
                leading: Image.network(_data!.image ??
                    'http://cdn-images.deezer.com/images/cover//256x256-000000-80-0-0.jpg')),
            const ImporterSettings(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
              child: ElevatedButton(
                child: Text('Start import'.i18n),
                onPressed: () async {
                  await _start();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (context) => const ImporterStatusScreen()));
                  }
                },
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class ImporterSettings extends StatefulWidget {
  const ImporterSettings({super.key});

  @override
  _ImporterSettingsState createState() => _ImporterSettingsState();
}

class _ImporterSettingsState extends State<ImporterSettings> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text('Download imported tracks'.i18n),
          leading: Switch(
            value: importer.download,
            onChanged: (v) => setState(() => importer.download = v),
          ),
        ),
      ],
    );
  }
}

class ImporterStatusScreen extends StatefulWidget {
  const ImporterStatusScreen({super.key});

  @override
  _ImporterStatusScreenState createState() => _ImporterStatusScreenState();
}

class _ImporterStatusScreenState extends State<ImporterStatusScreen> {
  bool _done = false;
  late StreamSubscription _subscription;

  @override
  void initState() {
    //If import done mark as not done, to prevent double routing
    if (importer.done) {
      _done = true;
      importer.done = false;
    }

    //Update
    _subscription = importer.updateStream.listen((event) {
      setState(() {
        //Unset done so this page doesn't reopen
        if (importer.done) {
          _done = true;
          importer.done = false;
        }
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Importing...'.i18n),
      body: ListView(
        children: [
          // Spinner
          if (!_done)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[CircularProgressIndicator()],
              ),
            ),

          // Progress indicator
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.import_export,
                    size: 24.0,
                  ),
                  Container(
                    width: 4.0,
                  ),
                  Text(
                    '${importer.ok + importer.error}/${importer.tracks.length}',
                    style: const TextStyle(fontSize: 24.0),
                  )
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.done,
                    size: 24.0,
                  ),
                  Container(
                    width: 4.0,
                  ),
                  Text(
                    '${importer.ok}',
                    style: const TextStyle(fontSize: 24.0),
                  )
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.error,
                    size: 24.0,
                  ),
                  Container(
                    width: 4.0,
                  ),
                  Text(
                    '${importer.error}',
                    style: const TextStyle(fontSize: 24.0),
                  ),
                ],
              ),

              //When Done
              if (_done)
                TextButton(
                  child: Text('Playlist menu'.i18n),
                  onPressed: () {
                    MenuSheet m = MenuSheet();
                    m.defaultPlaylistMenu(importer.playlist!, context: context);
                  },
                )
            ],
          ),
          Container(height: 8.0),
          const FreezerDivider(),

          //Tracks
          ...List.generate(importer.tracks.length, (i) {
            ImporterTrack t = importer.tracks[i];
            return ListTile(
              leading: t.state.icon,
              title: Text(t.title),
              subtitle: Text(
                t.artists.join(', '),
                maxLines: 1,
              ),
            );
          })
        ],
      ),
    );
  }
}

class SpotifyImporterV2 extends StatefulWidget {
  const SpotifyImporterV2({super.key});

  @override
  _SpotifyImporterV2State createState() => _SpotifyImporterV2State();
}

class _SpotifyImporterV2State extends State<SpotifyImporterV2> {
  bool _authorizing = false;
  String? _clientId;
  String? _clientSecret;
  late SpotifyAPIWrapper spotify;

  //Spotify authorization flow
  Future _authorize() async {
    setState(() => _authorizing = true);
    spotify = SpotifyAPIWrapper();
    await spotify.authorize(_clientId ?? '', _clientSecret ?? '');
    //Save credentials
    settings.spotifyClientId = _clientId;
    settings.spotifyClientSecret = _clientSecret;
    await settings.save();
    setState(() => _authorizing = false);
    //Redirect
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => SpotifyImporterV2Main(spotify)));
    }
  }

  @override
  void initState() {
    _clientId = settings.spotifyClientId;
    _clientSecret = settings.spotifyClientSecret;

    //Try saved
    spotify = SpotifyAPIWrapper();
    spotify.trySaved().then((r) {
      if (r) {
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (context) => SpotifyImporterV2Main(spotify)));
        }
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    //Stop server
    spotify.cancelAuthorize();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FreezerAppBar('Spotify Importer v2'.i18n),
      body: ListView(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            child: Text(
              'This importer requires Spotify Client ID and Client Secret. To obtain them:'
                  .i18n,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18.0,
              ),
            ),
          ),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                '1. Go to: developer.spotify.com/dashboard and create an app.'
                    .i18n,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16.0,
                ),
              )),
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
            child: ElevatedButton(
              child: Text('Open in Browser'.i18n),
              onPressed: () {
                launchUrlString('https://developer.spotify.com/dashboard');
              },
            ),
          ),
          Container(height: 16.0),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                '2. In the app you just created go to settings, and set the Redirect URL to: '
                        .i18n +
                    'http://localhost:42069',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16.0,
                ),
              )),
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
            child: ElevatedButton(
              child: Text('Copy the Redirect URL'.i18n),
              onPressed: () async {
                await Clipboard.setData(
                    const ClipboardData(text: 'http://localhost:42069'));
                Fluttertoast.showToast(
                    msg: 'Copied'.i18n,
                    gravity: ToastGravity.BOTTOM,
                    toastLength: Toast.LENGTH_SHORT);
              },
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Flexible(
                  child: TextField(
                    controller: TextEditingController(text: _clientId),
                    decoration: InputDecoration(labelText: 'Client ID'.i18n),
                    onChanged: (v) => setState(() => _clientId = v),
                  ),
                ),
                Container(width: 16.0),
                Flexible(
                  child: TextField(
                    controller: TextEditingController(text: _clientSecret),
                    obscureText: true,
                    decoration:
                        InputDecoration(labelText: 'Client Secret'.i18n),
                    onChanged: (v) => setState(() => _clientSecret = v),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
            child: ElevatedButton(
                onPressed: (!_authorizing) ? () => _authorize() : null,
                child: Text('Authorize'.i18n)),
          ),
          if (_authorizing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [CircularProgressIndicator()],
              ),
            )
        ],
      ),
    );
  }
}

class SpotifyImporterV2Main extends StatefulWidget {
  final SpotifyAPIWrapper spotify;
  const SpotifyImporterV2Main(this.spotify, {super.key});

  @override
  _SpotifyImporterV2MainState createState() => _SpotifyImporterV2MainState();
}

class _SpotifyImporterV2MainState extends State<SpotifyImporterV2Main> {
  String? _url;
  bool _urlLoading = false;
  spotify.Playlist? _urlPlaylist;
  bool _playlistsLoading = true;
  late List<spotify.PlaylistSimple> _playlists;

  @override
  void initState() {
    _loadPlaylists();
    super.initState();
  }

  //Load playlists
  Future _loadPlaylists() async {
    var pages =
        widget.spotify.spotify.users.playlists(widget.spotify.me.id ?? '');
    _playlists = List.from(await pages.all());
    setState(() => _playlistsLoading = false);
  }

  Future _loadUrl() async {
    setState(() => _urlLoading = true);
    //Resolve URL
    try {
      String uri = await SpotifyScrapper.resolveUrl(_url ?? '');
      //Error/NonPlaylist
      if (uri.split(':')[1] != 'playlist') {
        throw Exception();
      }
      //Get playlist
      spotify.Playlist playlist =
          await widget.spotify.spotify.playlists.get(uri.split(':')[2]);
      setState(() {
        _urlLoading = false;
        _urlPlaylist = playlist;
      });
    } catch (e) {
      Fluttertoast.showToast(
          msg: 'Invalid/Unsupported URL'.i18n,
          gravity: ToastGravity.BOTTOM,
          toastLength: Toast.LENGTH_SHORT);
      setState(() => _urlLoading = false);
      return;
    }
  }

  Future _startImport(String title, String description, String id) async {
    //Show loading dialog
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
            canPop: false,
            child: AlertDialog(
                title: Text('Please wait...'.i18n),
                content: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [CircularProgressIndicator()],
                ))));

    try {
      //Fetch entire playlist
      var pages = widget.spotify.spotify.playlists.getTracksByPlaylistId(id);
      var all = await pages.all();
      //Map to importer track
      List<ImporterTrack> tracks = all
          .map((t) => ImporterTrack(
              t.name!, t.artists!.map((a) => a.name!).toList(),
              isrc: t.externalIds!.isrc))
          .toList();
      await importer.start(title, description, tracks);
      //Route
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (context) => const ImporterStatusScreen()));
      }
    } catch (e) {
      Fluttertoast.showToast(
          msg: e.toString(),
          gravity: ToastGravity.BOTTOM,
          toastLength: Toast.LENGTH_SHORT);
      if (mounted) Navigator.of(context).pop();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: FreezerAppBar('Spotify Importer v2'.i18n),
        body: ListView(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Text(
                  'Logged in as: '.i18n + widget.spotify.me.displayName!,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18.0, fontWeight: FontWeight.bold)),
            ),
            const FreezerDivider(),
            Container(height: 4.0),
            Text(
              'Options'.i18n,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            const ImporterSettings(),
            const FreezerDivider(),
            Container(height: 4.0),
            Text(
              'Import playlists by URL'.i18n,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                          decoration: InputDecoration(hintText: 'URL'.i18n),
                          onChanged: (v) => setState(() => _url = v)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => _loadUrl(),
                    )
                  ],
                )),
            if (_urlLoading)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: CircularProgressIndicator(),
                  )
                ],
              ),
            if (_urlPlaylist != null)
              ListTile(
                  title: Text(_urlPlaylist!.name!),
                  subtitle: Text(_urlPlaylist!.description ?? ''),
                  leading: Image.network(_urlPlaylist!.images?.first.url ??
                      'http://cdn-images.deezer.com/images/cover//256x256-000000-80-0-0.jpg')),
            if (_urlPlaylist != null)
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton(
                      child: Text('Import'.i18n),
                      onPressed: () {
                        _startImport(_urlPlaylist!.name!,
                            _urlPlaylist!.description!, _urlPlaylist!.id!);
                      })),

            // Playlists
            const FreezerDivider(),
            Container(height: 4.0),
            Text('Playlists'.i18n,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18.0, fontWeight: FontWeight.bold)),
            Container(height: 4.0),
            if (_playlistsLoading)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: CircularProgressIndicator(),
                  )
                ],
              ),
            if (!_playlistsLoading)
              ...List.generate(_playlists.length, (i) {
                spotify.PlaylistSimple p = _playlists[i];
                String imageUrl =
                    'http://cdn-images.deezer.com/images/cover//256x256-000000-80-0-0.jpg';
                if (p.images?.isNotEmpty ?? false) {
                  imageUrl = p.images!.first.url ?? imageUrl;
                }
                return ListTile(
                  title: Text(p.name!, maxLines: 1),
                  subtitle: Text(p.owner!.displayName!, maxLines: 1),
                  leading: Image.network(imageUrl),
                  onTap: () {
                    _startImport(p.name!, '', p.id!);
                  },
                );
              })
          ],
        ));
  }
}
