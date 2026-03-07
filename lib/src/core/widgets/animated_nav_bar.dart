import 'package:flutter/material.dart';

class AnimatedNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final ColorScheme colorScheme;
  final bool animationsEnabled;

  const AnimatedNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.colorScheme,
    this.animationsEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Instead of full width, make it a floating pill
    final navBarWidth = isTablet ? 400.0 : MediaQuery.of(context).size.width * 0.88;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24.0), // Floating above the bottom
        // Wrap in RepaintBoundary to prevent NavBar animations from repainting the whole screen
        child: RepaintBoundary(
          child: Container(
            width: navBarWidth,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              // Use opaque colors instead of BackdropFilter for massive performance gains
              // The illusion of depth is maintained by the shadow and border
              color: isDark 
                  ? const Color(0xFF1E1E2C) // Solid dark purple-gray
                  : const Color(0xFFF8F9FA), // Solid off-white
              border: Border.all(
                color: isDark 
                    ? Colors.white.withOpacity(0.08) 
                    : Colors.black.withOpacity(0.05),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / 3;
                  return Stack(
                    children: [
                      // Smooth gliding premium background indicator
                      AnimatedPositioned(
                        duration: animationsEnabled 
                            ? const Duration(milliseconds: 300) 
                            : Duration.zero,
                        curve: Curves.fastOutSlowIn,
                        left: currentIndex * itemWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: itemWidth,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            // Slightly simplified gradient for better render performance
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF4158D0), // Deep Indigo
                                Color(0xFFC850C0), // Purple
                                Color(0xFFFFCC70), // Peach/Gold
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            // Removed the inner box shadow on the indicator as it adds
                            // minimal visual value but costs performance during the animation
                          ),
                        ),
                      ),
                      
                      // The actual navigation items
                      Row(
                        children: [
                          _NavBarItem(
                            icon: Icons.home_rounded,
                            activeIcon: Icons.home_rounded,
                            label: 'Home',
                            isSelected: currentIndex == 0,
                            onTap: () => onTap(0),
                            width: itemWidth,
                            isDark: isDark,
                            animationsEnabled: animationsEnabled,
                          ),
                          _NavBarItem(
                            icon: Icons.library_music_outlined,
                            activeIcon: Icons.library_music_rounded,
                            label: 'Library',
                            isSelected: currentIndex == 1,
                            onTap: () => onTap(1),
                            width: itemWidth,
                            isDark: isDark,
                            animationsEnabled: animationsEnabled,
                          ),
                          _NavBarItem(
                            icon: Icons.settings_outlined,
                            activeIcon: Icons.settings_rounded,
                            label: 'Settings',
                            isSelected: currentIndex == 2,
                            onTap: () => onTap(2),
                            width: itemWidth,
                            isDark: isDark,
                            animationsEnabled: animationsEnabled,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double width;
  final bool isDark;
  final bool animationsEnabled;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.width,
    required this.isDark,
    required this.animationsEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected 
        ? Colors.white 
        : (isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.4));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: animationsEnabled ? const Duration(milliseconds: 300) : Duration.zero,
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected), // Force re-render for animation
                size: isSelected ? 26 : 24,
                color: textColor,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: isSelected 
                ? Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
            )
          ],
        ),
      ),
    );
  }
}
