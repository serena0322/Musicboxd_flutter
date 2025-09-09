import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../Classes/Track.dart';
import '../services/deezer_service.dart';

// ====== PALETTE COERENTE ======
const kBg     = Color(0xFF0E0F12);
const kCard   = Color(0xFF151821);
const kBorder = Color(0x22FFFFFF);
const kGradA  = Color(0xFFB5179E);
const kGradB  = Color(0xFF00E5FF);

class TrackInfoScreen extends StatefulWidget {
  final Track track;
  final String coverUrl;
  final String userId;

  const TrackInfoScreen({
    Key? key,
    required this.track,
    required this.coverUrl,
    required this.userId,
  }) : super(key: key);

  @override
  State<TrackInfoScreen> createState() => _TrackInfoScreenState();
}

class _TrackInfoScreenState extends State<TrackInfoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double? averageRating;
  Map<String, int> ratingsHistogram = {};
  bool histogramLoaded = false;
  String genre = "N/A";
  String releaseDate = "N/A";

  // ===== UID centralizzato (evita mismatch) =====
  String get _uid {
    final p = widget.userId.trim();
    if (p.isNotEmpty) return p;
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  void initState() {
    super.initState();
    _fetchAlbumDetails();
    _fetchHistogramAndRating();
  }

  Future<void> _fetchAlbumDetails() async {
    final albumId = widget.track.album.id;
    if (albumId == null) return;
    try {
      final album = await getAlbumDetails(albumId);
      if (!mounted) return;
      setState(() {
        releaseDate = _formatDate(album.releaseDate);
        genre = album.genres.isNotEmpty ? album.genres.first : "N/A";
      });
    } catch (_) {}
  }

  // ===== Stream realtime delle playlist dell’utente =====
  Stream<List<Map<String, dynamic>>> _userPlaylistsStream() {
    if (_uid.isEmpty) {
      return const Stream<List<Map<String, dynamic>>>.empty();
    }
    final coll = _firestore.collection('User').doc(_uid).collection('Playlists');

    return coll.snapshots().map((qs) {
      final list = qs.docs.map((d) {
        final data = d.data();
        final name = (data['name'] is String) ? data['name'] as String : '(Senza nome)';
        final tcRaw = data['trackCount'];
        final trackCount = (tcRaw is num) ? tcRaw.toInt() : 0;
        final updatedAtMs = (data['updatedAt'] is Timestamp)
            ? (data['updatedAt'] as Timestamp).millisecondsSinceEpoch
            : 0;
        return {
          'id': d.id,
          'name': name,
          'trackCount': trackCount,
          '_updatedAtMs': updatedAtMs,
        };
      }).toList();

      // Ordina per updatedAt desc (i null in coda)
      list.sort((a, b) =>
          (b['_updatedAtMs'] as int).compareTo(a['_updatedAtMs'] as int));
      return list;
    });
  }

  // ===== Crea playlist =====
  Future<String> _createPlaylist(String name) async {
    if (_uid.isEmpty) throw Exception('Utente non autenticato.');
    final ref = _firestore.collection('User').doc(_uid).collection('Playlists').doc();
    await ref.set({
      'name': name.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'trackCount': 0,
      'tracks': <String>[],
      'cover': '',
    });
    return ref.id;
  }

  // ===== Aggiungi brano con transazione (anti-duplicati) =====
  Future<void> _addTrackToPlaylistTx(String playlistId) async {
    if (_uid.isEmpty) throw Exception('Utente non autenticato.');
    final trackId = widget.track.id.toString();
    final playlistRef =
    _firestore.collection('User').doc(_uid).collection('Playlists').doc(playlistId);
    final itemRef = playlistRef.collection('Items').doc(trackId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(playlistRef);
      if (!snap.exists) throw Exception('Playlist non trovata.');

      final data = snap.data() as Map<String, dynamic>;
      final current = List<String>.from(
        (data['tracks'] ?? const <String>[]).map((e) => e.toString()),
      );

      if (current.contains(trackId)) {
        tx.update(playlistRef, {'updatedAt': FieldValue.serverTimestamp()});
        return;
      }

      tx.update(playlistRef, {
        'tracks': FieldValue.arrayUnion([trackId]),
        'trackCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
        'cover': widget.track.album.cover,
      });

      tx.set(itemRef, {
        'trackId': trackId,
        'title': widget.track.title,
        'artist': widget.track.artist.name,
        'cover': widget.track.album.cover,
        'duration': widget.track.duration,
        'addedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ===== Bottom sheet: scegli playlist o creane una nuova =====
  void _openAddToPlaylistSheet() {
    if (_uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utente non autenticato')),
      );
      return;
    }
    if (widget.track.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID brano mancante')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final TextEditingController nameCtrl = TextEditingController();

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Aggiungi a playlist',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 12),

                // Crea nuova
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kBorder),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: nameCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Nuova playlist…',
                              hintStyle: TextStyle(color: Colors.white54),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          final newId = await _createPlaylist(name);
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          await _addTrackToPlaylistTx(newId);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Brano aggiunto a "$name"'),
                                backgroundColor: Colors.green),
                          );
                        },
                        child: const Text('Crea',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Elenco realtime
                Flexible(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _userPlaylistsStream(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }
                      final playlists = snap.data ?? const <Map<String, dynamic>>[];
                      if (playlists.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            'Non hai ancora playlist. Creane una nuova qui sopra.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: playlists.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder),
                        itemBuilder: (_, i) {
                          final p = playlists[i];
                          final count = (p['trackCount'] is num)
                              ? (p['trackCount'] as num).toInt()
                              : 0;
                          return ListTile(
                            onTap: () async {
                              Navigator.pop(ctx);
                              await _addTrackToPlaylistTx(p['id'] as String);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Aggiunto a "${p['name']}"'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            leading: const Icon(Icons.playlist_play_rounded, color: Colors.white70),
                            title: Text(
                              p['name'] as String,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text('$count brani',
                                style: const TextStyle(color: Colors.white54)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== Ratings / formattazioni =====

  Future<void> _fetchHistogramAndRating() async {
    final doc = await _firestore.collection('Songs').doc('${widget.track.id}').get();

    if (!doc.exists) {
      setState(() {
        averageRating = null;
        ratingsHistogram = _generateEmptyHistogram();
        histogramLoaded = true;
      });
      return;
    }

    final data = doc.data()!;
    final sum = (data['totalRatingSum'] ?? 0.0).toDouble();
    final count = (data['totalRatings'] ?? 0).toInt();
    final histogram = Map<String, dynamic>.from(data['ratingsHistogram'] ?? {});
    final converted = histogram.map((k, v) => MapEntry(k, (v as num).toInt()));

    final complete = _generateEmptyHistogram();
    converted.forEach((k, v) => complete[k] = v);

    setState(() {
      averageRating = count > 0 ? sum / count : null;
      ratingsHistogram = complete;
      histogramLoaded = true;
    });
  }

  Map<String, int> _generateEmptyHistogram() => Map.fromIterable(
    List.generate(10, (i) => (0.5 + 0.5 * i).toStringAsFixed(1)),
    key: (k) => k,
    value: (_) => 0,
  );

  String _formatDuration(int? seconds) {
    if (seconds == null) return "Durata sconosciuta";
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')} min';
  }

  String _formatDate(String? dateStr) {
    try {
      final date = DateFormat("yyyy-MM-dd").parse(dateStr ?? "");
      return DateFormat("d MMMM yyyy", "it_IT").format(date);
    } catch (_) {
      return "Data sconosciuta";
    }
  }

  Widget _buildHistogramBar(String key, double maxValue) {
    final count = ratingsHistogram[key]?.toDouble() ?? 0.0;
    const double minVisibleHeight = 6.0;
    final double normalizedMax = maxValue < 5 ? 5.0 : maxValue;
    final double target =
    count == 0 ? minVisibleHeight : (sqrt(count) / sqrt(normalizedMax)) * 72.0;
    final double h = target < minVisibleHeight ? minVisibleHeight : target;

    return SizedBox(
      height: 72,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 10,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kGradB, kGradA],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final maxCount = ratingsHistogram.values.isEmpty
        ? 1.0
        : ratingsHistogram.values.map((e) => e.toDouble()).fold<double>(
      1.0,
          (a, b) => a > b ? a : b,
    );

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        centerTitle: true,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (Rect bounds) => const LinearGradient(
            colors: [kGradA, kGradB],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0.0, 0.7],
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: const Text(
            "Dettagli brano",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 0.2),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card info brano
            Container(
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: widget.coverUrl,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(width: 120, height: 120, color: const Color(0xFF2A2A2A)),
                      errorWidget: (_, __, ___) =>
                          Container(width: 120, height: 120, color: const Color(0xFF2A2A2A)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 14.5),
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(icon: Icons.album_rounded, text: "Album: ${t.album.title}"),
                        _InfoRow(icon: Icons.event_rounded, text: "Uscita: $releaseDate"),
                        _InfoRow(icon: Icons.category_rounded, text: "Genere: $genre"),
                        _InfoRow(icon: Icons.schedule_rounded,
                            text: "Durata: ${_formatDuration(t.duration)}"),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Azioni
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: kBorder),
                      backgroundColor: kCard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      // TODO: logica riproduzione anteprima
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Anteprima'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: kBorder),
                      backgroundColor: kCard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _openAddToPlaylistSheet,
                    icon: const Icon(Icons.playlist_add_rounded),
                    label: const Text('Aggiungi a playlist'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Ratings
            const _SectionHeader(title: "Ratings"),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: histogramLoaded
                  ? Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(10, (i) {
                        final label = (0.5 + 0.5 * i).toStringAsFixed(1);
                        return _buildHistogramBar(label, maxCount);
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (averageRating ?? 0.0).toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text("su 5",
                          style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                    ],
                  ),
                ],
              )
                  : const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ====== WIDGET DI SUPPORTO ======

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              )),
          const SizedBox(height: 6),
          Container(height: 1, color: kBorder),
        ],
      ),
    );
  }
}
