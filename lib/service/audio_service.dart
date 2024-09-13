import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equalizer_flutter/equalizer_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:refreezer/utils/env.dart';
import 'package:rxdart/rxdart.dart';
import 'package:scrobblenaut/scrobblenaut.dart';

import '../api/cache.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../settings.dart';
import '../translations.i18n.dart';
import '../ui/android_auto.dart';
import '../utils/mediaitem_converter.dart';

Future<AudioPlayerHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
        androidNotificationChannelId: 'r.r.refreezer.audio',
        androidNotificationChannelName: 'ReFreezer',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationClickStartsActivity: true,
        androidNotificationChannelDescription: 'ReFreezer',
        androidNotificationIcon: 'drawable/ic_logo'),
  );
}

class AudioPlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  AudioPlayerHandler() {
    _init();
  }

  int? _audioSession;
  int? _prevAudioSession;
  bool _equalizerOpen = false;

  final AndroidAuto _androidAuto = AndroidAuto(); // Create an instance of AndroidAuto

  // for some reason, dart can decide not to respect the 'await' due to weird task sceduling ...
  final Completer<void> _playerInitializedCompleter = Completer<void>();
  late AudioPlayer _player;
  final _playlist = ConcatenatingAudioSource(children: []);
  // Prevent MediaItem change while shuffling or otherwise rearranging the queue by just_audio internals
  bool _rearranging = false;

  Scrobblenaut? _scrobblenaut;
  bool _scrobblenautReady = false;
  // Last logged track id
  String? _loggedTrackId;

  //Visualizer
  final StreamController _visualizerController = StreamController.broadcast();
  Stream get visualizerStream => _visualizerController.stream;
  late StreamSubscription? _visualizerSubscription;

  QueueSource? queueSource;
  StreamSubscription? _queueStateSub;
  StreamSubscription? _mediaItemSub;
  final BehaviorSubject<QueueState> _queueStateSubject = BehaviorSubject<QueueState>();
  Stream<QueueState> get queueStateStream => _queueStateSubject.stream;
  QueueState get queueState => _queueStateSubject.value;
  int currentIndex = 0;
  int _requestedIndex = -1;

  Future<void> _init() async {
    await _startSession();
    _playerInitializedCompleter.complete();

    // Broadcast the current queue when just_audio sequence changes.
    // Only emit value when MediaItem list contents is different from previous queue
    _player.sequenceStateStream
        .map((state) {
          try {
            return state?.effectiveSequence.map((source) => source.tag as MediaItem).toList();
          } catch (e) {
            if (e is RangeError) {
              // This is caused by just_audio not updating the currentIndex first in the _broadcastSequence method.
              // Because in shufflemode it's out of range after removing items from the playlist.
              // Might be fixed in future
              Logger.root.severe('RangeError occurred while accessing effectiveSequence: $e');
              // Return null to indicate that the queue could/should not be broadcasted
              return null;
            }
            rethrow;
          }
        })
        .whereType<List<MediaItem>>() // Filter out null values (error occured).
        .distinct((a, b) => listEquals(a, b))
        .pipe(queue);

    // Update current QueueState
    _queueStateSub = Rx.combineLatest3<List<MediaItem>, PlaybackState, List<int>, QueueState>(
      queue,
      playbackState,
      _player.shuffleIndicesStream.whereType<List<int>>(),
      (queue, playbackState, shuffleIndices) => QueueState(
        queue,
        playbackState.queueIndex,
        playbackState.shuffleMode == AudioServiceShuffleMode.all ? shuffleIndices : null,
        playbackState.repeatMode,
        playbackState.shuffleMode,
      ),
    )
        .where(
          (state) => state.shuffleIndices == null || state.queue.length == state.shuffleIndices!.length,
        )
        .distinct()
        .listen(_queueStateSubject.add);

    // Broadcast media item changes after track or position in queue change,
    // only emit value when different from previous item
    _mediaItemSub = Rx.combineLatest3<int?, List<MediaItem>, bool, MediaItem?>(
        _player.currentIndexStream, queue, _player.shuffleModeEnabledStream, (index, queue, shuffleModeEnabled) {
      // Don't broadcast while shuffling to avoid intermediate MediaItem change
      if (_rearranging) return null;

      // Prevent broadcasting first item from new queue when other index is requested
      if (_requestedIndex != -1 && _requestedIndex != index) return null;

      final queueIndex = _getQueueIndex(
        index ?? 0,
        shuffleModeEnabled: shuffleModeEnabled,
      );
      return (queueIndex < queue.length) ? queue[queueIndex] : null;
    }).whereType<MediaItem>().distinct().listen((item) {
      // Change track
      mediaItem.add(item);

      final int queueIndex = queue.value.indexOf(item);
      final int queueLength = queue.value.length;

      if (queueLength - queueIndex == 1) {
        Logger.root.info('loaded last track of queue, adding more tracks');
        _onQueueEnd();
      }

      //Save queue
      _saveQueueToFile();
      //Add to history
      _addToHistory(item);
    });

    // Propagate all events from the audio player to AudioService clients.
    _player.playbackEventStream.listen(_broadcastState, onError: _playbackError);

    _player.shuffleModeEnabledStream.listen((enabled) => _broadcastState(_player.playbackEvent));

    _player.loopModeStream.listen((mode) => _broadcastState(_player.playbackEvent));

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed && _player.playing) {
        stop();
        _player.seek(Duration.zero, index: 0);
      }
    });

    //Audio session
    _player.androidAudioSessionIdStream.listen((session) {
      if (!settings.enableEqualizer) return;

      //Save
      _prevAudioSession = _audioSession;
      _audioSession = session;
      if (_audioSession == null) return;

      //Open EQ
      if (!_equalizerOpen) {
        EqualizerFlutter.open(session!);
        _equalizerOpen = true;
        return;
      }

      //Change session id
      if (_prevAudioSession != _audioSession) {
        if (_prevAudioSession != null) {
          EqualizerFlutter.removeAudioSessionId(_prevAudioSession!);
        }
        EqualizerFlutter.setAudioSessionId(_audioSession!);
      }
    });

    // When 75% of item played, save loggedTrackId to cache & log listen (if enabled)
    AudioService.position.listen((position) {
      if (mediaItem.value == null || !playbackState.value.playing) {
        return;
      }

      if (position.inSeconds > (mediaItem.value!.duration!.inSeconds * 0.75)) {
        if (cache.loggedTrackId == mediaItem.value!.id) return;
        cache.loggedTrackId = mediaItem.value!.id;
        cache.save();

        //Log to Deezer
        if (settings.logListen) {
          deezerAPI.logListen(mediaItem.value!.id);
        }
      }
    });
  }

  @override
  Future<void> play() async {
    _player.play();

    //Scrobble to LastFM
    MediaItem? newMediaItem = mediaItem.value;
    if (newMediaItem != null && newMediaItem.id != _loggedTrackId) {
      // Add to history if new track
      _addToHistory(newMediaItem);
    }
  }

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    // Check if the mediaId is for Android Auto
    if (mediaId.startsWith(AndroidAuto.prefix)) {
      // Forward the event to Android Auto
      await _androidAuto.playItem(mediaId);
      return;
    }

    // Handle other mediaIds by seeking to the appropriate item in the queue
    final index = queue.value.indexWhere((item) => item.id == mediaId);
    if (index != -1) {
      _player.seek(
        Duration.zero,
        index: _player.shuffleModeEnabled ? _player.shuffleIndices![index] : index,
      );
    } else {
      Logger.root.severe('playFromMediaId: MediaItem not found');
    }
  }

  @override
  Future<void> pause() async {
    _player.pause();
  }

  @override
  Future<void> stop() async {
    Logger.root.info('stopping player');
    await _player.stop();
    await super.stop();
    Logger.root.info('saving queue');
    _saveQueueToFile();
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final res = await _itemToSource(mediaItem);
    if (res != null) {
      await _playlist.add(res);
    }
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    await _playlist.addAll(await _itemsToSources(mediaItems));
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    //-1 == play next
    if (index == -1) index = currentIndex + 1;
    final res = await _itemToSource(mediaItem);
    if (res != null) {
      await _playlist.insert(index, res);
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    await _playlist.clear();
    if (newQueue.isNotEmpty) {
      await _playlist.addAll(await _itemsToSources(newQueue));
    } else {
      if (mediaItem.hasValue) {
        mediaItem.add(null);
      }
    }
  }

  Future<void> clearQueue() async {
    await updateQueue([]);
    await removeSavedQueueFile();
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final queue = this.queue.value;
    final index = queue.indexOf(mediaItem);

    if (_player.shuffleModeEnabled) {
      // Get the shuffled index of the media item
      final shuffledIndex = _player.shuffleIndices!.indexOf(index);
      await _playlist.removeAt(shuffledIndex);
    } else {
      await _playlist.removeAt(index);
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    await _playlist.removeAt(index);
  }

  Future<void> moveQueueItem(int currentIndex, int newIndex) async {
    _rearranging = true;
    await _playlist.move(currentIndex, newIndex);
    _rearranging = false;
    playbackState.add(playbackState.value.copyWith());
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() async {
    if ((_player.position.inSeconds) <= 5) {
      _player.seekToPrevious();
    } else {
      _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _playlist.children.length) return;

    _player.seek(
      Duration.zero,
      index: _player.shuffleModeEnabled ? _player.shuffleIndices![index] : index,
    );
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
    await _player.setLoopMode(LoopMode.values[repeatMode.index]);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    _rearranging = true;
    await _player.setShuffleModeEnabled(enabled);
    _rearranging = false;
    if (enabled) {
      await _player.shuffle();
    }
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  @override
  Future<void> onTaskRemoved() async {
    dispose();
  }

  @override
  Future<void> onNotificationDeleted() async {
    dispose();
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    //Android audio callback
    return _androidAuto.getScreen(parentMediaId);
  }

  //----------------------------------------------
  // Start internal methods native to AudioHandler
  //----------------------------------------------

  Future<void> _startSession() async {
    Logger.root.info('starting audio service...');
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    if (settings.ignoreInterruptions == true) {
      _player = AudioPlayer(handleInterruptions: false);
      // Handle audio interruptions. (ignore)
      session.interruptionEventStream.listen((_) {});
      // Handle unplugged headphones. (ignore)
      session.becomingNoisyEventStream.listen((_) {});
    } else {
      _player = AudioPlayer();
    }

    _loadEmptyPlaylist().then((_) => Logger.root.info('audio player initialized!'));
  }

  /// Broadcasts the current state to all clients.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    currentIndex = _getQueueIndex(_player.currentIndex ?? 0, shuffleModeEnabled: _player.shuffleModeEnabled);

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          // Custom Stop
          const MediaControl(androidIcon: 'drawable/ic_action_stop', label: 'stop', action: MediaAction.stop),
        ],
        systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: currentIndex,
      ),
    );
  }

  /// Resolve the effective queue index taking into account shuffleMode.
  int _getQueueIndex(int currentIndex, {bool shuffleModeEnabled = false}) {
    final effectiveIndices = _player.effectiveIndices ?? [];
    final shuffleIndicesInv = List.filled(effectiveIndices.length, 0);
    for (var i = 0; i < effectiveIndices.length; i++) {
      shuffleIndicesInv[effectiveIndices[i]] = i;
    }
    return (shuffleModeEnabled && (currentIndex < shuffleIndicesInv.length))
        ? shuffleIndicesInv[currentIndex]
        : currentIndex;
  }

  Future<void> _loadEmptyPlaylist() async {
    try {
      Logger.root.info('Loading empty playlist...');
      await _player.setAudioSource(_playlist);
    } catch (e) {
      Logger.root.severe('Error loading empty playlist: $e');
    }
  }

  Future<List<AudioSource>> _itemsToSources(List<MediaItem> mediaItems) async {
    var sources = await Future.wait(mediaItems.map(_itemToSource));
    return sources.whereType<AudioSource>().toList();
  }

  Future<AudioSource?> _itemToSource(MediaItem mi) async {
    String? url = await _getTrackUrl(mi);
    if (url == null) return null;
    if (url.startsWith('http')) {
      return ProgressiveAudioSource(Uri.parse(url), tag: mi);
    }
    return AudioSource.uri(Uri.parse(url), tag: mi);
  }

  Future _getTrackUrl(MediaItem mediaItem) async {
    //Check if offline
    String offlinePath = p.join((await getExternalStorageDirectory())!.path, 'offline/');
    File f = File(p.join(offlinePath, mediaItem.id));
    if (await f.exists()) {
      //return f.path;
      //Stream server URL
      return 'http://localhost:36958/?id=${mediaItem.id}';
    }

    //Show episode direct link
    if (mediaItem.extras?['showUrl'] != null) {
      return mediaItem.extras?['showUrl'];
    }

    //Due to current limitations of just_audio, quality fallback moved to DeezerDataSource in ExoPlayer
    //This just returns fake url that contains metadata
    int quality = await getStreamQuality();

    List? streamPlaybackDetails = jsonDecode(mediaItem.extras?['playbackDetails']);
    String streamItemId = mediaItem.id;

    //If Deezer provided a FALLBACK track, use the playbackDetails and id from the fallback track
    //for streaming (original stream unavailable)
    if (mediaItem.extras?['fallbackId'] != null) {
      streamItemId = mediaItem.extras?['fallbackId'];
      streamPlaybackDetails = jsonDecode(mediaItem.extras?['playbackDetailsFallback']);
    }

    if ((streamPlaybackDetails ?? []).length < 3) return null;
    String url =
        'http://localhost:36958/?q=$quality&id=${mediaItem.id}&streamTrackId=$streamItemId&trackToken=${streamPlaybackDetails?[2]}&mv=${streamPlaybackDetails?[1]}&md5origin=${streamPlaybackDetails?[0]}';
    return url;
  }

  /// Get requested stream quality based on connection and settings.
  Future<int> getStreamQuality() async {
    int quality = settings.getQualityInt(settings.mobileQuality);
    List<ConnectivityResult> conn = await Connectivity().checkConnectivity();
    if (conn.contains(ConnectivityResult.wifi)) {
      quality = settings.getQualityInt(settings.wifiQuality);
    }
    return quality;
  }

  /// Load new queue of MediaItems to just_audio & seek to given index & position
  Future _loadQueueAtIndex(List<MediaItem> newQueue, int index, {Duration position = Duration.zero}) async {
    //Set requested index
    _requestedIndex = index;

    //Clear old playlist from just_audio
    await _playlist.clear();

    // Convert new queue to AudioSources playlist & add to just_audio (Concurrent approach)
    await _playlist.addAll(await _itemsToSources(newQueue));

    //Seek to correct position & index
    try {
      await _player.seek(position, index: index);
    } catch (e, st) {
      Logger.root.severe('Error loading tracks', e, st);
    }
    _requestedIndex = -1;
  }

  //Replace queue, play specified item index
  Future _loadQueueAndPlayAtIndex(QueueSource newQueueSource, List<MediaItem> newQueue, int index) async {
    // Pauze platback if playing (Player seems to crash on some devices otherwise)
    await pause();
    //Set requested index
    _requestedIndex = index;

    queueSource = newQueueSource;
    await updateQueue(newQueue);
    await setShuffleMode(AudioServiceShuffleMode.none);
    await skipToQueueItem(index);

    play();
    _requestedIndex = -1;
  }

  /// Attempt to load more tracks when queue ends
  Future _onQueueEnd() async {
    //Flow
    if (queueSource == null) return;

    List<Track> tracks = [];
    switch (queueSource!.source) {
      case 'flow':
        tracks = await deezerAPI.flow();
        break;
      //SmartRadio/Artist radio
      case 'smartradio':
        tracks = await deezerAPI.smartRadio(queueSource!.id ?? '');
        break;
      //Library shuffle
      case 'libraryshuffle':
        tracks = await deezerAPI.libraryShuffle(start: queue.value.length);
        break;
      case 'mix':
        tracks = await deezerAPI.playMix(queueSource!.id ?? '');
        break;
      case 'playlist':
        // Get current position
        int pos = queue.value.length;
        // Load 25 more tracks from playlist
        tracks = await deezerAPI.playlistTracksPage(queueSource!.id!, pos, nb: 25);
        break;
      default:
        Logger.root.info('Reached end of queue source: ${queueSource!.source}');
        break;
    }

    // Deduplicate tracks already in queue with the same id
    List<String> queueIds = queue.value.map((mi) => mi.id).toList();
    tracks.removeWhere((track) => queueIds.contains(track.id));
    List<MediaItem> extraTracks = tracks.map<MediaItem>((t) => t.toMediaItem()).toList();
    addQueueItems(extraTracks);
  }

  void _playbackError(err) {
    Logger.root.severe('Playback Error from audioservice: ${err.code}', err);
    if (err is PlatformException && err.code == 'abort' && err.message == 'Connection aborted') {
      return;
    }
    _onError(err, null);
  }

  void _onError(err, stacktrace, {bool stopService = false}) {
    Logger.root.severe('Error from audioservice: ${err.code}', err);
    if (stopService) stop();
  }

  Future<void> _addToHistory(MediaItem item) async {
    if (!_player.playing) return;

    // Scrobble to LastFM
    if (_scrobblenautReady && !(_loggedTrackId == item.id)) {
      Logger.root.info('scrobbling track ${item.id} to recently LastFM');
      _loggedTrackId = item.id;
      await _scrobblenaut?.track.scrobble(
        track: item.title,
        artist: item.artist ?? '',
        album: item.album,
      );
    }

    if (cache.history.isNotEmpty && cache.history.last.id == item.id) return;
    Logger.root.info('adding track ${item.id} to recently played history');
    cache.history.add(Track.fromMediaItem(item));
    cache.save();
  }

  //Get queue save file path
  Future<String> _getQueueFilePath() async {
    Directory dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'playback.json');
  }

  //Export queue to JSON
  Future _saveQueueToFile() async {
    if (_player.currentIndex == 0 && queue.value.isEmpty) return;

    String path = await _getQueueFilePath();
    File f = File(path);
    //Create if doesn't exist
    if (!await File(path).exists()) {
      f = await f.create();
    }
    Map data = {
      'index': _player.currentIndex,
      'queue': queue.value.map<Map<String, dynamic>>((mi) => MediaItemConverter.mediaItemToMap(mi)).toList(),
      'position': _player.position.inMilliseconds,
      'queueSource': (queueSource ?? QueueSource()).toJson(),
      'loopMode': LoopMode.values.indexOf(_player.loopMode)
    };
    await f.writeAsString(jsonEncode(data));
  }

  //----------------------------------------------------------------------------------------------
  // Start app specific public methods.
  // Candidates for refactoring to "customAction"s to be called from the UI (PlayerHelper class)?
  //----------------------------------------------------------------------------------------------

  Future<void> waitForPlayerInitialization() async {
    await _playerInitializedCompleter.future;
  }

  Future dispose() async {
    _queueStateSub?.cancel();
    _mediaItemSub?.cancel();
    await stop();
    await _player.dispose();
  }

  //Restore queue & playback info from path
  Future loadQueueFromFile() async {
    Logger.root.info('looking for saved queue file...');
    File f = File(await _getQueueFilePath());
    if (await f.exists()) {
      Logger.root.info('saved queue file found, loading...');
      Map<String, dynamic> json = jsonDecode(await f.readAsString());
      List<MediaItem> savedQueue =
          (json['queue'] ?? []).map<MediaItem>((mi) => (MediaItemConverter.mediaItemFromMap(mi))).toList();
      final int lastIndex = json['index'] ?? 0;
      final Duration lastPos = Duration(milliseconds: json['position'] ?? 0);
      queueSource = QueueSource.fromJson(json['queueSource'] ?? {});
      var repeatType = LoopMode.values[(json['loopMode'] ?? 0)];
      _player.setLoopMode(repeatType);
      //Restore queue & Broadcast
      await _loadQueueAtIndex(savedQueue, lastIndex, position: lastPos);
      Logger.root.info('saved queue loaded from file!');
    }
  }

  Future removeSavedQueueFile() async {
    String path = await _getQueueFilePath();
    File f = File(path);
    if (await f.exists()) {
      await f.delete();
      Logger.root.info('saved queue file removed!');
    }
  }

  Future authorizeLastFM() async {
    if (settings.lastFMPassword == null) return;
    String username = settings.lastFMUsername ?? '';
    String password = settings.lastFMPassword ?? '';
    try {
      LastFM lastFM = await LastFM.authenticateWithPasswordHash(
          apiKey: Env.lastFmApiKey, apiSecret: Env.lastFmApiSecret, username: username, passwordHash: password);
      _scrobblenaut = Scrobblenaut(lastFM: lastFM);
      _scrobblenautReady = true;
    } catch (e) {
      Logger.root.severe('Error authorizing LastFM: $e');
      Fluttertoast.showToast(msg: 'Authorization error!'.i18n);
    }
  }

  Future<void> disableLastFM() async {
    _scrobblenaut = null;
    _scrobblenautReady = false;
  }

  Future toggleShuffle() async {
    await setShuffleMode(_player.shuffleModeEnabled ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all);
  }

  LoopMode getLoopMode() {
    return _player.loopMode;
  }

  //Repeat toggle
  Future changeRepeat() async {
    //Change to next repeat type
    switch (_player.loopMode) {
      case LoopMode.one:
        setRepeatMode(AudioServiceRepeatMode.none);
        break;
      case LoopMode.all:
        setRepeatMode(AudioServiceRepeatMode.one);
        break;
      default:
        setRepeatMode(AudioServiceRepeatMode.all);
        break;
    }
  }

  Future<void> updateQueueQuality() async {
    // Update quality by reconverting all items in the queue to new AudioSources
    if (_player.playing) {
      // Pauze playback if playing (Player seems to crash on some devices otherwise)
      await pause();
      await _loadQueueAtIndex(queue.value, queueState.queueIndex ?? 0, position: _player.position);
      await _player.play();
    } else {
      await _loadQueueAtIndex(queue.value, queueState.queueIndex ?? 0, position: _player.position);
    }
  }

  //Play track from album
  Future playFromAlbum(Album album, String trackId) async {
    await playFromTrackList(album.tracks ?? [], trackId, QueueSource(id: album.id, text: album.title, source: 'album'));
  }

  //Play mix by track
  Future playMix(String trackId, String trackTitle) async {
    List<Track> tracks = await deezerAPI.playMix(trackId);
    playFromTrackList(tracks, tracks[0].id ?? '',
        QueueSource(id: trackId, text: 'Mix based on'.i18n + ' $trackTitle', source: 'mix'));
  }

  //Play from artist top tracks
  Future playFromTopTracks(List<Track> tracks, String trackId, Artist artist) async {
    await playFromTrackList(
        tracks, trackId, QueueSource(id: artist.id, text: 'Top ${artist.name}', source: 'topTracks'));
  }

  Future playFromPlaylist(Playlist playlist, String trackId) async {
    await playFromTrackList(
        playlist.tracks ?? [], trackId, QueueSource(id: playlist.id, text: playlist.title, source: 'playlist'));
  }

  //Play episode from show, load whole show as queue
  Future playShowEpisode(Show show, List<ShowEpisode> episodes, {int index = 0}) async {
    QueueSource showQueueSource = QueueSource(id: show.id, text: show.name, source: 'show');
    //Generate media items
    List<MediaItem> episodeQueue = episodes.map<MediaItem>((e) => e.toMediaItem(show)).toList();

    //Load and play
    await _loadQueueAndPlayAtIndex(showQueueSource, episodeQueue, index);
  }

  //Load tracks as queue, play track id, set queue source
  Future playFromTrackList(List<Track> tracks, String trackId, QueueSource trackQueueSource) async {
    //Generate media items
    List<MediaItem> trackQueue = tracks.map<MediaItem>((track) => track.toMediaItem()).toList();

    //Load and play
    await _loadQueueAndPlayAtIndex(trackQueueSource, trackQueue, trackQueue.indexWhere((m) => m.id == trackId));
  }

  //Load smart track list as queue, start from beginning
  Future playFromSmartTrackList(SmartTrackList stl) async {
    //Load from API if no tracks
    if ((stl.tracks?.length ?? 0) == 0) {
      if (settings.offlineMode) {
        Fluttertoast.showToast(
            msg: "Offline mode, can't play flow or smart track lists.".i18n,
            gravity: ToastGravity.BOTTOM,
            toastLength: Toast.LENGTH_SHORT);
        return;
      }

      //Flow songs cannot be accessed by smart track list call
      if (stl.id == 'flow') {
        stl.tracks = await deezerAPI.flow(type: stl.flowType);
      } else {
        stl = await deezerAPI.smartTrackList(stl.id ?? '');
      }
    }
    QueueSource queueSource = QueueSource(
        id: stl.id,
        source: (stl.id == 'flow') ? 'flow' : 'smarttracklist',
        text: stl.title ?? ((stl.id == 'flow') ? 'Flow'.i18n : 'Smart track list'.i18n));
    await playFromTrackList(stl.tracks ?? [], stl.tracks?[0].id ?? '', queueSource);
  }

  //Start visualizer
  Future startVisualizer() async {
    /* Needs experimental 'visualizer' branch of just_audio
        _player.startVisualizer(enableWaveform: false, enableFft: true, captureRate: 15000, captureSize: 128);
        _visualizerSubscription = _player.visualizerFftStream.listen((event) {
          //Calculate actual values
          List<double> out = [];
          for (int i = 0; i < event.length / 2; i++) {
            int rfk = event[i * 2].toSigned(8);
            int ifk = event[i * 2 + 1].toSigned(8);
            out.add(log(hypot(rfk, ifk) + 1) / 5.2);
          }
          //Visualizer data
          _visualizerController.add(out);
        });
        */
  }

  //Stop visualizer
  Future stopVisualizer() async {
    if (_visualizerSubscription != null) {
      await _visualizerSubscription!.cancel();
      _visualizerSubscription = null;
    }
  }
}

class QueueState {
  static const QueueState empty = QueueState([], 0, [], AudioServiceRepeatMode.none, AudioServiceShuffleMode.none);

  final List<MediaItem> queue;
  final int? queueIndex;
  final List<int>? shuffleIndices;
  final AudioServiceRepeatMode repeatMode;
  final AudioServiceShuffleMode shuffleMode;

  const QueueState(this.queue, this.queueIndex, this.shuffleIndices, this.repeatMode, this.shuffleMode);

  bool get hasPrevious => repeatMode != AudioServiceRepeatMode.none || (queueIndex ?? 0) > 0;
  bool get hasNext => repeatMode != AudioServiceRepeatMode.none || (queueIndex ?? 0) + 1 < queue.length;

  List<int> get indices => shuffleIndices ?? List.generate(queue.length, (i) => i);
}
