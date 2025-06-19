import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Classes/PlaylistItem.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  _PlaylistScreenState createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late final String userId;
  List<PlaylistItem> playlists = [];

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null) {
      userId = user.uid;
      _listenPlaylists();
    } else {
      userId = '';
      // Gestisci utente non autenticato se necessario
    }
  }

  void _listenPlaylists() {
    _db
        .collection('User')
        .doc(userId)
        .collection('Playlists')
        .snapshots()
        .listen((snapshot) {
      final loadedPlaylists = snapshot.docs
          .map((doc) => PlaylistItem.fromMap(doc.data(), doc.id))
          .toList();

      setState(() {
        playlists = loadedPlaylists;
      });
    });
  }

  Future<void> _createPlaylist() async {
    final TextEditingController controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuova Playlist'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Inserisci il nome della playlist'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nome non valido')),
                );
                return;
              }
              Navigator.of(context).pop(name);
            },
            child: const Text('Crea'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _db.collection('User').doc(userId).collection('Playlists').add({
          'name': result,
          'createdBy': userId,
          'timestamp': FieldValue.serverTimestamp(),
          'tracks': <String>[],
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist creata')),
        );
      } catch (e) {
        debugPrint('Errore nella creazione playlist: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nella creazione')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Playlist',
          style: TextStyle(fontFamily: 'PoppinsBold', fontWeight: FontWeight.bold, fontSize: 30),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          TextButton(
            onPressed: _createPlaylist,
            child: const Text(
              'Create New Playlist',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              color: Colors.grey.shade900, // simile a scrollView background
              child: playlists.isEmpty
                  ? const Center(
                child: Text(
                  'Nessuna playlist disponibile',
                  style: TextStyle(color: Colors.white70),
                ),
              )
                  : ListView.builder(
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return ListTile(
                    title: Text(
                      playlist.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    // puoi aggiungere onTap o altre funzionalità
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}


