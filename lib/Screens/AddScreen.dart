import 'package:flutter/material.dart';

class Track {
  final String title;

  Track(this.title);
}

class AddScreen extends StatefulWidget {
  const AddScreen({Key? key}) : super(key: key);

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Track> _allTracks = [
    Track("Song A"),
    Track("Track B"),
    Track("Another Song"),
    Track("Example Song"),
  ]; // Dati simulati
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

    _focusNode.unfocus(); // Nasconde la tastiera
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
                  "Add a Song",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'PoppinsBold', // Definito in pubspec.yaml
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
                    hintText: 'Name of song',
                    hintStyle: TextStyle(color: Colors.white54),
                    icon: Icon(Icons.search, color: Colors.white54),
                  ),
                  onSubmitted: _search,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  color: const Color(0xFF1A1A1A), // corrispondente a @color/scrollView
                  padding: const EdgeInsets.only(bottom: 56), // paddingBottom="56dp"
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
