import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Classes/AppUser.dart';
import '../Classes/ActivityItem.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<AppUser?> loadMyBasicData() async {
    print("Chiamata a loadMyBasicData()");
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('User').doc(uid).get();

    if (doc.exists) {
      return AppUser.fromDocument(doc);
    }
    return null;
  }

  Future<Map<String, int>> loadCounts() async {
    print("Chiamata a loadCounts()");
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {'reviews': 0, 'playlists': 0};

    final reviewsSnapshot = await FirebaseFirestore.instance
        .collection('User')
        .doc(uid)
        .collection('Reviews')
        .get();

    final playlistSnapshot = await FirebaseFirestore.instance
        .collection('User')
        .doc(uid)
        .collection('Playlists')
        .get();

    return {
      'reviews': reviewsSnapshot.docs.length,
      'playlists': playlistSnapshot.docs.length,
    };
  }


  /// Recupera le attività degli amici con messaggi formattati
  Future<List<ActivityItem>> loadFriendsActivities(List<String> followingIds) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final List<ActivityItem> activities = [];
    final Map<String, String> userMap = {};

    // Carica username per ogni userId
    for (final fId in followingIds) {
      final userDoc = await _firestore.collection("User").doc(fId).get();
      userMap[fId] = userDoc.data()?['username'] ?? 'Utente';
    }

    for (final fId in followingIds) {
      final docs = await _firestore
          .collection("User")
          .doc(fId)
          .collection("ActivityForOthers")
          .orderBy("timestamp", descending: true)
          .limit(10)
          .get();

      for (final doc in docs.docs) {
        final data = doc.data();
        final String type = data['actionType'] ?? '';
        final String sourceUserId = data['sourceUserId'] ?? '';
        final String? targetUserId = data['targetUserId'];
        final Timestamp? timestamp = data['timestamp'];
        final String? songTitle = data['songTitle'];
        final String? artistName = data['artistName'];

        final sourceUsername = userMap[sourceUserId] ?? "Utente";

        String? content;
        switch (type) {
          case 'follow':
            if (targetUserId == uid) {
              content = "$sourceUsername ha iniziato a seguirti";
            }
            break;
          case 'review':
            final song = songTitle ?? "una canzone";
            final artist = artistName ?? "un artista";
            content = "$sourceUsername ha recensito \"$song\" di $artist";
            break;
        }

        if (content != null && timestamp != null) {
          activities.add(ActivityItem(message: content, timestamp: timestamp));
        }
      }
    }

    // Ordina per timestamp
    activities.sort((a, b) => b.timestamp!.compareTo(a.timestamp!));
    return activities;
  }

  /// Recupera le attività dell’utente corrente
  Future<List<ActivityItem>> loadMyActivities(String uid) async {
    final query = await _firestore
        .collection('User')
        .doc(uid)
        .collection('Activity')
        .orderBy('timestamp', descending: true)
        .get();

    final activities = query.docs.map((doc) {
      final data = doc.data();
      final message = data['action'] ?? '';
      final timestamp = data['timestamp'] as Timestamp;
      return ActivityItem(message: message, timestamp: timestamp);
    }).toList();

    return activities;
  }

  String? get currentUserId => _auth.currentUser?.uid;

  Future<List<String>> getFollowingIds() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection("User")
        .doc(uid)
        .collection("followingList")
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  }

}
