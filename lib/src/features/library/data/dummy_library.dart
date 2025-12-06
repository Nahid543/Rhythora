import '../domain/entities/song.dart';

const demoAssetPath = 'assets/audio/demo.mp3';

const dummySongs = <Song>[
  Song(
    id: '1',
    title: 'Midnight Skyline',
    artist: 'Rhythora',
    duration: Duration(minutes: 3, seconds: 42),
    album: 'City Echoes',
    audioAsset: demoAssetPath,
  ),
  Song(
    id: '2',
    title: 'Neon Raindrops',
    artist: 'Chrome Dreams',
    duration: Duration(minutes: 4, seconds: 5),
    album: 'Afterhours',
    audioAsset: demoAssetPath,
  ),
  Song(
    id: '3',
    title: 'Daylight Drift',
    artist: 'Solar Tide',
    duration: Duration(minutes: 2, seconds: 58),
    album: 'Waves & Windows',
    audioAsset: demoAssetPath,
  ),
];