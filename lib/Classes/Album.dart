
class Album {
  final int id;
  final String title;
  final String cover;
  final String? releaseDate;
  final List<String> genres;

  Album({
    required this.id,
    required this.title,
    required this.cover,
    this.releaseDate,
    required this.genres,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    final genresData = json['genres']?['data'] as List<dynamic>?;

    return Album(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      cover: json['cover'],
      releaseDate: json['release_date'],
      genres: genresData?.map((g) => g['name'].toString()).toList() ?? [],
    );
  }
}
