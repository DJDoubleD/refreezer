import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:async/async.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:refreezer/fonts/deezer_icons.dart';
import 'package:refreezer/utils/navigator_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../api/cache.dart';
import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';
import '../service/audio_service.dart';
import '../settings.dart';
import '../translations.i18n.dart';
import 'cached_image.dart';
import 'elements.dart';
import 'lyrics.dart';
import 'menu.dart';
import 'player_bar.dart';
import 'router.dart';
import 'settings_screen.dart';
import 'tiles.dart';

//So can be updated when going back from lyrics
late Function updateColor;
late Color scaffoldBackgroundColor;

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();
  LinearGradient? _bgGradient;
  StreamSubscription? _mediaItemSub;
  ImageProvider? _blurImage;

  //Calculate background color
  Future _updateColor() async {
    if (audioHandler.mediaItem.value == null) return;

    if (!settings.colorGradientBackground && !settings.blurPlayerBackground) {
      return;
    }

    //BG Image
    if (settings.blurPlayerBackground) {
      setState(() {
        _blurImage = NetworkImage(
            audioHandler.mediaItem.value?.extras?['thumb'] ??
                audioHandler.mediaItem.value?.artUri);
      });
    }

    //Run in isolate
    PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(
            audioHandler.mediaItem.value?.extras?['thumb'] ??
                audioHandler.mediaItem.value?.artUri));

    //Update notification
    if (settings.blurPlayerBackground) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: palette.dominantColor!.color.withOpacity(0.25),
          systemNavigationBarColor: Color.alphaBlend(
              palette.dominantColor!.color.withOpacity(0.25),
              scaffoldBackgroundColor)));
    }

    //Color gradient
    if (!settings.blurPlayerBackground) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: palette.dominantColor!.color.withOpacity(0.7),
      ));
      setState(() => _bgGradient = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                palette.dominantColor!.color.withOpacity(0.7),
                Settings.deezerBg
              ],
              stops: const [
                0.0,
                0.6
              ]));
    }
  }

  @override
  void initState() {
    _updateColor;
    _mediaItemSub = audioHandler.mediaItem.listen((event) {
      _updateColor();
    });

    updateColor = _updateColor;
    super.initState();
  }

  @override
  void dispose() {
    _mediaItemSub?.cancel();
    //Fix bottom buttons
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        systemNavigationBarColor: settings.themeData.bottomAppBarTheme.color,
        statusBarColor: Colors.transparent));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //Avoid async gap
    scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
        body: SafeArea(
            child: Container(
                decoration: BoxDecoration(
                    gradient:
                        settings.blurPlayerBackground ? null : _bgGradient),
                child: Stack(
                  children: [
                    if (settings.blurPlayerBackground)
                      ClipRect(
                        child: Container(
                          decoration: BoxDecoration(
                              image: DecorationImage(
                                  image: _blurImage ?? const NetworkImage(''),
                                  fit: BoxFit.fill,
                                  colorFilter: ColorFilter.mode(
                                      Colors.black.withOpacity(0.25),
                                      BlendMode.dstATop))),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(color: Colors.transparent),
                          ),
                        ),
                      ),
                    StreamBuilder(
                      stream: StreamZip(
                          [audioHandler.playbackState, audioHandler.mediaItem]),
                      builder: (BuildContext context, AsyncSnapshot snapshot) {
                        //When disconnected
                        if (audioHandler.mediaItem.value == null) {
                          //playerHelper.startService();
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        return OrientationBuilder(
                          builder: (context, orientation) {
                            //Responsive
                            ScreenUtil.init(context, minTextAdapt: true);
                            //Landscape
                            if (orientation == Orientation.landscape) {
                              // ignore: prefer_const_constructors
                              return PlayerScreenHorizontal();
                            }
                            //Portrait
                            // ignore: prefer_const_constructors
                            return PlayerScreenVertical();
                          },
                        );
                      },
                    ),
                  ],
                ))));
  }
}

//Landscape
class PlayerScreenHorizontal extends StatefulWidget {
  const PlayerScreenHorizontal({super.key});

  @override
  _PlayerScreenHorizontalState createState() => _PlayerScreenHorizontalState();
}

class _PlayerScreenHorizontalState extends State<PlayerScreenHorizontal> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
          child: SizedBox(
            width: ScreenUtil().setWidth(160),
            child: const Stack(
              children: <Widget>[
                BigAlbumArt(),
              ],
            ),
          ),
        ),
        //Right side
        SizedBox(
          width: ScreenUtil().setWidth(170),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                      height: ScreenUtil().setSp(50),
                      child: GetIt.I<AudioPlayerHandler>()
                                  .mediaItem
                                  .value!
                                  .displayTitle!
                                  .length >=
                              22
                          ? Marquee(
                              text: GetIt.I<AudioPlayerHandler>()
                                  .mediaItem
                                  .value!
                                  .displayTitle!,
                              style: TextStyle(
                                  fontSize: ScreenUtil().setSp(30),
                                  fontWeight: FontWeight.bold),
                              blankSpace: 32.0,
                              startPadding: 10.0,
                              accelerationDuration: const Duration(seconds: 1),
                              pauseAfterRound: const Duration(seconds: 2),
                            )
                          : Text(
                              GetIt.I<AudioPlayerHandler>()
                                  .mediaItem
                                  .value!
                                  .displayTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: ScreenUtil().setSp(30),
                                  fontWeight: FontWeight.bold),
                            )),
                  Container(
                    height: 4,
                  ),
                  Text(
                    GetIt.I<AudioPlayerHandler>()
                            .mediaItem
                            .value!
                            .displaySubtitle ??
                        '',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: ScreenUtil().setSp(32),
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: const SeekBar(24.0),
              ),
              PlaybackControls(ScreenUtil().setSp(40)),
              Padding(
                  //padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        LyricsIconButton(12, afterOnPressed: updateColor),
                        IconButton(
                          icon: Icon(
                            DeezerIcons.download,
                            size: ScreenUtil().setWidth(12),
                            semanticLabel: 'Download'.i18n,
                          ),
                          onPressed: () async {
                            Track t = Track.fromMediaItem(
                                GetIt.I<AudioPlayerHandler>().mediaItem.value!);
                            if (await downloadManager.addOfflineTrack(t,
                                    private: false, isSingleton: true) !=
                                false) {
                              Fluttertoast.showToast(
                                  msg: 'Downloads added!'.i18n,
                                  gravity: ToastGravity.BOTTOM,
                                  toastLength: Toast.LENGTH_SHORT);
                            }
                          },
                        ),
                        const QualityInfoWidget(),
                        RepeatButton(ScreenUtil().setWidth(12)),
                        const PlayerMenuButton()
                      ],
                    ),
                  ))
            ],
          ),
        )
      ],
    );
  }
}

//Portrait
class PlayerScreenVertical extends StatefulWidget {
  const PlayerScreenVertical({super.key});

  @override
  _PlayerScreenVerticalState createState() => _PlayerScreenVerticalState();
}

class _PlayerScreenVerticalState extends State<PlayerScreenVertical> {
  final GlobalKey iconButtonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 16, 0),
            child: PlayerScreenTopRow(
                textSize: ScreenUtil().setSp(14),
                iconSize: ScreenUtil().setSp(18),
                textWidth: ScreenUtil().setWidth(350),
                short: true)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: SizedBox(
            height: ScreenUtil().setHeight(360),
            child: const Stack(
              children: <Widget>[
                BigAlbumArt(),
              ],
            ),
          ),
        ),
        Container(height: 4.0),
        ActionControls(24.0),
        Container(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SeekBar(8.0),
              Container(
                height: 8.0,
              ),
              SizedBox(
                  height: ScreenUtil().setSp(18),
                  child: (GetIt.I<AudioPlayerHandler>()
                                      .mediaItem
                                      .value
                                      ?.displayTitle ??
                                  '')
                              .length >=
                          26
                      ? Marquee(
                          text: GetIt.I<AudioPlayerHandler>()
                                  .mediaItem
                                  .value
                                  ?.displayTitle ??
                              '',
                          style: TextStyle(
                              fontSize: ScreenUtil().setSp(16),
                              fontWeight: FontWeight.bold),
                          blankSpace: 32.0,
                          startPadding: 0,
                          accelerationDuration: const Duration(seconds: 1),
                          pauseAfterRound: const Duration(seconds: 2),
                        )
                      : Text(
                          GetIt.I<AudioPlayerHandler>()
                                  .mediaItem
                                  .value
                                  ?.displayTitle ??
                              '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: ScreenUtil().setSp(16),
                              fontWeight: FontWeight.bold),
                        )),
              Container(
                height: 4,
              ),
              Text(
                GetIt.I<AudioPlayerHandler>()
                        .mediaItem
                        .value
                        ?.displaySubtitle ??
                    '',
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: ScreenUtil().setSp(12),
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
        PlaybackControls(ScreenUtil().setSp(25)),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              LyricsIconButton(24, afterOnPressed: updateColor),
              IconButton(
                icon: Icon(
                  DeezerIcons.download,
                  size: ScreenUtil().setWidth(24),
                  semanticLabel: 'Download'.i18n,
                ),
                onPressed: () async {
                  Track t = Track.fromMediaItem(
                      GetIt.I<AudioPlayerHandler>().mediaItem.value!);
                  if (await downloadManager.addOfflineTrack(t,
                          private: false, isSingleton: true) !=
                      false) {
                    Fluttertoast.showToast(
                        msg: 'Downloads added!'.i18n,
                        gravity: ToastGravity.BOTTOM,
                        toastLength: Toast.LENGTH_SHORT);
                  }
                },
              ),
              const QualityInfoWidget(),
              RepeatButton(ScreenUtil().setWidth(24)),
              IconButton(
                key: iconButtonKey,
                icon: Icon(
                  //Icons.menu,
                  DeezerIcons.queue,
                  semanticLabel: 'Queue'.i18n,
                ),
                iconSize: ScreenUtil().setWidth(24),
                onPressed: () async {
                  //Fix bottom buttons (Not needed anymore?)
                  SystemChrome.setSystemUIOverlayStyle(
                      const SystemUiOverlayStyle(
                          statusBarColor: Colors.transparent));

                  // Calculate the center of the icon
                  final RenderBox buttonRenderBox =
                      iconButtonKey.currentContext!.findRenderObject()
                          as RenderBox;
                  final Offset buttonOffset = buttonRenderBox
                      .localToGlobal(buttonRenderBox.size.center(Offset.zero));
                  //Navigate
                  //await Navigator.of(context).push(MaterialPageRoute(builder: (context) => QueueScreen()));
                  await Navigator.of(context).push(CircularExpansionRoute(
                      widget: const QueueScreen(),
                      //centerAlignment: Alignment.topRight,
                      centerOffset: buttonOffset)); // Expand from icon
                  //Fix colors
                  updateColor();
                },
              ),
            ],
          ),
        )
      ],
    );
  }
}

class QualityInfoWidget extends StatefulWidget {
  const QualityInfoWidget({super.key});

  @override
  _QualityInfoWidgetState createState() => _QualityInfoWidgetState();
}

class _QualityInfoWidgetState extends State<QualityInfoWidget> {
  AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();
  String value = '';
  StreamSubscription? streamSubscription;

  //Load data from native
  void _load() async {
    if (audioHandler.mediaItem.value == null) return;
    Map? data = await DownloadManager.platform.invokeMethod(
        'getStreamInfo', {'id': audioHandler.mediaItem.value!.id});
    //N/A
    if (data == null) {
      if (mounted) setState(() => value = '');
      //If not shown, try again later
      if (audioHandler.mediaItem.value?.extras?['show'] == null) {
        Future.delayed(const Duration(milliseconds: 200), _load);
      }

      return;
    }
    //Update
    StreamQualityInfo info = StreamQualityInfo.fromJson(data);
    if (mounted) {
      setState(() {
        value =
            '${info.format} ${info.bitrate(audioHandler.mediaItem.value!.duration ?? const Duration(seconds: 0))}kbps';
      });
    }
  }

  @override
  void initState() {
    _load();
    streamSubscription ??= audioHandler.mediaItem.listen((event) async {
      _load();
    });
    super.initState();
  }

  @override
  void dispose() {
    streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (value != '') {
      return TextButton(
        child: Text(value),
        onPressed: () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const QualitySettings()));
        },
      );
    }
    return Container();
    /*return Center(
      child: Transform.scale(
        scale: 0.75, // Adjust the scale to 75% of the original size
        child: const CircularProgressIndicator(),
      ),
    );*/
  }
}

class LyricsIconButton extends StatelessWidget {
  final double width;
  final Function? afterOnPressed;

  const LyricsIconButton(
    this.width, {
    super.key,
    this.afterOnPressed,
  });

  @override
  Widget build(BuildContext context) {
    Track track =
        Track.fromMediaItem(GetIt.I<AudioPlayerHandler>().mediaItem.value!);

    bool isEnabled = (track.lyrics?.id ?? '0') != '0';

    return Opacity(
      opacity: isEnabled
          ? 1.0
          : 0.7, // Full opacity for enabled, reduced for disabled
      child: IconButton(
        icon: Icon(
          //Icons.lyrics,
          DeezerIcons.microphone,
          size: ScreenUtil().setWidth(width),
          semanticLabel: 'Lyrics'.i18n,
        ),
        onPressed: isEnabled
            ? () async {
                //Fix bottom buttons
                SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent));

                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => LyricsScreen(trackId: track.id!)));

                if (afterOnPressed != null) {
                  afterOnPressed!();
                }
              }
            : null, // No action when disabled
      ),
    );
  }
}

class PlayerMenuButton extends StatelessWidget {
  const PlayerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        //Icons.more_vert,
        Icons.menu,
        size: ScreenUtil().setWidth(12),
        semanticLabel: 'Options'.i18n,
      ),
      onPressed: () {
        Track t =
            Track.fromMediaItem(GetIt.I<AudioPlayerHandler>().mediaItem.value!);
        MenuSheet m = MenuSheet(navigateCallback: () {
          Navigator.of(context).pop();
        });
        if (GetIt.I<AudioPlayerHandler>().mediaItem.value!.extras?['show'] ==
            null) {
          m.defaultTrackMenu(t,
              context: context,
              options: [m.sleepTimer(context), m.wakelock(context)]);
        } else {
          m.defaultShowEpisodeMenu(
              Show.fromJson(jsonDecode(GetIt.I<AudioPlayerHandler>()
                  .mediaItem
                  .value!
                  .extras?['show'])),
              ShowEpisode.fromMediaItem(
                  GetIt.I<AudioPlayerHandler>().mediaItem.value!),
              context: context,
              options: [m.sleepTimer(context), m.wakelock(context)]);
        }
      },
    );
  }
}

class RepeatButton extends StatefulWidget {
  final double iconSize;
  const RepeatButton(this.iconSize, {super.key});

  @override
  _RepeatButtonState createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<RepeatButton> {
  Icon get repeatIcon {
    switch (GetIt.I<AudioPlayerHandler>().getLoopMode()) {
      case LoopMode.off:
        return Icon(
          DeezerIcons.repeat,
          size: widget.iconSize,
          semanticLabel: 'Repeat off'.i18n,
        );
      case LoopMode.all:
        return Icon(
          DeezerIcons.repeat,
          color: Theme.of(context).primaryColor,
          size: widget.iconSize,
          semanticLabel: 'Repeat'.i18n,
        );
      case LoopMode.one:
        return Icon(
          DeezerIcons.repeat_one,
          color: Theme.of(context).primaryColor,
          size: widget.iconSize,
          semanticLabel: 'Repeat one'.i18n,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: repeatIcon,
      onPressed: () async {
        await GetIt.I<AudioPlayerHandler>().changeRepeat();
        setState(() {});
      },
    );
  }
}

class ActionControls extends StatefulWidget {
  final double iconSize;
  const ActionControls(this.iconSize, {super.key});

  @override
  _ActionControls createState() => _ActionControls();
}

class _ActionControls extends State<ActionControls> {
  AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();
  Icon get libraryIcon {
    if (cache.checkTrackFavorite(
        Track.fromMediaItem(audioHandler.mediaItem.value!))) {
      return Icon(
        DeezerIcons.heart_fill,
        color: settings.primaryColor,
        size: widget.iconSize,
        semanticLabel: 'Unlove'.i18n,
      );
    }
    return Icon(
      DeezerIcons.heart,
      size: widget.iconSize,
      semanticLabel: 'Love'.i18n,
    );
  }

  @override
  Widget build(BuildContext context) {
    String? id = Track.fromMediaItem(audioHandler.mediaItem.value!).id;
    return Container(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
              onPressed: () async {
                Share.share('https://deezer.com/track/$id');
              },
              icon: Icon(
                DeezerIcons.share_android,
                size: widget.iconSize,
                semanticLabel: 'Share'.i18n,
              )),
          Container(
            margin: EdgeInsets.fromLTRB(12, 0, 12, 0),
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: Border.all(color: Settings.secondaryText, width: 1),
              borderRadius: BorderRadius.circular(100),
            ),
            alignment: Alignment.center,
            child: IconButton(
              icon: Icon(
                DeezerIcons.more_vert,
                size: widget.iconSize * 1.25,
                semanticLabel: 'Options'.i18n,
              ),
              onPressed: () {
                Track t = Track.fromMediaItem(
                    GetIt.I<AudioPlayerHandler>().mediaItem.value!);
                MenuSheet m = MenuSheet(navigateCallback: () {
                  Navigator.of(context).pop();
                });
                if (GetIt.I<AudioPlayerHandler>()
                        .mediaItem
                        .value!
                        .extras?['show'] ==
                    null) {
                  m.defaultTrackMenu(t,
                      context: context,
                      options: [m.sleepTimer(context), m.wakelock(context)]);
                } else {
                  m.defaultShowEpisodeMenu(
                      Show.fromJson(jsonDecode(GetIt.I<AudioPlayerHandler>()
                          .mediaItem
                          .value!
                          .extras?['show'])),
                      ShowEpisode.fromMediaItem(
                          GetIt.I<AudioPlayerHandler>().mediaItem.value!),
                      context: context,
                      options: [m.sleepTimer(context), m.wakelock(context)]);
                }
              },
            ),
          ),
          IconButton(
            icon: libraryIcon,
            onPressed: () async {
              cache.libraryTracks ??= [];

              if (cache.checkTrackFavorite(
                  Track.fromMediaItem(audioHandler.mediaItem.value!))) {
                //Remove from library
                setState(() => cache.libraryTracks
                    ?.remove(audioHandler.mediaItem.value!.id));
                await deezerAPI
                    .removeFavorite(audioHandler.mediaItem.value!.id);
                await cache.save();
              } else {
                //Add
                setState(() =>
                    cache.libraryTracks?.add(audioHandler.mediaItem.value!.id));
                await deezerAPI
                    .addFavoriteTrack(audioHandler.mediaItem.value!.id);
                await cache.save();
              }
            },
          )
        ],
      ),
    );
  }
}

class PlaybackControls extends StatefulWidget {
  final double iconSize;
  const PlaybackControls(this.iconSize, {super.key});

  @override
  _PlaybackControlsState createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<PlaybackControls> {
  AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          /*IconButton(
              icon: Icon(
                DeezerIcons.angry_face,
                size: widget.iconSize * 0.44,
                semanticLabel: 'Dislike'.i18n,
              ),
              onPressed: () async {
                await deezerAPI.dislikeTrack(audioHandler.mediaItem.value!.id);
                if (audioHandler.queueState.hasNext) {
                  audioHandler.skipToNext();
                }
              }),*/
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: PrevNextButton(widget.iconSize, prev: true),
          ),
          PlayPauseButton(widget.iconSize),
          Padding(
            padding: EdgeInsets.only(left: 12),
            child: PrevNextButton(widget.iconSize),
          )
        ],
      ),
    );
  }
}

class BigAlbumArt extends StatefulWidget {
  const BigAlbumArt({super.key});

  @override
  _BigAlbumArtState createState() => _BigAlbumArtState();
}

class _BigAlbumArtState extends State<BigAlbumArt> with WidgetsBindingObserver {
  final AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();
  List<ZoomableImage> _imageList = [];
  late PageController _pageController;
  StreamSubscription? _currentItemAndQueueSub;
  bool _isVisible = false;
  bool _changeTrackOnPageChange = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: audioHandler.currentIndex,
    );

    _imageList = _getImageList(audioHandler.queue.value);

    _currentItemAndQueueSub =
        Rx.combineLatest2<MediaItem?, List<MediaItem>, void>(
      audioHandler.mediaItem,
      audioHandler.queue,
      (mediaItem, queue) {
        if (queue.isNotEmpty) {
          _handleMediaItemChange(mediaItem);
          if (_didQueueChange(queue)) {
            setState(() {
              _imageList = _getImageList(queue);
            });
          }
        }
      },
    ).listen((_) {});

    WidgetsBinding.instance.addObserver(this);
  }

  List<ZoomableImage> _getImageList(List<MediaItem> queue) {
    return queue
        .map((item) => ZoomableImage(url: item.artUri?.toString() ?? ''))
        .toList();
  }

  bool _didQueueChange(List<MediaItem> newQueue) {
    if (newQueue.length != _imageList.length) {
      // Length changed = new queue
      return true;
    }
    for (int i = 0; i < newQueue.length; i++) {
      if (newQueue[i].artUri?.toString() != _imageList[i].url) {
        // An item changed on this position = new queue
        return true;
      }
    }
    // No changes = same queue
    return false;
  }

  void _handleMediaItemChange(MediaItem? item) async {
    final targetItemId = item?.id ?? '';
    final targetPage =
        audioHandler.queue.value.indexWhere((item) => item.id == targetItemId);
    if (targetPage == -1) return;

    // No need to animating to the same page
    if (_pageController.page?.round() == targetPage) return;

    if (_isVisible) {
      // Widget is visible, animate to the target page
      _changeTrackOnPageChange = false;
      await _pageController
          .animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      )
          .then((_) {
        _changeTrackOnPageChange = true;
      });
    } else {
      // Widget is not visible, jump to the target page without animation
      _changeTrackOnPageChange = false;
      _pageController.jumpToPage(targetPage);
      _changeTrackOnPageChange = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _currentItemAndQueueSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    setState(() {
      _isVisible = state == AppLifecycleState.resumed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('big_album_art'),
      onVisibilityChanged: (VisibilityInfo info) {
        if (mounted) {
          setState(() {
            _isVisible = info.visibleFraction > 0.0;
          });
        }
      },
      child: GestureDetector(
        onVerticalDragUpdate: (DragUpdateDetails details) {
          if (details.delta.dy > 16) {
            Navigator.of(context).pop();
          }
        },
        child: PageView(
          controller: _pageController,
          onPageChanged: (int index) {
            if (_changeTrackOnPageChange) {
              // Only trigger if the page change is caused by user swiping
              audioHandler.skipToQueueItem(index);
            }
          },
          children: _imageList,
        ),
      ),
    );
  }
}

//Top row containing QueueSource, queue...
class PlayerScreenTopRow extends StatelessWidget {
  final double? textSize;
  final double? iconSize;
  final double? textWidth;
  final bool? short;
  final GlobalKey iconButtonKey = GlobalKey();
  PlayerScreenTopRow(
      {super.key, this.textSize, this.iconSize, this.textWidth, this.short});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down_sharp,
          ),
          iconSize: iconSize ?? ScreenUtil().setSp(52),
          splashRadius: iconSize ?? ScreenUtil().setWidth(52),
          onPressed: () async {
            // Navigate back
            Navigator.pop(context);
          },
        ),
        Expanded(
          child: SizedBox(
            width: textWidth ?? ScreenUtil().setWidth(800),
            child: Text(
              (short ?? false)
                  ? (GetIt.I<AudioPlayerHandler>().queueSource?.text ?? '')
                  : 'Playing from:'.i18n +
                      ' ' +
                      (GetIt.I<AudioPlayerHandler>().queueSource?.text ?? ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: textSize ?? ScreenUtil().setSp(16)),
            ),
          ),
        ),
      ],
    );
  }
}

class SeekBar extends StatefulWidget {
  final double relativeTextSize;
  const SeekBar(this.relativeTextSize, {super.key});

  @override
  _SeekBarState createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();
  bool _seeking = false;
  double _pos = 0;

  double get position {
    if (_seeking) return _pos;
    double p =
        audioHandler.playbackState.value.position.inMilliseconds.toDouble();
    if (p > duration) return duration;
    return p;
  }

  //Duration to mm:ss
  String _timeString(double pos) {
    Duration d = Duration(milliseconds: pos.toInt());
    return "${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  double get duration {
    if (audioHandler.mediaItem.value == null) return 1.0;
    return audioHandler.mediaItem.value!.duration!.inMilliseconds.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(milliseconds: 250)),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        return Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 0.0, horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        _timeString(position),
                        style: TextStyle(
                            fontSize:
                                ScreenUtil().setSp(widget.relativeTextSize)),
                      ),
                      Text(
                        _timeString(duration),
                        style: TextStyle(
                            fontSize:
                                ScreenUtil().setSp(widget.relativeTextSize)),
                      )
                    ],
                  ),
                ),
                SizedBox(
                  height: 32.0,
                  child: Slider(
                    focusNode: FocusNode(
                        canRequestFocus: false,
                        skipTraversal:
                            true), // Don't focus on Slider - it doesn't work (and not needed)
                    value: position,
                    max: duration,
                    onChangeStart: (double d) {
                      setState(() {
                        _seeking = true;
                        _pos = d;
                      });
                    },
                    onChanged: (double d) {
                      setState(() {
                        _pos = d;
                      });
                    },
                    onChangeEnd: (double d) async {
                      await audioHandler
                          .seek(Duration(milliseconds: d.round()));
                      setState(() {
                        _pos = d;
                        _seeking = false;
                      });
                    },
                  ),
                )
              ],
            ));
      },
    );
  }
}

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  _QueueScreenState createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> with WidgetsBindingObserver {
  AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();
  late StreamSubscription _queueStateSub;
  late ScrollController _scrollController;
  int? _previousMediaItemIndex;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _queueStateSub = audioHandler.queueStateStream.listen((queueState) {
      setState(() {});
      if (queueState.queueIndex != _previousMediaItemIndex) {
        _previousMediaItemIndex = queueState.queueIndex;
        _scrollToCurrentItem();
      }
    });
  }

  @override
  void dispose() {
    _queueStateSub.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentItem() {
    final currentIndex = audioHandler.queueState.queueIndex ?? 0;
    if (currentIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          currentIndex * 72.0, // Estimated TrackTile height
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueState = audioHandler.queueState;
    final shuffleModeEnabled =
        queueState.shuffleMode == AudioServiceShuffleMode.all;

    return Scaffold(
      appBar: FreezerAppBar(
        'Queue'.i18n,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
            child: IconButton(
              icon: Icon(
                //cons.shuffle,
                DeezerIcons.shuffle,
                semanticLabel: 'Shuffle'.i18n,
                color:
                    shuffleModeEnabled ? Theme.of(context).primaryColor : null,
              ),
              onPressed: () async {
                await audioHandler.toggleShuffle();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 16, 0),
            child: IconButton(
              icon: Icon(
                DeezerIcons.trash,
                semanticLabel: 'Clear all'.i18n,
              ),
              onPressed: () async {
                await audioHandler.clearQueue();
                mainNavigatorKey.currentState!
                    .popUntil((route) => route.isFirst);
              },
            ),
          )
        ],
      ),
      body: shuffleModeEnabled // No manual re-ordring in shuffle mode
          ? ListView.builder(
              controller: _scrollController,
              itemCount: queueState.queue.length,
              itemBuilder: (context, index) {
                final mediaItem = queueState.queue[index];
                final track = Track.fromMediaItem(mediaItem);
                return TrackTile(
                  track,
                  onTap: () async {
                    await audioHandler.skipToQueueItem(index);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  key: Key(mediaItem.id),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.close,
                      semanticLabel: 'Close'.i18n,
                    ),
                    onPressed: () async {
                      await audioHandler.removeQueueItem(mediaItem);
                    },
                  ),
                );
              },
            )
          : ReorderableListView.builder(
              scrollController: _scrollController,
              itemCount: queueState.queue.length,
              onReorder: (int oldIndex, int newIndex) async {
                // Circumvent bug in ReorderableListView that won't be fixed: https://github.com/flutter/flutter/pull/93146#issuecomment-1032082749
                if (newIndex > oldIndex) newIndex -= 1;
                if (oldIndex == newIndex) return;
                await audioHandler.moveQueueItem(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final mediaItem = queueState.queue[index];
                final track = Track.fromMediaItem(mediaItem);
                return TrackTile(
                  track,
                  onTap: () async {
                    await audioHandler.skipToQueueItem(index);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  key: Key(mediaItem.id),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.close,
                      semanticLabel: 'Close'.i18n,
                    ),
                    onPressed: () async {
                      await audioHandler.removeQueueItem(mediaItem);
                    },
                  ),
                );
              },
            ),
    );
  }
}
