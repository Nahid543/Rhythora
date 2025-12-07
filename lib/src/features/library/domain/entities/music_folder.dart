class MusicFolder {
  final String path;
  final String name;
  final int songCount;

  const MusicFolder({
    required this.path,
    required this.name,
    required this.songCount,
  });

  MusicFolder copyWith({
    String? path,
    String? name,
    int? songCount,
  }) {
    return MusicFolder(
      path: path ?? this.path,
      name: name ?? this.name,
      songCount: songCount ?? this.songCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicFolder &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'MusicFolder(name: $name, songCount: $songCount)';
}
