import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:refreezer/fonts/deezer_icons.dart';

import '../service/audio_service.dart';
import '../settings.dart';
import '../translations.i18n.dart';
import '../ui/router.dart';
import 'cached_image.dart';
import 'player_screen.dart';

late Function updateColor;

class PlayerBar extends StatefulWidget {
  const PlayerBar({super.key});

  @override
  _PlayerBarState createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> {
  AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();
  Color? _bgColor;
  StreamSubscription? _mediaItemSub;
  final double iconSize = 20;
  //bool _gestureRegistered = false;

  //Recover dominant color
  Future _updateColor() async {
    if (audioHandler.mediaItem.value == null) return;

    PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(
            audioHandler.mediaItem.value?.extras?['thumb'] ??
                audioHandler.mediaItem.value?.artUri));

    setState(() => _bgColor = palette.dominantColor!.color.withOpacity(1));
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
    super.dispose();
  }

  double get _progress {
    if (GetIt.I<AudioPlayerHandler>().playbackState.value.processingState ==
        AudioProcessingState.idle) return 0.0;
    if (GetIt.I<AudioPlayerHandler>().mediaItem.value == null) return 0.0;
    if (GetIt.I<AudioPlayerHandler>().mediaItem.value!.duration!.inSeconds == 0)
      return 0.0; //Division by 0
    return GetIt.I<AudioPlayerHandler>()
            .playbackState
            .value
            .position
            .inSeconds /
        GetIt.I<AudioPlayerHandler>().mediaItem.value!.duration!.inSeconds;
  }

  @override
  Widget build(BuildContext context) {
    scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;

    var focusNode = FocusNode();
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
          color: scaffoldBackgroundColor,
          border: Border.all(
              color: _bgColor != null
                  ? _bgColor!.withOpacity(0.7)
                  : Theme.of(context).scaffoldBackgroundColor),
          borderRadius: BorderRadius.circular(15)),
      child: GestureDetector(
        key: UniqueKey(),
        onHorizontalDragEnd: (DragEndDetails details) async {
          if ((details.primaryVelocity ?? 0) < -100) {
            // Swiped left
            await GetIt.I<AudioPlayerHandler>().skipToNext();
            updateColor();
          } else if ((details.primaryVelocity ?? 0) > 100) {
            // Swiped right
            await GetIt.I<AudioPlayerHandler>().skipToPrevious();
            updateColor();
          }
        },
        onVerticalDragEnd: (DragEndDetails details) async {
          if ((details.primaryVelocity ?? 0) < -100) {
            // Swiped up
            Navigator.of(context)
                .push(SlideBottomRoute(widget: const PlayerScreen()));
            SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
              systemNavigationBarColor: _bgColor,
            ));
          } /*else if ((details.primaryVelocity ?? 0) > 100) {
          // Swiped down => no action
        }*/
          updateColor();
        },
        child: StreamBuilder(
            stream: Stream.periodic(const Duration(milliseconds: 250)),
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (GetIt.I<AudioPlayerHandler>().mediaItem.value == null) {
                return const SizedBox(
                  width: 0,
                  height: 0,
                );
              }
              return Container(
                  decoration: BoxDecoration(
                    color: _bgColor?.withOpacity(0.7),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ListTile(
                          dense: true,
                          focusNode: focusNode,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8.0),
                          onTap: () {
                            Navigator.of(context).push(
                                SlideBottomRoute(widget: const PlayerScreen()));
                            SystemChrome.setSystemUIOverlayStyle(
                                SystemUiOverlayStyle(
                              systemNavigationBarColor: Settings.deezerBottom,
                            ));
                          },
                          leading: CachedImage(
                            width: 50,
                            height: 50,
                            url: GetIt.I<AudioPlayerHandler>()
                                    .mediaItem
                                    .value
                                    ?.extras?['thumb'] ??
                                GetIt.I<AudioPlayerHandler>()
                                    .mediaItem
                                    .value
                                    ?.artUri,
                          ),
                          title: Text(
                            GetIt.I<AudioPlayerHandler>()
                                    .mediaItem
                                    .value
                                    ?.displayTitle ??
                                '',
                            overflow: TextOverflow.clip,
                            maxLines: 1,
                          ),
                          subtitle: Text(
                            GetIt.I<AudioPlayerHandler>()
                                    .mediaItem
                                    .value
                                    ?.displaySubtitle ??
                                '',
                            overflow: TextOverflow.clip,
                            maxLines: 1,
                          ),
                          trailing: IconTheme(
                            data: IconThemeData(
                                color: settings.isDark
                                    ? Colors.white
                                    : Colors.grey[600]),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                PrevNextButton(
                                  iconSize,
                                  prev: true,
                                  hidePrev: true,
                                ),
                                PlayPauseButton(iconSize),
                                PrevNextButton(iconSize)
                              ],
                            ),
                          )),
                      SizedBox(
                        height: 3.0,
                        child: LinearProgressIndicator(
                          backgroundColor: _bgColor!.withOpacity(0.1),
                          color: _bgColor,
                          value: _progress,
                        ),
                      )
                    ],
                  ));
            }),
      ),
    );
  }
}

class PrevNextButton extends StatelessWidget {
  final double size;
  final bool prev;
  final bool hidePrev;

  const PrevNextButton(this.size,
      {super.key, this.prev = false, this.hidePrev = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: GetIt.I<AudioPlayerHandler>().queueStateStream,
      builder: (context, snapshot) {
        final queueState = snapshot.data;
        if (!prev) {
          if (!(queueState?.hasNext ?? false)) {
            return IconButton(
              icon: Icon(
                DeezerIcons.skip_next_fill,
                semanticLabel: 'Play next'.i18n,
              ),
              iconSize: size,
              onPressed: null,
            );
          }
          return IconButton(
            icon: Icon(
              DeezerIcons.skip_next_fill,
              semanticLabel: 'Play next'.i18n,
            ),
            iconSize: size,
            onPressed: () => GetIt.I<AudioPlayerHandler>().skipToNext(),
          );
        }
        if (prev) {
          if (!(queueState?.hasPrevious ?? false)) {
            if (hidePrev) {
              return const SizedBox(
                height: 0,
                width: 0,
              );
            }
            return IconButton(
              icon: Icon(
                DeezerIcons.skip_back,
                semanticLabel: 'Play previous'.i18n,
              ),
              iconSize: size,
              onPressed: null,
            );
          }
          return IconButton(
            icon: Icon(
              DeezerIcons.skip_back,
              semanticLabel: 'Play previous'.i18n,
            ),
            iconSize: size,
            onPressed: () => GetIt.I<AudioPlayerHandler>().skipToPrevious(),
          );
        }
        return Container();
      },
    );
  }
}

class PlayPauseButton extends StatefulWidget {
  final double size;
  const PlayPauseButton(this.size, {super.key});

  @override
  _PlayPauseButtonState createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _animation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: GetIt.I<AudioPlayerHandler>().playbackState,
      builder: (context, snapshot) {
        final playbackState = GetIt.I<AudioPlayerHandler>().playbackState.value;
        final playing = playbackState.playing;
        final processingState = playbackState.processingState;

        // Animated icon by pato05
        // Morph from pause to play or from play to pause
        if (playing ||
            processingState == AudioProcessingState.ready ||
            processingState == AudioProcessingState.idle) {
          if (playing) {
            _controller.forward();
          } else {
            _controller.reverse();
          }

          return IconButton(
              splashRadius: widget.size,
              icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => RotationTransition(
                        turns: child.key == ValueKey('icon1')
                            ? Tween<double>(begin: 1, end: 0.75).animate(anim)
                            : Tween<double>(begin: 0.75, end: 1).animate(anim),
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                  child: !playing
                      ? Icon(DeezerIcons.play_fill_small,
                          key: const ValueKey('Play'))
                      : Icon(
                          DeezerIcons.pause_fill_small,
                          key: const ValueKey('Pause'),
                        )),
              iconSize: widget.size,
              onPressed: playing
                  ? () => GetIt.I<AudioPlayerHandler>().pause()
                  : () => GetIt.I<AudioPlayerHandler>().play());
        }

        switch (processingState) {
          //Loading, connecting, rewinding...
          case AudioProcessingState.buffering:
          case AudioProcessingState.loading:
            return SizedBox(
              width: widget.size * 0.85,
              height: widget.size * 0.85,
              child: Center(
                child: Transform.scale(
                  scale: 0.85, // Adjust the scale to 75% of the original size
                  child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor),
                ),
              ),
            );
          //Stopped/Error
          default:
            return SizedBox(width: widget.size, height: widget.size);
        }
      },
    );
  }
}
