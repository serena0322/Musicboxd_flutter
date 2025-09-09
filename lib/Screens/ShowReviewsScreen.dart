import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../Classes/Review.dart';

/// PALETTE coerente
const kBg     = Color(0xFF0E0F12);
const kCard   = Color(0xFF151821);
const kBorder = Color(0x22FFFFFF);
const kGradA  = Color(0xFFB5179E);
const kGradB  = Color(0xFF00E5FF);

class ShowReviewsScreen extends StatefulWidget {
  const ShowReviewsScreen({Key? key}) : super(key: key);

  @override
  State<ShowReviewsScreen> createState() => _ShowReviewsScreenState();
}

class _ShowReviewsScreenState extends State<ShowReviewsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _formatDate(Timestamp ts) =>
      DateFormat('d MMM y, HH:mm', 'it_IT').format(ts.toDate());

  Stream<List<Review>> _myReviewsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('User').doc(uid)
        .collection('Reviews')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Review.fromFirestore(d)).toList());
  }

  Future<void> _deleteReview(Review review) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final reviewRef = _firestore
        .collection('User')
        .doc(user.uid)
        .collection('Reviews')
        .doc(review.documentId);

    // Recupero dati necessari dalla review (adatta i nomi dei campi al tuo model)
    final double rating = review.rating; // se nullable, gestisci default
    final String title  = review.songTitle; // oppure review.title
    final String artist = review.artistName; // oppure review.artist

    // Aggiorna aggregato in Songs (matching per titolo+artista come nel tuo codice)
    final songQuery = await _firestore
        .collection('Songs')
        .where('title', isEqualTo: title)
        .where('artist', isEqualTo: artist)
        .limit(1)
        .get();

    if (songQuery.docs.isNotEmpty) {
      final songRef = songQuery.docs.first.reference;
      final ratingKey = rating.toStringAsFixed(1);

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(songRef);
        final data = snap.data() as Map<String, dynamic>? ?? {};
        final totalSum = (data['totalRatingSum'] ?? 0.0).toDouble();
        final totalCount = (data['totalRatings'] ?? 0).toInt();

        tx.update(songRef, {
          'totalRatingSum': totalSum - rating,
          'totalRatings': (totalCount - 1) < 0 ? 0 : totalCount - 1,
          'ratingsHistogram.$ratingKey': FieldValue.increment(-1),
        });
      });
    }

    await reviewRef.delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recensione eliminata')),
    );
  }

  void _confirmDelete(Review r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              const Text('Eliminare recensione',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              const Text('Sei sicura di voler eliminare questa recensione?',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
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
                          await _deleteReview(r);
                        },
                        child: const Text('Elimina',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
            'Le tue recensioni',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 0.2),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: StreamBuilder<List<Review>>(
          stream: _myReviewsStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            final reviews = snap.data ?? const <Review>[];
            if (reviews.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Non hai ancora scritto recensioni.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder),
              itemBuilder: (context, i) {
                final r = reviews[i];

                // ADATTA questi accessi ai campi del tuo model Review, se diverso:
                final cover   = r.albumCoverUrl;   // oppure r.cover
                final title   = r.songTitle;       // oppure r.title
                final artist  = r.artistName;      // oppure r.artist
                final text    = r.reviewText;      // testo recensione
                final rating  = r.rating;          // double
                final ts      = r.timestamp;       // Timestamp Firestore

                return InkWell(
                  onLongPress: () => _confirmDelete(r),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: cover,
                            width: 48, height: 48, fit: BoxFit.cover,
                            placeholder: (_, __) => Container(width: 48, height: 48, color: const Color(0xFF2A2A2A)),
                            errorWidget: (_, __, ___) =>
                                Container(width: 48, height: 48, color: const Color(0xFF2A2A2A)),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Testi
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Riga titolo
                              Text(
                                '$title • $artist',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Riga autore+data (qui sei tu stessa)
                              Text(
                                _formatDate(ts),
                                style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                              ),
                              const SizedBox(height: 6),

                              // Testo recensione
                              if (text.isNotEmpty)
                                Text(
                                  text,
                                  maxLines: 3, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, height: 1.35),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Rating
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star, size: 18, color: Colors.amber),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
