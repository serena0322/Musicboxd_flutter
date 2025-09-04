import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String documentId;
  final String actionType;
  final String artistName;
  final String songTitle;
  final String sourceUserId;
  final String albumCoverUrl;
  final double rating;
  final String reviewText;
  final Timestamp timestamp;

  const Review({
    required this.documentId,
    required this.actionType,
    required this.artistName,
    required this.songTitle,
    required this.sourceUserId,
    required this.albumCoverUrl,
    required this.rating,
    required this.reviewText,
    required this.timestamp,
  });

  /// Factory robusta: accetta numeri o stringhe per rating,
  /// timestamp mancante, e calcola sourceUserId dal path se assente.
  factory Review.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    // rating (num o string)
    final rawRating = data['rating'];
    final doubleRating = rawRating is num
        ? rawRating.toDouble()
        : double.tryParse(rawRating?.toString() ?? '') ?? 0.0;

    // timestamp (Timestamp o mancante)
    final rawTs = data['timestamp'];
    final ts = rawTs is Timestamp ? rawTs : Timestamp.now();

    // sourceUserId: preferisci campo, altrimenti userId; altrimenti prendi l'id del genitore (User/{uid}/Reviews/{doc})
    String sourceUid =
        (data['sourceUserId'] as String?) ??
            (data['userId'] as String?) ??
            '';
    if (sourceUid.isEmpty) {
      sourceUid = doc.reference.parent.parent?.id ?? '';
    }

    return Review(
      documentId: doc.id,
      actionType: (data['action'] as String?) ?? 'review',
      artistName: (data['artist'] as String?) ?? '',
      songTitle: (data['title'] as String?) ?? '',
      sourceUserId: sourceUid,
      albumCoverUrl: (data['cover'] as String?) ?? '',
      rating: doubleRating,
      reviewText: (data['textReview'] as String?) ?? '',
      timestamp: ts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': actionType,
      'artist': artistName,
      'title': songTitle,
      'sourceUserId': sourceUserId,
      'cover': albumCoverUrl,
      'rating': rating,
      'textReview': reviewText,
      'timestamp': timestamp,
    };
  }

  Review copyWith({
    String? documentId,
    String? actionType,
    String? artistName,
    String? songTitle,
    String? sourceUserId,
    String? albumCoverUrl,
    double? rating,
    String? reviewText,
    Timestamp? timestamp,
  }) {
    return Review(
      documentId: documentId ?? this.documentId,
      actionType: actionType ?? this.actionType,
      artistName: artistName ?? this.artistName,
      songTitle: songTitle ?? this.songTitle,
      sourceUserId: sourceUserId ?? this.sourceUserId,
      albumCoverUrl: albumCoverUrl ?? this.albumCoverUrl,
      rating: rating ?? this.rating,
      reviewText: reviewText ?? this.reviewText,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
