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

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: animationsEnabled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -2),
                ),
              ]
            : null,
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
                animationsEnabled: animationsEnabled,
              ),
              _NavBarItem(
                icon: Icons.library_music_rounded,
                label: 'Library',
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
                colorScheme: colorScheme,
                animationsEnabled: animationsEnabled,
              ),
              _NavBarItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
                colorScheme: colorScheme,
                animationsEnabled: animationsEnabled,
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
  final bool animationsEnabled;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    required this.animationsEnabled,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration:
          widget.animationsEnabled ? const Duration(milliseconds: 200) : Duration.zero,
    );

    _scaleAnimation = widget.animationsEnabled
        ? Tween<double>(
            begin: 1.0,
            end: 1.12,
          ).animate(
            CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOutCubic,
            ),
          )
        : const AlwaysStoppedAnimation<double>(1.0);

    if (widget.isSelected) {
      _controller.value = 1.0;
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
    if (widget.animationsEnabled) {
      _controller.forward().then((_) {
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {}
          });
        }
      });
    }

    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: widget.animationsEnabled
            ? const Duration(milliseconds: 200)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: widget.isSelected ? 18 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? widget.colorScheme.primaryContainer.withValues(alpha: 0.6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (widget.isSelected)
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: widget.colorScheme.primary.withValues(alpha: 0.25),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      Icon(
                        widget.icon,
                        size: 24,
                        color: widget.isSelected
                            ? widget.colorScheme.primary
                            : widget.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ],
                  ),
                );
              },
            ),

            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
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
                            height: 1.0,
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
