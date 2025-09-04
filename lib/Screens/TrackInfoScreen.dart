import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Classes/Track.dart';
import '../services/deezer_service.dart';

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

  @override
  void initState() {
    super.initState();
    print("User ID ricevuto: ${widget.userId}");
    _fetchAlbumDetails();
    _fetchHistogramAndRating();
  }


  Future<void> _fetchAlbumDetails() async {
    final albumId = widget.track.album.id;
    if (albumId == null) return;
    try {
      final album = await getAlbumDetails(albumId);
      setState(() {
        releaseDate = _formatDate(album.releaseDate);
        genre = album.genres.isNotEmpty ? album.genres.first : "N/A";
      });
    } catch (_) {
      // gestione errore
    }
  }

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
    final converted = histogram.map((key, value) => MapEntry(key, (value as num).toInt()));

    // Riempie con zeri anche le chiavi mancanti
    final completeHistogram = _generateEmptyHistogram();
    converted.forEach((key, value) {
      completeHistogram[key] = value;
    });

    setState(() {
      averageRating = count > 0 ? sum / count : null;
      ratingsHistogram = completeHistogram;
      histogramLoaded = true;
    });
  }

  Map<String, int> _generateEmptyHistogram() {
    return Map.fromIterable(
      List.generate(10, (i) => (0.5 + 0.5 * i).toStringAsFixed(1)),
      key: (k) => k,
      value: (_) => 0,
    );
  }

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

  Future<List<Map<String, dynamic>>> _getUserPlaylists() async {
    final snapshot = await _firestore
        .collection('User')
        .doc(widget.userId)
        .collection('Playlists')
        .get();

    return snapshot.docs.map((doc) => {
      'id': doc.id,
      'name': doc['name'],
    }).toList();
  }

  Future<void> _addTrackToPlaylist(String playlistId) async {
    final playlistRef = _firestore
        .collection('User')
        .doc(widget.userId)
        .collection('Playlists')
        .doc(playlistId);

    await playlistRef.update({
      'tracks': FieldValue.arrayUnion([widget.track.id])
    });
  }

  void _addToPlaylist() async {
    try {
      final playlists = await _getUserPlaylists();

      if (playlists.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Nessuna playlist trovata."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) =>
            AlertDialog(
              backgroundColor: Colors.black87,
              title: const Text("Seleziona una playlist",
                  style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (ctx, index) {
                    final playlist = playlists[index];
                    return ListTile(
                      title: Text(playlist['name'],
                          style: const TextStyle(color: Colors.white)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _addTrackToPlaylist(playlist['id']);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Brano aggiunto alla playlist"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
      );
    } catch (e) {
      debugPrint("Errore nel recupero playlist: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Errore durante l'aggiunta alla playlist"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildHistogramBar(String key, double maxValue) {
    final count = ratingsHistogram[key]?.toDouble() ?? 0.0;

    // Altezza minima visiva come in Kotlin
    const double minVisibleHeight = 6.0;
    // Normalizza come se ci fossero almeno 5 voti
    final double normalizedMax = maxValue < 5 ? 5.0 : maxValue;

    // Kotlin: ((sqrt(count) / sqrt(normalizedMax)) * 72).coerceAtLeast(minVisibleHeight)
    final double targetHeight = count == 0
        ? minVisibleHeight
        : (sqrt(count) / sqrt(normalizedMax)) * 72.0;

    final double clampedHeight =
    targetHeight < minVisibleHeight ? minVisibleHeight : targetHeight;

    return SizedBox(
      height: 72, // altezza massima fissa
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 10,
          height: clampedHeight,
          decoration: BoxDecoration(
            color: Colors.greenAccent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final t = widget.track;

    return Scaffold(
      backgroundColor: const Color(0xFF303C4A),
      appBar: AppBar(
        title: const Text("Dettagli Brano"),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(
                  widget.coverUrl,
                  width: 147,
                  height: 147,
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'PoppinsBold')),
                      const SizedBox(height: 7),
                      Text(t.artist.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              fontFamily: 'PoppinsMedium')),
                      const SizedBox(height: 7),
                      Text("Album: ${t.album.title}",
                          style: const TextStyle(
                              color: Color(0xFFCCCCCC),
                              fontSize: 14,
                              fontFamily: 'PoppinsRegular')),
                      const SizedBox(height: 7),
                      Text("Data uscita: $releaseDate",
                          style: const TextStyle(
                              color: Color(0xFFCCCCCC),
                              fontSize: 14,
                              fontFamily: 'PoppinsRegular')),
                      const SizedBox(height: 7),
                      Text("Genere: $genre",
                          style: const TextStyle(
                              color: Color(0xFFCCCCCC),
                              fontSize: 14,
                              fontFamily: 'PoppinsRegular')),
                      const SizedBox(height: 7),
                      Text("Durata: ${_formatDuration(t.duration)}",
                          style: const TextStyle(
                              color: Color(0xFFCCCCCC),
                              fontSize: 14,
                              fontFamily: 'PoppinsRegular')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                TextButton(
                  onPressed: () {
                    // TODO: aggiungi logica riproduzione anteprima
                  },
                  child: const Text("Riproduci Anteprima",
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF11F54E),
                          fontFamily: 'PoppinsMedium',
                          letterSpacing: 0.02)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _addToPlaylist,
                  child: const Text("Aggiungi alla Playlist",
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF11F54E),
                          fontFamily: 'PoppinsMedium',
                          letterSpacing: 0.02)),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text("RATINGS",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'PoppinsBold',
                    letterSpacing: 0.05)),
            const SizedBox(height: 12),

            if (histogramLoaded)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("★",
                      style: TextStyle(
                          color: Colors.greenAccent, fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(10, (i) {
                        final label = (0.5 + 0.5 * i).toStringAsFixed(1);
                        final maxVal = ratingsHistogram.values
                            .map((e) => e.toDouble())
                            .fold<double>(1.0, (a, b) => a > b ? a : b);
                        return _buildHistogramBar(label, maxVal);
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      // Mostra la media anche se è 0.0 oppure null
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          // Se `averageRating` è null o 0, mostra “0.0”
                          (averageRating ?? 0.0).toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Text("★★★★★",
                          style: TextStyle(color: Colors.greenAccent, fontSize: 14)),
                    ],
                  ),
                ],
              )
            else
              const Center(
                  child: CircularProgressIndicator(
                      color: Colors.greenAccent)),

            const SizedBox(height: 24),
            const Text(
              "Lyrics",
              style: TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 14,
                fontFamily: 'PoppinsRegular',
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
