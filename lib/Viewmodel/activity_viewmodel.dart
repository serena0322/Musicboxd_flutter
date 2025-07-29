import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../local/ActivityItem.dart';
import '../repositories/UserRepository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityViewModel extends ChangeNotifier {
  final UserRepository _repo;
  List<ActivityItem> friendsActivities = [];
  List<ActivityItem> myActivities = [];
  bool isLoading = false;

  ActivityViewModel(this._repo) {
    loadAllActivities();
  }

  Future<void> loadAllActivities() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    isLoading = true;
    notifyListeners();

    final followingSnapshot = await FirebaseFirestore.instance
        .collection('User')
        .doc(uid)
        .collection('followingList')
        .get();

    final followingIds = followingSnapshot.docs.map((e) => e.id).toList();

    final fa = await _repo.loadFriendsActivities(followingIds);
    final ma = await _repo.loadMyActivities(uid);

    friendsActivities = fa;
    myActivities = ma;

    isLoading = false;
    notifyListeners();
  }
}
