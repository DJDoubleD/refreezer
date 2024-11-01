import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'api/download.dart';
import 'main.dart';
import 'service/audio_service.dart';
import 'ui/cached_image.dart';

part 'settings.g.dart';

late Settings settings;

@JsonSerializable()
class Settings {
  //Language
  @JsonKey(defaultValue: null)
  String? language;

  //Main
  @JsonKey(defaultValue: false)
  late bool ignoreInterruptions;
  @JsonKey(defaultValue: false)
  late bool enableEqualizer;

  //Account
  String? arl;
  @JsonKey(includeFromJson: false)
  @JsonKey(includeToJson: false)
  bool offlineMode = false;

  //Quality
  @JsonKey(defaultValue: AudioQuality.MP3_320)
  late AudioQuality wifiQuality;
  @JsonKey(defaultValue: AudioQuality.MP3_128)
  late AudioQuality mobileQuality;
  @JsonKey(defaultValue: AudioQuality.FLAC)
  late AudioQuality offlineQuality;
  @JsonKey(defaultValue: AudioQuality.FLAC)
  late AudioQuality downloadQuality;

  //Download options
  String? downloadPath;

  @JsonKey(defaultValue: '%artist% - %title%')
  late String downloadFilename;
  @JsonKey(defaultValue: true)
  late bool albumFolder;
  @JsonKey(defaultValue: true)
  late bool artistFolder;
  @JsonKey(defaultValue: false)
  late bool albumDiscFolder;
  @JsonKey(defaultValue: false)
  late bool overwriteDownload;
  @JsonKey(defaultValue: 2)
  late int downloadThreads;
  @JsonKey(defaultValue: false)
  late bool playlistFolder;
  @JsonKey(defaultValue: true)
  late bool downloadLyrics;
  @JsonKey(defaultValue: false)
  late bool trackCover;
  @JsonKey(defaultValue: true)
  late bool albumCover;
  @JsonKey(defaultValue: false)
  late bool nomediaFiles;
  @JsonKey(defaultValue: ', ')
  late String artistSeparator;
  @JsonKey(defaultValue: '%artist% - %title%')
  late String singletonFilename;
  @JsonKey(defaultValue: 1400)
  late int albumArtResolution;
  @JsonKey(defaultValue: [
    'title',
    'album',
    'artist',
    'track',
    'disc',
    'albumArtist',
    'date',
    'label',
    'isrc',
    'upc',
    'trackTotal',
    'bpm',
    'lyrics',
    'genre',
    'contributors',
    'art'
  ])
  late List<String> tags;

  //Appearance
  @JsonKey(defaultValue: Themes.Dark)
  late Themes theme;
  @JsonKey(defaultValue: false)
  late bool useSystemTheme;
  @JsonKey(defaultValue: true)
  late bool colorGradientBackground;
  @JsonKey(defaultValue: false)
  late bool blurPlayerBackground;
  @JsonKey(defaultValue: 'Deezer')
  late String font;
  @JsonKey(defaultValue: false)
  late bool lyricsVisualizer;
  @JsonKey(defaultValue: null)
  int? displayMode;

  //Colors
  @JsonKey(toJson: _colorToJson, fromJson: _colorFromJson)
  Color primaryColor = Color(0xFFA238FF);
  static const deezerBg = Color(0xFF0F0D13);
  static const deezerBottom = Color(0xFF1B191F);
  static const secondaryText = Color(0xFFA9A6AA);

  static _colorToJson(Color c) => c.value;
  static _colorFromJson(int? v) => v == null ? Color(0xFFA238FF) : Color(v);

  @JsonKey(defaultValue: false)
  bool useArtColor = false;
  StreamSubscription? _useArtColorSub;

  //Deezer
  @JsonKey(defaultValue: 'en')
  late String deezerLanguage;
  @JsonKey(defaultValue: 'US')
  late String deezerCountry;
  @JsonKey(defaultValue: false)
  late bool logListen;
  @JsonKey(defaultValue: null)
  String? proxyAddress;

  //LastFM
  @JsonKey(defaultValue: null)
  String? lastFMUsername;
  @JsonKey(defaultValue: null)
  String? lastFMPassword;

  //Spotify
  @JsonKey(defaultValue: null)
  String? spotifyClientId;
  @JsonKey(defaultValue: null)
  String? spotifyClientSecret;
  @JsonKey(defaultValue: null)
  SpotifyCredentialsSave? spotifyCredentials;

  Settings({this.downloadPath, this.arl});

  ThemeData get themeData {
    //System theme
    if (useSystemTheme) {
      if (PlatformDispatcher.instance.platformBrightness == Brightness.light) {
        return _themeData[Themes.Light]!;
      } else {
        if (theme == Themes.Light) return _themeData[Themes.Dark]!;
        return _themeData[theme]!;
      }
    }
    //Theme
    return _themeData[theme] ?? ThemeData();
  }

  //Get all available fonts
  List<String> get fonts {
    return ['Deezer', ...GoogleFonts.asMap().keys];
  }

  //JSON to forward into download service
  Map getServiceSettings() {
    return {'json': jsonEncode(toJson())};
  }

  void updateUseArtColor(bool v) {
    useArtColor = v;
    if (v) {
      //On media item change set color
      _useArtColorSub =
          GetIt.I<AudioPlayerHandler>().mediaItem.listen((event) async {
        if (event == null || event.artUri == null) return;
        primaryColor =
            await imagesDatabase.getPrimaryColor(event.artUri.toString());
        updateTheme();
      });
    } else {
      //Cancel stream subscription
      _useArtColorSub?.cancel();
      _useArtColorSub = null;
    }
  }

  SliderThemeData get _sliderTheme => SliderThemeData(
      thumbColor: primaryColor,
      activeTrackColor: primaryColor,
      inactiveTrackColor: primaryColor.withOpacity(0.2));

  //Load settings/init
  Future<Settings> loadSettings() async {
    String path = await getPath();
    File f = File(path);
    if (await f.exists()) {
      String data = await f.readAsString();
      return Settings.fromJson(jsonDecode(data));
    }
    Settings s = Settings.fromJson({});
    //Set default path, because async
    s.downloadPath = (await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_MUSIC));
    s.save();
    return s;
  }

  Future save() async {
    File f = File(await getPath());
    await f.writeAsString(jsonEncode(toJson()));
    downloadManager.updateServiceSettings();
  }

  Future updateAudioServiceQuality() async {
    await GetIt.I<AudioPlayerHandler>().updateQueueQuality();
    //Send wifi & mobile quality to audio service isolate
    //await GetIt.I<AudioPlayerHandler>().customAction(
    //    'updateQuality', {'mobileQuality': getQualityInt(mobileQuality), 'wifiQuality': getQualityInt(wifiQuality)});
  }

  //AudioQuality to deezer int
  int getQualityInt(AudioQuality q) {
    switch (q) {
      case AudioQuality.MP3_128:
        return 1;
      case AudioQuality.MP3_320:
        return 3;
      case AudioQuality.FLAC:
        return 9;
      //Deezer default
      default:
        return 8;
    }
  }

  //Check if is dark, can't use theme directly, because of system themes, and Theme.of(context).brightness broke
  bool get isDark {
    if (useSystemTheme) {
      if (PlatformDispatcher.instance.platformBrightness == Brightness.light) {
        return false;
      }
      return true;
    }
    if (theme == Themes.Light) return false;
    return true;
  }

  TextTheme? get textTheme => (font == 'Deezer')
      ? null
      : GoogleFonts.getTextTheme(font,
          isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme);
  String? get _fontFamily => (font == 'Deezer') ? 'MabryPro' : null;

  //Overrides for the non-deprecated buttons to look like the old ones
  OutlinedButtonThemeData get outlinedButtonTheme => OutlinedButtonThemeData(
          style: ButtonStyle(
        foregroundColor:
            WidgetStateProperty.all(isDark ? Colors.white : Colors.black),
        side: WidgetStateProperty.all(BorderSide(color: Colors.grey.shade800)),
      ));
  TextButtonThemeData get textButtonTheme => TextButtonThemeData(
          style: ButtonStyle(
        foregroundColor:
            WidgetStateProperty.all(isDark ? Colors.white : Colors.black),
      ));

  Map<Themes, ThemeData> get _themeData => {
        Themes.Light: ThemeData(
            useMaterial3: false,
            brightness: Brightness.light,
            textTheme: textTheme,
            fontFamily: _fontFamily,
            primaryColor: primaryColor,
            sliderTheme: _sliderTheme,
            outlinedButtonTheme: outlinedButtonTheme,
            textButtonTheme: textButtonTheme,
            colorScheme: ColorScheme.fromSwatch().copyWith(
                secondary: primaryColor, brightness: Brightness.light),
            checkboxTheme: CheckboxThemeData(
              fillColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
            ),
            radioTheme: RadioThemeData(
              fillColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
              trackColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
            ),
            bottomAppBarTheme:
                const BottomAppBarTheme(color: Color(0xfff5f5f5))),
        Themes.Dark: ThemeData(
            useMaterial3: false,
            brightness: Brightness.dark,
            textTheme: textTheme,
            fontFamily: _fontFamily,
            primaryColor: primaryColor,
            sliderTheme: _sliderTheme,
            outlinedButtonTheme: outlinedButtonTheme,
            textButtonTheme: textButtonTheme,
            colorScheme: ColorScheme.fromSwatch()
                .copyWith(secondary: primaryColor, brightness: Brightness.dark),
            checkboxTheme: CheckboxThemeData(
              fillColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
            ),
            radioTheme: RadioThemeData(
              fillColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
              trackColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
            ),
            bottomAppBarTheme:
                const BottomAppBarTheme(color: Color(0xFF0F0D13))),
        Themes.Deezer: ThemeData(
            useMaterial3: false,
            brightness: Brightness.dark,
            textTheme: textTheme,
            fontFamily: _fontFamily,
            primaryColor: primaryColor,
            unselectedWidgetColor: secondaryText,
            sliderTheme: _sliderTheme,
            scaffoldBackgroundColor: deezerBg,
            dialogBackgroundColor: deezerBg,
            hintColor: secondaryText,
            inputDecorationTheme: const InputDecorationTheme(
              hintStyle: TextStyle(color: secondaryText),
              labelStyle: TextStyle(color: secondaryText),
            ),
            bottomSheetTheme:
                const BottomSheetThemeData(backgroundColor: deezerBg),
            cardColor: deezerBg,
            outlinedButtonTheme: outlinedButtonTheme,
            textButtonTheme: textButtonTheme,
            colorScheme: ColorScheme.fromSwatch().copyWith(
                secondary: primaryColor,
                surface: deezerBg,
                brightness: Brightness.dark),
            checkboxTheme: CheckboxThemeData(
              fillColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
            ),
            radioTheme: RadioThemeData(
              fillColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
              trackColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
            ),
            bottomAppBarTheme: const BottomAppBarTheme(color: deezerBg)),
        Themes.Black: ThemeData(
            useMaterial3: false,
            brightness: Brightness.dark,
            textTheme: textTheme,
            fontFamily: _fontFamily,
            primaryColor: primaryColor,
            scaffoldBackgroundColor: deezerBg,
            dialogBackgroundColor: deezerBg,
            sliderTheme: _sliderTheme,
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Colors.black,
            ),
            outlinedButtonTheme: outlinedButtonTheme,
            textButtonTheme: textButtonTheme,
            colorScheme: ColorScheme.fromSwatch().copyWith(
                secondary: primaryColor,
                surface: Colors.black,
                brightness: Brightness.dark),
            checkboxTheme: CheckboxThemeData(
              fillColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
            ),
            radioTheme: RadioThemeData(
              fillColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
              trackColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.disabled)) {
                  return null;
                }
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null;
              }),
            ),
            bottomAppBarTheme: const BottomAppBarTheme(color: Colors.black))
      };

  Future<String> getPath() async =>
      p.join((await getApplicationDocumentsDirectory()).path, 'settings.json');

  //JSON
  factory Settings.fromJson(Map<String, dynamic> json) =>
      _$SettingsFromJson(json);
  Map<String, dynamic> toJson() => _$SettingsToJson(this);
}

enum AudioQuality { MP3_128, MP3_320, FLAC, ASK }

enum Themes { Light, Dark, Deezer, Black }

@JsonSerializable()
class SpotifyCredentialsSave {
  String? accessToken;
  String? refreshToken;
  List<String>? scopes;
  DateTime? expiration;

  SpotifyCredentialsSave(
      {this.accessToken, this.refreshToken, this.scopes, this.expiration});

  //JSON
  factory SpotifyCredentialsSave.fromJson(Map<String, dynamic> json) =>
      _$SpotifyCredentialsSaveFromJson(json);
  Map<String, dynamic> toJson() => _$SpotifyCredentialsSaveToJson(this);
}
