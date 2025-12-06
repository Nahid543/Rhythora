import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SleepTimerDialog extends StatefulWidget {
  final Duration? currentDuration;

  const SleepTimerDialog({
    super.key,
    this.currentDuration,
  });

  @override
  State<SleepTimerDialog> createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends State<SleepTimerDialog> {
  static const List<int> _presetMinutes = [5, 10, 15, 30, 45, 60, 90, 120];
  int? _selectedMinutes;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.currentDuration?.inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Row(
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
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.bedtime_rounded,
              color: colorScheme.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Sleep Timer',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Music will stop after:',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetMinutes.map((minutes) {
                final isSelected = _selectedMinutes == minutes;
                return FilterChip(
                  label: Text(
                    minutes >= 60
                        ? '${minutes ~/ 60}h ${minutes % 60 > 0 ? '${minutes % 60}m' : ''}'.trim()
                        : '${minutes}m',
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedMinutes = selected ? minutes : null;
                    });
                  },
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  selectedColor: colorScheme.primaryContainer,
                  checkmarkColor: colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.currentDuration != null && widget.currentDuration!.inSeconds > 0)
          TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context, Duration.zero);
            },
            icon: const Icon(Icons.clear_rounded),
            label: const Text('Cancel Timer'),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.error,
            ),
          ),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _selectedMinutes != null
              ? () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(
                    context,
                    Duration(minutes: _selectedMinutes!),
                  );
                }
              : null,
          child: const Text('Set Timer'),
        ),
      ],
    );
  }
}
