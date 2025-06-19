import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';

import '../Classes/User.dart';

class NetworkScreen extends StatefulWidget {
  @override
  _NetworkScreenState createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _loadDataForTab(_tabController.index);
      }
    });

    // Carica inizialmente i dati per la prima tab (Search)
    _loadDataForTab(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDataForTab(int index) async {
    setState(() {
      _isLoading = true;
      _users = [];
    });

    final currentUserId = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    final firestore = FirebaseFirestore.instance;

    try {
      if (index == 0) {
        // Tab Search: mostra lista vuota (o implementa ricerca)
        setState(() {
          _users = [];
        });
      } else if (index == 1) {
        // Tab Followers
        if (currentUserId == null) return;
        final followersSnapshot = await firestore
            .collection('User')
            .doc(currentUserId)
            .collection('followersList')
            .get();

        final followerIds = followersSnapshot.docs.map((doc) => doc.id).toList();

        if (followerIds.isEmpty) {
          setState(() {
            _users = [];
          });
          return;
        }

        final usersQuery = await firestore
            .collection('User')
            .where(FieldPath.documentId, whereIn: followerIds)
            .get();

        setState(() {
          _users = usersQuery.docs
              .map((doc) => UserModel.fromDocument(doc))
              .toList();
        });
      } else if (index == 2) {
        // Tab Following
        if (currentUserId == null) return;
        final followingSnapshot = await firestore
            .collection('User')
            .doc(currentUserId)
            .collection('followingList')
            .get();

        final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();

        if (followingIds.isEmpty) {
          setState(() {
            _users = [];
          });
          return;
        }

        final usersQuery = await firestore
            .collection('User')
            .where(FieldPath.documentId, whereIn: followingIds)
            .get();

        setState(() {
          _users = usersQuery.docs
              .map((doc) => UserModel.fromDocument(doc))
              .toList();
        });
      }
    } catch (e) {
      print("Errore caricamento dati tab $index: $e");
      setState(() {
        _users = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final firestore = FirebaseFirestore.instance;

    try {
      final snapshot = await firestore
          .collection('User')
          .orderBy('username')
          .startAt([query])
          .endAt([query + '\uf8ff'])
          .get();

      setState(() {
        _users =
            snapshot.docs.map((doc) => UserModel.fromDocument(doc)).toList();
      });
    } catch (e) {
      print("Errore ricerca utenti: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onUserTap(UserModel user) {
    // Navigazione al profilo utente, passare user.id
    Navigator.of(context).pushNamed('/userProfile', arguments: user.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Network',
          style: TextStyle(
            fontFamily: 'PoppinsBold',
            fontWeight: FontWeight.bold,
            fontSize: 30,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.black,
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent, // colore tab selezionata
          tabs: const [
            Tab(text: 'Search'),
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_tabController.index == 0)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by username',
                  fillColor: Colors.grey[900],
                  filled: true,
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                onSubmitted: (value) => _searchUsers(value.trim()),
              ),
            )
          else
            const SizedBox(height: 16),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? Center(
              child: Text(
                'No users found',
                style: TextStyle(color: Colors.grey[400]),
              ),
            )
                : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  title: Text(
                    user.username ?? 'No username',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${user.firstName ?? ''} ${user.lastName ?? ''}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  onTap: () => _onUserTap(user),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
