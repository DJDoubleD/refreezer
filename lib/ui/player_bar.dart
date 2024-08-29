import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../service/audio_service.dart';
import '../settings.dart';
import '../translations.i18n.dart';
import '../ui/router.dart';
import 'cached_image.dart';
import 'player_screen.dart';

class PlayerBar extends StatefulWidget {
  const PlayerBar({super.key});

  @override
  _PlayerBarState createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> {
  final double iconSize = 28;
  //bool _gestureRegistered = false;

  double get _progress {
    if (GetIt.I<AudioPlayerHandler>().playbackState.value.processingState == AudioProcessingState.idle) return 0.0;
    if (GetIt.I<AudioPlayerHandler>().mediaItem.value == null) return 0.0;
    if (GetIt.I<AudioPlayerHandler>().mediaItem.value!.duration!.inSeconds == 0) return 0.0; //Division by 0
    return GetIt.I<AudioPlayerHandler>().playbackState.value.position.inSeconds /
        GetIt.I<AudioPlayerHandler>().mediaItem.value!.duration!.inSeconds;
  }

  @override
  Widget build(BuildContext context) {
    var focusNode = FocusNode();
    return GestureDetector(
      key: UniqueKey(),
      onHorizontalDragEnd: (DragEndDetails details) async {
        if ((details.primaryVelocity ?? 0) < -100) {
          // Swiped left
          await GetIt.I<AudioPlayerHandler>().skipToPrevious();
        } else if ((details.primaryVelocity ?? 0) > 100) {
          // Swiped right
          await GetIt.I<AudioPlayerHandler>().skipToNext();
        }
      },
      onVerticalDragEnd: (DragEndDetails details) async {
        if ((details.primaryVelocity ?? 0) < -100) {
          // Swiped up
          Navigator.of(context).push(SlideBottomRoute(widget: const PlayerScreen()));
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            systemNavigationBarColor: settings.themeData.scaffoldBackgroundColor,
          ));
        } /*else if ((details.primaryVelocity ?? 0) > 100) {
          // Swiped down => no action
        }*/
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
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  // For Android TV: indicate focus by grey
                  color: focusNode.hasFocus ? Colors.black26 : Theme.of(context).bottomAppBarTheme.color,
                  child: ListTile(
                      dense: true,
                      focusNode: focusNode,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                      onTap: () {
                        Navigator.of(context).push(SlideBottomRoute(widget: const PlayerScreen()));
                        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                          systemNavigationBarColor: settings.themeData.scaffoldBackgroundColor,
                        ));
                      },
                      leading: CachedImage(
                        width: 50,
                        height: 50,
                        url: GetIt.I<AudioPlayerHandler>().mediaItem.value?.extras?['thumb'] ??
                            GetIt.I<AudioPlayerHandler>().mediaItem.value?.artUri,
                      ),
                      title: Text(
                        GetIt.I<AudioPlayerHandler>().mediaItem.value?.displayTitle ?? '',
                        overflow: TextOverflow.clip,
                        maxLines: 1,
                      ),
                      subtitle: Text(
                        GetIt.I<AudioPlayerHandler>().mediaItem.value?.displaySubtitle ?? '',
                        overflow: TextOverflow.clip,
                        maxLines: 1,
                      ),
                      trailing: IconTheme(
                        data: IconThemeData(color: settings.isDark ? Colors.white : Colors.grey[600]),
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
                ),
                SizedBox(
                  height: 3.0,
                  child: LinearProgressIndicator(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    color: Theme.of(context).primaryColor,
                    value: _progress,
                  ),
                )
              ],
            );
          }),
    );
  }
}

class PrevNextButton extends StatelessWidget {
  final double size;
  final bool prev;
  final bool hidePrev;

  const PrevNextButton(this.size, {super.key, this.prev = false, this.hidePrev = false});

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
                Icons.skip_next,
                semanticLabel: 'Play next'.i18n,
              ),
              iconSize: size,
              onPressed: null,
            );
          }
          return IconButton(
            icon: Icon(
              Icons.skip_next,
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
                Icons.skip_previous,
                semanticLabel: 'Play previous'.i18n,
              ),
              iconSize: size,
              onPressed: null,
            );
          }
          return IconButton(
            icon: Icon(
              Icons.skip_previous,
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

class _PlayPauseButtonState extends State<PlayPauseButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
        if (playing || processingState == AudioProcessingState.ready || processingState == AudioProcessingState.idle) {
          if (playing) {
            _controller.forward();
          } else {
            _controller.reverse();
          }

          return IconButton(
              splashRadius: widget.size,
              icon: AnimatedIcon(
                icon: AnimatedIcons.play_pause,
                progress: _animation,
                semanticLabel: playing ? 'Pause'.i18n : 'Play'.i18n,
              ),
              iconSize: widget.size,
              onPressed:
                  playing ? () => GetIt.I<AudioPlayerHandler>().pause() : () => GetIt.I<AudioPlayerHandler>().play());
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
                  child: const CircularProgressIndicator(),
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
