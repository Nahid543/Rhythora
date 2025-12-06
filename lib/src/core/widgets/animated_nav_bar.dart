import 'package:flutter/material.dart';

class AnimatedNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final ColorScheme colorScheme;

  const AnimatedNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: isTablet ? 72 : 64,
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 48 : 20,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavBarItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
                colorScheme: colorScheme,
              ),
              _NavBarItem(
                icon: Icons.library_music_rounded,
                label: 'Library',
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
                colorScheme: colorScheme,
              ),
              _NavBarItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isTapped = false;

  @override
  void initState() {
    super.initState();
    
    // Faster, smoother animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200), // Reduced from 300ms
    );

    // Optimized scale animation with better curve
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.12, // Slightly reduced from 1.15 for subtlety
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic, // Smoother curve
    ));

    // Start animation immediately if selected
    if (widget.isSelected) {
      _controller.value = 1.0; // Skip animation on init
    }
  }

  @override
  void didUpdateWidget(_NavBarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Immediate feedback
    setState(() => _isTapped = true);
    
    // Quick bounce effect
    _controller.forward().then((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            setState(() => _isTapped = false);
          }
        });
      }
    });

    // Call tap immediately (don't wait for animation)
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque, // Better tap detection
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), // Faster transition
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: widget.isSelected ? 18 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? widget.colorScheme.primaryContainer.withOpacity(0.6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Icon
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Subtle glow effect when selected
                      if (widget.isSelected)
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: widget.colorScheme.primary.withOpacity(0.25),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      // Icon
                      Icon(
                        widget.icon,
                        size: 24, // Slightly smaller for consistency
                        color: widget.isSelected
                            ? widget.colorScheme.primary
                            : widget.colorScheme.onSurface.withOpacity(0.65),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Animated Label with optimized size transition
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200), // Faster
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                child: widget.isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          widget.label,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: widget.colorScheme.primary,
                            letterSpacing: 0.1,
                            height: 1.0, // Prevent layout shifts
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
