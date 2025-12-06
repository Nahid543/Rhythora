// lib/src/features/library/presentation/widgets/song_list_item.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/entities/song.dart';
import '../../data/playlist_repository.dart';

class SongListItem extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final int index;
  final bool showFavoriteIcon;
  final bool showTrailingNumber;
  final int? trailingNumber;

  const SongListItem({
    super.key,
    required this.song,
    required this.onTap,
    this.onLongPress,
    required this.colorScheme,
    required this.textTheme,
    required this.index,
    this.showFavoriteIcon = false,
    this.showTrailingNumber = false,
    this.trailingNumber,
  });

  @override
  Widget build(BuildContext context) {
    final repo = PlaylistRepository.instance;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Album Art
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: colorScheme.surfaceVariant,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: song.albumArtPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(song.albumArtPath!),
                          fit: BoxFit.cover,
                          cacheWidth: 150,
                          errorBuilder: (_, __, ___) => _defaultArtwork(),
                        ),
                      )
                    : _defaultArtwork(),
              ),
              const SizedBox(width: 12),

              // Song Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            song.title,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showFavoriteIcon)
                          ValueListenableBuilder<Set<String>>(
                            valueListenable: repo.favoriteSongIds,
                            builder: (context, favorites, _) {
                              if (favorites.contains(song.id)) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.favorite,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Trailing (number or more icon)
              if (showTrailingNumber && trailingNumber != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$trailingNumber',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                )
              else if (onLongPress != null)
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  onPressed: onLongPress,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultArtwork() {
    return Icon(
      Icons.music_note_rounded,
      color: colorScheme.onSurfaceVariant,
      size: 28,
    );
  }
}
