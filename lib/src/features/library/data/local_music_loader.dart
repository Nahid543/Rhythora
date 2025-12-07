import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/entities/song.dart';
import 'dummy_library.dart';

class LocalMusicLoader {
  LocalMusicLoader._internal();

  static final LocalMusicLoader instance = LocalMusicLoader._internal();

  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<bool> _requestPermission() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid) return false;

    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) return true;

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  Future<List<Song>> loadSongs() async {
    final granted = await _requestPermission();
    if (!granted) {
      return dummySongs;
    }

    final audioList = await _audioQuery.querySongs(
      sortType: SongSortType.DISPLAY_NAME,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    if (audioList.isEmpty) return dummySongs;

    final songs = audioList.where((s) {
      final source = s.uri ?? s.data;
      return source != null && source.isNotEmpty;
    }).map((s) {
      final durationMs = s.duration ?? 0;
      final duration = Duration(milliseconds: durationMs);
      final source = s.uri ?? s.data;

      final albumId = s.albumId;

      return Song(
        id: s.id.toString(),
        title: s.title,
        artist: s.artist ?? 'Unknown Artist',
        duration: duration,
        album: s.album ?? 'Unknown Album',
        filePath: source,
        albumArtPath: albumId != null && albumId > 0
            ? 'content://media/external/audio/albumart/$albumId'
            : null,
      );
    }).toList();

    if (songs.isEmpty) return dummySongs;
    return songs;
  }
}
