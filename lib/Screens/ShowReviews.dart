import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Classes/Review.dart';

class ShowReviewsScreen extends StatefulWidget {
  const ShowReviewsScreen({Key? key}) : super(key: key);

  @override
  State<ShowReviewsScreen> createState() => _ShowReviewsScreenState();
}

class _ShowReviewsScreenState extends State<ShowReviewsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Review> _reviewList = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('User')
        .doc(user.uid)
        .collection('Reviews')
        .get();

    final reviews = snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
    setState(() {
      _reviewList = reviews..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  Future<void> _deleteReview(Review review) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final reviewRef = _firestore
        .collection('User')
        .doc(user.uid)
        .collection('Reviews')
        .doc(review.documentId);

    final snapshot = await reviewRef.get();
    if (!snapshot.exists) return;

    final rating = snapshot.get('rating')?.toDouble();
    final title = snapshot.get('title');
    final artist = snapshot.get('artist');

    if (rating == null || title == null || artist == null) return;

    final songQuery = await _firestore
        .collection('Songs')
        .where('title', isEqualTo: title)
        .where('artist', isEqualTo: artist)
        .limit(1)
        .get();

    if (songQuery.docs.isNotEmpty) {
      final songRef = songQuery.docs.first.reference;
      final ratingKey = rating.toStringAsFixed(1);

      await _firestore.runTransaction((transaction) async {
        final songSnap = await transaction.get(songRef);
        final totalSum = (songSnap.get('totalRatingSum') ?? 0.0).toDouble();
        final totalCount = (songSnap.get('totalRatings') ?? 0).toInt();

        final histogramPath = 'ratingsHistogram.$ratingKey';

        transaction.update(songRef, {
          'totalRatingSum': totalSum - rating,
          'totalRatings': totalCount - 1,
          histogramPath: FieldValue.increment(-1),
        });
      });
    }

    await reviewRef.delete();
    setState(() {
      _reviewList.removeWhere((r) => r.documentId == review.documentId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recensione eliminata')),
    );
  }

  void _showDeleteDialog(Review review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminare recensione"),
        content: const Text("Sei sicura di voler eliminare questa recensione?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReview(review);
            },
            child: const Text("Elimina"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Le tue recensioni'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: ListView.builder(
        itemCount: _reviewList.length,
        itemBuilder: (context, index) {
          final review = _reviewList[index];
          final formattedDate = DateFormat("dd MMMM yyyy, HH:mm", "it_IT").format(review.timestamp.toDate());

          return Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text('${review.songTitle} - ${review.artistName}', style: const TextStyle(color: Colors.white)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Valutazione: ${review.rating}', style: const TextStyle(color: Colors.white70)),
                  Text('Recensione: ${review.reviewText}', style: const TextStyle(color: Colors.white70)),
                  Text(formattedDate, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => _showDeleteDialog(review),
              ),
            ),
          );
        },
      ),
    );
  }
}
