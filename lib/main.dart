import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'Screens/SignInScreen.dart';
import 'package:musicboxd_flutter/repositories/UserRepository.dart';
import 'firebase_options.dart';
import 'Classes/AuthWrapper.dart';
import 'Classes/Track.dart';
import 'Screens/ActivityScreen.dart';
import 'Screens/AddSongBottomSheet.dart';
import 'Screens/ChangePasswordScreen.dart';
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
import 'Screens/UserProfile.dart';
import 'Viewmodel/profile_viewmodel.dart';
import 'object/user_repository.dart' hide UserRepository;

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Localizzazione italiana
  Intl.defaultLocale = 'it_IT';
  await initializeDateFormatting('it_IT', null);

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Esegui un test Firestore solo in debug e dopo il primo frame
  if (kDebugMode) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final snap = await FirebaseFirestore.instance.collection('test').limit(1).get();
        // ignore: avoid_print
        print('Firestore test OK: ${snap.docs.length} documenti trovati');
      } catch (e) {
        // ignore: avoid_print
        print('Firestore test FAILED: $e');
      }
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Musicboxd',
      debugShowCheckedModeBanner: false,
      locale: const Locale('it', 'IT'),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('it', 'IT'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        fontFamily: 'Poppins',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
        // (facoltativo) Colori generali
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white70,
          surface: Colors.black,
        ),
      ),

      // Splash -> AuthWrapper
      home: const SplashScreen(
        duration: Duration(seconds: 3),
        nextScreen: AuthWrapper(),
      ),

      // Route statiche
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const SignInScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/network': (context) => const NetworkScreen(),
        '/playlist': (context) => const PlaylistScreen(),
        '/reviews': (context) => const ShowReviewsScreen(),
        '/passwordAndAuthentication': (context) => const ChangePasswordScreen(),
      },

      // Route con argomenti (tipizzata e difensiva)
      onGenerateRoute: (settings) {
        if (settings.name == '/userProfile') {
          final args = settings.arguments;
          if (args is String && args.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => UserProfile(userId: args),
              settings: settings,
            );
          } else {
            // fallback sicuro se gli argomenti mancano/sono invalidi
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Parametro mancante per /userProfile')),
              ),
              settings: settings,
            );
          }
        }
        return null; // lascia che passi a onUnknownRoute
      },

      // Fallback per route sconosciute
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(child: Text('Pagina non trovata')),
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  final String? destination;
  const MainPage({super.key, this.destination});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final UserRepository _userRepository = UserRepository();

  // ATTENZIONE: SearchScreen(userId: '') -> valuta di passare l'UID reale
  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(userId: ''), // <-- considera di iniettarlo da AuthWrapper/Provider
    SizedBox.shrink(),        // placeholder tab "Aggiungi"
    ActivityScreen(),
    ProfileScreen(),
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
    try {
      final user = await _userRepository.loadMyBasicData();
      if (user != null) {
        // ignore: avoid_print
        print('Utente caricato: ${user.username}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Errore caricamento utente: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final textScale = MediaQuery.of(context)
        .textScaler
        .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2);

    final isCompact = size.width < 360;
    final iconSize = isCompact ? 22.0 : 26.0;
    final selectedFontSize   = isCompact ? 10.0 : 12.0;
    final unselectedFontSize = isCompact ? 10.0 : 12.0;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: const EdgeInsets.only(bottom: 4),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScale),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.black,
            currentIndex: _currentIndex,
            onTap: _onTap,
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
      if (!mounted) return;

      if (selectedTrack != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReviewScreen(track: selectedTrack)),
        );
      }
    } else {
      setState(() => _currentIndex = index);
    }
  }
}
