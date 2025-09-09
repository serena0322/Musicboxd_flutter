import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ====== PALETTE COERENTE ======
const kBg     = Color(0xFF0E0F12);
const kCard   = Color(0xFF151821);
const kBorder = Color(0x22FFFFFF);
const kGradA  = Color(0xFFB5179E);
const kGradB  = Color(0xFF00E5FF);

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _auth = FirebaseAuth.instance;

  void _openChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final currentCtrl = TextEditingController();
        final newCtrl     = TextEditingController();
        final confirmCtrl = TextEditingController();

        bool obscure1 = true, obscure2 = true, obscure3 = true;
        bool loading = false;

        Future<void> submit() async {
          final user = _auth.currentUser;
          if (user == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Utente non autenticato')),
              );
            }
            return;
          }

          final current = currentCtrl.text.trim();
          final next    = newCtrl.text.trim();
          final confirm = confirmCtrl.text.trim();

          final email = user.email;
          if (email == null || email.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Questo account non ha una password. Impostala da “Password e autenticazione”.'),
                ),
              );
            }
            return;
          }

          if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Compila tutti i campi')),
              );
            }
            return;
          }
          if (next != confirm) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Le nuove password non coincidono')),
              );
            }
            return;
          }
          if (next == current) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('La nuova password non può essere uguale alla precedente')),
              );
            }
            return;
          }
          if (next.length < 6) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('La nuova password deve contenere almeno 6 caratteri')),
              );
            }
            return;
          }

          try {
            (ctx as Element).markNeedsBuild();
            loading = true;

            final cred = EmailAuthProvider.credential(email: email, password: current);
            await user.reauthenticateWithCredential(cred);
            await user.updatePassword(next);

            if (!mounted) return;
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password aggiornata con successo'), backgroundColor: Colors.green),
            );
            Navigator.maybePop(context);
          } on FirebaseAuthException catch (e) {
            String msg = e.message ?? 'Errore sconosciuto';
            switch (e.code) {
              case 'wrong-password':         msg = 'La password attuale non è corretta'; break;
              case 'requires-recent-login':  msg = 'Sessione scaduta, riesegui il login e riprova'; break;
              case 'weak-password':          msg = 'La nuova password è troppo debole'; break;
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
            }
          } finally {
            loading = false;
            (ctx as Element).markNeedsBuild();
          }
        }

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16, right: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                  top: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Cambia password',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 12),

                    _PasswordField(
                      controller: currentCtrl,
                      hint: 'Password attuale',
                      obscure: obscure1,
                      onToggle: () => setSheetState(() => obscure1 = !obscure1),
                    ),
                    const SizedBox(height: 10),

                    _PasswordField(
                      controller: newCtrl,
                      hint: 'Nuova password',
                      obscure: obscure2,
                      onToggle: () => setSheetState(() => obscure2 = !obscure2),
                    ),
                    const SizedBox(height: 10),

                    _PasswordField(
                      controller: confirmCtrl,
                      hint: 'Conferma nuova password',
                      obscure: obscure3,
                      onToggle: () => setSheetState(() => obscure3 = !obscure3),
                    ),

                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ClipRRect( // <<— clip per stondare anche l’interno
                        borderRadius: BorderRadius.circular(14),
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [kGradA, kGradB]),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: loading ? null : submit,
                            child: loading
                                ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : const Text('Salva',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        centerTitle: true,
        elevation: 0,
        toolbarHeight: 72, // <<— più alto per 2 righe
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [kGradA, kGradB],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0.0, 0.7],
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: const Text(
            'Password\ne autenticazione', // <<— va a capo
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 0.2),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Material(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias, // clip anche del contenuto
          child: InkWell(
            onTap: _openChangePasswordSheet,
            borderRadius: BorderRadius.circular(16),
            child: Ink( // <-- Ink per bordo+splash coerenti
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: const ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                leading: _LeadingLockIcon(),
                title: Text(
                  'Cambia password',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Reimposta la password del tuo account',
                  style: TextStyle(color: Colors.white60),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ),
            ),
          ),
        )

      ),
    );
  }
}

class _LeadingLockIcon extends StatelessWidget {
  const _LeadingLockIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42, height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: const Icon(Icons.lock_rounded, color: Colors.white70),
    );
  }
}


class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias, // <<— splash clippato
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                textInputAction: TextInputAction.done,
              ),
            ),
            IconButton(
              onPressed: onToggle,
              icon: Icon(
                obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: Colors.white54,
              ),
            )
          ],
        ),
      ),
    );
  }
}
