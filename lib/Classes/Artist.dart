// Artist.dart
class Artist {
  final int id;                 // <-- int, non String
  final String name;
  final String genre;           // Deezer non lo fornisce: tienilo vuoto
  final int? yearStarted;       // Deezer non lo fornisce
  final String bio;             // Deezer non lo fornisce
  final String? imageUrl;       // Deezer: picture / picture_*

  Artist({
    required this.id,
    required this.name,
    required this.genre,
    this.yearStarted,
    required this.bio,
    this.imageUrl,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: (json['id'] as num?)?.toInt() ?? 0,       // <-- cast sicuro a int
      name: (json['name'] ?? '').toString(),
      genre: (json['genre'] ?? '').toString(),      // non presente in Deezer → ""
      yearStarted: (json['yearStarted'] as num?)?.toInt(),
      bio: (json['bio'] ?? '').toString(),          // non presente in Deezer → ""
      imageUrl: (json['imageUrl'] ??
          json['picture'] ??
          json['picture_medium'] ??
          json['picture_small'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'genre': genre,
      'yearStarted': yearStarted,
      'bio': bio,
      'imageUrl': imageUrl,
    };
  }
}
