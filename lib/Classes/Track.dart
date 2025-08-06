// Track.dart
import 'Artist.dart';
import 'Album.dart';

class Track {
  final int id;
  final String title;
  final Artist artist;
  final Album album;
  final int? duration;
  final String? preview;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.duration,
    this.preview,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      artist: Artist.fromJson((json['artist'] ?? const {}) as Map<String, dynamic>),
      album:  Album.fromJson((json['album']  ?? const {}) as Map<String, dynamic>),
      duration: (json['duration'] as num?)?.toInt(),
      preview: (json['preview'])?.toString(),
    );
  }
}
