import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'Screens/ActivityScreen.dart';
import 'Screens/AddScreen.dart';
import 'Screens/HomeScreen.dart';
import 'Screens/LoginScreen.dart';
import 'Screens/NetworkScreen.dart';
import 'Screens/PlaylistScreen.dart';
import 'Screens/ProfileScreen.dart';
import 'Screens/SearchScreen.dart';
import 'Screens/SettingsScreen.dart';
import 'Screens/SplashScreen.dart';
import 'firebase_options.dart';


//
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  testFirestoreConnection(); // solo per attivare Firestore
  runApp(MyApp());
}

//verifica file trovati su Firestore
void testFirestoreConnection() async {
  final snapshot = await FirebaseFirestore.instance.collection('test').get();
  print("Firestore test: ${snapshot.docs.length} documenti trovati");
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Musicboxd',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: StreamBuilder<User?>( // controllo autenticazione
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SplashScreen(duration: const Duration(seconds: 3), nextScreen: const HomeScreen());
          } else if (snapshot.hasData) {
            return const MainPage();
          } else {
            return LoginScreen();
          }
        },
      ),
      routes: {
        '/settings': (context) => const SettingsScreen(),
        '/network': (context) => NetworkScreen(),
        '/playlist': (context) => const PlaylistScreen(),
      },
    );
  }
}

class MainPage extends StatefulWidget {
  final String? destination;

  const MainPage({Key? key, this.destination}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const AddScreen(),
    ActivityScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    const destinations = ['home', 'search', 'add', 'activity', 'profile'];
    final index = destinations.indexOf(widget.destination ?? 'home');
    _currentIndex = index != -1 ? index : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.black,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Cerca'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Aggiungi'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Attività'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profilo'),
        ],
      ),
    );
  }
}