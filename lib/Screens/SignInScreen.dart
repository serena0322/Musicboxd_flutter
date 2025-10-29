// lib/Screens/SignInScreen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _email.text.trim();
    final uname = _username.text.trim();
    final pwd = _password.text.trim();

    try {
      // 1) Verifica unicità username (case-insensitive)
      final unameKey = uname.toLowerCase();
      final taken = await FirebaseFirestore.instance
          .collection('User')
          .where('username_lc', isEqualTo: unameKey)
          .limit(1)
          .get();
      if (taken.docs.isNotEmpty) {
        setState(() => _error = 'Username già in uso');
        return;
      }

      // 2) Crea utente su FirebaseAuth
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pwd);
      final uid = cred.user?.uid ?? '';

      // 3) Salva documento utente su Firestore
      await FirebaseFirestore.instance.collection('User').doc(uid).set({
        'id': uid,
        'username': uname,
        'username_lc': unameKey,
        'email': email,
        'followers': 0,
        'following': 0,
        'createdAt': Timestamp.now(),
      });

      // 4) Email di verifica (facoltativa)
      await cred.user?.sendEmailVerification();

      // 5) Salva credenziali localmente
      final sp = await SharedPreferences.getInstance();
      await sp.setString('saved_email', email);
      await sp.setString('saved_username', uname);
      await sp.setString('saved_password', pwd);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrazione completata')),
      );

      // 6) Logout e ritorno alla Login svuotando lo stack
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _error = 'Email già registrata';
            break;
          case 'invalid-email':
            _error = 'Email non valida';
            break;
          case 'weak-password':
            _error = 'Password troppo debole';
            break;
          default:
            _error = e.message ?? e.code;
        }
      });
    } catch (e) {
      setState(() => _error = 'Errore durante la registrazione: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),

                    // Titolo grande centrato
                    const Text(
                      'Sign In',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Email
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: const Color(0xFF39424A),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Inserisci email';
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                          return 'Email non valida';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Username
                    TextFormField(
                      controller: _username,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Username',
                        hintStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: const Color(0xFF39424A),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Inserisci username';
                        if (t.length < 3) return 'Minimo 3 caratteri';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _loading ? null : _register(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: const Color(0xFF39424A),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Inserisci password';
                        if (v.length < 6) return 'Minimo 6 caratteri';
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Pulsante gradiente a tutta larghezza (REGISTER)
                    SizedBox(
                      height: 56,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _loading ? null : _register, // <-- usa _login
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF2EA6), // Fucsia
                                Color(0xFF4BC0F8), // Azzurro
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: _loading
                              ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Text(
                            'SignIn', // <-- etichetta corretta per la schermata di accesso
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Link per tornare alla Login
                    Center(
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/login'),
                        child: const Text(
                          'Hai già un account? Vai al Login',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
