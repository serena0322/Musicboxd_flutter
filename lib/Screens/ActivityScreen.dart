import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Classes/ActivityItem.dart';

class ActivityScreen extends StatefulWidget {
  @override
  _ActivityScreenState createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ActivityItem> _activities = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_loadActivities);
    _loadActivities();
  }

  void _loadActivities() {
    if (_tabController.index == 0) {
      _loadFriendsActivities();
    } else {
      _loadUserActivities();
    }
  }

  Future<void> _loadUserActivities() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    final query = await FirebaseFirestore.instance
        .collection('User')
        .doc(currentUser.uid)
        .collection('Activity')
        .orderBy('timestamp', descending: true)
        .get();

    final activities = query.docs.map((doc) {
      final action = doc['action'];
      final timestamp = doc['timestamp'] as Timestamp;
      return ActivityItem(message: action, timestamp: timestamp);
    }).toList();

    setState(() {
      _activities = activities;
      _isLoading = false;
    });
  }

  Future<void> _loadFriendsActivities() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    final followingSnapshot = await FirebaseFirestore.instance
        .collection('User')
        .doc(currentUser.uid)
        .collection('followingList')
        .get();

    if (followingSnapshot.docs.isEmpty) {
      setState(() {
        _activities = [];
        _isLoading = false;
      });
      return;
    }

    final rawActivities = <RawActivity>[];
    final futures = followingSnapshot.docs.map((doc) async {
      final followedId = doc.id;
      if (followedId == currentUser.uid) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('User')
          .doc(followedId)
          .collection('ActivityForOthers')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      for (var doc in snapshot.docs) {
        final actionType = doc['actionType'];
        final sourceUserId = doc['sourceUserId'];
        final targetUserId = doc['targetUserId'];
        final timestamp = doc['timestamp'] as Timestamp;

        if (sourceUserId == currentUser.uid) continue;

        rawActivities.add(RawActivity(
          actionType: actionType,
          sourceUserId: sourceUserId,
          targetUserId: targetUserId,
          timestamp: timestamp,
        ));
      }
    }).toList();

    await Future.wait(futures);

    // Recupera tutti gli username
    final userIds = rawActivities
        .expand((a) => [a.sourceUserId, if (a.targetUserId != null) a.targetUserId!])
        .toSet();

    final usernames = <String, String>{};
    await Future.wait(userIds.map((id) async {
      final doc = await FirebaseFirestore.instance.collection('User').doc(id).get();
      if (doc.exists) {
        usernames[id] = doc['username'] ?? 'Utente';
      }
    }));

    final activities = rawActivities.map((activity) {
      final sourceUsername = usernames[activity.sourceUserId] ?? 'Utente';
      final targetUsername = usernames[activity.targetUserId] ?? 'qualcuno';
      final isTargetCurrentUser = activity.targetUserId == currentUser.uid;

      String message;
      switch (activity.actionType) {
        case 'follow':
          message = isTargetCurrentUser
              ? "$sourceUsername ha iniziato a seguirti"
              : "$sourceUsername ha iniziato a seguire $targetUsername";
          break;
        case 'unfollow':
          message = isTargetCurrentUser
              ? "$sourceUsername ha smesso di seguirti"
              : "$sourceUsername ha smesso di seguire $targetUsername";
          break;
        default:
          message = "$sourceUsername ha effettuato un'azione";
      }

      return ActivityItem(message: message, timestamp: activity.timestamp);
    }).toList();

    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      _activities = activities;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 30),
            Center(
              child: Text(
                'Activity',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: Colors.cyanAccent,
              unselectedLabelColor: Colors.white,
              indicatorColor: Colors.cyanAccent,
              tabs: const [
                Tab(text: 'Friends'),
                Tab(text: 'You'),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                itemCount: _activities.length,
                itemBuilder: (context, index) {
                  final activity = _activities[index];
                  return ListTile(
                    title: Text(activity.message, style: TextStyle(color: Colors.white)),
                    subtitle: Text(activity.timestamp.toDate().toString(),
                        style: TextStyle(color: Colors.grey)),
                    tileColor: Colors.grey[900],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
