import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../models/movement_model.dart';
import '../../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _register() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos.')),
      );
      return;
    }

    if (_passCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden.')),
      );
      return;
    }

    if (_passCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres.')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Step 1: Create the Firebase Auth user
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) throw Exception('No se pudo crear el usuario.');

      // Step 2: Send verification email
      await firebaseUser.sendEmailVerification();

      // Step 3: Save user profile in Firestore using the UID from Auth
      final userRepo = ref.read(userRepositoryProvider);
      final newUser = UserModel(
        id: firebaseUser.uid,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        cashBalance: 0.0,
        debitBalance: 0.0,
        establishments: const [CostCenter.Administracion],
        role: 'user',
      );
      
      await userRepo.createUser(newUser);

      // Step 3: Sign out so user goes to login screen
      await FirebaseAuth.instance.signOut();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('¡Registro exitoso! Por favor revisa tu correo para verificar tu cuenta e ingresar.'),
             backgroundColor: AppTheme.incomeGreen,
           ),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Ya existe una cuenta con ese correo electrónico.';
          break;
        case 'invalid-email':
          message = 'El correo electrónico no es válido.';
          break;
        case 'weak-password':
          message = 'La contraseña es demasiado débil.';
          break;
        default:
          message = 'Error [${e.code}]: ${e.message ?? "Sin detalles"}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.expenseRed,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: ${e.toString()}'),
            backgroundColor: AppTheme.expenseRed,
            duration: const Duration(seconds: 6),
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
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.5,
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 30),
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
                      _buildTextField(_nameCtrl, 'Nombre Completo', Icons.person_outline),
                      const SizedBox(height: 16),
                      _buildTextField(_emailCtrl, 'Correo Electrónico', Icons.email_outlined),
                      const SizedBox(height: 16),
                      _buildTextField(_passCtrl, 'Contraseña', Icons.lock_outline, 
                        obscure: _obscurePassword, isPassword: true, 
                        onToggle: () => setState(() => _obscurePassword = !_obscurePassword)),
                      const SizedBox(height: 16),
                      _buildTextField(_confirmPassCtrl, 'Confirmar Contraseña', Icons.lock_reset_outlined, 
                        obscure: _obscureConfirmPassword, isPassword: true, 
                        onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),

                      const SizedBox(height: 30),

                      Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          gradient: AppTheme.buttonGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryOrange.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent, // Make button background transparent
                            shadowColor: Colors.transparent, // Remove shadow from button itself
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                'Registrarse',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('¿Ya tienes cuenta? ', style: TextStyle(color: Colors.black54)),
                          TextButton(
                            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                            child: const Text('Ingresar', style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      const SizedBox(height: 50),

                      const SizedBox(height: 10),

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

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center + const Offset(0, 5), radius - 5, shadowPaint);

    final ringPaint = Paint()
      ..color = const Color(0xFFE5A102).withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius - 5, ringPaint);

    final innerPaint = Paint()
      ..color = const Color(0xFF7A2C0A).withOpacity(0.05)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 10, innerPaint);

    final leafPaint = Paint()
      ..color = const Color(0xFFE5A102)
      ..style = PaintingStyle.fill;

    final rightPath = Path()
      ..moveTo(center.dx, center.dy + 15)
      ..quadraticBezierTo(center.dx + 40, center.dy - 10, center.dx + 25, center.dy - 40)
      ..quadraticBezierTo(center.dx - 10, center.dy - 20, center.dx, center.dy + 15);
    canvas.drawPath(rightPath, leafPaint);

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
        suffixIcon: isPassword ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey,
                ),
                onPressed: onToggle,
              ) : null,
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
