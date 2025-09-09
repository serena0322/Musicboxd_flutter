import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../Classes/Track.dart';
import '../Viewmodel/profile_viewmodel.dart';

// ====== PALETTE (coerente con gli altri screen) ======
const kBg     = Color(0xFF0E0F12);
const kCard   = Color(0xFF151821);
const kBorder = Color(0x22FFFFFF);
const kGradA  = Color(0xFFB5179E);
const kGradB  = Color(0xFF00E5FF);

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
    formattedDate =
        DateFormat("dd MMMM, HH:mm", "it_IT").format(timestamp.toDate());
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
        .where('artist', isEqualTo: widget.track.artist.name) // << qui
        .limit(1)
        .get();


    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      setState(() {
        _reviewDocId = doc.id;
        _reviewController.text = doc['textReview'] ?? '';
        final raw = (doc['rating'] ?? 0.0).toDouble();
        _rating = raw.isNaN ? 0.0 : raw;
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
      'artist': widget.track.artist.name,
      // 'artistId': widget.track.artist.id,
      'rating': _rating,
      'cover': widget.track.album.cover,
    };


    final songRef = _firestore.collection('Songs').doc(widget.track.id.toString());

    try {
      if (_isUpdating) {
        await userDoc.collection('Reviews').doc(_reviewDocId).set(reviewData);
      } else {
        await userDoc.collection('Reviews').add(reviewData);
        await userDoc.collection('Activity').add({
          'action': 'Hai recensito "${widget.track.title}" di ${widget.track.artist.name}', // << qui
          'timestamp': now,
        });

        await userDoc.collection('ActivityForOthers').add({
          'actionType': 'review',
          'sourceUserId': uid,
          'songTitle': widget.track.title,
          'artistName': widget.track.artist.name, // << qui
          'timestamp': now,
        });


        final songSnap = await songRef.get();
        if (!songSnap.exists) {
          await songRef.set({
            'totalRatingSum': 0.0,
            'totalRatings': 0,
            'ratingsHistogram': {
              for (var r in [
                "0.5","1.0","1.5","2.0","2.5","3.0","3.5","4.0","4.5","5.0"
              ]) r: 0
            }
          });
        }

        await _firestore.runTransaction((transaction) async {
          final snap = await transaction.get(songRef);
          final data = snap.data() ?? {};

          final totalSum = (data['totalRatingSum'] ?? 0.0).toDouble();
          final totalCount = (data['totalRatings'] ?? 0).toInt();

          final ratingValue = (_rating * 2).roundToDouble() / 2.0;
          final ratingKey = ratingValue.toStringAsFixed(1);

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
    final coverUrl = widget.track.album.cover;

    return WillPopScope(
      onWillPop: () async {
        if (_isSaving) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: kCard,
              titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              contentTextStyle: const TextStyle(color: Colors.white70),
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
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg,
          centerTitle: true,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: ShaderMask(
            shaderCallback: (Rect bounds) => const LinearGradient(
              colors: [kGradA, kGradB],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0.0, 0.7],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: const Text(
              'Review',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // ---- CARD COVER + INFO TRACK ----
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
                      imageUrl: (coverUrl.isNotEmpty)
                          ? coverUrl
                          : 'https://via.placeholder.com/120',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(width: 96, height: 96, color: const Color(0xFF2A2A2A)),
                      errorWidget: (_, __, ___) =>
                          Container(width: 96, height: 96, color: const Color(0xFF2A2A2A)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.track.title,
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
                          widget.track.artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0x1AFFFFFF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: kBorder),
                          ),
                          child: Text(
                            formattedDate,
                            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ---- RATING ----
            Container(
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('La tua valutazione',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Center(
                    child: RatingBar.builder(
                      initialRating: _rating.isNaN ? 0.0 : _rating,
                      minRating: 0,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      glow: false,
                      itemSize: 34,
                      unratedColor: Colors.grey[700],
                      itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                      itemBuilder: (context, _) =>
                      const Icon(Icons.star_rounded, color: Colors.amber),
                      onRatingUpdate: (rating) => setState(() => _rating = rating),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ---- TEXT REVIEW ----
            Container(
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _reviewController,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Scrivi la tua recensione…',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0x0FFFFFFF), // leggermente differente dal card
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ---- LIKE TOGGLE ----
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                selected: _isLiked,
                onSelected: (v) => setState(() => _isLiked = v),
                label: Text(_isLiked ? 'Liked' : 'Like',
                    style: const TextStyle(color: Colors.white)),
                avatar: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.redAccent : Colors.white70,
                  size: 18,
                ),
                backgroundColor: kCard,
                selectedColor: const Color(0x33FF1744),
                shape: StadiumBorder(side: BorderSide(color: kBorder)),
              ),
            ),

            const SizedBox(height: 20),

            // ---- PULSANTE SALVA (GRADIENTE FULL-WIDTH) ----
            SizedBox(
              height: 48,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kGradA, kGradB],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSaving
                      ? null
                      : () {
                    FocusScope.of(context).unfocus();
                    _saveReview();
                  },
                  child: Text(_isUpdating ? "Aggiorna" : "Salva",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
