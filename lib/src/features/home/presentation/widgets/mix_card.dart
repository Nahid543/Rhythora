import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/mix_generator.dart';
import '../screens/mix_detail_screen.dart';
import '../../../library/domain/entities/song.dart';

class MixCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final MixType mixType;
  final List<Song> allSongs;
  final List<Song>? recentlyPlayed;
  final Function(Song, List<Song>, int) onSongSelected;

  const MixCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.colorScheme,
    required this.textTheme,
    required this.mixType,
    required this.allSongs,
    this.recentlyPlayed,
    required this.onSongSelected,
  });

  Future<void> _handleTap(BuildContext context) async {
    if (allSongs.isEmpty) {
      final hasPermission = await _checkAndRequestPermission(context);
      
      if (!hasPermission) {
        _showPermissionDialog(context);
        return;
      }
      
      _showNoSongsDialog(context);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MixDetailScreen(
          mixType: mixType,
          allSongs: allSongs,
          recentlyPlayed: recentlyPlayed,
          onSongSelected: onSongSelected,
        ),
      ),
    );
  }

  Future<bool> _checkAndRequestPermission(BuildContext context) async {
    var status = await Permission.audio.status;
    
    if (status.isDenied) {
      status = await Permission.audio.request();
    }
    
    return status.isGranted;
  }

  void _showPermissionDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.folder_open_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Storage Permission'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rhythora needs storage permission to access your music files and create mixes.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Please grant permission in:',
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '1. Go to Library tab\n2. Allow storage access\n3. Return here to enjoy mixes',
              style: textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showNoSongsDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.music_off_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            const Text('No Songs Found'),
          ],
        ),
        content: const Text(
          'Go to the Library tab to load your music first, then come back to enjoy personalized mixes!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleTap(context),
              borderRadius: BorderRadius.circular(24),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
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
  }
}
