class Track {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverUrl,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'],
      title: json['title'],
      artist: json['artist']['name'],
      album: json['album']['title'],
      coverUrl: json['album']['cover_medium'],
    );
  }
}
