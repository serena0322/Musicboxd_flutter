import 'Artist.dart';
import 'Album.dart';

class Track {
  final int id;
  final String title;
  final Artist artist;
  final Album album;
  final int duration;
  final String? preview;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.preview,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'],
      title: json['title'],
      artist: Artist.fromJson(json['artist']),
      album: Album.fromJson(json['album']),
      duration: json['duration'],
      preview: json['preview'],
    );
  }
}
