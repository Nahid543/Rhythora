import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../library/domain/entities/song.dart';
import '../../../playback/data/audio_player_manager.dart';

class RecentlyPlayedCard extends StatelessWidget {
  final Song song;
  final Song? currentSong;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isTablet;
  final bool isSmallScreen;

  const RecentlyPlayedCard({
    super.key,
    required this.song,
    required this.currentSong,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
    required this.isTablet,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    final artworkId = int.tryParse(song.id) ?? 0;
    final isCurrentSong = currentSong?.id == song.id;

    return ValueListenableBuilder<bool>(
      valueListenable: AudioPlayerManager.instance.isPlaying,
      builder: (context, isPlaying, child) {
        final showPlayingIndicator = isCurrentSong && isPlaying;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.9, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Ink(
                    width: isTablet ? 160 : (isSmallScreen ? 130 : 140),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: colorScheme.surfaceVariant.withOpacity(0.4),
                      border: Border.all(
                        color: isCurrentSong
                            ? colorScheme.primary.withOpacity(0.6)
                            : colorScheme.outline.withOpacity(0.15),
                        width: isCurrentSong ? 2 : 1,
                      ),
                      boxShadow: isCurrentSong
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    padding: EdgeInsets.all(isTablet ? 12 : (isSmallScreen ? 8 : 10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                height: isTablet ? 90 : (isSmallScreen ? 68 : 76),
                                width: double.infinity,
                                child: QueryArtworkWidget(
                                  id: artworkId,
                                  type: ArtworkType.AUDIO,
                                  artworkFit: BoxFit.cover,
                                  artworkBorder: BorderRadius.zero,
                                  nullArtworkWidget: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          colorScheme.primary.withOpacity(0.7),
                                          colorScheme.secondary.withOpacity(0.5),
                                        ],
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.music_note_rounded,
                                      color: colorScheme.onPrimary,
                                      size: isTablet ? 32 : (isSmallScreen ? 24 : 28),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (showPlayingIndicator)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: Colors.black45,
                                  ),
                                  child: Center(
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: const Duration(milliseconds: 600),
                                      curve: Curves.elasticOut,
                                      builder: (context, value, child) {
                                        return Transform.scale(
                                          scale: value,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: colorScheme.primary.withOpacity(0.5),
                                                  blurRadius: 12,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.graphic_eq_rounded,
                                              color: colorScheme.onPrimary,
                                              size: 20,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 10 : 8),
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
