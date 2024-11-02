import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_it/get_it.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:refreezer/fonts/deezer_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../api/cache.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';
import '../utils/navigator_keys.dart';
import '../service/audio_service.dart';
import '../translations.i18n.dart';
import '../ui/cached_image.dart';
import '../ui/details_screens.dart';
import '../ui/error.dart';

class MenuSheet {
  Function navigateCallback;

  // Use no-op callback if not provided
  MenuSheet({Function? navigateCallback})
      : navigateCallback = navigateCallback ?? (() {});

  //===================
  // DEFAULT
  //===================

  void show(BuildContext context, List<Widget> options) {
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (BuildContext context) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  (MediaQuery.of(context).orientation == Orientation.landscape)
                      ? 220
                      : 350,
            ),
            child: SingleChildScrollView(
              child: Column(children: options),
            ),
          );
        });
  }

  //===================
  // TRACK
  //===================

  void showWithTrack(BuildContext context, Track track, List<Widget> options) {
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (BuildContext context) {
          return Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.transparent),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    height: 16.0,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Semantics(
                        label: 'Album art'.i18n,
                        image: true,
                        child: CachedImage(
                          url: track.albumArt?.full ?? '',
                          height: 128,
                          width: 128,
                          circular: true,
                        ),
                      ),
                      Container(
                        height: 8,
                      ),
                      SizedBox(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              track.title ?? '',
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 18.0, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              track.artistString ?? '',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 14.0),
                            ),
                            Container(
                              height: 8.0,
                            ),
                            Text(
                              track.album?.title ?? '',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(track.durationString ?? '')
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 16.0,
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (MediaQuery.of(context).orientation ==
                              Orientation.landscape)
                          ? 200
                          : 350,
                    ),
                    child: SingleChildScrollView(
                      child: Column(children: options),
                    ),
                  )
                ],
              ));
        });
  }

  //Default track options
  void defaultTrackMenu(Track track,
      {required BuildContext context,
      List<Widget> options = const [],
      Function? onRemove}) {
    showWithTrack(context, track, [
      addToQueueNext(track, context),
      addToQueue(track, context),
      (cache.checkTrackFavorite(track))
          ? removeFavoriteTrack(track, context, onUpdate: onRemove)
          : addTrackFavorite(track, context),
      addToPlaylist(track, context),
      downloadTrack(track, context),
      offlineTrack(track, context),
      shareTile('track', track.id ?? ''),
      playMix(track, context),
      showAlbum(track.album!, context),
      ...List.generate(track.artists?.length ?? 0,
          (i) => showArtist(track.artists![i], context)),
      ...options
    ]);
  }

  //===================
  // TRACK OPTIONS
  //===================

  Widget addToQueueNext(Track t, BuildContext context) => ListTile(
      title: Text('Play next'.i18n),
      leading: const Icon(Icons.playlist_play),
      onTap: () async {
        //-1 = next
        await GetIt.I<AudioPlayerHandler>()
            .insertQueueItem(-1, t.toMediaItem());
        if (context.mounted) _close(context);
      });

  Widget addToQueue(Track t, BuildContext context) => ListTile(
      title: Text('Add to queue'.i18n),
      leading: const Icon(Icons.playlist_add),
      onTap: () async {
        await GetIt.I<AudioPlayerHandler>().addQueueItem(t.toMediaItem());
        if (context.mounted) _close(context);
      });

  Widget addTrackFavorite(Track t, BuildContext context) => ListTile(
      title: Text('Add track to favorites'.i18n),
      leading: const Icon(DeezerIcons.heart_fill),
      onTap: () async {
        await deezerAPI.addFavoriteTrack(t.id!);
        //Make track offline, if favorites are offline
        Playlist p = Playlist(id: deezerAPI.favoritesPlaylistId);
        if (await downloadManager.checkOffline(playlist: p)) {
          downloadManager.addOfflinePlaylist(p);
        }
        Fluttertoast.showToast(
            msg: 'Added to library'.i18n,
            gravity: ToastGravity.BOTTOM,
            toastLength: Toast.LENGTH_SHORT);
        //Add to cache
        cache.libraryTracks ??= [];
        cache.libraryTracks?.add(t.id!);

        if (context.mounted) _close(context);
      });

  Widget downloadTrack(Track t, BuildContext context) => ListTile(
        title: Text('Download'.i18n),
        leading: const Icon(DeezerIcons.download),
        onTap: () async {
          if (await downloadManager.addOfflineTrack(t,
                  private: false, isSingleton: true) !=
              false) {
            showDownloadStartedToast();
          }
          if (context.mounted) _close(context);
        },
      );

  Widget addToPlaylist(Track t, BuildContext context) => ListTile(
        title: Text('Add to playlist'.i18n),
        leading: const Icon(Icons.playlist_add),
        onTap: () async {
          //Show dialog to pick playlist
          await showDialog(
              context: context,
              builder: (context) {
                return SelectPlaylistDialog(
                    track: t,
                    callback: (Playlist p) async {
                      await deezerAPI.addToPlaylist(t.id!, p.id!);
                      //Update the playlist if offline
                      if (await downloadManager.checkOffline(playlist: p)) {
                        downloadManager.addOfflinePlaylist(p);
                      }
                      Fluttertoast.showToast(
                        msg: 'Track added to'.i18n + ' ${p.title}',
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                      );
                    });
              });
          if (context.mounted) _close(context);
        },
      );

  Widget removeFromPlaylist(Track t, Playlist p, BuildContext context) =>
      ListTile(
        title: Text('Remove from playlist'.i18n),
        leading: const Icon(DeezerIcons.trash),
        onTap: () async {
          await deezerAPI.removeFromPlaylist(t.id!, p.id!);
          Fluttertoast.showToast(
            msg: 'Track removed from'.i18n + ' ${p.title}',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
          if (context.mounted) _close(context);
        },
      );

  Widget removeFavoriteTrack(Track t, BuildContext context, {onUpdate}) =>
      ListTile(
        title: Text('Remove favorite'.i18n),
        leading: const Icon(DeezerIcons.trash),
        onTap: () async {
          await deezerAPI.removeFavorite(t.id!);
          //Check if favorites playlist is offline, update it
          Playlist p = Playlist(id: deezerAPI.favoritesPlaylistId);
          if (await downloadManager.checkOffline(playlist: p)) {
            await downloadManager.addOfflinePlaylist(p);
          }
          //Remove from cache
          cache.libraryTracks?.removeWhere((i) => i == t.id);
          Fluttertoast.showToast(
              msg: 'Track removed from library'.i18n,
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM);
          if (onUpdate != null) onUpdate();
          if (context.mounted) _close(context);
        },
      );

  //Redirect to artist page (ie from track)
  Widget showArtist(Artist a, BuildContext context) => ListTile(
        title: Text(
          'Go to'.i18n + ' ${a.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: const Icon(Icons.recent_actors),
        onTap: () {
          if (context.mounted) _close(context);
          customNavigatorKey.currentState
              ?.push(MaterialPageRoute(builder: (context) => ArtistDetails(a)));

          navigateCallback();
        },
      );

  Widget showAlbum(Album a, BuildContext context) => ListTile(
        title: Text(
          'Go to'.i18n + ' ${a.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: const Icon(Icons.album),
        onTap: () {
          if (context.mounted) _close(context);
          customNavigatorKey.currentState
              ?.push(MaterialPageRoute(builder: (context) => AlbumDetails(a)));

          navigateCallback();
        },
      );

  Widget playMix(Track track, BuildContext context) => ListTile(
        title: Text('Play mix'.i18n),
        leading: const Icon(Icons.online_prediction),
        onTap: () async {
          GetIt.I<AudioPlayerHandler>().playMix(track.id!, track.title!);
          if (context.mounted) _close(context);
        },
      );

  Widget offlineTrack(Track track, BuildContext context) => FutureBuilder(
        future: downloadManager.checkOffline(track: track),
        builder: (innerContext, snapshot) {
          bool isOffline = snapshot.data ?? (track.offline ?? false);
          return ListTile(
            title: Text(isOffline ? 'Remove offline'.i18n : 'Offline'.i18n),
            leading: const Icon(Icons.offline_pin),
            onTap: () async {
              if (isOffline) {
                await downloadManager.removeOfflineTracks([track]);
                Fluttertoast.showToast(
                    msg: 'Track removed from offline!'.i18n,
                    gravity: ToastGravity.BOTTOM,
                    toastLength: Toast.LENGTH_SHORT);
              } else {
                await downloadManager.addOfflineTrack(track, private: true);
              }
              if (context.mounted) _close(context);
            },
          );
        },
      );

  //===================
  // ALBUM
  //===================

  //Default album options
  void defaultAlbumMenu(Album album,
      {required BuildContext context,
      List<Widget> options = const [],
      Function? onRemove}) {
    show(context, [
      (album.library != null && onRemove != null)
          ? removeAlbum(album, context, onRemove: onRemove)
          : libraryAlbum(album, context),
      downloadAlbum(album, context),
      offlineAlbum(album, context),
      shareTile('album', album.id!),
      ...options
    ]);
  }

  //===================
  // ALBUM OPTIONS
  //===================

  Widget downloadAlbum(Album a, BuildContext context) => ListTile(
      title: Text('Download'.i18n),
      leading: const Icon(DeezerIcons.download),
      onTap: () async {
        if (context.mounted) _close(context);
        if (await downloadManager.addOfflineAlbum(a, private: false) != false) {
          showDownloadStartedToast();
        }
      });

  Widget offlineAlbum(Album a, BuildContext context) => ListTile(
        title: Text('Make offline'.i18n),
        leading: const Icon(Icons.offline_pin),
        onTap: () async {
          await deezerAPI.addFavoriteAlbum(a.id!);
          await downloadManager.addOfflineAlbum(a, private: true);
          if (context.mounted) _close(context);
          showDownloadStartedToast();
        },
      );

  Widget libraryAlbum(Album a, BuildContext context) => ListTile(
        title: Text('Add to library'.i18n),
        leading: const Icon(Icons.library_music),
        onTap: () async {
          await deezerAPI.addFavoriteAlbum(a.id!);
          Fluttertoast.showToast(
              msg: 'Added to library'.i18n, gravity: ToastGravity.BOTTOM);
          if (context.mounted) _close(context);
        },
      );

  //Remove album from favorites
  Widget removeAlbum(Album a, BuildContext context,
          {required Function onRemove}) =>
      ListTile(
        title: Text('Remove album'.i18n),
        leading: const Icon(DeezerIcons.trash),
        onTap: () async {
          await deezerAPI.removeAlbum(a.id!);
          await downloadManager.removeOfflineAlbum(a.id!);
          Fluttertoast.showToast(
            msg: 'Album removed'.i18n,
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
          onRemove();
          if (context.mounted) _close(context);
        },
      );

  //===================
  // ARTIST
  //===================

  void defaultArtistMenu(Artist artist,
      {required BuildContext context,
      List<Widget> options = const [],
      Function? onRemove}) {
    show(context, [
      (artist.library != null)
          ? removeArtist(artist, context, onRemove: onRemove)
          : favoriteArtist(artist, context),
      shareTile('artist', artist.id!),
      ...options
    ]);
  }

  //===================
  // ARTIST OPTIONS
  //===================

  Widget removeArtist(Artist a, BuildContext context, {Function? onRemove}) =>
      ListTile(
        title: Text('Remove from favorites'.i18n),
        leading: const Icon(DeezerIcons.trash),
        onTap: () async {
          await deezerAPI.removeArtist(a.id!);
          Fluttertoast.showToast(
              msg: 'Artist removed from library'.i18n,
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM);
          if (onRemove != null) onRemove();
          if (context.mounted) _close(context);
        },
      );

  Widget favoriteArtist(Artist a, BuildContext context) => ListTile(
        title: Text('Add to favorites'.i18n),
        leading: const Icon(DeezerIcons.heart_fill),
        onTap: () async {
          await deezerAPI.addFavoriteArtist(a.id!);
          Fluttertoast.showToast(
              msg: 'Added to library'.i18n,
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM);
          if (context.mounted) _close(context);
        },
      );

  //===================
  // PLAYLIST
  //===================

  void defaultPlaylistMenu(Playlist playlist,
      {required BuildContext context,
      List<Widget> options = const [],
      Function? onRemove,
      Function? onUpdate}) {
    show(context, [
      (playlist.library != null)
          ? removePlaylistLibrary(playlist, context, onRemove: onRemove)
          : addPlaylistLibrary(playlist, context),
      addPlaylistOffline(playlist, context),
      downloadPlaylist(playlist, context),
      shareTile('playlist', playlist.id!),
      if (playlist.user?.id == deezerAPI.userId)
        editPlaylist(playlist, context: context, onUpdate: onUpdate),
      ...options
    ]);
  }

  //===================
  // PLAYLIST OPTIONS
  //===================

  Widget removePlaylistLibrary(Playlist p, BuildContext context,
          {Function? onRemove}) =>
      ListTile(
        title: Text('Remove from library'.i18n),
        leading: const Icon(DeezerIcons.trash),
        onTap: () async {
          if (p.user?.id?.trim() == deezerAPI.userId) {
            //Delete playlist if own
            await deezerAPI.deletePlaylist(p.id!);
          } else {
            //Just remove from library
            await deezerAPI.removePlaylist(p.id!);
          }
          downloadManager.removeOfflinePlaylist(p.id!);
          if (onRemove != null) onRemove();
          if (context.mounted) _close(context);
        },
      );

  Widget addPlaylistLibrary(Playlist p, BuildContext context) => ListTile(
        title: Text('Add playlist to library'.i18n),
        leading: const Icon(DeezerIcons.heart_fill),
        onTap: () async {
          await deezerAPI.addPlaylist(p.id!);
          Fluttertoast.showToast(
              msg: 'Added playlist to library'.i18n,
              gravity: ToastGravity.BOTTOM);
          if (context.mounted) _close(context);
        },
      );

  Widget addPlaylistOffline(Playlist p, BuildContext context) => ListTile(
        title: Text('Make playlist offline'.i18n),
        leading: const Icon(Icons.offline_pin),
        onTap: () async {
          //Add to library
          await deezerAPI.addPlaylist(p.id!);
          downloadManager.addOfflinePlaylist(p, private: true);
          if (context.mounted) _close(context);
          showDownloadStartedToast();
        },
      );

  Widget downloadPlaylist(Playlist p, BuildContext context) => ListTile(
        title: Text('Download playlist'.i18n),
        leading: const Icon(DeezerIcons.download),
        onTap: () async {
          if (context.mounted) _close(context);
          if (await downloadManager.addOfflinePlaylist(p, private: false) !=
              false) {
            showDownloadStartedToast();
          }
        },
      );

  Widget editPlaylist(Playlist p,
          {required BuildContext context, Function? onUpdate}) =>
      ListTile(
        title: Text('Edit playlist'.i18n),
        leading: const Icon(DeezerIcons.pen),
        onTap: () async {
          await showDialog(
              context: context,
              builder: (context) => CreatePlaylistDialog(playlist: p));
          if (context.mounted) _close(context);
          if (onUpdate != null) onUpdate();
        },
      );

  //===================
  // SHOW/EPISODE
  //===================

  defaultShowEpisodeMenu(Show s, ShowEpisode e,
      {required BuildContext context, List<Widget> options = const []}) {
    show(context, [
      shareTile('episode', e.id!),
      shareShow(s.id!),
      downloadExternalEpisode(e),
      ...options
    ]);
  }

  Widget shareShow(String id) => ListTile(
        title: Text('Share show'.i18n),
        leading: const Icon(DeezerIcons.share_android),
        onTap: () async {
          Share.share('https://deezer.com/show/$id');
        },
      );

  //Open direct download link in browser
  Widget downloadExternalEpisode(ShowEpisode e) => ListTile(
        title: Text('Download externally'.i18n),
        leading: const Icon(DeezerIcons.download),
        onTap: () async {
          if (e.url != null) await launchUrlString(e.url!);
        },
      );

  //===================
  // OTHER
  //===================

  showDownloadStartedToast() {
    Fluttertoast.showToast(
        msg: 'Downloads added!'.i18n,
        gravity: ToastGravity.BOTTOM,
        toastLength: Toast.LENGTH_SHORT);
  }

  //Create playlist
  Future createPlaylist(BuildContext context) async {
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return const CreatePlaylistDialog();
        });
  }

  Widget shareTile(String type, String id) => ListTile(
        title: Text('Share'.i18n),
        leading: const Icon(Icons.share),
        onTap: () async {
          Share.share('https://deezer.com/$type/$id');
        },
      );

  Widget sleepTimer(BuildContext context) => ListTile(
        title: Text('Sleep timer'.i18n),
        leading: const Icon(Icons.access_time),
        onTap: () async {
          showDialog(
              context: context,
              builder: (context) {
                return const SleepTimerDialog();
              });
        },
      );

  Widget wakelock(BuildContext context) => ListTile(
        title: Text(cache.wakelock
            ? 'Allow screen to turn off'.i18n
            : 'Keep the screen on'.i18n),
        leading: const Icon(Icons.screen_lock_portrait),
        onTap: () async {
          _close(context);
          //Enable
          if (!cache.wakelock) {
            WakelockPlus.enable();
            Fluttertoast.showToast(
                msg: 'Wakelock enabled!'.i18n, gravity: ToastGravity.BOTTOM);
            cache.wakelock = true;
            return;
          }
          //Disable
          WakelockPlus.disable();
          Fluttertoast.showToast(
              msg: 'Wakelock disabled!'.i18n, gravity: ToastGravity.BOTTOM);
          cache.wakelock = false;
        },
      );

  void _close(BuildContext context) => Navigator.of(context).pop();
}

class SleepTimerDialog extends StatefulWidget {
  const SleepTimerDialog({super.key});

  @override
  _SleepTimerDialogState createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends State<SleepTimerDialog> {
  int hours = 0;
  int minutes = 30;

  String _endTime() {
    return '${cache.sleepTimerTime!.hour.toString().padLeft(2, '0')}:${cache.sleepTimerTime!.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sleep timer'.i18n),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Hours:'.i18n),
                  NumberPicker(
                      value: hours,
                      minValue: 0,
                      maxValue: 69,
                      onChanged: (v) => setState(() => hours = v)),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Minutes:'.i18n),
                  NumberPicker(
                      value: minutes,
                      minValue: 0,
                      maxValue: 60,
                      onChanged: (v) => setState(() => minutes = v)),
                ],
              ),
            ],
          ),
          Container(height: 4.0),
          if (cache.sleepTimerTime != null)
            Text(
              'Current timer ends at'.i18n + ': ' + _endTime(),
              textAlign: TextAlign.center,
            )
        ],
      ),
      actions: [
        TextButton(
          child: Text('Dismiss'.i18n),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        if (cache.sleepTimer != null)
          TextButton(
            child: Text('Cancel current timer'.i18n),
            onPressed: () {
              cache.sleepTimer!.cancel();
              cache.sleepTimer = null;
              cache.sleepTimerTime = null;
              Navigator.of(context).pop();
            },
          ),
        TextButton(
          child: Text('Save'.i18n),
          onPressed: () {
            Duration duration = Duration(hours: hours, minutes: minutes);
            cache.sleepTimer?.cancel();
            //Create timer
            cache.sleepTimer =
                Stream.fromFuture(Future.delayed(duration)).listen((_) {
              GetIt.I<AudioPlayerHandler>().pause();
              cache.sleepTimer?.cancel();
              cache.sleepTimerTime = null;
              cache.sleepTimer = null;
            });
            cache.sleepTimerTime = DateTime.now().add(duration);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class SelectPlaylistDialog extends StatefulWidget {
  final Track? track;
  final Function callback;
  const SelectPlaylistDialog({this.track, required this.callback, super.key});

  @override
  _SelectPlaylistDialogState createState() => _SelectPlaylistDialogState();
}

class _SelectPlaylistDialogState extends State<SelectPlaylistDialog> {
  bool createNew = false;

  @override
  Widget build(BuildContext context) {
    //Create new playlist
    if (createNew) {
      if (widget.track == null) {
        return const CreatePlaylistDialog();
      }
      return CreatePlaylistDialog(tracks: [widget.track!]);
    }

    return AlertDialog(
      title: Text('Select playlist'.i18n),
      content: FutureBuilder(
        future: deezerAPI.getPlaylists(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            const SizedBox(
              height: 100,
              child: ErrorScreen(),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          List<Playlist> playlists = snapshot.data!;
          return SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ...List.generate(
                  playlists.length,
                  (i) => ListTile(
                        title: Text(playlists[i].title!),
                        leading: CachedImage(
                          url: playlists[i].image?.thumb ?? '',
                        ),
                        onTap: () {
                          widget.callback(playlists[i]);
                          Navigator.of(context).pop();
                        },
                      )),
              ListTile(
                title: Text('Create new playlist'.i18n),
                leading: const Icon(Icons.add),
                onTap: () async {
                  setState(() {
                    createNew = true;
                  });
                },
              )
            ]),
          );
        },
      ),
    );
  }
}

class CreatePlaylistDialog extends StatefulWidget {
  final List<Track>? tracks;
  //If playlist not null, update
  final Playlist? playlist;
  const CreatePlaylistDialog({this.tracks, this.playlist, super.key});

  @override
  _CreatePlaylistDialogState createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  int _playlistType = 1;
  String _title = '';
  String _description = '';
  TextEditingController? _titleController;
  TextEditingController? _descController;

  //Create or edit mode
  bool get edit => widget.playlist != null;

  @override
  void initState() {
    //Edit playlist mode
    if (edit) {
      _title = widget.playlist?.title ?? '';
      _description = widget.playlist?.description ?? '';
    }

    _titleController = TextEditingController(text: _title);
    _descController = TextEditingController(text: _description);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(edit ? 'Edit playlist'.i18n : 'Create playlist'.i18n),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            decoration: InputDecoration(labelText: 'Title'.i18n),
            controller: _titleController ?? TextEditingController(),
            onChanged: (String s) => _title = s,
          ),
          TextField(
            onChanged: (String s) => _description = s,
            controller: _descController ?? TextEditingController(),
            decoration: InputDecoration(labelText: 'Description'.i18n),
          ),
          Container(
            height: 4.0,
          ),
          DropdownButton<int>(
            value: _playlistType,
            onChanged: (int? v) {
              setState(() => _playlistType = v!);
            },
            items: [
              DropdownMenuItem<int>(
                value: 1,
                child: Text('Private'.i18n),
              ),
              DropdownMenuItem<int>(
                value: 2,
                child: Text('Collaborative'.i18n),
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Cancel'.i18n),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(edit ? 'Update'.i18n : 'Create'.i18n),
          onPressed: () async {
            if (edit) {
              //Update
              await deezerAPI.updatePlaylist(widget.playlist!.id!,
                  _titleController!.value.text, _descController!.value.text,
                  status: _playlistType);
              Fluttertoast.showToast(
                  msg: 'Playlist updated!'.i18n, gravity: ToastGravity.BOTTOM);
            } else {
              List<String> tracks = [];
              tracks = widget.tracks?.map<String>((t) => t.id!).toList() ?? [];
              await deezerAPI.createPlaylist(_title,
                  status: _playlistType,
                  description: _description,
                  trackIds: tracks);
              Fluttertoast.showToast(
                  msg: 'Playlist created!'.i18n, gravity: ToastGravity.BOTTOM);
            }
            if (context.mounted) Navigator.of(context).pop();
          },
        )
      ],
    );
  }
}
