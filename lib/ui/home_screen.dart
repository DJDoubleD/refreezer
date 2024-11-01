import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:refreezer/fonts/deezer_icons.dart';

import '../api/deezer.dart';
import '../api/definitions.dart';
import '../service/audio_service.dart';
import '../settings.dart';
import '../translations.i18n.dart';
import '../ui/elements.dart';
import '../ui/error.dart';
import '../ui/menu.dart';
import 'details_screens.dart';
import 'downloads_screen.dart';
import 'settings_screen.dart';
import 'tiles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: const HomeAppBar(),
        body: SingleChildScrollView(
            child: Container(
          padding: EdgeInsets.only(bottom: 72.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SafeArea(child: Container()),
              const Flexible(
                child: HomePageScreen(),
              )
            ],
          ),
        )));
  }
}

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Size get preferredSize => AppBar().preferredSize;

  @override
  Widget build(BuildContext context) {
    return FreezerAppBar(
      'Home'.i18n,
      actions: <Widget>[
        IconButton(
          icon: Icon(
            DeezerIcons.download_fill,
            semanticLabel: 'Download'.i18n,
          ),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const DownloadsScreen()));
          },
        ),
        IconButton(
          icon: Icon(
            DeezerIcons.settings,
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

class FreezerTitle extends StatelessWidget {
  const FreezerTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.asset('assets/icon.png', width: 64, height: 64),
              const Text(
                'ReFreezer',
                style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900),
              )
            ],
          )
        ],
      ),
    );
  }
}

class HomePageScreen extends StatefulWidget {
  final HomePage? homePage;
  final DeezerChannel? channel;
  const HomePageScreen({this.homePage, this.channel, super.key});

  @override
  _HomePageScreenState createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  HomePage? _homePage;
  bool _cancel = false;
  bool _error = false;

  void _loadChannel() async {
    HomePage? hp;
    //Fetch channel from api
    try {
      hp = await deezerAPI.getChannel(widget.channel?.target ?? '');
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    if (hp == null) {
      //On error
      setState(() => _error = true);
      return;
    }
    setState(() => _homePage = hp);
  }

  void _loadHomePage() async {
    //Load local
    try {
      HomePage hp = await HomePage().load();
      setState(() => _homePage = hp);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    //On background load from API
    try {
      if (settings.offlineMode) await deezerAPI.authorize();
      HomePage hp = await deezerAPI.homePage();
      if (_cancel) return;
      if (hp.sections.isEmpty) return;
      setState(() => _homePage = hp);
      //Save to cache
      await _homePage?.save();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  void _load() {
    if (widget.channel != null) {
      _loadChannel();
      return;
    }
    if (widget.channel == null && widget.homePage == null) {
      _loadHomePage();
      return;
    }
    if (widget.homePage?.sections == null ||
        widget.homePage!.sections.isEmpty) {
      _loadHomePage();
      return;
    }
    //Already have data
    setState(() => _homePage = widget.homePage);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cancel = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_homePage == null) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(8.0),
        child: CircularProgressIndicator(),
      ));
    }
    if (_error) return const ErrorScreen();
    return Column(
        children: List.generate(
      _homePage?.sections.length ?? 0,
      (i) {
        switch (_homePage!.sections[i].layout) {
          case HomePageSectionLayout.ROW:
            return HomepageRowSection(_homePage!.sections[i]);
          case HomePageSectionLayout.GRID:
            return HomePageGridSection(_homePage!.sections[i]);
          default:
            return HomepageRowSection(_homePage!.sections[i]);
        }
      },
    ));
  }
}

class HomepageRowSection extends StatelessWidget {
  final HomePageSection section;
  const HomepageRowSection(this.section, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
          child: Text(
            section.title ?? '',
            textAlign: TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.w900),
          ),
        ),
        subtitle: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate((section.items?.length ?? 0) + 1, (j) {
              //Has more items
              if (j == (section.items?.length ?? 0)) {
                if (section.hasMore ?? false) {
                  return TextButton(
                    child: Text(
                      'Show more'.i18n,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20.0),
                    ),
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: FreezerAppBar(section.title ?? ''),
                        body: SingleChildScrollView(
                            child: HomePageScreen(
                                channel:
                                    DeezerChannel(target: section.pagePath))),
                      ),
                    )),
                  );
                }
                return const SizedBox(height: 0, width: 0);
              }

              //Show item
              HomePageItem item = section.items![j] ?? HomePageItem();
              return HomePageItemWidget(item);
            }),
          ),
        ));
  }
}

class HomePageGridSection extends StatelessWidget {
  final HomePageSection section;
  const HomePageGridSection(this.section, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
        child: Text(
          section.title ?? '',
          textAlign: TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.w900),
        ),
      ),
      subtitle: Wrap(
        alignment: WrapAlignment.spaceAround,
        children: List.generate(section.items!.length, (i) {
          //Item
          return HomePageItemWidget(section.items![i] ?? HomePageItem());
        }),
      ),
    );
  }
}

class HomePageItemWidget extends StatelessWidget {
  final HomePageItem item;
  const HomePageItemWidget(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (item.type) {
      case HomePageItemType.FLOW:
        return FlowTrackListTile(
          item.value,
          onTap: () {
            DeezerFlow deezerFlow = item.value;
            GetIt.I<AudioPlayerHandler>().playFromSmartTrackList(SmartTrackList(
                id: 'flow', title: deezerFlow.title, flowType: deezerFlow.id));
          },
        );
      case HomePageItemType.SMARTTRACKLIST:
        return SmartTrackListTile(
          item.value,
          onTap: () {
            GetIt.I<AudioPlayerHandler>().playFromSmartTrackList(item.value);
          },
        );
      case HomePageItemType.ALBUM:
        return AlbumCard(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => AlbumDetails(item.value)));
          },
          onHold: () {
            MenuSheet m = MenuSheet();
            m.defaultAlbumMenu(item.value, context: context);
          },
        );
      case HomePageItemType.ARTIST:
        return ArtistTile(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ArtistDetails(item.value)));
          },
          onHold: () {
            MenuSheet m = MenuSheet();
            m.defaultArtistMenu(item.value, context: context);
          },
        );
      case HomePageItemType.PLAYLIST:
        return PlaylistCardTile(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => PlaylistDetails(item.value)));
          },
          onHold: () {
            MenuSheet m = MenuSheet();
            m.defaultPlaylistMenu(item.value, context: context);
          },
        );
      case HomePageItemType.CHANNEL:
        return ChannelTile(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => Scaffold(
                      appBar: FreezerAppBar(item.value.title.toString()),
                      body: SingleChildScrollView(
                          child: HomePageScreen(
                        channel: item.value,
                      )),
                    )));
          },
        );
      case HomePageItemType.SHOW:
        return ShowCard(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ShowScreen(item.value)));
          },
        );
      default:
        return const SizedBox(height: 0, width: 0);
    }
  }
}
