import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Classes/Track.dart';
import '../Viewmodel/profile_viewmodel.dart';

class ReviewScreen extends StatefulWidget {
  final Track track;

  const ReviewScreen({Key? key, required this.track}) : super(key: key);

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _reviewController = TextEditingController();

  double _rating = 0.0;
  bool _isLiked = false;
  String _reviewDocId = '';
  bool _isUpdating = false;
  bool _isSaving = false;

  late String formattedDate;

  @override
  void initState() {
    super.initState();
    final timestamp = Timestamp.now();
    formattedDate = DateFormat("dd MMMM, HH:mm", "it_IT").format(timestamp.toDate());
    _loadExistingReview();
  }

  void _loadExistingReview() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final query = await _firestore
        .collection('User')
        .doc(user.uid)
        .collection('Reviews')
        .where('title', isEqualTo: widget.track.title)
        .where('artist', isEqualTo: widget.track.artist)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      setState(() {
        _reviewDocId = doc.id;
        _reviewController.text = doc['textReview'] ?? '';
        double rawRating = (doc['rating'] ?? 0.0).toDouble();
        _rating = rawRating.isNaN ? 0.0 : rawRating;
        _isUpdating = true;
      });
    }
  }

  Future<void> _saveReview() async {
    final user = _auth.currentUser;

    if (_rating.isNaN || _rating < 0 || _rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Valutazione non valida.")),
      );
      setState(() => _isSaving = false);
      return;
    }


    if (user == null || _isSaving) return;

    setState(() => _isSaving = true);

    final uid = user.uid;
    final now = Timestamp.now();

    final userDoc = _firestore.collection('User').doc(uid);

    if (widget.track.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ID canzone mancante. Salvataggio annullato.")),
      );
      setState(() => _isSaving = false);
      return;
    }

    final reviewData = {
      'action': 'review',
      'timestamp': now,
      'textReview': _reviewController.text.trim(),
      'title': widget.track.title,
      'artist': widget.track.artist,
      'rating': _rating,
      'cover': widget.track.coverUrl,
    };

    final songRef = _firestore.collection('Songs').doc(widget.track.id.toString());

    try {
      if (_isUpdating) {
        await userDoc.collection('Reviews').doc(_reviewDocId).set(reviewData);
      } else {
        await userDoc.collection('Reviews').add(reviewData);
        await userDoc.collection('Activity').add({
          'action': 'Hai recensito "${widget.track.title}" di ${widget.track.artist}',
          'timestamp': now,
        });
        await userDoc.collection('ActivityForOthers').add({
          'actionType': 'review',
          'sourceUserId': uid,
          'songTitle': widget.track.title,
          'artistName': widget.track.artist,
          'timestamp': now,
        });

        final songSnap = await songRef.get();
        if (!songSnap.exists) {
          await songRef.set({
            'totalRatingSum': 0.0,
            'totalRatings': 0,
            'ratingsHistogram': {
              for (var r in ["0.5", "1.0", "1.5", "2.0", "2.5", "3.0", "3.5", "4.0", "4.5", "5.0"]) r: 0
            }
          });
        }

        await _firestore.runTransaction((transaction) async {
          final snap = await transaction.get(songRef);
          final data = snap.data() ?? {};

          final totalSum = (data['totalRatingSum'] ?? 0.0).toDouble();
          final totalCount = (data['totalRatings'] ?? 0).toInt();

          final ratingValue = (_rating * 2).roundToDouble() / 2.0;
          // Forza ratingKey a essere "3.0" anche se ratingValue è 3
          final ratingKey = ratingValue.toStringAsFixed(1); // es. "3.0"

          final Map<String, dynamic> updates = {
            'totalRatingSum': totalSum + _rating,
            'totalRatings': totalCount + 1,
            'ratingsHistogram': {
              ratingKey: FieldValue.increment(1),
            }
          };

          transaction.set(songRef, updates, SetOptions(merge: true));

        });

      }

      if (_isLiked) {
        await userDoc.update({'likes': FieldValue.increment(1)});
      }

      final profileVM = context.read<ProfileViewModel>();
      await profileVM.loadFullProfileData();

      Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore nel salvataggio: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = widget.track.coverUrl;

    return WillPopScope(
      onWillPop: () async {
        if (_isSaving) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Salvataggio in corso"),
              content: const Text("Sei sicura di voler uscire senza salvare?"),
              actions: [
                TextButton(
                  child: const Text("Annulla"),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text("Esci"),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          );
          return confirm ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Review', style: TextStyle(color: Colors.white)),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            children: [
              const SizedBox(height: 16),
              CachedNetworkImage(
                imageUrl: coverUrl.isNotEmpty ? coverUrl : 'https://via.placeholder.com/120',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                placeholder: (context, url) => const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.image),
              ),
              const SizedBox(height: 16),
              Text(widget.track.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(widget.track.artist,
                  style: const TextStyle(fontSize: 16, color: Colors.white60)),
              const SizedBox(height: 12),
              Text(formattedDate, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              RatingBar.builder(
                initialRating: _rating.isNaN ? 0.0 : _rating,
                minRating: 0,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                glow: false,
                itemSize: 32,
                unratedColor: Colors.grey[700],
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (rating) => setState(() => _rating = rating),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reviewController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Scrivi la tua recensione...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.redAccent : Colors.white54,
                    ),
                    onPressed: () => setState(() => _isLiked = !_isLiked),
                  ),
                  Text(_isLiked ? "Liked" : "Like",
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                onPressed: _isSaving
                    ? null
                    : () {
                  FocusScope.of(context).unfocus();
                  _saveReview();
                },
                child: Text(_isUpdating ? "Aggiorna" : "Salva"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
