import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Classes/Review.dart';

class ReviewItem extends StatelessWidget {
  final Review review;
  final VoidCallback onLongPress;

  const ReviewItem({
    Key? key,
    required this.review,
    required this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formattedDate =
    DateFormat("d MMMM yyyy, HH:mm", "it_IT").format(review.timestamp.toDate());
    final hasReviewText = review.reviewText.trim().isNotEmpty;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(10),
        color: const Color(0xFF1E1E1E),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Album Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: review.albumCoverUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const CircularProgressIndicator(),
                    errorWidget: (context, url, error) => const Icon(Icons.music_note),
                  ),
                ),
                const SizedBox(width: 12),
                // Right section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.songTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        review.artistName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                      if (hasReviewText) ...[
                        const SizedBox(height: 6),
                        Text(
                          review.reviewText,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(review.rating % 1 == 0) ? review.rating.toInt() : review.rating}/5',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            formattedDate,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.grey, thickness: 0.6),
          ],
        ),
      ),
    );
  }
}
