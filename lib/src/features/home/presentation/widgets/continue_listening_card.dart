import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../library/domain/entities/song.dart';
import '../../../playback/data/audio_player_manager.dart';

class ContinueListeningCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const ContinueListeningCard({
    super.key,
    required this.song,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final artworkId = int.tryParse(song.id) ?? 0;

    return ValueListenableBuilder<bool>(
      valueListenable: AudioPlayerManager.instance.isPlaying,
      builder: (context, isPlaying, child) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.95, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(24),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primaryContainer.withOpacity(0.5),
                          colorScheme.secondaryContainer.withOpacity(0.3),
                          colorScheme.tertiaryContainer.withOpacity(0.15),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Album Art
                        Hero(
                          tag: 'current_song_${song.id}',
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: Stack(
                                  children: [
                                    QueryArtworkWidget(
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
                                              colorScheme.primary,
                                              colorScheme.secondary,
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.music_note_rounded,
                                          color: colorScheme.onPrimary,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                    if (isPlaying)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            color: Colors.black26,
                                          ),
                                          child: Center(
                                            child: TweenAnimationBuilder<double>(
                                              tween: Tween(begin: 0.8, end: 1.0),
                                              duration: const Duration(milliseconds: 800),
                                              curve: Curves.easeInOut,
                                              builder: (context, scale, child) {
                                                return Transform.scale(
                                                  scale: scale,
                                                  child: const Icon(
                                                    Icons.graphic_eq_rounded,
                                                    color: Colors.white,
                                                    size: 32,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isPlaying ? 'Now playing' : 'Continue listening',
                                style: textTheme.labelLarge?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 14,
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.5),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              key: ValueKey(isPlaying),
                              color: colorScheme.onPrimary,
                              size: 28,
                            ),
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
