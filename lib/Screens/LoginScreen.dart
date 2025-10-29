import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Classes/AuthWrapper.dart'; // se preferisce /home cambi sotto la navigazione

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});


  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String? _errorMessage;



  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---- AZIONI ----
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = cred.user;
      if (user != null && !user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() => _errorMessage = 'Verifica la tua email prima di accedere.');
        }
        return;
      }

      if (!mounted) return;
      // Porta al flow principale e SVUOTA lo stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (route) => false,
      );
      // In alternativa: Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = 'Utente non trovato';
            break;
          case 'wrong-password':
            _errorMessage = 'Password errata';
            break;
          case 'invalid-email':
            _errorMessage = 'Email non valida';
            break;
          case 'invalid-credential':
            _errorMessage = 'Credenziali non valide o scadute';
            break;
          case 'too-many-requests':
            _errorMessage = 'Troppi tentativi. Riprova più tardi.';
            break;
          default:
            _errorMessage = 'Errore: ${e.message ?? e.code}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Errore imprevisto: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Inserisci l’email per ricevere il link di reset.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email per reimpostare la password inviata.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l’invio dell’email: $e')),
      );
    }
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    );

    return WillPopScope(
      onWillPop: () async => false, // niente back
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520), // meglio su tablet
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),

                        // Logo gradiente "Musicboxd"
                        _GradientTitle(
                          'Musicboxd',
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF2EA6), Color(0xFF4BC0F8)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          style: const TextStyle(
                            fontSize: 56,
                            height: 1.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 36),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Email',
                            hintStyle: const TextStyle(color: Colors.white60),
                            filled: true,
                            fillColor: const Color(0xFF39424A), // grigio scuro
                            border: inputBorder,
                            enabledBorder: inputBorder,
                            focusedBorder: inputBorder,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Inserisci la tua email';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Email non valida';
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _isLoading ? null : _login(),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: const TextStyle(color: Colors.white60),
                            filled: true,
                            fillColor: const Color(0xFF39424A),
                            border: inputBorder,
                            enabledBorder: inputBorder,
                            focusedBorder: inputBorder,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Inserisci la password';
                            if (value.length < 6) return 'Minimo 6 caratteri';
                            return null;
                          },
                        ),

                        const SizedBox(height: 28),

                        // Pulsante viola
                        // Pulsante gradiente a tutta larghezza
                        SizedBox(
                          height: 56,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _isLoading ? null : _login,
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
                              child: _isLoading
                                  ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Riga "Don't have an account? Sign Up"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? ",
                                style: TextStyle(color: Colors.white70, fontSize: 16)),
                            InkWell(
                              onTap: () => Navigator.of(context).pushNamed('/register'),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text('Sign Up',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Link verde "Recover your Account"
                        Center(
                          child: InkWell(
                            onTap: _resetPassword,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Recover your Account',
                                style: TextStyle(
                                  color: Color(0xFF2ECC71), // verde
                                  fontSize: 16,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        if (_errorMessage != null)
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent),
                          ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Titolo gradiente grande
class _GradientTitle extends StatelessWidget {
  final String text;
  final Gradient gradient;
  final TextStyle style;
  final TextAlign? textAlign;

  const _GradientTitle(
      this.text, {
        required this.gradient,
        required this.style,
        this.textAlign,
      });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}
