// Modello PlaylistItem
import 'package:cloud_firestore/cloud_firestore.dart';

class PlaylistItem {
  final String id;
  final String name;
  final String createdBy;
  final Timestamp? timestamp;
  final List<String> tracks;

  PlaylistItem({
    required this.id,
    required this.name,
    required this.createdBy,
    this.timestamp,
    required this.tracks,
  });

  factory PlaylistItem.fromMap(Map<String, dynamic> data, String docId) {
    return PlaylistItem(
      id: docId,
      name: data['name'] ?? '',
      createdBy: data['createdBy'] ?? '',
      timestamp: data['timestamp'],
      tracks: List<String>.from(data['tracks'] ?? []),
    );
  }
}