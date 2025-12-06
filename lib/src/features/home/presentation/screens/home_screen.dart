import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../library/domain/entities/song.dart';
import '../widgets/continue_listening_card.dart';
import '../widgets/greeting_section.dart';
import '../widgets/library_stats_card.dart';
import '../widgets/mix_card.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/recently_played_card.dart';
import '../widgets/section_header.dart';
import 'search_screen.dart';
import '../../domain/mix_generator.dart';
import '../../../../app/rhythora_app.dart' show listeningStatsService;
import '../../domain/services/listening_stats_service.dart'
    show ListeningStatsSnapshot;

class HomeScreen extends StatefulWidget {
  final Song? currentSong;
  final List<Song> recentlyPlayed;
  final VoidCallback onOpenNowPlaying;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenQueue;
  final Function(Song) onRecentlyPlayedTap;
  final Function(Song)? onRemoveFromRecent;
  final VoidCallback? onClearRecentlyPlayed;
  final List<Song> allSongs;
  final Function(Song, List<Song>, int) onSongSelected;

  const HomeScreen({
    super.key,
    required this.currentSong,
    required this.recentlyPlayed,
    required this.onOpenNowPlaying,
    required this.onOpenLibrary,
    required this.onOpenQueue,
    required this.onRecentlyPlayedTap,
    this.onRemoveFromRecent,
    this.onClearRecentlyPlayed,
    required this.allSongs,
    required this.onSongSelected,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late List<Animation<double>> _staggeredAnimations;
  // ignore: unused_field
  late Animation<double> _fadeAnimation;
  // ignore: unused_field
  late Animation<Offset> _slideAnimation;

  final ScrollController _scrollController = ScrollController();
  bool _isAppBarCollapsed = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _staggeredAnimations = List.generate(
      6,
      (index) => CurvedAnimation(
        parent: _staggerController,
        curve: Interval(
          index * 0.1,
          0.5 + (index * 0.1),
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _scrollController.addListener(_onScroll);

    _fadeController.forward();
    _staggerController.forward();
  }

  void _onScroll() {
    final isCollapsed = _scrollController.hasClients && 
                        _scrollController.offset > 50;
    if (isCollapsed != _isAppBarCollapsed) {
      setState(() => _isAppBarCollapsed = isCollapsed);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 18) return 'Good afternoon';
    if (hour >= 18 && hour < 23) return 'Good evening';
    return 'Welcome back';
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();

    await listeningStatsService.refreshStats();

    if (mounted) {
      setState(() {});
    }

    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.onInverseSurface,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text('Library refreshed!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _handleSearch() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SearchScreen(
          allSongs: widget.allSongs,
          onSongSelected: widget.onSongSelected,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _handleClearRecentlyPlayed() async {
    HapticFeedback.mediumImpact();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_sweep_rounded,
                  color: colorScheme.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Clear history?',
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Text(
            'This will remove all ${widget.recentlyPlayed.length} songs from your recently played history. This action cannot be undone.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(dialogContext).pop(false);
              },
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      widget.onClearRecentlyPlayed?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: colorScheme.onInverseSurface,
              ),
              const SizedBox(width: 12),
              Text(
                'Recently played history cleared',
                style: TextStyle(color: colorScheme.onInverseSurface),
              ),
            ],
          ),
          backgroundColor: colorScheme.inverseSurface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Widget _buildLogoGraphic({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required bool isLightTheme,
  }) {
    final image = Image.asset(
      'assets/images/rhythora_logo.png',
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      errorBuilder: (context, error, stackTrace) {
        return _buildLogoFallback(colorScheme, textTheme);
      },
    );

    if (!isLightTheme) {
      return image;
    }

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          1.08, 0, 0, 0, 0,
          0, 1.08, 0, 0, 0,
          0, 0, 1.08, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: image,
      ),
    );
  }

  Widget _buildLogoFallback(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              Icons.music_note_rounded,
              color: colorScheme.onPrimary,
              size: 20,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              'Rhythora',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isLightTheme = theme.brightness == Brightness.light;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      appBar: AppBar(
        // ✨ OPTIMIZED: Logo-only AppBar with responsive sizing
        title: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          height: _isAppBarCollapsed ? 32 : 40,
          child: Hero(
            tag: 'app_logo',
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0.0,
                end: _isAppBarCollapsed ? 0.8 : 1.0,
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  alignment: Alignment.centerLeft,
                  child: child,
                );
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: _isAppBarCollapsed ? 120 : 160,
                  maxHeight: _isAppBarCollapsed ? 32 : 40,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: isLightTheme
                      ? LinearGradient(
                          colors: [
                            colorScheme.primary.withOpacity(0.16),
                            colorScheme.secondary.withOpacity(0.12),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isLightTheme
                      ? colorScheme.surface.withOpacity(0.9)
                      : Colors.transparent,
                  border: isLightTheme
                      ? Border.all(
                          color: colorScheme.primary.withOpacity(0.2),
                          width: 1,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: isLightTheme
                          ? Colors.black.withOpacity(0.05)
                          : colorScheme.primary.withOpacity(0.2),
                      blurRadius: isLightTheme ? 6 : 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isLightTheme ? 12 : 0,
                  vertical: isLightTheme ? 4 : 0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildLogoGraphic(
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    isLightTheme: isLightTheme,
                  ),
                ),
              ),
            ),
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: theme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: _handleSearch,
            tooltip: 'Search',
            splashRadius: 24,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: colorScheme.primary,
        displacement: 40,
        edgeOffset: 0,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 32 : 20,
                vertical: isSmallScreen ? 12 : 16,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _AnimatedSection(
                    animation: _staggeredAnimations[0],
                    child: GreetingSection(
                      greeting: _greeting(),
                      textTheme: textTheme,
                      colorScheme: colorScheme,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 16 : (isTablet ? 28 : 20)),

                  _AnimatedSection(
                    animation: _staggeredAnimations[1],
                    child: ValueListenableBuilder<ListeningStatsSnapshot>(
                      valueListenable: listeningStatsService.statsNotifier,
                      builder: (context, snapshot, _) {
                        return LibraryStatsCard(
                          songCount: widget.allSongs.length,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          isTablet: isTablet,
                          todayListeningTime: snapshot.listeningTime,
                          todaySongPlays: snapshot.songPlays,
                        );
                      },
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 16 : (isTablet ? 28 : 20)),

                  if (widget.currentSong != null) ...[
                    _AnimatedSection(
                      animation: _staggeredAnimations[2],
                      child: ContinueListeningCard(
                        song: widget.currentSong!,
                        onTap: widget.onOpenNowPlaying,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 16 : (isTablet ? 28 : 20)),
                  ],

                  _AnimatedSection(
                    animation: _staggeredAnimations[3],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Quick actions',
                          textTheme: textTheme,
                          icon: Icons.bolt_rounded,
                        ),
                        const SizedBox(height: 12),
                        QuickActionsRow(
                          currentSong: widget.currentSong,
                          onOpenLibrary: widget.onOpenLibrary,
                          onOpenQueue: widget.onOpenQueue,
                          onOpenNowPlaying: widget.onOpenNowPlaying,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          isTablet: isTablet,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 20 : (isTablet ? 32 : 24)),

                  if (widget.recentlyPlayed.isNotEmpty)
                    _AnimatedSection(
                      animation: _staggeredAnimations[4],
                      child: SectionHeader(
                        title: 'Recently played',
                        textTheme: textTheme,
                        icon: Icons.history_rounded,
                        action: TextButton.icon(
                          onPressed: _handleClearRecentlyPlayed,
                          icon: const Icon(Icons.clear_all_rounded, size: 18),
                          label: const Text('Clear'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.recentlyPlayed.isNotEmpty)
                    const SizedBox(height: 12),
                ]),
              ),
            ),

            if (widget.recentlyPlayed.isNotEmpty)
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _staggeredAnimations[4],
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(_staggeredAnimations[4]),
                    child: SizedBox(
                      height: isTablet ? 200 : (isSmallScreen ? 150 : 170),
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 32 : 20,
                        ),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: widget.recentlyPlayed.length.clamp(0, 12),
                        separatorBuilder: (_, __) =>
                            SizedBox(width: isTablet ? 16 : 12),
                        itemBuilder: (context, index) {
                          final song = widget.recentlyPlayed[index];

                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(
                              milliseconds: 400 + (index * 50),
                            ),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: 0.8 + (0.2 * value),
                                child: Opacity(
                                  opacity: value,
                                  child: child,
                                ),
                              );
                            },
                            child: Dismissible(
                              key: Key('recent_${song.id}'),
                              direction: DismissDirection.up,
                              onDismissed: (direction) {
                                HapticFeedback.mediumImpact();
                                widget.onRemoveFromRecent?.call(song);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${song.title} removed'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              },
                              background: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                alignment: Alignment.center,
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.delete_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Remove',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              child: RecentlyPlayedCard(
                                song: song,
                                currentSong: widget.currentSong,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  widget.onRecentlyPlayedTap(song);
                                },
                                colorScheme: colorScheme,
                                textTheme: textTheme,
                                isTablet: isTablet,
                                isSmallScreen: isSmallScreen,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 32 : 20,
                vertical: isSmallScreen ? 20 : (isTablet ? 32 : 24),
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _AnimatedSection(
                    animation: _staggeredAnimations[5],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Your mixes',
                          textTheme: textTheme,
                          icon: Icons.auto_awesome_rounded,
                        ),
                        const SizedBox(height: 12),
                        MixCard(
                          title: 'Chill evening',
                          subtitle: 'Soft tracks for focus & relax',
                          icon: Icons.nightlight_rounded,
                          gradientColors: const [
                            Color(0xFF1E293B),
                            Color(0xFF0F172A),
                          ],
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          mixType: MixType.chillEvening,
                          allSongs: widget.allSongs,
                          recentlyPlayed: widget.recentlyPlayed,
                          onSongSelected: widget.onSongSelected,
                        ),
                        const SizedBox(height: 12),
                        MixCard(
                          title: 'Energy boost',
                          subtitle: 'Upbeat songs from your library',
                          icon: Icons.bolt_rounded,
                          gradientColors: const [
                            Color(0xFF7C3AED),
                            Color(0xFF4C1D95),
                          ],
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          mixType: MixType.energyBoost,
                          allSongs: widget.allSongs,
                          recentlyPlayed: widget.recentlyPlayed,
                          onSongSelected: widget.onSongSelected,
                        ),
                        const SizedBox(height: 12),
                        MixCard(
                          title: 'Focus mode',
                          subtitle: 'Instrumental tracks for deep work',
                          icon: Icons.workspace_premium_rounded,
                          gradientColors: const [
                            Color(0xFF0EA5E9),
                            Color(0xFF0C4A6E),
                          ],
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          mixType: MixType.focusMode,
                          allSongs: widget.allSongs,
                          recentlyPlayed: widget.recentlyPlayed,
                          onSongSelected: widget.onSongSelected,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 16 : (isTablet ? 24 : 20)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedSection extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _AnimatedSection({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}
