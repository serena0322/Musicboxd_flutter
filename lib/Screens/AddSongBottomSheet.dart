import 'package:flutter/material.dart';
import '../services/deezer_service.dart';
import '../Classes/Track.dart';


class AddSongBottomSheet extends StatefulWidget {
  const AddSongBottomSheet({Key? key}) : super(key: key);

  @override
  State<AddSongBottomSheet> createState() => _AddSongBottomSheetState();
}

class _AddSongBottomSheetState extends State<AddSongBottomSheet> {
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
    } catch (e) {
      print("Errore durante la ricerca: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F0F),
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
                  fontSize: 26,
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
                    hintText: 'Name of song',
                    hintStyle: TextStyle(color: Colors.white54),
                    icon: Icon(Icons.search, color: Colors.white54),
                  ),
                  onSubmitted: _search,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filteredTracks.length,
                  itemBuilder: (context, index) {
                    final track = _filteredTracks[index];
                    return ListTile(
                      leading: Image.network(
                        track.coverUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                      title: Text(
                        track.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        track.artist,
                        style: const TextStyle(color: Colors.white60),
                      ),
                      onTap: () {
                        Navigator.pop(context, track);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
