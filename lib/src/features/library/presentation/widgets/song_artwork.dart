import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/local_music_loader.dart';

/// A widget that lazily loads and caches album artwork for a song.
///
/// Shows a placeholder icon immediately, then fades in the artwork
/// once it's loaded from cache or fetched from the platform.
class SongArtwork extends StatefulWidget {
  final String songId;
  final String? albumArtPath;
  final double size;
  final double borderRadius;
  final double iconSize;
  final int? cacheWidth;

  const SongArtwork({
    super.key,
    required this.songId,
    required this.albumArtPath,
    this.size = 56,
    this.borderRadius = 8,
    this.iconSize = 28,
    this.cacheWidth,
  });

  @override
  State<SongArtwork> createState() => _SongArtworkState();
}

class _SongArtworkState extends State<SongArtwork> {
  String? _resolvedPath;
  bool _isLoading = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _resolvedPath = widget.albumArtPath;

    // If no artwork path is set, try to lazily load it
    if (_resolvedPath == null) {
      _loadArtworkLazily();
    }
  }

  @override
  void didUpdateWidget(SongArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId ||
        oldWidget.albumArtPath != widget.albumArtPath) {
      _resolvedPath = widget.albumArtPath;
      _loadFailed = false;
      if (_resolvedPath == null) {
        _loadArtworkLazily();
      }
    }
  }

  Future<void> _loadArtworkLazily() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final songIdInt = int.tryParse(widget.songId);
      if (songIdInt == null) {
        _isLoading = false;
        return;
      }

      final path = await LocalMusicLoader.instance.getOrCacheArtwork(songIdInt);
      if (mounted && path != null) {
        setState(() {
          _resolvedPath = path;
          _isLoading = false;
        });
      } else {
        _isLoading = false;
      }
    } catch (_) {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveCacheWidth = widget.cacheWidth ??
        (widget.size * MediaQuery.devicePixelRatioOf(context)).toInt();

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: colorScheme.surfaceContainerHighest,
      ),
      child: _resolvedPath != null && !_loadFailed
          ? ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Image.file(
                File(_resolvedPath!),
                fit: BoxFit.cover,
                width: widget.size,
                height: widget.size,
                cacheWidth: effectiveCacheWidth,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    return child;
                  }
                  // Show placeholder while decoding
                  return _defaultIcon(colorScheme);
                },
                errorBuilder: (_, __, ___) {
                  // Mark as failed so we don't retry with a broken file
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _loadFailed = true);
                  });
                  return _defaultIcon(colorScheme);
                },
              ),
            )
          : _defaultIcon(colorScheme),
    );
  }

  Widget _defaultIcon(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.music_note_rounded,
        color: colorScheme.onSurfaceVariant,
        size: widget.iconSize,
      ),
    );
  }
}
