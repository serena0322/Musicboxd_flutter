import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
      // ignore: avoid_print
      print('Skip item malformato: $err\n$st');
    }
  }
  return tracks;
}

Future<Track> getTrackById(dynamic id, {Duration timeout = const Duration(seconds: 12)}) async {
  final String trackId = id.toString().trim();
  if (trackId.isEmpty) {
    throw ArgumentError('trackId vuoto');
  }

  final uri = Uri.https('api.deezer.com', '/track/$trackId');

  try {
    final res = await http.get(uri).timeout(timeout);

    if (res.statusCode != 200) {
      throw HttpException('Deezer $trackId -> ${res.statusCode}: ${res.body}');
    }

    final map = json.decode(res.body) as Map<String, dynamic>;
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

Future<Album> getAlbumDetails(int albumId) async {
  final uri = Uri.https('api.deezer.com', '/album/$albumId');

  final res = await http.get(uri).timeout(const Duration(seconds: 12));
  if (res.statusCode != 200) {
    throw Exception('Album ${res.statusCode}: ${res.body}');
  }

  final decoded = json.decode(res.body);
  return Album.fromJson(decoded as Map<String, dynamic>);
}

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

const _host = 'api.deezer.com';
const Duration _timeout = Duration(seconds: 12);

class _AlbumMeta {
  final DateTime? release;
  final List<String> genres;
  const _AlbumMeta(this.release, this.genres);
}

final Map<int, _AlbumMeta> _albumMetaCache = {};

DateTime? _parseYMD(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    final p = s.split('-').map(int.parse).toList(); // yyyy-mm-dd
    return DateTime.utc(p[0], p[1], p[2]);
  } catch (_) {
    return null;
  }
}

Future<_AlbumMeta> _albumMeta(int? albumId) async {
  if (albumId == null) return const _AlbumMeta(null, []);
  final cached = _albumMetaCache[albumId];
  if (cached != null) return cached;

  final a = await getAlbumDetails(albumId);
  final meta = _AlbumMeta(
    _parseYMD(a.releaseDate),
    a.genres.map((e) => e.toLowerCase()).toList(),
  );
  _albumMetaCache[albumId] = meta;
  return meta;
}

DateTime _sinceWeeks(int weeks) {
  final now = DateTime.now().toUtc();
  return now.subtract(Duration(days: 7 * weeks));
}

bool _titleContainsAny(String title, List<String> words) {
  final t = title.toLowerCase();
  return words.any((w) => t.contains(w.toLowerCase()));
}

final Map<String, int> _genreNameToId = {};

Future<void> _ensureGenresLoaded() async {
  if (_genreNameToId.isNotEmpty) return;
  final uri = Uri.https(_host, '/genre');
  final res = await http.get(uri).timeout(_timeout);
  if (res.statusCode != 200) {
    throw HttpException('GET /genre -> ${res.statusCode}');
  }
  final map = json.decode(res.body);
  final data = (map is Map && map['data'] is List) ? map['data'] as List : const [];
  for (final g in data) {
    final m = (g as Map).cast<String, dynamic>();
    final id = (m['id'] as num?)?.toInt();
    final name = (m['name'] as String?)?.toLowerCase().trim();
    if (id != null && name != null && name.isNotEmpty) {
      _genreNameToId[name] = id;
    }
  }
}

Future<int?> _resolveGenreId(String name) async {
  await _ensureGenresLoaded();
  final n = name.toLowerCase().trim();

  if (_genreNameToId.containsKey(n)) return _genreNameToId[n];

  const synonyms = {
    'hip hop': ['hip-hop', 'rap', 'hip hop/rap'],
    'electronic': ['electro', 'edm'],
    'r&b': ['rnb', 'soul', 'r&b/soul'],
    'indie': ['alternative', 'indie pop', 'indie rock'],
    'dance': ['electronic dance', 'edm'],
  };

  if (synonyms.containsKey(n)) {
    for (final alt in synonyms[n]!) {
      final k = _genreNameToId.keys.firstWhere(
            (g) => g.contains(alt),
        orElse: () => '',
      );
      if (k.isNotEmpty) return _genreNameToId[k];
    }
  }

  final k = _genreNameToId.keys.firstWhere(
        (g) => g.contains(n) || n.contains(g),
    orElse: () => '',
  );
  if (k.isNotEmpty) return _genreNameToId[k];
  return null;
}

Future<List<Track>> _fetchGenreChart(int genreId, {int limit = 100}) async {
  final uri = Uri.https(_host, '/chart/$genreId/tracks', {'limit': '$limit'});
  final res = await http.get(uri).timeout(_timeout);
  if (res.statusCode != 200) {
    throw HttpException('GET /chart/$genreId/tracks -> ${res.statusCode}');
  }
  final map = json.decode(res.body);
  final list = (map is Map && map['data'] is List) ? map['data'] as List : const [];
  return list.map((e) => Track.fromJson((e as Map).cast<String, dynamic>())).toList();
}


Future<List<Track>> _filterRecentBatch(
    List<Track> seed, {
      required DateTime since,
      List<String> excludeWordsInTitle = const [],
      int take = 40,
      int batchSize = 8,
      int maxAlbumLookups = 80,
    }) async {
  final out = <Track>[];
  final seen = <int>{};
  int checked = 0;

  int i = 0;
  while (i < seed.length && out.length < take && checked < maxAlbumLookups) {
    final batch = <Future<Track?>>[];
    for (var j = 0; j < batchSize && i < seed.length && checked < maxAlbumLookups; j++, i++) {
      final t = seed[i];
      final id = t.id;
      if (id == null || seen.contains(id)) continue;
      if (_titleContainsAny(t.title, excludeWordsInTitle)) continue;

      seen.add(id);
      batch.add(() async {
        checked++;
        final meta = await _albumMeta(t.album.id);
        if (meta.release != null && meta.release!.isBefore(since)) return null;
        return t;
      }());
    }

    final results = await Future.wait(batch, eagerError: false);
    for (final r in results) {
      if (r != null) {
        out.add(r);
        if (out.length >= take) break;
      }
    }
  }

  return out;
}

Future<List<Track>> genreTopRecentTracks(
    String genreName, {
      int weeksBack = 3,
      int limit = 40,
      List<String> excludeWordsInTitle = const [],
    }) async {
  final gid = await _resolveGenreId(genreName);
  if (gid == null) return [];

  final seed = await _fetchGenreChart(gid, limit: limit * 2);

  final since = _sinceWeeks(weeksBack);
  var filtered = await _filterRecentBatch(
    seed,
    since: since,
    take: limit,
    excludeWordsInTitle: excludeWordsInTitle,
  );

  if (filtered.length < (limit / 3).round()) {
    final relaxed = _sinceWeeks(6);
    filtered = await _filterRecentBatch(
      seed,
      since: relaxed,
      take: limit,
      excludeWordsInTitle: excludeWordsInTitle,
    );
  }

  return filtered;
}


int _editorialIdForIso(String iso) {
  const map = {
    'IT': 110,
    'US': 2,
    'FR': 16,
    'DE': 7,
    'GB': 6,
  };
  return map[iso.toUpperCase()] ?? 0;
}

Future<List<Track>> _fetchEditorialCharts(int editorialId, {int limit = 100}) async {
  final uri = editorialId == 0
      ? Uri.https(_host, '/chart', {'limit': '$limit'})
      : Uri.https(_host, '/editorial/$editorialId/charts', {'limit': '$limit'});

  final res = await http.get(uri).timeout(_timeout);
  if (res.statusCode != 200) {
    throw HttpException('GET ${uri.path} -> ${res.statusCode}');
  }

  final map = json.decode(res.body);
  final list = (map is Map && map['tracks'] is Map)
      ? (map['tracks']['data'] as List? ?? const [])
      : const [];

  return list.map((e) => Track.fromJson((e as Map).cast<String, dynamic>())).toList();
}

Future<List<Track>> countryCharts(
    String iso, {
      int limit = 50,
      int weeksBack = 3,
    }) async {
  final editorialId = _editorialIdForIso(iso);

  List<Track> seed;
  try {
    seed = await _fetchEditorialCharts(editorialId, limit: limit * 2);
  } catch (_) {
    seed = await globalCharts();
  }

  final since = _sinceWeeks(weeksBack);
  var filtered = await _filterRecentBatch(
    seed,
    since: since,
    take: limit,
    excludeWordsInTitle: const [],
    batchSize: 8,
    maxAlbumLookups: 80,
  );

  if (filtered.length < (limit / 3).round()) {
    filtered = await _filterRecentBatch(
      seed,
      since: _sinceWeeks(6),
      take: limit,
      excludeWordsInTitle: const [],
      batchSize: 8,
      maxAlbumLookups: 80,
    );
  }

  return filtered.isNotEmpty ? filtered : seed.take(limit).toList();
}



