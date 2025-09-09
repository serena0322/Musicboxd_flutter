import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ====== PALETTE COERENTE ======
const kBg     = Color(0xFF0E0F12);
const kCard   = Color(0xFF151821);
const kBorder = Color(0x22FFFFFF);
const kGradA  = Color(0xFFB5179E);
const kGradB  = Color(0xFF00E5FF);

class UserProfile extends StatelessWidget {
  final String userId;
  const UserProfile({super.key, required this.userId});

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // --- Streams ---
  Stream<DocumentSnapshot<Map<String, dynamic>>> _userDocStream() =>
      _db.collection('User').doc(userId).snapshots();

  Stream<int> _countStream(CollectionReference<Map<String, dynamic>> col) =>
      col.snapshots().map((qs) => qs.size);

  @override
  Widget build(BuildContext context) {
    final followersCol = _db.collection('User').doc(userId).collection('followersList');
    final followingCol = _db.collection('User').doc(userId).collection('followingList');
    final playlistsCol = _db.collection('User').doc(userId).collection('Playlists');
    final reviewsCol   = _db.collection('User').doc(userId).collection('Reviews');

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
            'Profilo utente',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 0.2),
          ),
        ),
      ),

      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userDocStream(),
        builder: (context, snap) {
          final data = snap.data?.data();
          final username = (data?['username'] as String?) ?? 'Utente';
          final likes    = (data?['likes'] as num?)?.toInt() ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                // Header card stondato (clip + border)
                Material(
                  color: kCard,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: kBorder),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Avatar iniziale con gradiente
                        Container(
                          width: 64, height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [kGradA, kGradB]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _initial(username),
                            style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Username su due righe se lungo
                        Expanded(
                          child: Text(
                            username,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Riga contatori (followers / following)
                Row(
                  children: [
                    Expanded(
                      child: _StatPill(
                        label: 'Followers',
                        stream: _countStream(followersCol),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatPill(
                        label: 'Following',
                        stream: _countStream(followingCol),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Riga contatori (likes / reviews / playlists)
                Row(
                  children: [
                    Expanded(
                      child: _StaticPill(label: 'Likes', value: likes),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatPill(
                        label: 'Recensioni',
                        stream: _countStream(reviewsCol),
                        onTap: () {
                          // 🔁 Sostituisci con la tua route
                          Navigator.pushNamed(context, '/showUserReviews', arguments: userId);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatPill(
                        label: 'Playlist',
                        stream: _countStream(playlistsCol),
                        onTap: () {
                          // 🔁 Sostituisci con la tua route
                          Navigator.pushNamed(context, '/userPlaylist', arguments: userId);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Sezione scorciatoie (card tappabili)
                _ActionCard(
                  icon: Icons.queue_music_rounded,
                  title: 'Vedi playlist',
                  subtitle: 'Tutte le playlist pubbliche',
                  onTap: () => Navigator.pushNamed(context, '/userPlaylist', arguments: userId),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.rate_review_rounded,
                  title: 'Vedi recensioni',
                  subtitle: 'Tutte le recensioni dell’utente',
                  onTap: () => Navigator.pushNamed(context, '/showUserReviews', arguments: userId),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _initial(String name) {
    final s = name.trim();
    return s.isEmpty ? 'U' : s.characters.first.toUpperCase();
  }
}

/// ========== WIDGETS ==========

class _StatPill extends StatelessWidget {
  final String label;
  final Stream<int> stream;
  final VoidCallback? onTap;

  const _StatPill({required this.label, required this.stream, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = StreamBuilder<int>(
      stream: stream,
      builder: (context, snap) {
        final value = snap.data;
        return _pill(
          label: label,
          value: value == null ? '…' : value.toString(),
        );
      },
    );

    return onTap == null
        ? child
        : InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: child,
    );
  }

  Widget _pill({required String label, required String value}) {
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [kGradA, kGradB],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(b),
              blendMode: BlendMode.srcIn,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaticPill extends StatelessWidget {
  final String label;
  final int value;
  const _StaticPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [kGradA, kGradB],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(b),
              blendMode: BlendMode.srcIn,
              child: Text(
                '$value',
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: Icon(icon, color: Colors.white70),
            ),
            title: Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(color: Colors.white60),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ),
        ),
      ),
    );
  }
}
