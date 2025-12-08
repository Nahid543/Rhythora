import 'library_source_mode.dart';

class LibrarySourceSettings {
  final LibrarySourceMode mode;
  final List<String> folderPaths;
  final List<String> hiddenFolderPaths;

  const LibrarySourceSettings({
    this.mode = LibrarySourceMode.allMusic,
    this.folderPaths = const [],
    this.hiddenFolderPaths = const [],
  });

  bool get isAllMusic => mode == LibrarySourceMode.allMusic;
  bool get hasSelectedFolders => folderPaths.isNotEmpty;
  int get selectedFolderCount => folderPaths.length;

  bool isFolderActive(String folderPath) {
    if (isAllMusic) return false;
    final normalized = folderPath.trim().toLowerCase();
    return folderPaths.any((p) => p.trim().toLowerCase() == normalized);
  }

  bool isFolderHiddenFromFilterBar(String folderPath) {
    final normalized = folderPath.trim().toLowerCase();
    return hiddenFolderPaths.any((p) => p.trim().toLowerCase() == normalized);
  }

  LibrarySourceSettings copyWith({
    LibrarySourceMode? mode,
    List<String>? folderPaths,
    List<String>? hiddenFolderPaths,
  }) {
    return LibrarySourceSettings(
      mode: mode ?? this.mode,
      folderPaths: folderPaths ?? this.folderPaths,
      hiddenFolderPaths: hiddenFolderPaths ?? this.hiddenFolderPaths,
    );
  }

  LibrarySourceSettings activateAllMusic() {
    return copyWith(mode: LibrarySourceMode.allMusic, folderPaths: []);
  }

  LibrarySourceSettings toggleFolder(String folderPath) {
    final normalized = folderPath.trim();
    if (normalized.isEmpty) return this;

    final isCurrentlyActive = isFolderActive(normalized);
    final updatedPaths = List<String>.from(folderPaths);

    if (isCurrentlyActive) {
      updatedPaths.remove(normalized);
    } else {
      if (!updatedPaths.contains(normalized)) {
        updatedPaths.add(normalized);
      }
    }

    return copyWith(
      mode: updatedPaths.isEmpty
          ? LibrarySourceMode.allMusic
          : LibrarySourceMode.selectedFolders,
      folderPaths: updatedPaths,
    );
  }

  LibrarySourceSettings toggleFolderVisibility(String folderPath) {
    final normalized = folderPath.trim();
    if (normalized.isEmpty) return this;

    final isCurrentlyHidden = isFolderHiddenFromFilterBar(normalized);
    final updatedHidden = List<String>.from(hiddenFolderPaths);

    if (isCurrentlyHidden) {
      updatedHidden.remove(normalized);
    } else {
      if (!updatedHidden.contains(normalized)) {
        updatedHidden.add(normalized);
      }
    }

    return copyWith(hiddenFolderPaths: updatedHidden);
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'folderPaths': folderPaths,
      'hiddenFolderPaths': hiddenFolderPaths,
    };
  }

  factory LibrarySourceSettings.fromJson(Map<String, dynamic> json) {
    return LibrarySourceSettings(
      mode: LibrarySourceMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => LibrarySourceMode.allMusic,
      ),
      folderPaths:
          (json['folderPaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      hiddenFolderPaths:
          (json['hiddenFolderPaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibrarySourceSettings &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          _listEquals(folderPaths, other.folderPaths) &&
          _listEquals(hiddenFolderPaths, other.hiddenFolderPaths);

  @override
  int get hashCode => Object.hash(mode, folderPaths, hiddenFolderPaths);

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'LibrarySourceSettings(mode: $mode, folders: ${folderPaths.length}, hidden: ${hiddenFolderPaths.length})';
}

extension LibrarySourceSettingsX on LibrarySourceSettings {
  bool get hasExplicitSource => isAllMusic || hasSelectedFolders;
}
