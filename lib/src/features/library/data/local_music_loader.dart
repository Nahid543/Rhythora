import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/entities/song.dart';
import 'dummy_library.dart';

class LocalMusicLoader {
  LocalMusicLoader._internal();

  static final LocalMusicLoader instance = LocalMusicLoader._internal();

  final OnAudioQuery _audioQuery = OnAudioQuery();
  Directory? _artworkCacheDir;
  final Map<int, String?> _artworkPathCache = {};

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

    final songs = <Song>[];
    for (final s in audioList) {
      final source = (s.uri != null && s.uri!.isNotEmpty) ? s.uri! : s.data;
      if (source.isEmpty) continue;

      final durationMs = s.duration ?? 0;
      final duration = Duration(milliseconds: durationMs);
      final cachedArtPath = await _cacheArtworkIfNeeded(s);

      songs.add(
        Song(
          id: s.id.toString(),
          title: s.title,
          artist: s.artist ?? 'Unknown Artist',
          duration: duration,
          album: s.album ?? 'Unknown Album',
          filePath: source,
          albumArtPath: cachedArtPath,
        ),
      );
    }

    if (songs.isEmpty) return dummySongs;
    return songs;
  }

  Future<Directory> _getArtworkCacheDir() async {
    if (_artworkCacheDir != null) return _artworkCacheDir!;
    final baseDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${baseDir.path}/artwork_cache');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    _artworkCacheDir = cacheDir;
    return cacheDir;
  }

  Future<String?> _cacheArtworkIfNeeded(SongModel songModel) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final songId = songModel.id;
    if (_artworkPathCache.containsKey(songId)) {
      return _artworkPathCache[songId];
    }

    if (songModel.albumId == null || songModel.albumId! <= 0) {
      _artworkPathCache[songId] = null;
      return null;
    }

    try {
      final data = await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.PNG,
        size: 512,
      );

      if (data == null || data.isEmpty) {
        _artworkPathCache[songId] = null;
        return null;
      }

      final cacheDir = await _getArtworkCacheDir();
      final file = File('${cacheDir.path}/artwork_$songId.png');
      await file.writeAsBytes(data, flush: true);
      _artworkPathCache[songId] = file.path;
      return file.path;
    } catch (e) {
      debugPrint('LocalMusicLoader: Failed to cache artwork for $songId: $e');
      _artworkPathCache[songId] = null;
      return null;
    }
  }
}
