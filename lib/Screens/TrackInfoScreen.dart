import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Classes/Track.dart';
import '../services/deezer_service.dart';

class TrackInfoScreen extends StatefulWidget {
  final Track track;
  final String coverUrl;

  const TrackInfoScreen({Key? key, required this.track, required this.coverUrl}) : super(key: key);

  @override
  State<TrackInfoScreen> createState() => _TrackInfoScreenState();
}

class _TrackInfoScreenState extends State<TrackInfoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  String genre = "N/A";
  String releaseDate = "N/A";
  double? averageRating;
  Map<String, int> ratingsHistogram = {};
  bool histogramLoaded = false;

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
      setState(() {
        releaseDate = _formatDate(album.releaseDate);
        genre = (album.genres.isNotEmpty) ? album.genres.first : "N/A";
      });
    } catch (e) {
      debugPrint('Errore caricamento album: $e');
    }
  }

  Future<void> _fetchHistogramAndRating() async {
    final doc = await _firestore.collection('Songs').doc('track_${widget.track.id}').get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final sum = (data['totalRatingSum'] ?? 0.0).toDouble();
    final count = (data['totalRatings'] ?? 0).toInt();
    final histogram = Map<String, dynamic>.from(data['ratingsHistogram'] ?? {});
    final converted = histogram.map((key, value) => MapEntry(key, (value as num).toInt()));

    setState(() {
      averageRating = count > 0 ? sum / count : null;
      ratingsHistogram = converted;
      histogramLoaded = true;
    });
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

  void _togglePlayback() async {
    if (!isPlaying && widget.track.preview != null) {
      await _audioPlayer.play(UrlSource(widget.track.preview!));
      setState(() => isPlaying = true);
      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() => isPlaying = false);
      });
    } else {
      await _audioPlayer.stop();
      setState(() => isPlaying = false);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildHistogramBar(String key, double maxValue) {
    final count = ratingsHistogram[key]?.toDouble() ?? 0;
    final height = max(6.0, sqrt(count) / sqrt(maxValue) * 72.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 10,
      height: height,
      decoration: BoxDecoration(
        color: Colors.greenAccent,
        borderRadius: BorderRadius.circular(4),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // INFO BASE
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
                      Text(t.title ?? 'Titolo', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(t.artist.name ?? 'Artista', style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 6),
                      Text("Album: ${t.album.title ?? 'N/A'}", style: const TextStyle(color: Colors.grey)),
                      Text("Data uscita: $releaseDate", style: const TextStyle(color: Colors.grey)),
                      Text("Genere: $genre", style: const TextStyle(color: Colors.grey)),
                      Text("Durata: ${_formatDuration(t.duration)}", style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),

            // PULSANTI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _togglePlayback,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
                  child: Text(isPlaying ? "⏸ Stop" : "▶️ Anteprima", style: const TextStyle(color: Colors.greenAccent)),
                ),
                ElevatedButton(
                  onPressed: () {
                    // TO DO: aggiunta a playlist
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
                  child: const Text("➕ Playlist", style: TextStyle(color: Colors.greenAccent)),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ISTOGRAMMA
            const Text("RATINGS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text("★", style: TextStyle(color: Colors.greenAccent, fontSize: 18)),
                const SizedBox(width: 4),
                Text(averageRating?.toStringAsFixed(1) ?? "-", style: const TextStyle(color: Colors.white, fontSize: 18)),
                const Spacer(),
                const Text("★★★★★", style: TextStyle(color: Colors.greenAccent)),
              ],
            ),
            const SizedBox(height: 12),
            if (histogramLoaded)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(10, (i) {
                  final label = (0.5 + 0.5 * i).toStringAsFixed(1);
                  final maxVal = ratingsHistogram.values
                      .map((e) => e.toDouble())
                      .fold<double>(1.0, (a, b) => a > b ? a : b);
                  return Expanded(child: _buildHistogramBar(label, maxVal));
                }),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),

            const SizedBox(height: 24),
            const Text("Lyrics", style: TextStyle(color: Colors.white70)),
            const Text(
              "Testo non disponibile in questa versione.",
              style: TextStyle(color: Colors.white54, height: 1.4),
            )
          ],
        ),
      ),
    );
  }
}
