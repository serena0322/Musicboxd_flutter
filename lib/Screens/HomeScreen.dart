import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';


import '../Classes/Review.dart';
import '../Classes/Track.dart';
import '../screens/TrackInfoScreen.dart';
import '../services/deezer_service.dart';

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
  Color _indicatorColor = Colors.deepPurple;

  // Stato per tab Music
  final List<TrackSection> _sections = [];
  bool _isLoading = true;
  String? _errorMessage;
  Set<String> _followingIds = {};
  final Map<String, String> _usernameCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadAllSections();
    _loadFollowingIds(); // <-- carica utenti seguiti per il ranking reviews
  }

  String _formatDate(Timestamp ts) {
    final dt = ts.toDate();
    return DateFormat('d MMM y, HH:mm', 'it_IT').format(dt);
  }

  Future<void> _loadFollowingIds() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('User')
        .doc(uid)
        .collection('followingList')
        .get();
    setState(() {
      _followingIds = snap.docs.map((d) => d.id).toSet();
    });
  }

  Stream<List<Review>> _homeReviewsStream() {
    return FirebaseFirestore.instance
        .collectionGroup('Reviews')
        .limit(200)
        .snapshots()
        .map((snap) {
      final all = snap.docs.map((d) => Review.fromFirestore(d)).toList();

      // Ordina tutto per timestamp desc
      all.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Se non hai la lista dei seguiti, restituisci direttamente le più recenti
      if (_followingIds.isEmpty) {
        return all; // già ordinato desc
      }

      // Altrimenti fai la suddivisione (seguiti vs altri), poi riordina desc
      final followed = <Review>[];
      final others = <Review>[];
      for (final r in all) {
        if (_followingIds.contains(r.sourceUserId)) {
          followed.add(r);
        } else {
          others.add(r);
        }
      }

      final out = <Review>[]
        ..addAll(followed.take(10))
        ..addAll(others.take(20));

      // Ordina comunque desc per data
      out.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return out;
    });
  }


  Future<String> _usernameFor(String uid) async {
    if (_usernameCache.containsKey(uid)) return _usernameCache[uid]!;
    final doc = await FirebaseFirestore.instance.collection('User').doc(uid).get();
    final name = (doc.data()?['username'] as String?) ?? uid;
    _usernameCache[uid] = name;
    return name;
  }


  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _indicatorColor =
      _tabController.index == 0 ? Colors.deepPurple : Colors.purpleAccent;
    });
  }

  Future<void> _loadAllSections() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _sections.clear();
    });

    try {
      // Caricamenti in parallelo (limita a 20 brani per sezione)
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
          // In caso di errore su una sezione, ritorna lista vuota
          return <Track>[];
        }
      }));

      final sectionsBuilt = <TrackSection>[
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
        _sections.addAll(sectionsBuilt);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Errore nel caricamento contenuti: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              colors: [Colors.purple, Colors.tealAccent],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0.0, 0.6],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: const Text(
            'Musicboxd',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _indicatorColor,
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

  // --- TAB: MUSIC -> più canzoni in sezioni orizzontali ---
  Widget _buildMusicTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _loadAllSections,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(_errorMessage!, textAlign: TextAlign.center),
            )),
          ],
        ),
      );
    }
    if (_sections.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAllSections,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text("Nessun contenuto disponibile")),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllSections,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _sections.length,
        itemBuilder: (context, index) {
          final section = _sections[index];
          return _SectionCarousel(
            title: section.title,
            tracks: section.tracks,
            onTapTrack: _openTrack,
          );
        },
      ),
    );
  }

  void _openTrack(Track track) {
    final coverUrl = track.album.cover;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackInfoScreen(
          track: track,
          coverUrl: coverUrl,
          userId: userId,
        ),
      ),
    );
  }

  // --- TAB: REVIEWS (placeholder) ---
  Widget _buildReviewsTab() {
    return StreamBuilder<List<Review>>(
      stream: _homeReviewsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Errore: ${snap.error}'));
        }
        final reviews = snap.data ?? const <Review>[];
        if (reviews.isEmpty) {
          return const Center(child: Text('Nessuna recensione disponibile'));
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: reviews.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final r = reviews[index];

            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  r.albumCoverUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(width: 48, height: 48, color: Colors.grey.shade300),
                ),
              ),
              title: Text(
                '${r.songTitle} • ${r.artistName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r.reviewText.isEmpty ? '' : r.reviewText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                },
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, size: 18, color: Colors.amber),
                  Text(r.rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              isThreeLine: true,
            );
          },
        );
      },
    );
  }


  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }
}

// =================== WIDGET SEZIONE/CAROUSEL ===================

class _SectionCarousel extends StatelessWidget {
  final String title;
  final List<Track> tracks;
  final void Function(Track) onTapTrack;

  const _SectionCarousel({
    Key? key,
    required this.title,
    required this.tracks,
    required this.onTapTrack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              // Pulsante "Mostra tutti" opzionale: collega a schermo categoria
              // TextButton(
              //   onPressed: () {},
              //   child: const Text('Mostra tutti'),
              // ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 170,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: tracks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final t = tracks[index];
              final cover = t.album.cover;

              return GestureDetector(
                onTap: () => onTapTrack(t),
                child: SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            cover,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        t.artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
