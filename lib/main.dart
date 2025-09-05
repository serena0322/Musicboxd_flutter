import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:musicboxd_flutter/repositories/UserRepository.dart';
import 'package:provider/provider.dart';
import 'Classes/AuthWrapper.dart';
import 'Classes/Track.dart';
import 'Screens/ActivityScreen.dart';
import 'Screens/AddSongBottomSheet.dart';
import 'Screens/HomeScreen.dart';
import 'Screens/LoginScreen.dart';
import 'Screens/NetworkScreen.dart';
import 'Screens/PlaylistScreen.dart';
import 'Screens/ProfileScreen.dart';
import 'Screens/Review_Screen.dart';
import 'Screens/SearchScreen.dart';
import 'Screens/SettingsScreen.dart';
import 'Screens/ShowReviewsScreen.dart';
import 'Screens/SplashScreen.dart';
import 'Viewmodel/profile_viewmodel.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
      ],
      child: MyApp(),
    ),
  );
}

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
      home: SplashScreen(duration: const Duration(seconds: 3), nextScreen: const AuthWrapper()),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/network': (context) => NetworkScreen(),
        '/playlist': (context) => const PlaylistScreen(),
        '/reviews': (context) => const ShowReviewsScreen(),
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
  final UserRepository _userRepository = UserRepository();

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(userId: '',),
    Container(),
    ActivityScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    _loadUserData();

    const destinations = ['home', 'search', 'add', 'activity', 'profile'];
    final index = destinations.indexOf(widget.destination ?? 'home');
    _currentIndex = index != -1 ? index : 0;
  }

  Future<void> _loadUserData() async {
    final user = await _userRepository.loadMyBasicData();
    if (user != null) {
      print('Utente caricato: ${user.username}');
      // esempio: UserViewModel().setUser(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) async {
          if (index == 2) {
            final selectedTrack = await showModalBottomSheet<Track>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddSongBottomSheet(),
            );

            if (selectedTrack != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReviewScreen(track: selectedTrack),
                ),
              );
            }
          } else {
            setState(() => _currentIndex = index);
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        items: List.generate(5, (index) {
          final isSelected = _currentIndex == index;

          final List<IconData> icons = [
            Icons.home,
            Icons.search,
            Icons.add_box,
            Icons.favorite,
            Icons.person,
          ];

          final List<String> labels = [
            'Home',
            'Cerca',
            'Aggiungi',
            'Attività',
            'Profilo',
          ];

          final List<Color> activeColors = [
            Colors.purple,
            Colors.purpleAccent,
            Colors.pinkAccent,
            Colors.teal,
            Colors.tealAccent,
          ];

          return BottomNavigationBarItem(
            icon: Icon(
              icons[index],
              color: isSelected ? activeColors[index] : Colors.grey,
            ),
            label: labels[index],
          );
        }),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        selectedItemColor: Colors.transparent,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}