import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:musicboxd_flutter/Screens/ChangePasswordScreen.dart';
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
import 'Screens/SignInScreen.dart';
import 'Screens/SearchScreen.dart';
import 'Screens/SettingsScreen.dart';
import 'Screens/ShowReviewsScreen.dart';
import 'Screens/SplashScreen.dart';
import 'Screens/UserProfile.dart';
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
        '/network': (context) => const NetworkScreen(),
        '/playlist': (context) => const PlaylistScreen(),
        '/reviews': (context) => const ShowReviewsScreen(),
        '/register': (context) => const SignInScreen(),
        '/passwordAndAuthentication': (context) => const ChangePasswordScreen(),

        '/userProfile': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return UserProfile(userId: userId);
        },
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
    // Adattività semplice
    final size = MediaQuery.of(context).size;
    final textScale = MediaQuery.of(context).textScaler.clamp(
        minScaleFactor: 0.9, maxScaleFactor: 1.2); // evita label troppo grandi
    final isCompact = size.width < 360;

    final iconSize = isCompact ? 22.0 : 26.0;
    final selectedFontSize   = isCompact ? 10.0 : 12.0;
    final unselectedFontSize = isCompact ? 10.0 : 12.0;

    return Scaffold(
      // Mantiene lo stato delle tab ed è più stabile su molti device
      body: IndexedStack(index: _currentIndex, children: _screens),

      bottomNavigationBar: SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: const EdgeInsets.only(bottom: 4), // piccola aria extra
        child: MediaQuery(
          // controlla l'effetto di grandi dimensioni font a livello di app
          data: MediaQuery.of(context).copyWith(textScaler: textScale),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.black,
            currentIndex: _currentIndex,
            onTap: _onTap,
            // ✅ dimensioni adattive
            iconSize: iconSize,
            selectedFontSize: selectedFontSize,
            unselectedFontSize: unselectedFontSize,
            showUnselectedLabels: true,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white60,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home),     label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.search),   label: 'Cerca'),
              BottomNavigationBarItem(icon: Icon(Icons.add_box),  label: 'Aggiungi'),
              BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Attività'),
              BottomNavigationBarItem(icon: Icon(Icons.person),   label: 'Profilo'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(int index) async {
    if (index == 2) {
      final selectedTrack = await showModalBottomSheet<Track>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AddSongBottomSheet(),
      );

      if (selectedTrack != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewScreen(track: selectedTrack),
          ),
        );
      }
    } else {
      setState(() => _currentIndex = index);
    }
  }

}