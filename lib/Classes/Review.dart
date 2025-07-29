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

  Review({
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

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review(
      documentId: doc.id,
      actionType: data['action'] ?? '',
      artistName: data['artist'] ?? '',
      songTitle: data['title'] ?? '',
      sourceUserId: data['sourceUserId'] ?? '',
      albumCoverUrl: data['cover'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewText: data['textReview'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
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
}
