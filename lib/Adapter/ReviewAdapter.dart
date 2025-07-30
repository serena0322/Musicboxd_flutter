import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Classes/Review.dart'; // Assicurati che questa contenga la classe Review

class ReviewAdapter extends StatelessWidget {
  final List<Review> reviews;
  final void Function(Review) onDelete;

  const ReviewAdapter({
    Key? key,
    required this.reviews,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        final review = reviews[index];
        final ratingFormatted = review.rating % 1 == 0
            ? review.rating.toInt().toString()
            : review.rating.toStringAsFixed(1);

        final formattedDate = review.timestamp != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(review.timestamp.toDate())
            : 'Data non disponibile';

        return GestureDetector(
          onLongPress: () => onDelete(review),
          child: Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: review.albumCoverUrl.isNotEmpty
                          ? review.albumCoverUrl
                          : 'https://via.placeholder.com/80',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => const Icon(Icons.image),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.songTitle,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          review.artistName,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        if (review.reviewText.trim().isNotEmpty)
                          Text(
                            review.reviewText.trim(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '$ratingFormatted/5',
                          style: const TextStyle(color: Colors.amber),
                        ),
                        Text(
                          formattedDate,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
