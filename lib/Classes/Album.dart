class Album {
  final int id;
  final String title;
  final String cover;          // URL preferito (fallback se mancante)
  final String? releaseDate;   // "yyyy-MM-dd"
  final List<String> genres;   // può essere vuoto in search

  Album({
    required this.id,
    required this.title,
    required this.cover,
    this.releaseDate,
    required this.genres,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    // Deezer fornisce più chiavi per la cover: cover, cover_small, cover_medium, cover_big, cover_xl
    final coverUrl = (json['cover'] ??
        json['cover_medium'] ??
        json['cover_big'] ??
        json['cover_small'] ??
        json['cover_xl'])
        ?.toString() ?? '';

    // Nei dettagli album: { "genres": { "data": [ {"name": "..."} ] } }
    final List<String> genreNames = (() {
      final genresContainer = json['genres'];
      if (genresContainer is Map && genresContainer['data'] is List) {
        return (genresContainer['data'] as List)
            .whereType<Map>()
            .map((e) => (e['name'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return <String>[];
    })();

    return Album(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      cover: coverUrl,
      releaseDate: (json['release_date'])?.toString(),
      genres: genreNames,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'cover': cover,
    'release_date': releaseDate,
    'genres': genres,
  };
}
