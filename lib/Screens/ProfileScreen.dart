import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String username = '...';
  List<String> currentItems = [];
  bool showList = false;

  final List<Tab> myTabs = const [
    Tab(text: 'Profile'),
    Tab(text: 'Diary'),
    Tab(text: 'Collection'),
    Tab(text: 'To Listen'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: myTabs.length, vsync: this);
    _fetchUsername();

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        switch (_tabController.index) {
          case 0:
            showList = false;
            break;
          case 1:
            showList = true;
            currentItems = ['Diario 1', 'Appunto 2', 'Nota 3'];
            break;
          case 2:
            showList = true;
            currentItems = ['Lista Album Preferiti', 'Top 10 Canzoni', 'Playlist Chill'];
            break;
          case 3:
            showList = true;
            currentItems = ['Album da ascoltare', 'Da riascoltare', 'Nuove uscite'];
            break;
        }
      });
    });
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
    final backgroundColor = Colors.black;
    final scrollViewColor = const Color(0xFF1E1E1E); // esempio

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 47),
            Center(
              child: Text(
                username,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'PoppinsBold',
                ),
              ),
            ),
            const SizedBox(height: 20),
            TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _getTabIndicatorColor(_tabController.index),
              tabs: myTabs,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: showList
                  ? Container(
                color: scrollViewColor,
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
              )
                  : Container(
                color: scrollViewColor,
                padding: const EdgeInsets.only(bottom: 30),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _clickableItem('Music'),
                      _clickableItem('Reviews'),
                      _clickableItem('Playlist', routeName: '/playlist'),
                      _clickableItem('Likes'),
                      _clickableItem('Followers and Following', routeName: '/network'),
                      _clickableItem('Settings', bold: true, routeName: '/settings'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTabIndicatorColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFF00C853); // R.color.home
      case 1:
        return const Color(0xFFFF4081); // R.color.add
      case 2:
        return Colors.tealAccent; // R.color.teal_200
      case 3:
        return const Color(0xFF536DFE); // R.color.profile
      default:
        return Colors.white;
    }
  }

  Widget _clickableItem(String text, {bool bold = false, String? routeName}) {
    return GestureDetector(
      onTap: routeName != null
          ? () {
        Navigator.pushNamed(context, routeName);
      }
          : null,
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
