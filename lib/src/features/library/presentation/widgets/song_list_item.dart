
import 'package:flutter/material.dart';
import '../../domain/entities/song.dart';
import '../../data/playlist_repository.dart';
import 'song_artwork.dart';

String _formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

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
              SongArtwork(
                songId: song.id,
                albumArtPath: song.albumArtPath,
                size: 56,
                borderRadius: 8,
                iconSize: 28,
              ),
              const SizedBox(width: 12),

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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            song.artist,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(song.duration),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (showTrailingNumber && trailingNumber != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
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
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: onLongPress,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
