import 'dart:async';

import 'package:flutter/material.dart';

import '../api/deezer.dart';
import '../api/definitions.dart';
import '../api/download.dart';

Importer importer = Importer();

class Importer {
  //Options
  bool download = false;

  late String title;
  late String description;
  late List<ImporterTrack> tracks;
  late String playlistId;
  Playlist? playlist;

  bool done = false;
  bool busy = false;

  late StreamController _streamController;

  Stream get updateStream => _streamController.stream;
  int get ok => tracks.fold(0, (v, t) => (t.state == TrackImportState.OK) ? v + 1 : v);
  int get error => tracks.fold(0, (v, t) => (t.state == TrackImportState.ERROR) ? v + 1 : v);

  Importer();

  //Start importing wrapper
  Future<void> start(String title, String? description, List<ImporterTrack> tracks) async {
    //Save variables
    playlist = null;
    this.title = title;
    this.description = description ?? '';
    this.tracks = tracks.map((t) {
      t.state = TrackImportState.NONE;
      return t;
    }).toList();

    //Create playlist
    playlistId = await deezerAPI.createPlaylist(title, description: this.description);

    busy = true;
    done = false;
    _streamController = StreamController.broadcast();
    _start();
  }

  //Start importer
  Future _start() async {
    for (int i = 0; i < tracks.length; i++) {
      try {
        String? id = await _searchTrack(tracks[i]);
        //Not found
        if (id == null) {
          tracks[i].state = TrackImportState.ERROR;
          _streamController.add(tracks[i]);
          continue;
        }
        //Add to playlist
        await deezerAPI.addToPlaylist(id, playlistId.toString());
        tracks[i].state = TrackImportState.OK;
      } catch (_) {
        //Error occurred, mark as error
        tracks[i].state = TrackImportState.ERROR;
      }
      _streamController.add(tracks[i]);
    }
    //Get full playlist
    playlist = await deezerAPI.playlist(playlistId, nb: 10000);
    playlist?.library = true;

    //Download
    if (download) {
      await downloadManager.addOfflinePlaylist(playlist!, private: false);
    }

    //Mark as done
    done = true;
    busy = false;
    //To update UI
    _streamController.add(null);
    _streamController.close();
  }

  //Find track on Deezer servers
  Future<String?> _searchTrack(ImporterTrack track) async {
    //Try by ISRC
    if (track.isrc?.length == 12) {
      Map deezer = await deezerAPI.callPublicApi('track/isrc:' + track.isrc.toString());
      if (deezer['id'] != null) {
        return deezer['id'].toString();
      }
    }

    //Search
    String cleanedTitle = track.title.trim().toLowerCase().replaceAll('-', '').replaceAll('&', '').replaceAll('+', '');
    SearchResults results = await deezerAPI.search('${track.artists[0]} $cleanedTitle');
    for (Track t in results.tracks ?? []) {
      //Match title
      if (_cleanMatching(t.title ?? '') == _cleanMatching(track.title)) {
        if (t.artists != null) {
          //Match artist
          if (_matchArtists(track.artists, t.artists!.map((a) => a.name.toString()).toList())) {
            return t.id;
          }
        }
      }
    }

    return null;
  }

  //Clean title for matching
  String _cleanMatching(String t) {
    return t
        .toLowerCase()
        .replaceAll(',', '')
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .replaceAll('&', '')
        .replaceAll('+', '')
        .replaceAll('/', '');
  }

  String _cleanArtist(String a) {
    return a.toLowerCase().replaceAll(' ', '').replaceAll(',', '');
  }

  //Match at least 1 artist
  bool _matchArtists(List<String> a, List<String> b) {
    //Clean
    List<String> a0 = a.map(_cleanArtist).toList();
    List<String> b0 = b.map(_cleanArtist).toList();

    for (String artist in a0) {
      if (b0.contains(artist)) {
        return true;
      }
    }
    return false;
  }
}

class ImporterTrack {
  String title;
  List<String> artists;
  String? isrc;
  TrackImportState state;

  ImporterTrack(this.title, this.artists, {this.isrc, this.state = TrackImportState.NONE});
}

enum TrackImportState { NONE, ERROR, OK }

extension TrackImportStateExtension on TrackImportState {
  Widget get icon {
    switch (this) {
      case TrackImportState.ERROR:
        return const Icon(
          Icons.error,
          color: Colors.red,
        );
      case TrackImportState.OK:
        return const Icon(Icons.done, color: Colors.green);
      default:
        return const SizedBox(width: 0, height: 0);
    }
  }
}
