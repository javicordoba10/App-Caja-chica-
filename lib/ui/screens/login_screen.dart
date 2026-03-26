import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/movement_model.dart';
import '../../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/main_layout.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa tus credenciales.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Authenticate with Firebase Auth
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passCtrl.text.trim(),
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) throw Exception('No se pudo autenticar el usuario.');

      // Step 2: Fetch the user profile from Firestore using Firebase UID
      final userRepo = ref.read(userRepositoryProvider);
      final user = await userRepo.getUser(firebaseUser.uid);

      if (user != null) {
        if (!user.isActive) {
          throw Exception('Tu cuenta ha sido bloqueada por un administrador.');
        }

        // v29.3: Auto-Migration (Auto-Sello)
        // Si el usuario no tiene companyId en Firestore, lo sellamos con la empresa default
        final rawDoc = await FirebaseFirestore.instance.collection('users').doc(user.id).get();
        if (!rawDoc.data()!.containsKey('companyId')) {
          await FirebaseFirestore.instance.collection('users').doc(user.id).update({
            'companyId': 'alm_agro',
          });
          print('v29.3: Usuario ${user.email} auto-migrado a alm_agro');
        }

        ref.read(currentUserIdProvider.notifier).state = user.id;
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainLayout()),
          );
        }
      } else {
        // No Firestore profile found — auto-create one using Firebase Auth data
        final displayName = firebaseUser.displayName ?? 
            firebaseUser.email?.split('@').first ?? 'Usuario';
        
        final userRepo = ref.read(userRepositoryProvider);
        final newUser = UserModel(
          id: firebaseUser.uid,
          name: displayName,
          email: firebaseUser.email ?? email,
          balances: {'Efectivo': 0.0, 'Tarjeta / Débito': 0.0},
          paymentMethods: const ['Efectivo', 'Tarjeta / Débito'],
          establishments: const [CostCenter.Administracion],
          role: 'user',
          isActive: true, 
          companyId: 'alm_agro',
        );
        await userRepo.createUser(newUser);

        ref.read(currentUserIdProvider.notifier).state = firebaseUser.uid;
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainLayout()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
          message = 'Correo o contrase\u00f1a incorrectos.';
          break;
        case 'wrong-password':
          message = 'Contrase\u00f1a incorrecta. Por favor, intenta de nuevo.';
          break;
        case 'invalid-email':
          message = 'El correo electr\u00f3nico no es v\u00e1lido.';
          break;
        case 'user-disabled':
          message = 'Esta cuenta ha sido deshabilitada.';
          break;
        case 'too-many-requests':
          message = 'Demasiados intentos. Por favor, espera un momento.';
          break;
        default:
          message = 'Error de autenticaci\u00f3n: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.expenseRed,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'REINTENTAR',
              textColor: Colors.white,
              onPressed: _login,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: ${e.toString()}'),
            backgroundColor: AppTheme.expenseRed,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'REINTENTAR',
              textColor: Colors.white,
              onPressed: _login,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.headerGradient),
        child: Column(
          children: [
            // --- HEADER (40%) ---
            Expanded(
              flex: 40,
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // V14 Surgical Logo ALM (Custom Seedling Ring)
                      CustomPaint(
                        size: const Size(100, 100),
                        painter: SurgicalLogoPainter(),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'REGISTRO DE\nCAJA CHICA',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),

            // --- FORM PANEL (60%) ---
            Expanded(
              flex: 60,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(50),
                    topRight: Radius.circular(50),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    )
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(
                        _emailCtrl,
                        'Usuario / Correo',
                        Icons.email_outlined,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        _passCtrl,
                        'Contraseña',
                        Icons.lock_outline,
                        obscure: _obscurePassword,
                        isPassword: true,
                        onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Gradient Button
                      Container(
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: AppTheme.buttonGradient,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            )
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  'Ingresar',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Register Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "¿No tienes cuenta? ",
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                            },
                            child: const Text(
                              "Registrarse",
                              style: TextStyle(
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      
                      const SizedBox(height: 30),

                      // Footer
                      Column(
                        children: [
                          Text(
                            'AGROPECUARIA',
                            style: GoogleFonts.montserrat(
                              color: Colors.black45,
                              fontSize: 13,
                              letterSpacing: 3,
                            ),
                          ),
                          Text(
                            'LAS MARÍAS',
                            style: GoogleFonts.montserrat(
                              color: Colors.black87,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SurgicalLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center + const Offset(0, 5), radius - 5, shadowPaint);

    // Outer Ring
    final ringPaint = Paint()
      ..color = const Color(0xFFE5A102).withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius - 5, ringPaint);

    // Inner Circle Background
    final innerPaint = Paint()
      ..color = const Color(0xFF7A2C0A).withOpacity(0.05)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 10, innerPaint);

    // Asymmetric Leaves
    final leafPaint = Paint()
      ..color = const Color(0xFFE5A102)
      ..style = PaintingStyle.fill;

    // Right (Main) Leaf
    final rightPath = Path()
      ..moveTo(center.dx, center.dy + 15)
      ..quadraticBezierTo(center.dx + 40, center.dy - 10, center.dx + 25, center.dy - 40)
      ..quadraticBezierTo(center.dx - 10, center.dy - 20, center.dx, center.dy + 15);
    canvas.drawPath(rightPath, leafPaint);

    // Left (Smaller) Leaf
    final leftPath = Path()
      ..moveTo(center.dx, center.dy + 15)
      ..quadraticBezierTo(center.dx - 30, center.dy - 5, center.dx - 20, center.dy - 25)
      ..quadraticBezierTo(center.dx, center.dy - 10, center.dx, center.dy + 15);
    canvas.drawPath(leftPath, leafPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon,
      {bool obscure = false, bool isPassword = false, VoidCallback? onToggle}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: GoogleFonts.montserrat(fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey,
                ),
                onPressed: onToggle,
              )
            : null,
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textGrey),
        filled: true,
        fillColor: const Color(0xFFF4F5F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }
