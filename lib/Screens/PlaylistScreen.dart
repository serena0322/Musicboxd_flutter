import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'ShowSongPlaylist.dart';

// Palette coerente
const kBg     = Color(0xFF0E0F12);
const kCard   = Color(0xFF151821);
const kBorder = Color(0x22FFFFFF);
const kGradA  = Color(0xFFB5179E);
const kGradB  = Color(0xFF00E5FF);

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  // Stream realtime delle playlist (ordinamento lato client)
  Stream<List<Map<String, dynamic>>> _playlistsStream() {
    if (_uid.isEmpty) return const Stream.empty();
    return _db
        .collection('User').doc(_uid)
        .collection('Playlists')
        .snapshots()
        .map((qs) {
      final list = qs.docs.map((d) {
        final data  = d.data();
        final name  = (data['name'] is String) ? data['name'] as String : '(Senza nome)';
        final tc    = (data['trackCount'] is num) ? (data['trackCount'] as num).toInt() : 0;
        final cover = (data['cover'] is String) ? data['cover'] as String : '';

        final tracksArr = (data['tracks'] is List) ? (data['tracks'] as List) : const <dynamic>[];
        final tracksLen = tracksArr.length;

        final updatedAtMs = (data['updatedAt'] is Timestamp)
            ? (data['updatedAt'] as Timestamp).millisecondsSinceEpoch
            : 0;

        // >>> fallback intelligente: prima la lunghezza reale dell’array, poi il campo contatore
        final fallbackCount = (tracksLen > 0) ? tracksLen : (tc > 0 ? tc : 0);

        return {
          'id': d.id,
          'name': name,
          'cover': cover,
          '_ms': updatedAtMs,
          'fallbackCount': fallbackCount,   // <— passa solo questo
        };
      }).toList();

      list.sort((a, b) => (b['_ms'] as int).compareTo(a['_ms'] as int));
      return list;
    });
  }

  // Creazione playlist (bottom sheet)
  Future<void> _createPlaylistSheet() async {
    if (_uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devi essere autenticata per creare playlist.')),
      );
      return;
    }
    final TextEditingController nameCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                const Text('Nuova playlist',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 46,
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
                        hintText: 'Nome playlist…',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [kGradA, kGradB]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          final ref = _db.collection('User').doc(_uid).collection('Playlists').doc();
                          await ref.set({
                            'name': name,
                            'createdAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                            'trackCount': 0,
                            'tracks': <String>[],
                            'cover': '',
                          });
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Playlist "$name" creata'), backgroundColor: Colors.green),
                          );
                        },
                        child: const Text('Crea', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Conferma ed eliminazione (long-press)
  void _confirmDeletePlaylist({required String playlistId, required String name}) {
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
                const Text('Elimina playlist',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 8),
                Text('Sei sicura di voler eliminare "$name"?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
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
                            await _deletePlaylist(playlistId, name);
                          },
                          child: const Text('Elimina', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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

  Future<void> _deletePlaylist(String playlistId, String name) async {
    if (_uid.isEmpty) return;
    final playlistRef = _db.collection('User').doc(_uid).collection('Playlists').doc(playlistId);

    try {
      // Elimina Items a batch
      const int batchSize = 400;
      while (true) {
        final qs = await playlistRef.collection('Items').limit(batchSize).get();
        if (qs.docs.isEmpty) break;
        final batch = _db.batch();
        for (final doc in qs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      // Elimina la playlist
      await playlistRef.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playlist "$name" eliminata'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l’eliminazione: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        centerTitle: true,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [kGradA, kGradB],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0.0, 0.7],
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: const Text(
            'Playlist',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 0.2),
          ),
        ),
      ),

      body: _uid.isEmpty
          ? const Center(
        child: Text('Nessun utente autenticato', style: TextStyle(color: Colors.white70)),
      )
          : Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _playlistsStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }
                  final list = snap.data ?? const <Map<String, dynamic>>[];
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Nessuna playlist disponibile.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 12),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [kGradA, kGradB]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                ),
                                onPressed: _createPlaylistSheet,
                                icon: const Icon(Icons.add_rounded, color: Colors.white),
                                label: const Text('Crea playlist',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p       = list[i];
                      final id      = p['id'] as String;
                      final name    = p['name'] as String;
                      final cover   = (p['cover'] as String?) ?? '';
                      final fbCount = (p['fallbackCount'] as int?) ?? 0;


                      return _PlaylistTile(
                        uid: _uid,
                        playlistId: id,
                        name: name,
                        cover: cover,
                        fallbackCount: fbCount,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(playlistId: id /*, userId: opzionale */),
                            ),
                          );
                        },
                        onLongPress: () => _confirmDeletePlaylist(playlistId: id, name: name),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPlaylistSheet,
        backgroundColor: kCard,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuova'),
      ),
    );
  }
}

// --- Tile playlist con conteggio brani realtime (Items), accento/gradiente e long-press delete ---
class _PlaylistTile extends StatelessWidget {
  final String uid;
  final String playlistId;
  final String name;
  final String cover;
  final int fallbackCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PlaylistTile({
    required this.uid,
    required this.playlistId,
    required this.name,
    required this.cover,
    required this.fallbackCount,
    required this.onTap,
    this.onLongPress,
  });

  Stream<int> _itemsCountStream() {
    final col = FirebaseFirestore.instance
        .collection('User').doc(uid)
        .collection('Playlists').doc(playlistId)
        .collection('Items');
    // Conteggio live (qs.size) — aggiornato su aggiunta/rimozione
    return col.snapshots().map((qs) => qs.size);
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
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Barra accent a sinistra
              Container(
                width: 4,
                height: 52,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                  gradient: LinearGradient(
                      colors: [kGradA, kGradB],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
              ),
              const SizedBox(width: 10),

              // Cover (o placeholder)
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                  image: cover.isNotEmpty
                      ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover)
                      : null,
                  color: cover.isEmpty ? const Color(0xFF2A2A2A) : null,
                ),
                child: cover.isEmpty
                    ? const Icon(Icons.queue_music_rounded, color: Colors.white54)
                    : null,
              ),

              const SizedBox(width: 12),

              // Testi + conteggio live
              Expanded(
                child: StreamBuilder<int>(
                  stream: _itemsCountStream(),
                  builder: (context, snap) {
                    // conteggio da Items (può essere 0 se non esiste/è vuota)
                    final itemsCount = snap.data ?? 0;

                    // fallback passato dal padre (calcolato sul documento playlist)
                    final fb = fallbackCount;

                    // priorità: Items > 0 ? Items : fallback
                    final count = (itemsCount > 0) ? itemsCount : (fb > 0 ? fb : 0);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text('$count brani',
                            style: const TextStyle(color: Colors.white60, fontSize: 13.5)),
                      ],
                    );
                  },
                ),
              ),

              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
