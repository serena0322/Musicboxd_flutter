import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../Classes/Review.dart';
import '../Classes/Track.dart';
import '../screens/TrackInfoScreen.dart';
import '../services/deezer_service.dart';

const kBg    = Color(0xFF0E0F12);
const kCard  = Color(0xFF151821);
const kBorder= Color(0x22FFFFFF);
const kGradA = Color(0xFFB5179E);
const kGradB = Color(0xFF00E5FF);


class TrackSection {
  final String title;
  final List<Track> tracks;
  const TrackSection(this.title, this.tracks);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<TrackSection> _sections = [];
  bool _isLoading = true;
  String? _errorMessage;
  Set<String> _followingIds = {};
  final Map<String, String> _usernameCache = {};

  static const _bg = Color(0xFF0E0F12);
  static const _card = Color(0xFF151821);
  static const _border = Color(0x22FFFFFF);
  static const _gradA = Color(0xFFB5179E);
  static const _gradB = Color(0xFF00E5FF);

  Color _indicatorColor = Colors.deepPurple;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (_tabController.indexIsChanging) return;
        setState(() {
          _indicatorColor =
          _tabController.index == 0 ? Colors.deepPurple : Colors.purpleAccent;
        });
      });
    _loadAllSections();
    _loadFollowingIds();
  }

  String _formatDate(Timestamp ts) =>
      DateFormat('d MMM y, HH:mm', 'it_IT').format(ts.toDate());

  Future<void> _loadFollowingIds() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('User')
        .doc(uid)
        .collection('followingList')
        .get();
    setState(() => _followingIds = snap.docs.map((d) => d.id).toSet());
  }

  Stream<List<Review>> _homeReviewsStream() {
    return FirebaseFirestore.instance
        .collectionGroup('Reviews')
        .limit(200)
        .snapshots()
        .map((snap) {
      final all = snap.docs.map((d) => Review.fromFirestore(d)).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (_followingIds.isEmpty) return all;
      final followed = <Review>[];
      final others = <Review>[];
      for (final r in all) {
        (_followingIds.contains(r.sourceUserId) ? followed : others).add(r);
      }
      final out = <Review>[]
        ..addAll(followed.take(10))
        ..addAll(others.take(20))
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return out;
    });
  }

  Future<String> _usernameFor(String uid) async {
    if (_usernameCache.containsKey(uid)) return _usernameCache[uid]!;
    final doc =
    await FirebaseFirestore.instance.collection('User').doc(uid).get();
    final name = (doc.data()?['username'] as String?) ?? uid;
    _usernameCache[uid] = name;
    return name;
  }

  Future<void> _loadAllSections() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _sections.clear();
    });

    try {
      final futures = await Future.wait<List<Track>>([
        globalCharts(),
        searchTracks("pop"),
        searchTracks("rock"),
        searchTracks("hip hop"),
        searchTracks("indie"),
        searchTracks("electronic"),
        searchTracks("italian"),
        searchTracks("new"),
      ].map((f) async {
        try {
          final list = await f;
          return list.take(20).toList();
        } catch (_) {
          return <Track>[];
        }
      }));

      final built = <TrackSection>[
        TrackSection("Top Charts", futures[0]),
        TrackSection("Pop Hits", futures[1]),
        TrackSection("Rock Classics", futures[2]),
        TrackSection("Hip-Hop Vibes", futures[3]),
        TrackSection("Indie Discoveries", futures[4]),
        TrackSection("Electronic Essentials", futures[5]),
        TrackSection("Italian Favorites", futures[6]),
        TrackSection("Fresh Finds", futures[7]),
      ].where((s) => s.tracks.isNotEmpty).toList();

      setState(() {
        _sections.addAll(built);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Errore nel caricamento contenuti: $e";
        _isLoading = false;
      });
    }
  }

  void _openTrack(Track track) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackInfoScreen(
          track: track,
          coverUrl: track.album.cover,
          userId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        // Titolo più grande degli altri screen
        title: ShaderMask(
          shaderCallback: (Rect b) => const LinearGradient(
            colors: [_gradA, _gradB],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0.0, 0.7],
          ).createShader(b),
          blendMode: BlendMode.srcIn,
          child: const Text(
            'Musicboxd',
            style: TextStyle(
              fontSize: 30,           // più grande
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _indicatorColor,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Music'),
            Tab(text: 'Reviews'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMusicTab(),
          _buildReviewsTab(),
        ],
      ),
    );
  }

  // --- TAB: MUSIC ---
  Widget _buildMusicTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _loadAllSections,
        color: Colors.white,
        backgroundColor: _card,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }
    if (_sections.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAllSections,
        color: Colors.white,
        backgroundColor: _card,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                "Nessun contenuto disponibile",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllSections,
      color: Colors.white,
      backgroundColor: _card,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _sections.length,
        itemBuilder: (context, index) {
          final section = _sections[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _SectionHeader(title: section.title),
              const SizedBox(height: 8),
              _SectionCarousel(
                tracks: section.tracks,
                onTapTrack: _openTrack,
              ),
            ],
          );
        },
      ),
    );
  }

  // --- TAB: REVIEWS ---
  Widget _buildReviewsTab() {
    return Container(
      color: _bg,
      child: StreamBuilder<List<Review>>(
        stream: _homeReviewsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snap.hasError) {
            return Center(
              child: Text('Errore: ${snap.error}',
                  style: const TextStyle(color: Colors.white70)),
            );
          }
          final reviews = snap.data ?? const <Review>[];
          if (reviews.isEmpty) {
            return const Center(
              child: Text('Nessuna recensione disponibile',
                  style: TextStyle(color: Colors.white70)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: _border),
            itemBuilder: (context, index) {
              final r = reviews[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                tileColor: _card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _border),
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: r.albumCoverUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(width: 48, height: 48, color: const Color(0xFF2A2A2A)),
                    errorWidget: (_, __, ___) =>
                        Container(width: 48, height: 48, color: const Color(0xFF2A2A2A)),
                  ),
                ),
                title: Text(
                  '${r.songTitle} • ${r.artistName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: FutureBuilder<String>(
                  future: _usernameFor(r.sourceUserId),
                  builder: (context, s) {
                    final author = s.data ?? r.sourceUserId;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'di $author • ${_formatDate(r.timestamp)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                        ),
                        if (r.reviewText.isNotEmpty) const SizedBox(height: 4),
                        if (r.reviewText.isNotEmpty)
                          Text(
                            r.reviewText,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                      ],
                    );
                  },
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                    Text(r.rating.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}


class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: const Color(0x22FFFFFF)), // underline sottile
        ],
      ),
    );
  }
}


class _SectionCarousel extends StatelessWidget {
  final List<Track> tracks;
  final void Function(Track) onTapTrack;

  const _SectionCarousel({
    Key? key,
    required this.tracks,
    required this.onTapTrack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 188,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final t = tracks[index];
          return GestureDetector(
            onTap: () => onTapTrack(t),
            child: SizedBox(
              width: 136,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Material(
                      color: kCard,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kBorder),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CachedNetworkImage(
                          imageUrl: t.album.cover,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: const Color(0xFF2A2A2A)),
                          errorWidget: (_, __, ___) =>
                              Container(color: const Color(0xFF2A2A2A)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    t.artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
