import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../Classes/Album.dart';
import '../Classes/Track.dart';

// --- SEARCH ---
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
      // evita crash per un item malformato
      // ignore: avoid_print
      print('Skip item malformato: $err\n$st');
    }
  }
  return tracks;
}

// --- TRACK DETAIL ---
Future<Track> getTrackById(dynamic id, {Duration timeout = const Duration(seconds: 12)}) async {
  final String trackId = id.toString().trim();
  if (trackId.isEmpty) {
    throw ArgumentError('trackId vuoto');
  }

  final uri = Uri.https('api.deezer.com', '/track/$trackId');

  try {
    final res = await http.get(uri).timeout(timeout);

    if (res.statusCode != 200) {
      // Deezer ritorna 200 su success; su errore spesso 404/400 con JSON descrittivo
      throw HttpException('Deezer $trackId -> ${res.statusCode}: ${res.body}');
    }

    final map = json.decode(res.body) as Map<String, dynamic>;
    // Alcune risposte errore di Deezer arrivano come { "error": {...} } ma con 200 quasi mai sui /track
    if (map.containsKey('error')) {
      throw HttpException('Deezer error for $trackId: ${map['error']}');
    }

    return Track.fromJson(map);
  } on TimeoutException {
    throw TimeoutException('Timeout chiamando Deezer per track $trackId');
  } on SocketException catch (e) {
    throw SocketException('Rete non disponibile (track $trackId): ${e.message}');
  }
}

// --- ALBUM DETAIL ---
Future<Album> getAlbumDetails(int albumId) async {
  final uri = Uri.https('api.deezer.com', '/album/$albumId');

  final res = await http.get(uri).timeout(const Duration(seconds: 12));
  if (res.statusCode != 200) {
    throw Exception('Album ${res.statusCode}: ${res.body}');
  }

  final decoded = json.decode(res.body);
  return Album.fromJson(decoded as Map<String, dynamic>);
}

// --- GLOBAL CHARTS ---
Future<List<Track>> globalCharts() async {
  final uri = Uri.https('api.deezer.com', '/chart');

  final res = await http.get(uri).timeout(const Duration(seconds: 12));
  if (res.statusCode != 200) {
    throw Exception('Chart ${res.statusCode}: ${res.body}');
  }

  final decoded = json.decode(res.body);

  final tracksJson = (decoded is Map && decoded['tracks'] is Map)
      ? (decoded['tracks']['data'] as List? ?? [])
      : const [];

  final tracks = <Track>[];
  for (final e in tracksJson) {
    try {
      tracks.add(Track.fromJson((e as Map).cast<String, dynamic>()));
    } catch (err, st) {
      // ignore: avoid_print
      print('Skip chart item malformato: $err\n$st');
    }
  }
  return tracks;
}
