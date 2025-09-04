// lib/viewmodels/user_view_model.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Modelli del progetto
import '../Classes/Review.dart';
import '../Classes/AppUser.dart';
import '../Classes/PlaylistItem.dart';

// ⬅️ Usa il file dove hai definito ActivityItem e RawActivity
// (aggiorna il path se diverso)
import '../Classes/ActivityItem.dart'; // contiene ActivityItem {message,timestamp}

import '../object/user_repository.dart';

class UserViewModel with ChangeNotifier {
  final UserRepository _repo = UserRepository();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  // aggiungi tra i campi privati
  StreamSubscription<List<String>>? _followingIdsSub;


  // ---- Home: Reviews stream + usernames ----
  final _homeReviewsCtrl = StreamController<List<Review>>.broadcast();
  Stream<List<Review>> get homeReviewsStream => _homeReviewsCtrl.stream;

  final _usernamesCtrl = StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get usernamesStream => _usernamesCtrl.stream;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _homeSub;
  Set<String> _followingCache = {};

  Future<Set<String>> _loadFollowingSet(String uid) async {
    try {
      final docUser = await _db.collection('User').doc(uid).get();
      if (docUser.exists) {
        final list = (docUser.data()?['following'] as List?)?.cast<String>() ?? const <String>[];
        return list.toSet();
      }
      final docUsers = await _db.collection('Users').doc(uid).get();
      final list = (docUsers.data()?['following'] as List?)?.cast<String>() ?? const <String>[];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> resolveUsernamesFor(Iterable<String> uids) async {
    final uniq = uids.where((e) => e.trim().isNotEmpty).toSet();
    if (uniq.isEmpty) {
      _usernamesCtrl.add(const {});
      return;
    }
    final result = <String, String>{};
    final list = uniq.toList();
    for (var i = 0; i < list.length; i += 10) {
      final chunk = list.sublist(i, (i + 10 > list.length) ? list.length : i + 10);
      try {
        final snap = await _db
            .collection('User')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          final data = d.data();
          result[d.id] = (data['username'] as String?) ??
              (data['displayName'] as String?) ??
              d.id;
        }
      } catch (_) {}
    }
    _usernamesCtrl.add(result);
  }

  void observeHomeReviewsRealtime() async {
    if (_homeSub != null) return;

    final uid = _auth.currentUser?.uid;
    _followingCache = uid != null ? await _loadFollowingSet(uid) : {};

    final q = _db.collectionGroup('Reviews').limit(200);
    _homeSub = q.snapshots().listen((snap) {
      // 1) Mapping tipizzato + ordinamento per timestamp decrescente
      final items = snap.docs
          .map((d) => Review.fromFirestore(d))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // 2) Partiziona: da seguiti vs altri
      final fromFollowed = <Review>[];
      final fromOthers = <Review>[];

      for (final r in items) {
        final uid = r.sourceUserId;
        if (uid.isNotEmpty && _followingCache.contains(uid)) {
          fromFollowed.add(r);
        } else {
          fromOthers.add(r);
        }
      }

      // 3) Limita + shuffle come su Android: 10 seguiti + 20 altri
      final out = <Review>[]
        ..addAll(fromFollowed.take(10))
        ..addAll(fromOthers.take(20));
      out.shuffle();

      _homeReviewsCtrl.add(out);

      // opzionale: risolvi gli username autori per la UI
      // resolveUsernamesFor(out.map((r) => r.sourceUserId));
    }, onError: (_) {
      _homeReviewsCtrl.add(const []);
    });
  }

  Future<void> reloadHomeReviewsOnce() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (_followingCache.isEmpty && uid != null) {
        _followingCache = await _loadFollowingSet(uid);
      }

      final snap = await _db.collectionGroup('Reviews').limit(200).get();

      final items = snap.docs
          .map((d) => Review.fromFirestore(d))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final fromFollowed = <Review>[];
      final fromOthers = <Review>[];

      for (final r in items) {
        final id = r.sourceUserId;
        if (id.isNotEmpty && _followingCache.contains(id)) {
          fromFollowed.add(r);
        } else {
          fromOthers.add(r);
        }
      }

      final out = <Review>[]
        ..addAll(fromFollowed.take(10))
        ..addAll(fromOthers.take(20));
      out.shuffle();

      _homeReviewsCtrl.add(out);

      // opzionale:
      // resolveUsernamesFor(out.map((r) => r.sourceUserId));
    } catch (_) {
      _homeReviewsCtrl.add(const []);
    }
  }


  // ---- Attività (mie + amici) usando ActivityItem {message,timestamp} ----
  List<ActivityItem> _myActivities = const [];
  List<ActivityItem> _friendsActivities = const [];
  List<ActivityItem> get myActivities => _myActivities;
  List<ActivityItem> get friendsActivities => _friendsActivities;

  Future<void> loadMyAndFriendsActivities() async {
    final pair = await _repo.loadMyActivitiesAndFollowersActivities(); // mantiene la firma
    _myActivities = pair.myActivities;
    _friendsActivities = pair.friendsActivities;
    notifyListeners();
  }

  StreamSubscription<List<ActivityItem>>? _myActSub;
  StreamSubscription<List<ActivityItem>>? _friendsActSub;

  void observeAllActivitiesRealtime() {
    _myActSub?.cancel();
    _friendsActSub?.cancel();

    _myActSub = _repo.observeMyActivityRealtime().listen((list) {
      _myActivities = list;
      notifyListeners();
    });

    // recupera i seguiti dall’utente corrente, se il repo lo espone; altrimenti passa l’elenco che hai
    _followingIdsSub?.cancel();
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _followingIdsSub = _repo.observeFollowingIds(uid).listen((followingList) {
        _friendsActSub?.cancel();
        _friendsActSub = _repo
            .observeFriendsActivitiesRealtime(followingList)
            .listen((list) {
          _friendsActivities = list;
          notifyListeners();
        });
      });
    }
  }

  // ---- Profilo base + realtime (opzionale) ----
  BasicProfileData? _basicProfile;
  BasicProfileData? get basicProfile => _basicProfile;
  bool _basicLoaded = false;

  Future<void> loadMyBasicProfile({bool forceReload = false}) async {
    if (_basicLoaded && !forceReload) return;
    _basicProfile = await _repo.loadMyBasicDataWithReviewsAndPlaylists();
    _basicLoaded = true;
    notifyListeners();
  }

  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<List<Review>>? _myReviewsSub;
  StreamSubscription<List<PlaylistItem>>? _myPlaylistsSub;

  void observeMyProfileDataRealtime() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _userSub?.cancel();
    _userSub = _repo.observeUserDocument(uid).listen((user) {
      _basicProfile = (_basicProfile ?? const BasicProfileData(null, [], []))
          .copyWith(user: user);
      notifyListeners();
    });

    _myReviewsSub?.cancel();
    _myReviewsSub = _repo.observeUserReviewsRealtime(uid).listen((reviews) {
      _basicProfile = (_basicProfile ?? const BasicProfileData(null, [], []))
          .copyWith(reviews: reviews);
      notifyListeners();
    });

    _myPlaylistsSub?.cancel();
    _myPlaylistsSub =
        _repo.observeUserPlaylistsRealtime(uid).listen((playlists) {
          _basicProfile = (_basicProfile ?? const BasicProfileData(null, [], []))
              .copyWith(playlists: playlists);
          notifyListeners();
        });
  }

  @override
  void dispose() {
    _homeSub?.cancel();
    _homeReviewsCtrl.close();
    _usernamesCtrl.close();

    _myActSub?.cancel();
    _friendsActSub?.cancel();
    _followingIdsSub?.cancel();


    _userSub?.cancel();
    _myReviewsSub?.cancel();
    _myPlaylistsSub?.cancel();
    super.dispose();
  }
}
