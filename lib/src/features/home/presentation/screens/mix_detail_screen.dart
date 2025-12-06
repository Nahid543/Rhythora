import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../library/domain/entities/song.dart';
import '../../domain/mix_generator.dart';

class MixDetailScreen extends StatefulWidget {
  final MixType mixType;
  final List<Song> allSongs;
  final List<Song>? recentlyPlayed;
  final Function(Song, List<Song>, int) onSongSelected;

  const MixDetailScreen({
    super.key,
    required this.mixType,
    required this.allSongs,
    this.recentlyPlayed,
    required this.onSongSelected,
  });

  @override
  State<MixDetailScreen> createState() => _MixDetailScreenState();
}

class _MixDetailScreenState extends State<MixDetailScreen> with TickerProviderStateMixin {
  late List<Song> _mixSongs;
  late MixInfo _mixInfo;
  bool _isGenerating = true;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    
    _mixInfo = MixGenerator.getMixInfo(widget.mixType);
    _generateMix();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _generateMix() async {
    setState(() => _isGenerating = true);
    
    try {
      final cachedMix = await MixGenerator.loadMixFromPreferences(widget.mixType);
      
      if (cachedMix != null && cachedMix.isNotEmpty) {
        debugPrint('✅ Using cached ${widget.mixType} mix (${cachedMix.length} songs)');
        setState(() {
          _mixSongs = cachedMix;
          _isGenerating = false;
        });
        _fadeController.forward();
        return;
      }

      debugPrint('Generating new ${widget.mixType} mix...');
      _mixSongs = await MixGenerator.generateMix(
        type: widget.mixType,
        allSongs: widget.allSongs,
        recentlyPlayed: widget.recentlyPlayed,
        maxSongs: 30,
      );
      
      debugPrint('✅ Generated ${_mixSongs.length} songs');
      
      setState(() => _isGenerating = false);
      _fadeController.forward();
    } catch (e) {
      debugPrint('❌ Error generating mix: $e');
      setState(() {
        _mixSongs = [];
        _isGenerating = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to generate mix'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _regenerateMix() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.refresh_rounded),
            SizedBox(width: 12),
            Text('Regenerate Mix?'),
          ],
        ),
        content: const Text(
          'This will create a new mix with different songs. Your current mix will be replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      MixGenerator.clearCache(widget.mixType);
      await _generateMix();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mix regenerated!'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _shuffleMix() {
    setState(() {
      _mixSongs.shuffle();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Mix shuffled!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _playAll() {
    if (_mixSongs.isEmpty) return;
    
    final firstSong = _mixSongs.first;
    final correctIndex = widget.allSongs.indexWhere((s) => s.id == firstSong.id);
    
    debugPrint('Playing all: Song=${firstSong.title}, Index=$correctIndex');
    
    widget.onSongSelected(
      firstSong,
      widget.allSongs,
      correctIndex >= 0 ? correctIndex : 0,
    );
  }

  void _playSongFromMix(Song song, int mixIndex) {
    final correctIndex = widget.allSongs.indexWhere((s) => s.id == song.id);
    
    debugPrint('Playing from mix: Song=${song.title}, MixIndex=$mixIndex, LibraryIndex=$correctIndex');
    
    widget.onSongSelected(
      song,
      widget.allSongs,
      correctIndex >= 0 ? correctIndex : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: isTablet ? 300 : 240,
            pinned: true,
            stretch: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
                onPressed: _regenerateMix,
                tooltip: 'Regenerate mix',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _mixInfo.gradientColors,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _mixInfo.icon,
                          size: isTablet ? 64 : 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _mixInfo.title,
                        style: textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          _mixInfo.description,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_isGenerating)
            SliverFillRemaining(
              child: _buildLoadingState(colorScheme, textTheme),
            )
          else if (_mixSongs.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(colorScheme, textTheme),
            )
          else
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(isTablet ? 32 : 20),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _ActionButton(
                              label: 'Play All',
                              icon: Icons.play_arrow_rounded,
                              isPrimary: true,
                              onTap: _playAll,
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              label: 'Shuffle',
                              icon: Icons.shuffle_rounded,
                              isPrimary: false,
                              onTap: _shuffleMix,
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Row(
                        children: [
                          Icon(
                            Icons.music_note_rounded,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_mixSongs.length} songs in this mix',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ..._mixSongs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final song = entry.value;
                    
                    return TweenAnimationBuilder<double>(
                      key: ValueKey(song.id),
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (index * 50)),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: _MixSongItem(
                              song: song,
                              index: index,
                              onTap: () => _playSongFromMix(song, index),
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                              isTablet: isTablet,
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),

                  SizedBox(height: isTablet ? 40 : 24),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              color: colorScheme.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Generating your mix...',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analyzing your library for the perfect tracks',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off_rounded,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'No songs found',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Unable to generate mix. Try adding more songs to your library.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isPrimary
                ? colorScheme.primary
                : colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? colorScheme.primary
                  : colorScheme.outline.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isPrimary ? colorScheme.onPrimary : colorScheme.onSurface,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isPrimary ? colorScheme.onPrimary : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MixSongItem extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isTablet;

  const _MixSongItem({
    required this.song,
    required this.index,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final artworkId = int.tryParse(song.id) ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 20,
            vertical: 8,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${index + 1}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
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
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDuration(song.duration),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.play_circle_outline_rounded,
                color: colorScheme.primary,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
