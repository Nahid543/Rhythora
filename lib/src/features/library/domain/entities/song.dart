class Song {
  final String id;
  final String title;
  final String artist;
  final Duration duration;
  final String album;

  /// For demo songs bundled as assets (fallback)
  final String? audioAsset;

  /// For real songs on device
  final String? filePath;

  final String? albumArtPath;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.album,
    this.audioAsset,
    this.filePath,
    this.albumArtPath,
  });

  bool get isLocalFile => filePath != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'duration': duration.inMilliseconds,
      'album': album,
      'audioAsset': audioAsset,
      'filePath': filePath,
      'albumArtPath': albumArtPath,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      duration: Duration(milliseconds: json['duration'] as int),
      album: json['album'] as String,
      audioAsset: json['audioAsset'] as String?,
      filePath: json['filePath'] as String?,
      albumArtPath: json['albumArtPath'] as String?,
    );
  }

  @override
  String toString() {
    return 'Song(id: $id, title: $title, artist: $artist)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Song && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
