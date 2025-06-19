import 'package:flutter/material.dart';

class Track {
  final String title;

  Track(this.title);
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Track> _allTracks = [
    Track("Song A"),
    Track("Song B"),
    Track("Another Track"),
    Track("Example"),
  ]; // Simulazione dati
  List<Track> _filteredTracks = [];

  @override
  void initState() {
    super.initState();
    _filteredTracks = [];
  }

  void _search(String query) {
    final results = _allTracks
        .where((track) => track.title.toLowerCase().contains(query.toLowerCase()))
        .toList();

    setState(() {
      _filteredTracks = results;
    });

    // Nasconde la tastiera
    _focusNode.unfocus();
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
                        title: Text(
                          track.title,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Hai selezionato: ${track.title}"),
                              backgroundColor: Colors.grey[900],
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
