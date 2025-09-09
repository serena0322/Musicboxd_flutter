import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Classes/Track.dart';
import '../services/deezer_service.dart';
import 'TrackInfoScreen.dart';

class SearchScreen extends StatefulWidget {
  final String userId;
  const SearchScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final Duration _debounceDuration = const Duration(milliseconds: 350);
  Timer? _debounce;

  List<Track> _results = [];
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {}); // aggiorna la visibilità dell’icona clear
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => _search(value));
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await searchTracks(q);
      if (!mounted) return;
      setState(() {
        _results = res;
        _isLoading = false;
      });
      _focusNode.unfocus();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Si è verificato un errore durante la ricerca.';
      });
    }
  }

  void _clear() {
    _searchController.clear();
    setState(() {
      _results = [];
      _error = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F12), // palette bottom sheet
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Titolo centrato con gradiente (nessuna freccia)
            Center(
              child: ShaderMask(
                shaderCallback: (Rect bounds) => const LinearGradient(
                  colors: [Color(0xFFB5179E), Color(0xFF00E5FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0.0, 0.7],
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const Text(
                  'Cerca brano',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Barra di ricerca stile pill
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
                        onChanged: _onQueryChanged,
                        onSubmitted: _search,
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: _clear,
                        child: const Icon(Icons.close, color: Colors.white38, size: 18),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Corpo
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return const _StateMessage(
        icon: Icons.error_outline,
        title: 'Errore',
        subtitle: 'Si è verificato un errore durante la ricerca.',
      );
    }
    if (_results.isEmpty) {
      return const _StateMessage(
        icon: Icons.search,
        title: 'Inizia a cercare',
        subtitle: 'Digita il titolo o l’artista per iniziare.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        thickness: 0.7,
        color: Color(0x22FFFFFF),
      ),
      itemBuilder: (context, index) {
        final t = _results[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: t.album.cover,
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TrackInfoScreen(
                  track: t,
                  coverUrl: t.album.cover,
                  userId: widget.userId,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _StateMessage({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white38, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
