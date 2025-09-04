import 'dart:async';
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

  List<Track> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _searchNow(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await searchTracks(q);
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Errore nella ricerca';
        _loading = false;
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchNow(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0E0F12),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),

                // Titolo con gradiente
                ShaderMask(
                  shaderCallback: (Rect bounds) => const LinearGradient(
                    colors: [Color(0xFFB5179E), Color(0xFF00E5FF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0.0, 0.7],
                  ).createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: const Text(
                    "Aggiungi brano",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Barra di ricerca (pill)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF151821),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x22FFFFFF)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.white54, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _focusNode,
                            style: const TextStyle(color: Colors.white),
                            cursorColor: Colors.white70,
                            decoration: const InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: 'Cerca brano, artista…',
                              hintStyle: TextStyle(color: Colors.white54),
                            ),
                            onChanged: _onChanged,
                            onSubmitted: _searchNow,
                            textInputAction: TextInputAction.search,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onChanged('');
                            },
                            child: const Icon(Icons.close, color: Colors.white38, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Lista risultati / stati
                Expanded(
                  child: _buildBody(scrollController),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController controller) {
    // Stato loading
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    // Stato errore
    if (_error != null) {
      return ListView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      );
    }

    // Nessun risultato / iniziale
    if (_results.isEmpty) {
      return ListView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Cerca un brano per iniziare.\nSuggerimento: prova il titolo o il nome dell’artista.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      );
    }

    // Lista piatta con divider sottili (stile tab Reviews)
    return ListView.separated(
      controller: controller,
      itemCount: _results.length,
      padding: const EdgeInsets.only(bottom: 16),
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        thickness: 0.7,
        color: Color(0x22FFFFFF),
      ),
      itemBuilder: (context, index) {
        final t = _results[index];
        final cover = t.album.cover;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              cover,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(width: 48, height: 48, color: Colors.grey.shade800),
            ),
          ),
          title: Text(
            t.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            t.artist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70),
          ),
          onTap: () {
            Navigator.pop(context); // chiude la bottom sheet
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReviewScreen(track: t)),
            );
          },
          // niente trailing per uno stile pulito
        );
      },
    );
  }
}
