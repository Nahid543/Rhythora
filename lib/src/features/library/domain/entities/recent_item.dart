enum RecentItemType { song, playlist, mix }

class RecentItem {
  final String id;
  final String title;
  final String? subtitle;
  final RecentItemType type;
  final DateTime lastPlayed;

  const RecentItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    required this.lastPlayed,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'type': type.name,
    'lastPlayed': lastPlayed.toIso8601String(),
  };

  factory RecentItem.fromJson(Map<String, dynamic> json) => RecentItem(
    id: json['id'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String?,
    type: RecentItemType.values.byName(json['type'] as String),
    lastPlayed: DateTime.parse(json['lastPlayed'] as String),
  );
}
