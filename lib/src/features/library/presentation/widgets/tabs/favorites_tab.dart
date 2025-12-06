// lib/src/features/library/presentation/widgets/tabs/favorites_tab.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../domain/entities/song.dart';
import '../../../data/playlist_repository.dart';
import '../song_list_item.dart';

class FavoritesTab extends StatefulWidget {
  final List<Song> allSongs;
  final Function(Song, List<Song>, int) onSongSelected;

  const FavoritesTab({
    super.key,
    required this.allSongs,
    required this.onSongSelected,
  });

  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab>
    with AutomaticKeepAliveClientMixin {
  final PlaylistRepository _repo = PlaylistRepository.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<Set<String>>(
      valueListenable: _repo.favoriteSongIds,
      builder: (context, favoriteIds, _) {
        final favoriteSongs = widget.allSongs
            .where((song) => favoriteIds.contains(song.id))
            .toList();

        if (favoriteSongs.isEmpty) {
          return _buildEmptyState(colorScheme, textTheme);
        }

        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: Colors.red),
                  const SizedBox(width: 12),
                  Text(
                    '${favoriteSongs.length} favorite songs',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (favoriteSongs.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.play_circle_filled_rounded),
                      iconSize: 32,
                      color: colorScheme.primary,
                      onPressed: () {
                        // Play all favorites
                        if (favoriteSongs.isNotEmpty) {
                          widget.onSongSelected(
                            favoriteSongs.first,
                            favoriteSongs,
                            0,
                          );
                        }
                      },
                      tooltip: 'Play all',
                    ),
                ],
              ),
            ),

            // Favorites List
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: favoriteSongs.length,
                itemExtent: 72.0,
                itemBuilder: (context, index) {
                  final song = favoriteSongs[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 200 + (index * 30)),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: SongListItem(
                            song: song,
                            onTap: () => widget.onSongSelected(
                              song,
                              favoriteSongs,
                              index,
                            ),
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                            index: index,
                            showFavoriteIcon: true,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No favorites yet',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the heart icon on songs you love',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
