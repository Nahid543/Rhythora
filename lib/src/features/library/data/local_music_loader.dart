import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/entities/song.dart';
import '../domain/entities/music_folder.dart';
import '../domain/models/library_source_settings.dart';
import 'dummy_library.dart';

class LocalMusicLoader {
  LocalMusicLoader._internal();

  static final LocalMusicLoader instance = LocalMusicLoader._internal();

  final OnAudioQuery _audioQuery = OnAudioQuery();
  Directory? _artworkCacheDir;
  final Map<int, String?> _artworkPathCache = {};
  Future<List<Song>>? _cachedSongsFuture;
  DateTime? _lastSuccessfulScan;
  String? _lastSourceSignature;

  static const Duration _cacheTtl = Duration(minutes: 5);

  Future<bool> _requestPermission() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid) return false;

    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) return true;

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  Future<List<Song>> loadSongs({
    bool forceRefresh = false,
    LibrarySourceSettings? sourceSettings,
  }) {
    final now = DateTime.now();
    final signature = _buildSourceSignature(sourceSettings);

    final cacheIsFresh = _cachedSongsFuture != null &&
        _lastSuccessfulScan != null &&
        now.difference(_lastSuccessfulScan!) < _cacheTtl &&
        _lastSourceSignature == signature;

    if (!forceRefresh && cacheIsFresh) {
      return _cachedSongsFuture!;
    }

    _lastSourceSignature = signature;
    _cachedSongsFuture = _scanSongs(sourceSettings: sourceSettings);
    return _cachedSongsFuture!;
  }

  String _buildSourceSignature(LibrarySourceSettings? settings) {
    if (settings == null || settings.isAllMusic || settings.folderPaths.isEmpty) {
      return 'all';
    }

    final normalized = settings.folderPaths
        .map((p) => p.trim().toLowerCase())
        .where((p) => p.isNotEmpty)
        .toList()
      ..sort();

    return 'selected:${normalized.join('|')}';
  }

  Future<List<MusicFolder>> loadAvailableFolders() async {
    final granted = await _requestPermission();
    if (!granted) {
      debugPrint('⚠️ Permission denied for music folders');
      return const <MusicFolder>[];
    }

    final audioList = await _audioQuery.querySongs(
      sortType: SongSortType.DISPLAY_NAME,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    if (audioList.isEmpty) {
      debugPrint('⚠️ No audio files found');
      return const <MusicFolder>[];
    }

    final Map<String, int> folderCounts = {};

    for (final s in audioList) {
      String rawPath = '';
      
      if (s.data.isNotEmpty) {
        rawPath = s.data;
      } else if (s.uri != null && s.uri!.isNotEmpty) {
        rawPath = s.uri!;
      }
      
      if (rawPath.isEmpty) continue;

      String normalized = rawPath.replaceAll('\\', '/');
      
      if (normalized.startsWith('file://')) {
        normalized = normalized.substring(7);
      }

      final lastSlash = normalized.lastIndexOf('/');
      if (lastSlash <= 0) continue;

      String folderPath = normalized.substring(0, lastSlash);
      folderPath = '$folderPath/';
      
      folderCounts[folderPath] = (folderCounts[folderPath] ?? 0) + 1;
    }

    if (folderCounts.isEmpty) {
      debugPrint('⚠️ No folders extracted from audio files');
      return const <MusicFolder>[];
    }

    debugPrint('🔍 Found ${folderCounts.length} unique folders:');
    folderCounts.forEach((path, count) {
      debugPrint('  📁 $count song${count == 1 ? '' : 's'} in: $path');
    });

    final folders = folderCounts.entries.map((entry) {
      final pathWithoutSlash = entry.key.substring(0, entry.key.length - 1);
      final segments = pathWithoutSlash.split('/')
        ..removeWhere((e) => e.trim().isEmpty);
      
      final name = segments.isNotEmpty ? segments.last : entry.key;

      return MusicFolder(
        path: entry.key,
        name: name,
        songCount: entry.value,
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    debugPrint('✅ Returning ${folders.length} folders to UI');
    return folders;
  }

  Future<List<Song>> _scanSongs({LibrarySourceSettings? sourceSettings}) async {
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

    final filteredAudio = _applyFolderFilter(audioList, sourceSettings);
    if (filteredAudio.isEmpty) return dummySongs;

    final songs = <Song>[];
    for (final s in filteredAudio) {
      final source = (s.uri != null && s.uri!.isNotEmpty) ? s.uri! : s.data;
      if (source.isEmpty) continue;

      final durationMs = s.duration ?? 0;
      final duration = Duration(milliseconds: durationMs);
      final cachedArtPath = await _cacheArtworkIfNeeded(s);

      songs.add(
        Song(
          id: s.id.toString(),
          title: s.title,
          artist: s.artist?.trim().isNotEmpty == true
              ? s.artist!
              : 'Unknown Artist',
          duration: duration,
          album: s.album?.trim().isNotEmpty == true
              ? s.album!
              : 'Unknown Album',
          filePath: source,
          albumArtPath: cachedArtPath,
        ),
      );
    }

    if (songs.isEmpty) {
      _lastSuccessfulScan = DateTime.now();
      return dummySongs;
    }

    _lastSuccessfulScan = DateTime.now();
    return songs;
  }

  List<SongModel> _applyFolderFilter(
    List<SongModel> all,
    LibrarySourceSettings? sourceSettings,
  ) {
    if (sourceSettings == null ||
        sourceSettings.isAllMusic ||
        sourceSettings.folderPaths.isEmpty) {
      return all;
    }

    final folders = sourceSettings.folderPaths
        .map((raw) => raw.trim().toLowerCase())
        .where((p) => p.isNotEmpty)
        .map((p) => p.endsWith('/') ? p : '$p/')
        .toList();

    if (folders.isEmpty) return all;

    return all.where((song) {
      String path = '';
      
      if (song.data.isNotEmpty) {
        path = song.data;
      } else if (song.uri != null && song.uri!.isNotEmpty) {
        path = song.uri!;
      }

      if (path.isEmpty) return false;

      path = path.trim().replaceAll('\\', '/').toLowerCase();

      if (path.startsWith('file://')) {
        path = path.substring(7);
      }

      for (final folder in folders) {
        if (path.startsWith(folder)) {
          return true;
        }
      }
      return false;
    }).toList();
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
