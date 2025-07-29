import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Classes/ActivityItem.dart';
import '../repositories/UserRepository.dart';

// Assicurati che RawActivity sia definita nel progetto
class RawActivity {
  final String actionType;
  final String sourceUserId;
  final String? targetUserId;
  final Timestamp timestamp;

  RawActivity({
    required this.actionType,
    required this.sourceUserId,
    required this.targetUserId,
    required this.timestamp,
  });
}

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
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadActivities();
      }
    });
    _loadActivities();
  }

  void _loadActivities() {
    if (_tabController.index == 0) {
      _loadFriendsActivities();
    } else {
      _loadMyActivities();
    }
  }

  Future<void> _loadMyActivities() async {
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

    final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();

    if (followingIds.isEmpty) {
      setState(() {
        _activities = [];
        _isLoading = false;
      });
      return;
    }

    final userRepository = UserRepository();
    final activities = await userRepository.loadFriendsActivities(followingIds);

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
                  : _activities.isEmpty
                  ? Center(
                child: Text(
                  "Nessuna attività trovata",
                  style: TextStyle(color: Colors.grey),
                ),
              )
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
