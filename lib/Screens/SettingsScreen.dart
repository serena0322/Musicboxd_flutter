import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ===== palette coerente (stessa dell’app) =====
const kBg     = Color(0xFF0E0F12);
const kCard   = Color(0xFF151821);
const kBorder = Color(0x22FFFFFF);
const kGradA  = Color(0xFFB5179E);
const kGradB  = Color(0xFF00E5FF);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  late User _currentUser;
  DocumentReference<Map<String, dynamic>>? _userDocRef;

  String _username = '';
  String _firstName = '';
  String _lastName  = '';
  String _email     = '';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  Future<void> _initializeUserData() async {
    _currentUser  = _auth.currentUser!;
    _userDocRef   = _db.collection('User').doc(_currentUser.uid);

    try {
      final doc = await _userDocRef!.get();
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _username  = (data['username']  as String?) ?? '';
          _firstName = (data['firstName'] as String?) ?? '';
          _lastName  = (data['lastName']  as String?) ?? '';
          _email     = (data['email']     as String?) ?? _currentUser.email ?? '';
          _loading   = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore nel caricamento dei dati')),
      );
    }
  }

  Future<void> _updateData(String field, String current, String title, String hint) async {
    final controller = TextEditingController(text: current);

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kBorder),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kGradB),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          TextButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.pop(context, v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      await _userDocRef!.set({field: result}, SetOptions(merge: true));
      setState(() {
        if (field == 'username')  _username  = result;
        if (field == 'firstName') _firstName = result;
        if (field == 'lastName')  _lastName  = result;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title aggiornato con successo')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore durante l'aggiornamento: $e")),
      );
    }
  }

  Future<void> _signOut() async {
    final ok = await _confirmDialog('Esci', 'Sei sicura di voler uscire?');
    if (ok != true) return;
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamed('/login');
  }

  Future<void> _deleteAccount() async {
    final ok = await _confirmDialog('Elimina account',
        'Sei sicura di voler eliminare il tuo account? Questa operazione è irreversibile.');
    if (ok != true) return;

    try {
      await _userDocRef!.delete();
      await _currentUser.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account eliminato con successo')),
      );
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore durante l'eliminazione: $e")),
      );
    }
  }

  Future<bool?> _confirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kBorder),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sì')),
        ],
      ),
    );
  }

  void _navigateToSecurity() {
    Navigator.of(context).pushNamed('/passwordAndAuthentication');
  }

  @override
  Widget build(BuildContext context) {
    final initial = (_username.trim().isNotEmpty ? _username.trim()[0] : 'U').toUpperCase();

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [kGradA, kGradB],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0.0, 0.7],
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: const Text('Settings',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          children: [
            // --- HEADER PROFILO STONDATO (clip corretto) ---
            Material(
              color: kCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: kBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kGradA, kGradB]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  _username,
                  maxLines: 2, // va a capo se lungo
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                ),
                subtitle: Text(
                  _email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60),
                ),
                trailing: TextButton(
                  onPressed: () => _updateData('username', _username, 'Username', 'Inserisci username'),
                  child: const Text('Modifica', style: TextStyle(color: Color(0xFFB7A6FF))),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- sezione dati ---
            SettingsSection(
              children: [
                SettingsItem(
                  leading: iconBox(Icons.badge_rounded),
                  title: 'Nome',
                  subtitle: _firstName.isEmpty ? '—' : _firstName,
                  onTap: () => _updateData('firstName', _firstName, 'Nome', 'Inserisci nome'),
                ),
                SettingsItem(
                  leading: iconBox(Icons.badge_outlined),
                  title: 'Cognome',
                  subtitle: _lastName.isEmpty ? '—' : _lastName,
                  onTap: () => _updateData('lastName', _lastName, 'Cognome', 'Inserisci cognome'),
                ),
                SettingsItem(
                  leading: iconBox(Icons.mail_rounded),
                  title: 'Email',
                  subtitle: _email,
                  onTap: null,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --- sezione sicurezza ---
            SettingsSection(
              children: [
                SettingsItem(
                  leading: iconBox(Icons.lock_rounded),
                  title: 'Password e autenticazione',
                  subtitle: 'Gestisci password e sicurezza',
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                  onTap: _navigateToSecurity,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --- sezione azioni ---
            SettingsSection(
              children: [
                SettingsItem(
                  leading: iconBox(Icons.logout_rounded),
                  title: 'Logout',
                  subtitle: 'Esci dal tuo account',
                  onTap: _signOut,
                ),
                SettingsItem(
                  leading: iconBox(Icons.delete_forever_rounded),
                  title: 'Elimina account',
                  subtitle: 'Operazione irreversibile',
                  titleColor: Colors.redAccent,
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ===========================
///  WIDGET RIUTILIZZABILI
/// ===========================

class SettingsSection extends StatelessWidget {
  final List<Widget> children;
  const SettingsSection({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias, // fondamentale: clip di tutto
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, thickness: 1, color: kBorder),
          ],
        ],
      ),
    );
  }
}

class SettingsItem extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Widget? trailing;

  const SettingsItem({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
    this.titleColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: leading,
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: const TextStyle(color: Colors.white60)),
        trailing: trailing ?? const SizedBox.shrink(),
      ),
    );
  }
}

Widget iconBox(IconData icon, {Color? color}) {
  return Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kBorder),
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: color ?? Colors.white70),
  );
}
