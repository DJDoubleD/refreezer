import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../api/cache.dart';
import '../api/download.dart';
import '../translations.i18n.dart';
import '../ui/elements.dart';
import '../ui/error.dart';
import '../utils/version.dart';

class UpdaterScreen extends StatefulWidget {
  const UpdaterScreen({super.key});

  @override
  _UpdaterScreenState createState() => _UpdaterScreenState();
}

class _UpdaterScreenState extends State<UpdaterScreen> {
  bool _loading = true;
  bool _error = false;
  FreezerVersions? _versions;
  String? _current;
  String? _arch;
  double _progress = 0.0;
  bool _buttonEnabled = true;

  Future _load() async {
    //Load current version
    PackageInfo info = await PackageInfo.fromPlatform();
    setState(() => _current = info.version);

    //Get architecture
    _arch = await DownloadManager.platform.invokeMethod('arch');
    if (_arch == 'armv8l') _arch = 'arm32';

    //Load from website
    try {
      FreezerVersions versions = await FreezerVersions.fetch();
      setState(() {
        _versions = versions;
        _loading = false;
      });
    } catch (e, st) {
      if (kDebugMode) {
        print(e.toString() + st.toString());
      }
      _error = true;
      _loading = false;
    }
  }

  FreezerDownload? get _versionDownload {
    return _versions?.versions[0].downloads.firstWhere((d) => d.version.toLowerCase().contains(_arch!.toLowerCase()));
  }

  Future _download() async {
    String? url = _versionDownload?.directUrl;
    //Start request
    http.Client client = http.Client();
    http.StreamedResponse res = await client.send(http.Request('GET', Uri.parse(url ?? '')));
    int? size = res.contentLength;
    //Open file
    String path = p.join((await getExternalStorageDirectory())!.path, 'update.apk');
    File file = File(path);
    IOSink fileSink = file.openWrite();
    //Update progress
    Future.doWhile(() async {
      int received = await file.length();
      setState(() => _progress = received / size!.toInt());
      return received != size;
    });
    //Pipe
    await res.stream.pipe(fileSink);
    fileSink.close();

    OpenFilex.open(path);
    setState(() => _buttonEnabled = true);
  }

  @override
  void initState() {
    _load();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: FreezerAppBar('Updates'.i18n),
        body: ListView(
          children: [
            if (_error) const ErrorScreen(),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [CircularProgressIndicator()],
                ),
              ),
            if (!_error &&
                !_loading &&
                Version.parse((_versions?.latest.toString() ?? '0.0.0')) <= Version.parse(_current!))
              Center(
                  child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('You are running latest version!'.i18n,
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 26.0)),
              )),
            if (!_error &&
                !_loading &&
                Version.parse((_versions?.latest.toString() ?? '0.0.0')) > Version.parse(_current!))
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'New update available!'.i18n + ' ' + _versions!.latest.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    'Current version: ' + _current!,
                    style: const TextStyle(fontSize: 14.0, fontStyle: FontStyle.italic),
                  ),
                  Container(height: 8.0),
                  const FreezerDivider(),
                  Container(height: 8.0),
                  const Text(
                    'Changelog',
                    style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      _versions!.versions[0].changelog,
                      style: const TextStyle(fontSize: 16.0),
                    ),
                  ),
                  const FreezerDivider(),
                  Container(height: 8.0),
                  //Available download
                  if (_versionDownload != null)
                    Column(children: [
                      ElevatedButton(
                          onPressed: _buttonEnabled
                              ? () {
                                  setState(() => _buttonEnabled = false);
                                  _download();
                                }
                              : null,
                          child: Text('Download'.i18n + ' (${_versionDownload?.version})')),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: LinearProgressIndicator(value: _progress),
                      )
                    ]),
                  //Unsupported arch
                  if (_versionDownload == null)
                    Text(
                      'Unsupported platform!'.i18n + ' $_arch',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16.0),
                    )
                ],
              )
          ],
        ));
  }
}

class FreezerVersions {
  String latest;
  List<FreezerVersion> versions;

  FreezerVersions({required this.latest, required this.versions});

  factory FreezerVersions.fromJson(Map data) => FreezerVersions(
      latest: data['android']['latest'],
      versions: data['android']['versions'].map<FreezerVersion>((v) => FreezerVersion.fromJson(v)).toList());

  //Fetch from website API
  static Future<FreezerVersions> fetch() async {
    http.Response response = await http.get('https://freezer.life/api/versions' as Uri);
//    http.Response response = await http.get('https://cum.freezerapp.workers.dev/api/versions');
    return FreezerVersions.fromJson(jsonDecode(response.body));
  }

  static Future checkUpdate() async {
    //Check only each 24h
    int updateDelay = 86400000;
    if ((DateTime.now().millisecondsSinceEpoch - (cache.lastUpdateCheck ?? 0)) < updateDelay) return;
    cache.lastUpdateCheck = DateTime.now().millisecondsSinceEpoch;
    await cache.save();

    FreezerVersions versions = await FreezerVersions.fetch();

    //Load current version
    PackageInfo info = await PackageInfo.fromPlatform();
    if (Version.parse(versions.latest) <= Version.parse(info.version)) return;

    //Get architecture
    String arch = await DownloadManager.platform.invokeMethod('arch');
    if (arch == 'armv8l') arch = 'arm32';
    //Check compatible architecture
    var compatibleVersion =
        versions.versions[0].downloads.firstWhereOrNull((d) => d.version.toLowerCase().contains(arch.toLowerCase()));
    if (compatibleVersion == null) return;

    //Show notification
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('drawable/ic_logo');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidInitializationSettings);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
        'freezerupdates', 'Freezer Updates'.i18n,
        channelDescription: 'Freezer Updates'.i18n);
    NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        0, 'New update available!'.i18n, 'Update to latest version in the settings.'.i18n, notificationDetails);
  }
}

class FreezerVersion {
  String version;
  String changelog;
  List<FreezerDownload> downloads;

  FreezerVersion({required this.version, required this.changelog, required this.downloads});

  factory FreezerVersion.fromJson(Map data) => FreezerVersion(
      version: data['version'],
      changelog: data['changelog'],
      downloads: data['downloads'].map<FreezerDownload>((d) => FreezerDownload.fromJson(d)).toList());
}

class FreezerDownload {
  String version;
  String directUrl;

  FreezerDownload({required this.version, required this.directUrl});

  factory FreezerDownload.fromJson(Map data) =>
      FreezerDownload(version: data['version'], directUrl: data['links'].first['url']);
}
