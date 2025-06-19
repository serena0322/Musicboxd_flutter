import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityItem {
  final String message;
  final Timestamp timestamp;

  ActivityItem({required this.message, required this.timestamp});
}

class RawActivity {
  final String actionType;
  final String sourceUserId;
  final String? targetUserId;
  final Timestamp timestamp;

  RawActivity({
    required this.actionType,
    required this.sourceUserId,
    this.targetUserId,
    required this.timestamp,
  });
}
