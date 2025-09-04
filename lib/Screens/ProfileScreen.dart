import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Viewmodel/profile_viewmodel.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  String _username = '...';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _fetchUsername();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Carico i dati base del profilo una volta sola dal ViewModel (se previsto)
    if (!_initialized) {
      final vm = context.read<ProfileViewModel>();
      // Se il tuo VM ha un metodo di load, chiamalo qui.
      // vm.loadBasicUserData();
      _initialized = true;
    }
  }

  Future<void> _fetchUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _username = 'Non autenticato');
      return;
    }
    final doc =
    await FirebaseFirestore.instance.collection('User').doc(user.uid).get();
    setState(() {
      _username =
      doc.exists ? (doc.data()?['username'] as String? ?? 'Sconosciuto') : 'Utente non trovato';
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final user = vm.profileData;

    final displayName = user?.username?.isNotEmpty == true
        ? user!.username
        : _username;

    // Provo a interpretare i "likes": se non è un numero, mostro 0
    final likesCount = _parseLikesCount(user?.like);

    final followersCount = _safeInt(user?.followers);
    final followingCount = _safeInt(user?.following);

    return Scaffold(
      backgroundColor: const Color(0xFF0E0F12),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchUsername();
        },
        color: Colors.white,
        backgroundColor: Colors.black,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              expandedHeight: 280,
              pinned: true,
              elevation: 0,
              centerTitle: false,
              title: Transform.translate(
                offset: const Offset(0, 6),
                child: ShaderMask(
                  shaderCallback: (Rect bounds) => const LinearGradient(
                    colors: [Color(0xFFB5179E), Color(0xFF00E5FF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0.0, 0.7],
                  ).createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: const Text(
                    'Profilo',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _Header(
                  name: displayName ?? '...',
                  email: user?.email ?? '',
                ),
              ),
            ),


            // Section: Stats
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.favorite_border,
                        label: 'Likes',
                        value: _formatK(likesCount),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.person_add_alt_1_outlined,
                        label: 'Followers',
                        value: _formatK(followersCount),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.person_outline,
                        label: 'Following',
                        value: _formatK(followingCount),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Section: Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    _ActionTile(
                      icon: Icons.rate_review_outlined,
                      title: 'Le mie recensioni',
                      subtitle: 'Visualizza e gestisci le tue review',
                      onTap: () => Navigator.pushNamed(context, '/reviews'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.queue_music_outlined,
                      title: 'Playlist',
                      subtitle: 'Le tue raccolte',
                      onTap: () => Navigator.pushNamed(context, '/playlist'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.people_outline,
                      title: 'Followers e Seguiti',
                      subtitle: 'Rete e attività degli amici',
                      onTap: () => Navigator.pushNamed(context, '/network'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.settings_outlined,
                      title: 'Impostazioni',
                      subtitle: 'Account, privacy e preferenze',
                      onTap: () => Navigator.pushNamed(context, '/settings'),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _safeInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  int _parseLikesCount(dynamic like) {
    if (like == null) return 0;
    if (like is int) return like;
    if (like is num) return like.toInt();
    if (like is List) return like.length;
    if (like is Map) return like.length;
    return int.tryParse(like.toString()) ?? 0;
  }

  String _formatK(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

/// Header con gradiente, avatar dalle iniziali e dati utente
class _Header extends StatelessWidget {
  final String name;
  final String email;
  const _Header({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final initials = _initialsFrom(name);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF13151A), Color(0xFF1C1E26), Color(0xFF222736)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      // sposta tutto sotto la tacca + margine
      padding: EdgeInsets.fromLTRB(20, topInset + 56, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // ⬅️ centra nel Row
        children: [
          // Avatar
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFB5179E), Color(0xFF00E5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Center(
              child: Container(
                width: 82,
                height: 82,
                decoration: const BoxDecoration(
                  color: Color(0xFF0E0F12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Testi con altezza uguale all'avatar e contenuto centrato verticalmente
          Expanded(
            child: SizedBox(
              height: 86, // ⬅️ stessa altezza dell’avatar
              child: Column(
                mainAxisAlignment: MainAxisAlignment
                    .center, // ⬅️ centra username+email verticalmente
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isNotEmpty ? name : '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email.isNotEmpty ? email : '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 14,
                      height: 1.1,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initialsFrom(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'U';
    }
    return (parts[0].isNotEmpty ? parts[0][0] : 'U').toUpperCase() +
        (parts[1].isNotEmpty ? parts[1][0] : '');
  }
}

/// Card statistica (Likes / Followers / Following)
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 132), // più aria verticale
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x22FFFFFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icona
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF202434),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 10),
          // Numero (ridimensionabile se testo grande)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Etichetta SOTTO il numero
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 13,
              height: 1.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}


/// Card azione (Reviews, Playlist, Network, Settings)
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF151821),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF202434),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white70, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
