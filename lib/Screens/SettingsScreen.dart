import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  late User _currentUser;
  DocumentReference<Map<String, dynamic>>? _userDocRef;

  String _username = '';
  String _firstName = '';
  String _lastName = '';
  String _email = '';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  Future<void> _initializeUserData() async {
    _currentUser = auth.currentUser!;
    _userDocRef = firestore.collection('User').doc(_currentUser.uid);

    try {
      final docSnapshot = await _userDocRef!.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        setState(() {
          _username = data['username'] ?? '';
          _firstName = data['firstName'] ?? '';
          _lastName = data['lastName'] ?? '';
          _email = data['email'] ?? _currentUser.email ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore nel caricamento dei dati")),
      );
    }
  }

  Future<void> _updateData(String fieldName, String currentValue, String dialogTitle, String hint) async {
    final controller = TextEditingController(text: currentValue);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dialogTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _userDocRef!.set({fieldName: result}, SetOptions(merge: true));
        setState(() {
          switch (fieldName) {
            case 'username':
              _username = result;
              break;
            case 'firstName':
              _firstName = result;
              break;
            case 'lastName':
              _lastName = result;
              break;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$dialogTitle aggiornato con successo")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore durante l'aggiornamento: $e")),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Esci'),
        content: const Text('Sei sicuro di voler uscire?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sì')),
        ],
      ),
    );
    if (confirm == true) {
      await auth.signOut();
      Navigator.of(context).pushNamed('/login');
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina account'),
        content: const Text('Sei sicuro di voler eliminare il tuo account? Questa operazione è irreversibile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sì')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _userDocRef!.delete();
        await _currentUser.delete();

        // Puoi pulire eventuali preferenze locali qui, se necessario

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account eliminato con successo')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore durante l'eliminazione: $e")),
        );
      }
    }
  }

  void _navigateToSecurity() {
    Navigator.of(context).pushNamed('/passwordAndAuthentication'); // Cambia con la tua route
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildClickableText(
              label: 'Signed in as $_username',
              onTap: () => _updateData('username', _username, 'Username', 'Inserisci username'),
              textColor: Colors.grey,
              fontSize: 20,
            ),
            const SizedBox(height: 16),
            _buildClickableText(
              label: 'Logout',
              onTap: _signOut,
              textColor: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 24),
            _buildClickableText(
              label: 'Password and authentication',
              onTap: _navigateToSecurity,
            ),
            const SizedBox(height: 16),
            _buildClickableText(
              label: 'First name: $_firstName',
              onTap: () => _updateData('firstName', _firstName, 'Nome', 'Inserisci nome'),
            ),
            const SizedBox(height: 16),
            _buildClickableText(
              label: 'Last name: $_lastName',
              onTap: () => _updateData('lastName', _lastName, 'Cognome', 'Inserisci cognome'),
            ),
            const SizedBox(height: 16),
            _buildClickableText(
              label: 'Email: $_email',
              onTap: null,
            ),
            const SizedBox(height: 24),
            _buildClickableText(
              label: 'Delete account',
              onTap: _deleteAccount,
              textColor: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClickableText({
    required String label,
    required void Function()? onTap,
    Color textColor = Colors.grey,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final textWidget = Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
        decoration: onTap != null ? TextDecoration.underline : null,
      ),
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: textWidget,
      ),
    );
  }
}
