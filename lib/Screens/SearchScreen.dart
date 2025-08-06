import 'package:flutter/material.dart';
import '../Classes/Track.dart';
import '../services/deezer_service.dart';
import 'TrackInfoScreen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Track> _filteredTracks = [];

  @override
  void initState() {
    super.initState();
    _filteredTracks = [];
  }

  void _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredTracks.clear();
      });
      return;
    }

    try {
      final results = await searchTracks(query);
      setState(() {
        _filteredTracks = results;
      });
      _focusNode.unfocus();
    } catch (e, st) {
      debugPrint('Errore ricerca: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // come android:background="@color/black"
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 47),
              const Center(
                child: Text(
                  "Search",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'PoppinsBold', // Deve essere dichiarato in pubspec.yaml
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Cerca su Musicboxd...',
                    hintStyle: TextStyle(color: Colors.white54),
                    icon: Icon(Icons.search, color: Colors.white54),
                  ),
                  onSubmitted: _search,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  color: const Color(0xFF1A1A1A), // come @color/scrollView
                  child: ListView.builder(
                    itemCount: _filteredTracks.length,
                    itemBuilder: (context, index) {
                      final track = _filteredTracks[index];
                      return ListTile(
                        leading: Image.network(
                          track.album.cover,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                        title: Text(
                          track.title,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          track.artist.name,
                          style: const TextStyle(color: Colors.white60),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrackInfoScreen(
                                track: track,
                                coverUrl: track.album.cover, // URL della cover
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
