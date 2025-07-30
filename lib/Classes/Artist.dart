
class Artist {
  final String id;
  final String name;
  final String genre;
  final int? yearStarted;
  final String bio;
  final String? imageUrl;

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
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      genre: json['genre'] ?? '',
      yearStarted: json['yearStarted'],
      bio: json['bio'] ?? '',
      imageUrl: json['imageUrl'],
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
