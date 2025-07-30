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

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  String username = '...';
  List<String> currentItems = [];
  bool showList = false;

  @override
  void initState() {
    super.initState();
    _fetchUsername();
  }

  void _fetchUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('User').doc(user.uid).get();
      setState(() {
        username = doc.exists ? (doc['username'] ?? 'Sconosciuto') : 'Utente non trovato';
      });
    } else {
      setState(() {
        username = 'Non autenticato';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProfileViewModel>(context);
    final user = viewModel.profileData;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 47),
            Center(
              child: Text(
                user?.username ?? '...',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'PoppinsBold',
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 6),
            Expanded(
              child: showList
                  ? buildList()  // Se mostra una lista (Diary, Collection, etc.)
                  : buildProfileOptions(context, viewModel), // Profilo principale
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProfileOptions(BuildContext context, ProfileViewModel viewModel) {
    // Avvolgo il container in uno scroll view per essere sicuri che il contenuto sia scrollabile se necessario
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        color: const Color(0xFF1E1E1E),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _clickableItem('Reviews : ${viewModel.reviews}', routeName: '/reviews'),
            const SizedBox(height: 20),
            _clickableItem('Playlist : ${viewModel.playlists}', routeName: '/playlist'),
            const SizedBox(height: 20),
            _clickableItem('Likes : ${viewModel.profileData?.like ?? 0}'),
            const SizedBox(height: 20),
            _clickableItem('Followers and Following', routeName: '/network'),
            const SizedBox(height: 20),
            _clickableItem('Settings', bold: true, routeName: '/settings'),
          ],
        ),
      ),
    );
  }

  Widget buildList() {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.only(bottom: 30),
      child: ListView.builder(
        itemCount: currentItems.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(
            currentItems[index],
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _clickableItem(String text, {bool bold = false, String? routeName, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? (routeName != null ? () => Navigator.pushNamed(context, routeName) : null),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
