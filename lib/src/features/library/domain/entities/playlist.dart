
import 'package:flutter/foundation.dart';

@immutable
class Playlist {
  final String id;
  final String name;
  final List<String> songIds;
  final DateTime createdAt;
  final DateTime lastModified;
  final bool isSystemPlaylist;

  const Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
    required this.lastModified,
    this.isSystemPlaylist = false,
  });

  Playlist copyWith({
    String? name,
    List<String>? songIds,
    DateTime? lastModified,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt,
      lastModified: lastModified ?? this.lastModified,
      isSystemPlaylist: isSystemPlaylist,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songIds': songIds,
        'createdAt': createdAt.toIso8601String(),
        'lastModified': lastModified.toIso8601String(),
        'isSystemPlaylist': isSystemPlaylist,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        songIds: List<String>.from(json['songIds'] as List),
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastModified: DateTime.parse(json['lastModified'] as String),
        isSystemPlaylist: json['isSystemPlaylist'] as bool? ?? false,
      );

  int get songCount => songIds.length;
  bool get isEmpty => songIds.isEmpty;
}
