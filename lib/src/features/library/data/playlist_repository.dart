
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/playlist.dart';
import '../domain/entities/song.dart';

class PlaylistRepository {
  static const _keyPlaylists = 'playlists_v1';
  static const _keyFavorites = 'favorite_song_ids';
  static const _favoritesId = 'favorites_system_playlist';

  PlaylistRepository._();
  static final instance = PlaylistRepository._();

  final ValueNotifier<List<Playlist>> playlistsNotifier = ValueNotifier([]);
  final ValueNotifier<Set<String>> favoriteSongIds = ValueNotifier({});

  Future<void> initialize() async {
    await loadPlaylists();
    await loadFavorites();
  }


  Future<void> loadPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_keyPlaylists) ?? [];

      final playlists = jsonList
          .map((json) => Playlist.fromJson(jsonDecode(json)))
          .toList();

      playlistsNotifier.value = playlists;
      debugPrint('✅ Loaded ${playlists.length} playlists');
    } catch (e) {
      debugPrint('❌ Error loading playlists: $e');
      playlistsNotifier.value = [];
    }
  }

  Future<void> _savePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = playlistsNotifier.value
          .map((p) => jsonEncode(p.toJson()))
          .toList();

      await prefs.setStringList(_keyPlaylists, jsonList);
      debugPrint('✅ Saved ${jsonList.length} playlists');
    } catch (e) {
      debugPrint('❌ Error saving playlists: $e');
    }
  }

  Future<Playlist> createPlaylist(String name) async {
    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      songIds: [],
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
    );

    final updated = [...playlistsNotifier.value, playlist];
    playlistsNotifier.value = updated;
    await _savePlaylists();

    debugPrint('✅ Created playlist: $name');
    return playlist;
  }

  Future<void> deletePlaylist(String playlistId) async {
    final updated = playlistsNotifier.value
        .where((p) => p.id != playlistId && !p.isSystemPlaylist)
        .toList();

    playlistsNotifier.value = updated;
    await _savePlaylists();
    debugPrint('✅ Deleted playlist: $playlistId');
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final updated = playlistsNotifier.value.map((p) {
      if (p.id == playlistId && !p.isSystemPlaylist) {
        return p.copyWith(name: newName, lastModified: DateTime.now());
      }
      return p;
    }).toList();

    playlistsNotifier.value = updated;
    await _savePlaylists();
    debugPrint('✅ Renamed playlist: $playlistId → $newName');
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final updated = playlistsNotifier.value.map((p) {
      if (p.id == playlistId) {
        if (p.songIds.contains(songId)) {
          debugPrint('⚠️ Song already in playlist');
          return p;
        }
        final newSongIds = [...p.songIds, songId];
        return p.copyWith(songIds: newSongIds, lastModified: DateTime.now());
      }
      return p;
    }).toList();

    playlistsNotifier.value = updated;
    await _savePlaylists();
    debugPrint('✅ Added song to playlist: $songId → $playlistId');
  }

  Future<void> addMultipleSongsToPlaylist(
    String playlistId,
    List<String> songIds,
  ) async {
    final updated = playlistsNotifier.value.map((p) {
      if (p.id == playlistId) {
        final existingIds = Set.from(p.songIds);
        final newIds = songIds.where((id) => !existingIds.contains(id));
        final updatedSongIds = [...p.songIds, ...newIds];
        return p.copyWith(
          songIds: updatedSongIds,
          lastModified: DateTime.now(),
        );
      }
      return p;
    }).toList();

    playlistsNotifier.value = updated;
    await _savePlaylists();
    debugPrint('✅ Added ${songIds.length} songs to playlist');
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final updated = playlistsNotifier.value.map((p) {
      if (p.id == playlistId) {
        final newSongIds = p.songIds.where((id) => id != songId).toList();
        return p.copyWith(songIds: newSongIds, lastModified: DateTime.now());
      }
      return p;
    }).toList();

    playlistsNotifier.value = updated;
    await _savePlaylists();
    debugPrint('✅ Removed song from playlist');
  }

  Future<void> reorderPlaylistSongs(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final updated = playlistsNotifier.value.map((p) {
      if (p.id == playlistId) {
        final songIds = List<String>.from(p.songIds);
        final item = songIds.removeAt(oldIndex);
        songIds.insert(newIndex, item);
        return p.copyWith(songIds: songIds, lastModified: DateTime.now());
      }
      return p;
    }).toList();

    playlistsNotifier.value = updated;
    await _savePlaylists();
  }

  List<Song> getPlaylistSongs(Playlist playlist, List<Song> allSongs) {
    final songMap = {for (var song in allSongs) song.id: song};
    return playlist.songIds
        .map((id) => songMap[id])
        .whereType<Song>()
        .toList();
  }


  Future<void> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList(_keyFavorites) ?? [];
      favoriteSongIds.value = Set.from(favorites);
      debugPrint('✅ Loaded ${favorites.length} favorites');
    } catch (e) {
      debugPrint('❌ Error loading favorites: $e');
      favoriteSongIds.value = {};
    }
  }

  Future<void> toggleFavorite(String songId) async {
    final favorites = Set<String>.from(favoriteSongIds.value);

    if (favorites.contains(songId)) {
      favorites.remove(songId);
      debugPrint('💔 Removed from favorites: $songId');
    } else {
      favorites.add(songId);
      debugPrint('❤️ Added to favorites: $songId');
    }

    favoriteSongIds.value = favorites;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFavorites, favorites.toList());
  }

  bool isFavorite(String songId) => favoriteSongIds.value.contains(songId);

  List<Song> getFavoriteSongs(List<Song> allSongs) {
    return allSongs
        .where((song) => favoriteSongIds.value.contains(song.id))
        .toList();
  }

  Playlist getFavoritesAsPlaylist() {
    return Playlist(
      id: _favoritesId,
      name: 'Favorites',
      songIds: favoriteSongIds.value.toList(),
      createdAt: DateTime(2024),
      lastModified: DateTime.now(),
      isSystemPlaylist: true,
    );
  }

  void dispose() {
    playlistsNotifier.dispose();
    favoriteSongIds.dispose();
  }
}
