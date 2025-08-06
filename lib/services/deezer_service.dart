// lib/services/deezer_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Classes/Album.dart';
import '../Classes/Track.dart';

Future<List<Track>> searchTracks(String query) async {
  final q = query.trim();
  if (q.isEmpty) return [];

  final uri = Uri.https('api.deezer.com', '/search', {'q': q});
  final res = await http.get(uri).timeout(const Duration(seconds: 12));

  if (res.statusCode != 200) {
    throw Exception('Deezer ${res.statusCode}: ${res.body}');
  }

  final decoded = json.decode(res.body);
  final list = (decoded is Map && decoded['data'] is List)
      ? decoded['data'] as List
      : const [];

  final tracks = <Track>[];
  for (final e in list) {
    try {
      tracks.add(Track.fromJson((e as Map).cast<String, dynamic>()));
    } catch (err, st) {
      // Evita di rompere tutta la ricerca per un item malformato
      // e lascia un log per capire quale campo manca
      // (usa debugPrint per non intasare la console in release)
      // ignore: avoid_print
      print('Skip item malformato: $err\n$st');
    }
  }
  return tracks;
}


Future<Album> getAlbumDetails(int albumId) async {
  final uri = Uri.https('api.deezer.com', '/album/$albumId');

  final res = await http.get(uri).timeout(const Duration(seconds: 12));
  if (res.statusCode != 200) {
    throw Exception('Album ${res.statusCode}: ${res.body}');
  }

  final decoded = json.decode(res.body);
  return Album.fromJson(decoded as Map<String, dynamic>);
}
