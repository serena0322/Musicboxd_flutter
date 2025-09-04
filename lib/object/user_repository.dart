// lib/repositories/user_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ADATTA questi import ai tuoi model reali:
import '../Classes/AppUser.dart';
import '../Classes/Review.dart';
import '../Classes/PlaylistItem.dart';
import '../Classes/ActivityItem.dart';

class BasicProfileData {
  final AppUser? user;
  final List<Review> reviews;
  final List<PlaylistItem> playlists;
  const BasicProfileData(this.user, this.reviews, this.playlists);

  BasicProfileData copyWith({
    AppUser? user,
    List<Review>? reviews,
    List<PlaylistItem>? playlists,
  }) {
    return BasicProfileData(
      user ?? this.user,
      reviews ?? this.reviews,
      playlists ?? this.playlists,
    );
  }
}

/// Sostituisce la Pair di Kotlin
class ActivitiesPair {
  final List<ActivityItem> myActivities;
  final List<ActivityItem> friendsActivities;
  ActivitiesPair(this.myActivities, this.friendsActivities);
}

class UserRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ============= Helpers =============
  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      final end = (i + size < list.length) ? i + size : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }

  // ================== Activities ==================

  Future<ActivitiesPair> loadMyActivitiesAndFollowersActivities() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return ActivitiesPair(const [], const []);

    // Attività personali
    final personalSnap = await _db
        .collection('User')
        .doc(uid)
        .collection('Activity')
        .orderBy('timestamp', descending: true)
        .get();

    final myActivities = personalSnap.docs.map((d) {
      final data = d.data();
      final action = data['action'] as String?;
      final ts = data['timestamp'] as Timestamp?;
      if (action == null || ts == null) return null;
      return ActivityItem(message: action, timestamp: ts);
    }).whereType<ActivityItem>().toList();

    // Seguiti
    final followingDocs = await _db
        .collection('User')
        .doc(uid)
        .collection('followingList')
        .get();
    final followingIds = followingDocs.docs.map((e) => e.id).toList();

    // Cache username
    final userMap = <String, String>{};
    for (final fId in followingIds) {
      final u = await _db.collection('User').doc(fId).get();
      userMap[fId] = (u.data()?['username'] as String?) ?? 'Utente';
    }

    // Attività amici
    final friends = <ActivityItem>[];
    for (final fId in followingIds) {
      final acts = await _db
          .collection('User')
          .doc(fId)
          .collection('ActivityForOthers')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      for (final d in acts.docs) {
        final data = d.data();
        final type = data['actionType'] as String?;
        final ts = data['timestamp'] as Timestamp?;
        final targetUserId = data['targetUserId'] as String?;
        final songTitle = data['songTitle'] as String?;
        final artistName = data['artistName'] as String?;
        final sourceUserId = data['sourceUserId'] as String?;

        if (type == null || ts == null || sourceUserId == null) continue;
        final sourceName = userMap[sourceUserId] ?? 'Utente';

        String? msg;
        if (type == 'follow') {
          if (targetUserId == uid) {
            msg = '$sourceName ha iniziato a seguirti';
          }
        } else if (type == 'review') {
          msg =
          '$sourceName ha recensito "${songTitle ??
              "una canzone"}" di ${artistName ?? "un artista"}';
        }
        if (msg != null) friends.add(ActivityItem(message: msg, timestamp: ts));
      }
    }
    friends.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return ActivitiesPair(myActivities, friends);
  }

  // Stream degli ID utenti seguiti (collezione: User/{uid}/followingList)
  Stream<List<String>> observeFollowingIds(String uid) {
    return _db
        .collection('User')
        .doc(uid)
        .collection('followingList')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  // (Opzionale) one-shot
  Future<List<String>> getFollowingIdsOnce(String uid) async {
    final snap = await _db
        .collection('User')
        .doc(uid)
        .collection('followingList')
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  /// Realtime mie attività
  Stream<List<ActivityItem>> observeMyActivityRealtime() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream<List<ActivityItem>>.empty();

    return _db
        .collection('User')
        .doc(uid)
        .collection('Activity')
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) {
        final data = d.data();
        final action = data['action'] as String?;
        final ts = data['timestamp'] as Timestamp?;
        if (action == null || ts == null) return null;
        return ActivityItem(message: action, timestamp: ts);
      }).whereType<ActivityItem>().toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  /// Realtime attività amici
  Stream<List<ActivityItem>> observeFriendsActivitiesRealtime(
      List<String> followingIds) {
    if (followingIds.isEmpty) return Stream<List<ActivityItem>>.empty();

    final controller = StreamController<List<ActivityItem>>.broadcast();
    final subscriptions = <
        StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final combined = <ActivityItem>[];
    final userCache = <String, String>{};

    void emit() {
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(List<ActivityItem>.from(combined));
    }

    for (final friendId in followingIds) {
      final sub = _db
          .collection('User')
          .doc(friendId)
          .collection('ActivityForOthers')
          .snapshots()
          .listen((snap) async {
        // username cache
        if (!userCache.containsKey(friendId)) {
          final u = await _db.collection('User').doc(friendId).get();
          userCache[friendId] = (u.data()?['username'] as String?) ?? 'Utente';
        }
        final username = userCache[friendId]!;

        final acts = snap.docs.map((d) {
          final data = d.data();
          final type = data['actionType'] as String?;
          final ts = data['timestamp'] as Timestamp?;
          final songTitle = data['songTitle'] as String?;
          final artistName = data['artistName'] as String?;
          if (type == null || ts == null) return null;

          String? msg;
          if (type == 'follow') {
            msg = '$username ha iniziato a seguire qualcuno';
          } else if (type == 'review') {
            msg =
            '$username ha recensito "${songTitle ??
                "una canzone"}" di ${artistName ?? "un artista"}';
          }
          return (msg != null)
              ? ActivityItem(message: msg, timestamp: ts)
              : null;
        }).whereType<ActivityItem>().toList();

        // rimpiazzo semplice: tolgo vecchie entry di questo autore e aggiungo le nuove
        combined.removeWhere((it) => it.message.startsWith(username));
        combined.addAll(acts);
        emit();
      });

      subscriptions.add(sub);
    }

    controller.onCancel = () async {
      for (final s in subscriptions) {
        await s.cancel();
      }
    };

    return controller.stream;
  }

  // ================== Reviews & Playlists ==================

  Stream<List<Review>> observeUserReviewsRealtime(String userId) {
    return _db
        .collection('User')
        .doc(userId)
        .collection('Reviews')
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => Review.fromFirestore(d))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      // Filtra record incompleti se necessario:
      return list
          .where((r) => r.songTitle.isNotEmpty && r.artistName.isNotEmpty)
          .toList();
    });
  }

  Stream<List<PlaylistItem>> observeUserPlaylistsRealtime(String userId) {
    return _db
        .collection('User')
        .doc(userId)
        .collection('Playlists')
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) {
        final m = d.data();
        return PlaylistItem(
          id: d.id,
          name: (m['name'] as String?) ?? '',
          createdBy: (m['createdBy'] as String?) ?? '',
          timestamp: (m['timestamp'] as Timestamp?),
          tracks: (m['tracks'] as List?)?.cast<String>() ?? const [],
        );
      }).where((p) => p.name.isNotEmpty).toList()
        ..sort((a, b) =>
        (b.timestamp?.compareTo(a.timestamp ?? Timestamp.now()) ?? 0));
      return list;
    });
  }

  Future<List<Review>> loadReviewsForUser(String userId) async {
    final snap = await _db
        .collection('User')
        .doc(userId)
        .collection('Reviews')
        .get();

    final list = snap.docs
        .map((d) => Review.fromFirestore(d))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return list
        .where((r) => r.songTitle.isNotEmpty && r.artistName.isNotEmpty)
        .toList();
  }

  // ================== Profile base (me & altri) ==================

  Future<BasicProfileData> loadMyBasicDataWithReviewsAndPlaylists() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const BasicProfileData(null, [], []);

    final userDoc = await _db.collection('User').doc(uid).get();
    AppUser? user;
    if (userDoc.exists) {
      user = AppUser.fromDocument(userDoc);
    }

    final reviews = await loadReviewsForUser(uid);

    final playlistsSnap =
    await _db.collection('User').doc(uid).collection('Playlists').get();

    final playlists = playlistsSnap.docs.map((d) {
      final m = d.data();
      return PlaylistItem(
        id: d.id,
        name: (m['name'] as String?) ?? '',
        createdBy: (m['createdBy'] as String?) ?? '',
        timestamp: (m['timestamp'] as Timestamp?),
        tracks: (m['tracks'] as List?)?.cast<String>() ?? const [],
      );
    }).where((p) => p.name.isNotEmpty).toList();

    return BasicProfileData(user, reviews, playlists);
  }

  Stream<AppUser?> observeUserDocument(String userId) {
    return _db.collection('User').doc(userId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AppUser.fromDocument(snap);
    });
  }


  Future<BasicProfileData> loadUserBasicDataWithReviewsAndPlaylists(
      String userId) async {
    final userDoc = await _db.collection('User').doc(userId).get();
    AppUser? user;
    if (userDoc.exists) {
      user = AppUser.fromDocument(userDoc);
    }

    final reviews = await loadReviewsForUser(userId);

    final playlistsSnap =
    await _db.collection('User').doc(userId).collection('Playlists').get();

    final playlists = playlistsSnap.docs.map((d) {
      final m = d.data();
      return PlaylistItem(
        id: d.id,
        name: (m['name'] as String?) ?? '',
        createdBy: (m['createdBy'] as String?) ?? '',
        timestamp: (m['timestamp'] as Timestamp?),
        tracks: (m['tracks'] as List?)?.cast<String>() ?? const [],
      );
    }).where((p) => p.name.isNotEmpty).toList();

    return BasicProfileData(user, reviews, playlists);
  }


  // ================== Followers / Following / Search ==================

  Future<List<AppUser>> searchUsersByUsername(String query) async {
    final snap = await _db
        .collection('User')
        .orderBy('username')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .get();

    return snap.docs.map((d) => AppUser.fromDocument(d)).toList();
  }

  Future<List<AppUser>> getFollowers() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const [];

    final followerIds = (await _db
        .collection('User')
        .doc(uid)
        .collection('followersList')
        .get())
        .docs
        .map((d) => d.id)
        .toList();

    if (followerIds.isEmpty) return const [];

    final users = <AppUser>[];
    for (final chunk in _chunk(followerIds, 10)) {
      final snap = await _db
          .collection('User')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      users.addAll(snap.docs.map((d) => AppUser.fromDocument(d)));
    }
    return users;
  }

  Future<List<AppUser>> getFollowing() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const [];

    final followingIds = (await _db
        .collection('User')
        .doc(uid)
        .collection('followingList')
        .get())
        .docs
        .map((d) => d.id)
        .toList();

    if (followingIds.isEmpty) return const [];

    final users = <AppUser>[];
    for (final chunk in _chunk(followingIds, 10)) {
      final snap = await _db
          .collection('User')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      users.addAll(snap.docs.map((d) => AppUser.fromDocument(d)));
    }
    return users;
  }
}