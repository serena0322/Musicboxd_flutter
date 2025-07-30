import 'package:flutter/material.dart';
import '../services/deezer_service.dart';
import '../Classes/Track.dart';
import 'Review_Screen.dart';

class AddSongBottomSheet extends StatefulWidget {
  const AddSongBottomSheet({Key? key}) : super(key: key);

  @override
  State<AddSongBottomSheet> createState() => _AddSongBottomSheetState();
}

class _AddSongBottomSheetState extends State<AddSongBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Track> _filteredTracks = [];

  void _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _filteredTracks.clear());
      return;
    }

    try {
      final results = await searchTracks(query);
      setState(() {
        _filteredTracks = results;
      });
      _focusNode.unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Errore nella ricerca"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Add a Song",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'PoppinsBold',
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
                    color: const Color(0xFF1A1A1A),
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _filteredTracks.length,
                      itemBuilder: (context, index) {
                        final track = _filteredTracks[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              track.album.cover,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            track.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            track.artist.name,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.pop(context); // Chiude la bottom sheet
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReviewScreen(track: track),
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
        );
      },
    );
  }
}
