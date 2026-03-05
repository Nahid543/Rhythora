import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/entities/song.dart';
import '../domain/entities/music_folder.dart';
import '../domain/models/library_source_settings.dart';
import 'dummy_library.dart';
import '../../../core/services/battery_saver_service.dart';

class LocalMusicLoader {
  LocalMusicLoader._internal();

  static final LocalMusicLoader instance = LocalMusicLoader._internal();

  final OnAudioQuery _audioQuery = OnAudioQuery();
  Directory? _artworkCacheDir;

  /// In-memory cache: songId -> artwork file path (or null if no artwork).
  final Map<int, String?> _artworkPathCache = {};

  Future<List<Song>>? _cachedSongsFuture;
  DateTime? _lastSuccessfulScan;
  String? _lastSourceSignature;

  static const Duration _cacheTtl = Duration(minutes: 5);

  // ──────────────────────────────────────────────
  // Permission
  // ──────────────────────────────────────────────

  Future<bool> _requestPermission() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid) return false;

    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) return true;

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  // ──────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────

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

  /// Lazily fetch and cache artwork for a song.
  /// Returns the cached file path immediately if available,
  /// otherwise fetches from the platform and writes to disk.
  ///
  /// Safe to call from the UI — returns quickly for cached artwork.
  Future<String?> getOrCacheArtwork(int songId) async {
    // 1. Check in-memory cache first (instant)
    if (_artworkPathCache.containsKey(songId)) {
      return _artworkPathCache[songId];
    }

    // 2. Check if file exists on disk (fast sync I/O)
    final diskPath = _getDiskCachePath(songId);
    if (diskPath != null) {
      final file = File(diskPath);
      if (file.existsSync()) {
        _artworkPathCache[songId] = diskPath;
        return diskPath;
      }
    }

    // 3. Fetch from platform & cache to disk
    if (!BatterySaverService.instance.shouldLoadAlbumArt) {
      _artworkPathCache[songId] = null;
      return null;
    }

    return _fetchAndCacheArtwork(songId);
  }

  // ──────────────────────────────────────────────
  // Scanning (no artwork fetching in the loop!)
  // ──────────────────────────────────────────────

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

    debugPrint('🔍 Found ${folderCounts.length} unique folders');

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

  // --- Metadata cleaning helpers ---

  static final _extensionPattern = RegExp(
    r'\.(mp3|flac|m4a|wav|ogg|aac|wma|opus|alac)$',
    caseSensitive: false,
  );
  static final _bitratePattern = RegExp(
    r'[\(\[]\s*\d{2,4}\s*k(?:bps)?\s*[\)\]]',
    caseSensitive: false,
  );
  static final _tagPattern = RegExp(
    r'[\[\(]\s*(?:FULL|HQ|HD|LQ|Official|Audio|Video|Lyrics?|MV)\s*[\]\)]',
    caseSensitive: false,
  );
  static final _unknownPattern = RegExp(
    r'^<unknown>$',
    caseSensitive: false,
  );

  static String _cleanTitle(String raw) {
    var t = raw;
    // Remove file extension
    t = t.replaceAll(_extensionPattern, '');
    // Remove bitrate tags like (256k), [320kbps]
    t = t.replaceAll(_bitratePattern, '');
    // Remove common tags like [FULL], (Official Audio)
    t = t.replaceAll(_tagPattern, '');
    // Replace underscores with spaces
    t = t.replaceAll('_', ' ');
    // Collapse multiple spaces & trim
    t = t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    // Remove trailing dash/hyphen artifacts (e.g. "Artist - " → "Artist")
    t = t.replaceAll(RegExp(r'[\-–—]\s*$'), '').trim();
    return t.isEmpty ? raw : t;
  }

  static String _cleanArtist(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Unknown Artist';
    if (_unknownPattern.hasMatch(raw.trim())) return 'Unknown Artist';
    return raw.trim();
  }

  static String _cleanAlbum(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Unknown Album';
    if (_unknownPattern.hasMatch(raw.trim())) return 'Unknown Album';
    return raw.trim();
  }

  // --- Song scanning ---

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

    // Build songs list WITHOUT fetching artwork — fast!
    final songs = <Song>[];
    for (final s in filteredAudio) {
      final source = (s.uri != null && s.uri!.isNotEmpty) ? s.uri! : s.data;
      if (source.isEmpty) continue;

      final durationMs = s.duration ?? 0;
      final duration = Duration(milliseconds: durationMs);

      // Only check if cached artwork already exists on disk (sync, fast).
      // No platform queries, no file writes here.
      final cachedArtPath = _getCachedArtworkPathSync(s.id);

      songs.add(
        Song(
          id: s.id.toString(),
          title: _cleanTitle(s.title),
          artist: _cleanArtist(s.artist),
          duration: duration,
          album: _cleanAlbum(s.album),
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

  // ──────────────────────────────────────────────
  // Artwork caching (lazy, on-demand)
  // ──────────────────────────────────────────────

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

  /// Returns the expected disk cache path for a song's artwork.
  String? _getDiskCachePath(int songId) {
    if (_artworkCacheDir == null) return null;
    return '${_artworkCacheDir!.path}/artwork_$songId.jpg';
  }

  /// Synchronous check: returns cached artwork path if the file exists.
  /// Does NOT trigger any platform calls or file writes.
  String? _getCachedArtworkPathSync(int songId) {
    // Check in-memory cache
    if (_artworkPathCache.containsKey(songId)) {
      return _artworkPathCache[songId];
    }

    // Check disk (the cache dir might not be initialized yet on first scan)
    if (_artworkCacheDir != null) {
      final path = '${_artworkCacheDir!.path}/artwork_$songId.jpg';
      if (File(path).existsSync()) {
        _artworkPathCache[songId] = path;
        return path;
      }
      // Also check old PNG format from previous cache
      final pngPath = '${_artworkCacheDir!.path}/artwork_$songId.png';
      if (File(pngPath).existsSync()) {
        _artworkPathCache[songId] = pngPath;
        return pngPath;
      }
    }

    return null;
  }

  /// Fetches artwork from the platform and caches it to disk as JPEG.
  Future<String?> _fetchAndCacheArtwork(int songId) async {
    if (kIsWeb || !Platform.isAndroid) {
      _artworkPathCache[songId] = null;
      return null;
    }

    try {
      final data = await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 200,
        quality: 80,
      );

      if (data == null || data.isEmpty) {
        _artworkPathCache[songId] = null;
        return null;
      }

      final cacheDir = await _getArtworkCacheDir();
      final file = File('${cacheDir.path}/artwork_$songId.jpg');
      await file.writeAsBytes(data, flush: true);
      _artworkPathCache[songId] = file.path;
      return file.path;
    } catch (e) {
      debugPrint('LocalMusicLoader: Failed to cache artwork for $songId: $e');
      _artworkPathCache[songId] = null;
      return null;
    }
  }

  /// Pre-warms the artwork cache directory so sync checks work on first scan.
  Future<void> warmUpCacheDir() async {
    await _getArtworkCacheDir();
  }

  Future<void> clearCache() async {
    _cachedSongsFuture = null;
    _lastSuccessfulScan = null;
    _lastSourceSignature = null;
    _artworkPathCache.clear();

    try {
      final dir = _artworkCacheDir ?? await _getArtworkCacheDir();
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
        debugPrint('LocalMusicLoader: Cleared artwork cache at ${dir.path}');
      }
    } catch (e) {
      debugPrint('LocalMusicLoader: Failed to clear artwork cache: $e');
    } finally {
      _artworkCacheDir = null;
    }
  }
}
