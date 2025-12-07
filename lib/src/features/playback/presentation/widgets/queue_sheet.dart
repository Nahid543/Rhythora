
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../../../library/domain/entities/song.dart';
import '../../data/audio_player_manager.dart';

/// Production-ready queue sheet with:
/// - Auto-scroll to current song
/// - "You are here" indicator
/// - Smooth animations
/// - Drag-to-reorder (future-ready)
class QueueSheet extends StatefulWidget {
  final List<Song> queue;
  final Function(Song song, int index) onSongTap;

  const QueueSheet({
    super.key,
    required this.queue,
    required this.onSongTap,
  });

  @override
  State<QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<QueueSheet>
    with SingleTickerProviderStateMixin {
  final AudioPlayerManager _player = AudioPlayerManager.instance;
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  bool _hasScrolled = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentSong();
    });
  }

  void _scrollToCurrentSong() {
    if (_hasScrolled || !mounted) return;

    if (!_scrollController.hasClients) return;

    final currentIndex = _player.currentIndex.value;
    if (currentIndex >= 0 && currentIndex < widget.queue.length) {
      const itemHeight = 72.0;
      final targetPosition = currentIndex * itemHeight;
      
      final screenHeight = MediaQuery.of(context).size.height * 0.7;
      final offset = (targetPosition - screenHeight / 2 + itemHeight / 2).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          );
          _hasScrolled = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.queue_music_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Up Next',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.queue.length} ${widget.queue.length == 1 ? "song" : "songs"}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.5)),
            const SizedBox(height: 8),

            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ValueListenableBuilder<int>(
                  valueListenable: _player.currentIndex,
                  builder: (context, currentPlayerIndex, _) {
                    return ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: widget.queue.length,
                      itemBuilder: (context, index) {
                        final song = widget.queue[index];
                        final isCurrent = index == currentPlayerIndex;
                        final isPast = index < currentPlayerIndex;

                        return _QueueItem(
                          song: song,
                          index: index,
                          isCurrent: isCurrent,
                          isPast: isPast,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pop();
                            widget.onSongTap(song, index);
                          },
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueItem extends StatefulWidget {
  final Song song;
  final int index;
  final bool isCurrent;
  final bool isPast;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _QueueItem({
    required this.song,
    required this.index,
    required this.isCurrent,
    required this.isPast,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  State<_QueueItem> createState() => _QueueItemState();
}

class _QueueItemState extends State<_QueueItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleTap,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isCurrent
                        ? widget.colorScheme.primaryContainer.withOpacity(0.4)
                        : widget.isPast
                            ? widget.colorScheme.surfaceVariant.withOpacity(0.3)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: widget.isCurrent
                        ? Border.all(
                            color: widget.colorScheme.primary.withOpacity(0.5),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: widget.isCurrent
                            ? _PlayingIndicator(
                                colorScheme: widget.colorScheme,
                              )
                            : Text(
                                '${widget.index + 1}',
                                style: widget.textTheme.bodyMedium?.copyWith(
                                  color: widget.colorScheme.onSurface.withOpacity(
                                    widget.isPast ? 0.4 : 0.6,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                                textAlign: TextAlign.center,
                              ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: widget.textTheme.bodyLarge?.copyWith(
                                      fontWeight: widget.isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: widget.colorScheme.onSurface.withOpacity(
                                        widget.isPast ? 0.5 : 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.isCurrent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          widget.colorScheme.primary,
                                          widget.colorScheme.secondary,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Now',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.song.artist.isEmpty || widget.song.artist == '<unknown>'
                                  ? 'Unknown Artist'
                                  : widget.song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: widget.textTheme.bodySmall?.copyWith(
                                color: widget.colorScheme.onSurface.withOpacity(
                                  widget.isPast ? 0.4 : 0.7,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      Text(
                        _formatDuration(widget.song.duration),
                        style: widget.textTheme.bodySmall?.copyWith(
                          color: widget.colorScheme.onSurface.withOpacity(
                            widget.isPast ? 0.4 : 0.6,
                          ),
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _PlayingIndicator extends StatefulWidget {
  final ColorScheme colorScheme;

  const _PlayingIndicator({
    required this.colorScheme,
  });

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Bar(
              height: 12 + (_controller.value * 8),
              color: widget.colorScheme.primary,
            ),
            const SizedBox(width: 2),
            _Bar(
              height: 8 + ((1 - _controller.value) * 12),
              color: widget.colorScheme.primary,
            ),
            const SizedBox(width: 2),
            _Bar(
              height: 12 + (_controller.value * 8),
              color: widget.colorScheme.primary,
            ),
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  final Color color;

  const _Bar({
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
