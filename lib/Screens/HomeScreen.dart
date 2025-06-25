import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Color _indicatorColor = Colors.deepPurple; // Colore iniziale

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    setState(() {
      switch (_tabController.index) {
        case 0:
          _indicatorColor = Colors.deepPurple; // home
          break;
        case 1:
          _indicatorColor = Colors.purpleAccent; // add
          break;
        case 2:
          _indicatorColor = Colors.teal; // teal_200
          break;
        case 3:
          _indicatorColor = Colors.tealAccent; // profile
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              colors: [Colors.purple, Colors.tealAccent],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0.0, 0.6],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: const Text(
            'Musicboxd',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _indicatorColor,
          tabs: const [
            Tab(text: 'Tab 1'),
            Tab(text: 'Tab 2'),
            Tab(text: 'Tab 3'),
            Tab(text: 'Tab 4'),
          ],
        ),
      ),
      body: ListView.builder(
        itemCount: 20, // Simulazione contenuto RecyclerView
        itemBuilder: (context, index) {
          return ListTile(
            title: Text('Elemento $index'),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
