import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';

import '../Classes/AppUser.dart';

// ====== PALETTE COERENTE ======
const kBg     = Color(0xFF0E0F12);
const kCard   = Color(0xFF151821);
const kBorder = Color(0x22FFFFFF);
const kGradA  = Color(0xFFB5179E);
const kGradB  = Color(0xFF00E5FF);

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<AppUser> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _loadDataForTab(_tabController.index);
      }
      setState(() {}); // per ricostruire la searchbar quando cambia tab
    });
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
        setState(() => _users = []);
      } else if (index == 1) {
        if (currentUserId == null) return;
        final followersSnapshot = await firestore
            .collection('User')
            .doc(currentUserId)
            .collection('followersList')
            .get();

        final followerIds = followersSnapshot.docs.map((d) => d.id).toList();
        if (followerIds.isEmpty) {
          setState(() => _users = []);
          return;
        }

        final usersQuery = await firestore
            .collection('User')
            .where(FieldPath.documentId, whereIn: followerIds)
            .get();

        setState(() {
          _users = usersQuery.docs.map(AppUser.fromDocument).toList();
        });
      } else if (index == 2) {
        if (currentUserId == null) return;
        final followingSnapshot = await firestore
            .collection('User')
            .doc(currentUserId)
            .collection('followingList')
            .get();

        final followingIds = followingSnapshot.docs.map((d) => d.id).toList();
        if (followingIds.isEmpty) {
          setState(() => _users = []);
          return;
        }

        final usersQuery = await firestore
            .collection('User')
            .where(FieldPath.documentId, whereIn: followingIds)
            .get();

        setState(() {
          _users = usersQuery.docs.map(AppUser.fromDocument).toList();
        });
      }
    } catch (e) {
      debugPrint("Errore caricamento dati tab $index: $e");
      setState(() => _users = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('User')
          .orderBy('username')
          .startAt([query])
          .endAt([query + '\uf8ff'])
          .get();

      setState(() {
        _users = snapshot.docs.map(AppUser.fromDocument).toList();
      });
    } catch (e) {
      debugPrint("Errore ricerca utenti: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onUserTap(AppUser user) {
    Navigator.of(context).pushNamed('/userProfile', arguments: user.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        centerTitle: true,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [kGradA, kGradB],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0.0, 0.7],
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: const Text(
            'Network',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 0.2),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _GradientTabBar(controller: _tabController),
          ),
        ),
      ),

      body: Column(
        children: [
          // Search bar solo nella tab 0
          if (_tabController.index == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Cerca per username',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (v) => _searchUsers(v.trim()),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _users = []);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _users.isEmpty
                ? const _EmptyState()
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final user = _users[index];
                return _UserTile(
                  user: user,
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



/// ---- UI widgets ----

class _GradientTabBar extends StatelessWidget {
  final TabController controller;
  const _GradientTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(colors: [kGradA, kGradB]),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Search'),
          Tab(text: 'Followers'),
          Tab(text: 'Following'),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;
  const _UserTile({required this.user, required this.onTap});

  String get _initial {
    final s = (user.username ?? user.firstName ?? 'U').trim();
    return s.isEmpty ? 'U' : s.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            leading: Container(
              width: 48, height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kGradA, kGradB]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _initial,
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20,
                ),
              ),
            ),
            title: Text(
              user.username ?? 'No username',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim(),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: const Text(
          'No users found',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
