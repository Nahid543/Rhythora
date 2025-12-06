// lib/src/features/library/presentation/widgets/song_grid_item.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/entities/song.dart';
import '../../data/playlist_repository.dart';

class SongGridItem extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const SongGridItem({
    super.key,
    required this.song,
    required this.onTap,
    this.onLongPress,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final repo = PlaylistRepository.instance;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album Art
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: colorScheme.surfaceVariant,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: song.albumArtPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(song.albumArtPath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                cacheWidth: 300,
                                errorBuilder: (_, __, ___) => _defaultArtwork(),
                              ),
                            )
                          : _defaultArtwork(),
                    ),

                    // Favorite Badge
                    ValueListenableBuilder<Set<String>>(
                      valueListenable: repo.favoriteSongIds,
                      builder: (context, favorites, _) {
                        if (favorites.contains(song.id)) {
                          return Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.favorite,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),

              // Song Info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.title,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultArtwork() {
    return Center(
      child: Icon(
        Icons.music_note_rounded,
        color: colorScheme.onSurfaceVariant,
        size: 48,
      ),
    );
  }
}
