import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/deezer_service.dart';
import '../Classes/Track.dart';


// ====== PALETTE COERENTE ======
const kBg     = Color(0xFF0E0F12);
const kCard   = Color(0xFF151821);
const kBorder = Color(0x22FFFFFF);
const kGradA  = Color(0xFFB5179E);
const kGradB  = Color(0xFF00E5FF);

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final String? userId; // opzionale; se null usa l’utente autenticato

  const PlaylistDetailScreen({
    Key? key,
    required this.playlistId,
    this.userId,
  }) : super(key: key);

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final _db = FirebaseFirestore.instance;

  String get _uid {
    final fromParam = (widget.userId ?? '').trim();
    if (fromParam.isNotEmpty) return fromParam;
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  DocumentReference<Map<String, dynamic>> get _playlistRef =>
      _db.collection('User').doc(_uid).collection('Playlists').doc(widget.playlistId);

  Stream<String> _nameStream() {
    if (_uid.isEmpty) return const Stream.empty();
    return _playlistRef.snapshots().map((s) => (s.data()?['name'] as String?) ?? 'Playlist');
  }

  Stream<List<_ItemVM>> _itemsStream() {
    if (_uid.isEmpty) return const Stream.empty();

    // Ascolta il documento per leggere l’array `tracks`
    return _playlistRef.snapshots().asyncExpand((docSnap) {
      if (!docSnap.exists) return Stream.value(const <_ItemVM>[]);

      final data = docSnap.data() as Map<String, dynamic>;
      final trackIds = (data['tracks'] as List?)
          ?.map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList() ?? const <String>[];

      // Ascolta anche la subcollection Items
      final items$ = _playlistRef
          .collection('Items')
          .orderBy('addedAt', descending: true)
          .snapshots();

      // Scegli dinamicamente la sorgente
      return items$.asyncMap((qs) async {
        if (qs.docs.isNotEmpty) {
          // Caso “nuovo”: abbiamo già gli Items
          return qs.docs.map((d) => _ItemVM.fromDoc(d)).toList();
        }

        // Fallback: non ci sono Items → carico da Deezer gli ID in `tracks`
        if (trackIds.isEmpty) return const <_ItemVM>[];

        final tracks = await _fetchTracksByIds(trackIds);
        return tracks.map((t) => _ItemVM.fromTrack(t)).toList();
      });
    });
  }

  Future<List<Track>> _fetchTracksByIds(List<String> ids, {int concurrency = 6}) async {
    if (ids.isEmpty) return const [];
    final out = List<Track?>.filled(ids.length, null, growable: false);

    for (int start = 0; start < ids.length; start += concurrency) {
      final end = (start + concurrency < ids.length) ? start + concurrency : ids.length;
      await Future.wait([
        for (int i = start; i < end; i++)
          getTrackById(ids[i]).then((t) => out[i] = t).catchError((_) {/* skip id fallito */}),
      ]);
    }

    return out.whereType<Track>().toList();
  }


  Future<void> _removeItem(_ItemVM item) async {
    if (_uid.isEmpty) return;
    final playlistRef = _playlistRef;
    final itemRef     = playlistRef.collection('Items').doc(item.trackId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(playlistRef);
      if (!snap.exists) throw Exception('Playlist non trovata.');
      final data = snap.data() as Map<String, dynamic>;

      // trackCount sicuro
      final currentCount = (data['trackCount'] is num) ? (data['trackCount'] as num).toInt() : 0;
      final newCount = (currentCount - 1) < 0 ? 0 : currentCount - 1;

      // rimuovi dall’array tracks se presente
      tx.update(playlistRef, {
        'trackCount': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
        'tracks': FieldValue.arrayRemove([item.trackId]),
      });

      // elimina l’item
      tx.delete(itemRef);
    });

    // Aggiorna la cover se abbiamo tolto proprio quella mostrata
    await _ensureCoverAfterDeletion();
  }

  Future<void> _ensureCoverAfterDeletion() async {
    // Se la playlist ha cover vuota o la cover faceva riferimento all’item appena rimosso,
    // scegli la cover del primo item rimasto, se esiste.
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_playlistRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final currentCover = (data['cover'] as String?) ?? '';

      // Se c’è già una cover valida, niente da fare
      if (currentCover.isNotEmpty) return;

      // Trova il primo item rimasto
      final itemsSnap = await _playlistRef
          .collection('Items')
          .orderBy('addedAt', descending: true)
          .limit(1)
          .get();

      if (itemsSnap.docs.isEmpty) {
        // Nessun item → cover vuota
        tx.update(_playlistRef, {'cover': ''});
      } else {
        final one = itemsSnap.docs.first.data();
        final newCover = (one['cover'] as String?) ?? '';
        tx.update(_playlistRef, {'cover': newCover});
      }
    });
  }

  void _confirmRemove(_ItemVM item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                const Text('Rimuovi brano',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 8),
                Text('Vuoi rimuovere "${item.title}" dalla playlist?',
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: kBorder),
                          backgroundColor: kCard,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annulla'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [kGradA, kGradB]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await _removeItem(item);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Brano rimosso'), backgroundColor: Colors.green),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          child: const Text('Rimuovi',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: Text('Nessun utente autenticato', style: TextStyle(color: Colors.white70))),
      );
    }

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        centerTitle: true,
        elevation: 0,
        title: StreamBuilder<String>(
          stream: _nameStream(),
          builder: (context, snap) {
            final name = snap.data ?? 'Playlist';
            return ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [kGradA, kGradB],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.7],
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Text(
                name,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 0.2),
              ),
            );
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: StreamBuilder<List<_ItemVM>>(
          stream: _itemsStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            final items = snap.data ?? const <_ItemVM>[];
            if (items.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Questa playlist è vuota.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final it = items[i];
                return _TrackTile(
                  item: it,
                  onTap: () {
                    // TODO: apri dettaglio brano, es. TrackInfoScreen con i dati dell’item
                    // Navigator.push(...);
                  },
                  onLongPress: () => _confirmRemove(it),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ====== VIEW MODEL ITEM ======
class _ItemVM {
  final String trackId;
  final String title;
  final String artist;
  final String cover;
  final int? durationSec;

  _ItemVM({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.cover,
    this.durationSec,
  });

  factory _ItemVM.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? const <String, dynamic>{};
    return _ItemVM(
      trackId: (data['trackId'] ?? d.id).toString(),
      title: (data['title'] as String?) ?? 'Senza titolo',
      artist: (data['artist'] as String?) ?? 'Sconosciuto',
      cover: (data['cover'] as String?) ?? '',
      durationSec: (data['duration'] is num) ? (data['duration'] as num).toInt() : null,
    );
  }

  factory _ItemVM.fromTrack(Track t) {
    return _ItemVM(
      trackId: t.id.toString(),
      title: t.title,
      artist: t.artist.name,
      cover: t.album.cover,
      durationSec: t.duration,
    );
  }

}

// ====== TILE UI ======
class _TrackTile extends StatelessWidget {
  final _ItemVM item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _TrackTile({
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  String _formatDuration(int? s) {
    if (s == null) return '';
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: item.cover,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(width: 52, height: 52, color: const Color(0xFF2A2A2A)),
                  errorWidget: (_, __, ___) =>
                      Container(width: 52, height: 52, color: const Color(0xFF2A2A2A),
                          child: const Icon(Icons.music_note, color: Colors.white54)),
                ),
              ),
              const SizedBox(width: 12),

              // Testi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text(item.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 13.5)),
                  ],
                ),
              ),

              // Durata + Chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatDuration(item.durationSec),
                      style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
