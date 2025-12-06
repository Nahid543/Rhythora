import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/rhythora_app.dart' show listeningStatsService;

class ExportDialog extends StatefulWidget {
  const ExportDialog({super.key});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  String _selectedFormat = 'json';
  bool _isExporting = false;

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    HapticFeedback.mediumImpact();

    try {
      // Get listening history data
      final listeningTime = listeningStatsService.getTodayListeningTime();
      final data = {
        'export_date': DateTime.now().toIso8601String(),
        'total_time_seconds': listeningTime.inSeconds,
        'total_time_minutes': listeningTime.inMinutes,
        'song_plays': listeningStatsService.getTodaySongPlays(),
        'unique_songs': listeningStatsService.getTodayUniqueSongsCount(),
        'app_version': '1.0.0',
      };

      final String content;
      final String fileName;

      if (_selectedFormat == 'json') {
        content = const JsonEncoder.withIndent('  ').convert(data);
        fileName = 'rhythora_stats_${DateTime.now().millisecondsSinceEpoch}.json';
      } else {
        // CSV format - Fix the date formatting
        final exportDate = DateTime.now().toLocal().toString().split('.')[0];
        content = 'Export Date,Total Time (seconds),Total Time (minutes),Song Plays,Unique Songs\n'
            '$exportDate,${data['total_time_seconds']},${data['total_time_minutes']},${data['song_plays']},${data['unique_songs']}';
        fileName = 'rhythora_stats_${DateTime.now().millisecondsSinceEpoch}.csv';
      }

      // Save to app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Rhythora Listening Statistics',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 20),
                SizedBox(width: 12),
                Text('Stats exported successfully'),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, size: 20, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Export failed: ${e.toString()}', // ✅ FIXED - properly shows error
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
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
              Icons.download_rounded,
              color: colorScheme.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Export Data',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose export format:',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),

          // JSON Option
          RadioListTile<String>(
            value: 'json',
            groupValue: _selectedFormat,
            onChanged: _isExporting
                ? null
                : (value) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedFormat = value!);
                  },
            title: const Text('JSON'),
            subtitle: const Text('Structured data format'),
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          // CSV Option
          RadioListTile<String>(
            value: 'csv',
            groupValue: _selectedFormat,
            onChanged: _isExporting
                ? null
                : (value) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedFormat = value!);
                  },
            title: const Text('CSV'),
            subtitle: const Text('Open in Excel or Google Sheets'),
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isExporting
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isExporting ? null : _exportData,
          icon: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.file_download_rounded),
          label: Text(_isExporting ? 'Exporting...' : 'Export'),
        ),
      ],
    );
  }
}
