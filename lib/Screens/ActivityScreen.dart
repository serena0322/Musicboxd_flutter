import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Classes/ActivityItem.dart';
import '../object/user_repository.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = UserRepository();
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0F12),
        appBar: AppBar(
          backgroundColor: const Color(0xFF13151A),
          elevation: 0,
          centerTitle: true,
          title: ShaderMask(
            shaderCallback: (Rect bounds) => const LinearGradient(
              colors: [Color(0xFFB5179E), Color(0xFF00E5FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0.0, 0.7],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: const Text(
              'Attività',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 28),
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFF00E5FF),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Amici'),
              Tab(text: 'Tu'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FriendsActivitiesTab(repo: _repo, auth: _auth),
            _MyActivitiesTab(repo: _repo),
          ],
        ),
      ),
    );
  }

}

/// Sfondo header con gradiente, in linea con il profilo
class _HeaderGradient extends StatelessWidget {
  const _HeaderGradient();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: top + 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF13151A), Color(0xFF1C1E26), Color(0xFF222736)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

/// TAB "Amici": stream degli ID seguiti -> stream attività amici
class _FriendsActivitiesTab extends StatelessWidget {
  final UserRepository repo;
  final FirebaseAuth auth;

  const _FriendsActivitiesTab({required this.repo, required this.auth});

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      return const _EmptyState(message: 'Acceda per vedere le attività degli amici.');
    }

    return StreamBuilder<List<String>>(
      stream: repo.observeFollowingIds(uid),
      builder: (context, followSnap) {
        if (followSnap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        if (followSnap.hasError) {
          return _ErrorState(error: followSnap.error.toString());
        }
        final ids = followSnap.data ?? const <String>[];
        if (ids.isEmpty) {
          return const _EmptyState(message: 'Non segue ancora nessuno.');
        }

        return StreamBuilder<List<ActivityItem>>(
          stream: repo.observeFriendsActivitiesRealtime(ids),
          builder: (context, actSnap) {
            if (actSnap.connectionState == ConnectionState.waiting) {
              return const _Loading();
            }
            if (actSnap.hasError) {
              return _ErrorState(error: actSnap.error.toString());
            }
            final list = actSnap.data ?? const <ActivityItem>[];
            if (list.isEmpty) {
              return const _EmptyState(message: 'Nessuna attività recente dagli amici.');
            }
            return _ActivityListPlain(list: list);
          },
        );
      },
    );
  }
}

/// TAB "Tu": stream attività personali
class _MyActivitiesTab extends StatelessWidget {
  final UserRepository repo;

  const _MyActivitiesTab({required this.repo});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityItem>>(
      stream: repo.observeMyActivityRealtime(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        if (snap.hasError) {
          return _ErrorState(error: snap.error.toString());
        }
        final list = snap.data ?? const <ActivityItem>[];
        if (list.isEmpty) {
          return const _EmptyState(message: 'Nessuna attività recente.');
        }
        return _ActivityListPlain(list: list);

      },
    );
  }
}

class _ActivityListPlain extends StatelessWidget {
  final List<ActivityItem> list;
  const _ActivityListPlain({required this.list});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        thickness: 0.7,
        color: Color(0x22FFFFFF),
      ),
      itemBuilder: (context, i) => _ActivityRowPlain(item: list[i]),
    );
  }
}

class _ActivityRowPlain extends StatelessWidget {
  final ActivityItem item;
  const _ActivityRowPlain({required this.item});

  IconData _iconFor(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('recensito') || m.contains('review')) return Icons.rate_review_outlined;
    if (m.contains('seguit') || m.contains('follow')) return Icons.person_add_alt_1_outlined;
    if (m.contains('playlist')) return Icons.queue_music_outlined;
    return Icons.history; // fallback
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('d MMM y, HH:mm', 'it_IT').format(item.timestamp.toDate());

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      dense: false,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFF202434),
        child: Icon(_iconFor(item.message), color: Colors.white, size: 20),
      ),
      title: Text(
        item.message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Text(time, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
      trailing: null,
      tileColor: Colors.transparent,
    );
  }
}

/// Lista attività in stile card scure arrotondate
class _ActivityList extends StatelessWidget {
  final List<ActivityItem> list;

  const _ActivityList({required this.list});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14), // leggermente più ampio
      itemBuilder: (context, i) => _ActivityTile(item: list[i]),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityItem item;

  const _ActivityTile({required this.item});

  IconData _iconFor(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('recensito') || m.contains('review')) return Icons.rate_review_outlined;
    if (m.contains('seguit') || m.contains('follow')) return Icons.person_add_alt_1_outlined;
    if (m.contains('playlist')) return Icons.queue_music_outlined;
    return Icons.history; // fallback
  }

  @override
  Widget build(BuildContext context) {
    final dt = DateFormat('d MMM y, HH:mm', 'it_IT').format(item.timestamp.toDate());

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22FFFFFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          )
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icona
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF202434),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconFor(item.message), color: Colors.white),
          ),
          const SizedBox(width: 12),
          // Testi (solo display, niente tap)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Messaggio
                Text(
                  item.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                // Riga data con icona orologio
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.white54),
                    const SizedBox(width: 6),
                    Text(
                      dt,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stati di comodo (loading / empty / error) coerenti con lo stile scuro

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: Colors.white70)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Errore: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }
}
