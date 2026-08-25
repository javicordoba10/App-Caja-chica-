import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/main_layout.dart';
import '../widgets/company_logo_widget.dart';
import 'register_screen.dart';
import 'superadmin_home_screen.dart';

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
        const SnackBar(content: Text('Por favor, completa todos los campos.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passCtrl.text.trim(),
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) throw Exception('No se pudo autenticar el usuario.');

      await firebaseUser.reload();
      if (!firebaseUser.emailVerified) {
        // StreamBuilder in main.dart will display UnverifiedEmailScreen
        return;
      }

      final userRepo = ref.read(userRepositoryProvider);
      final user = await userRepo.getUser(firebaseUser.uid);
      final targetId = ref.read(targetCompanyIdProvider);

      if (user != null) {
        if (!user.isActive) {
          await FirebaseAuth.instance.signOut();
          throw Exception('Tu cuenta ha sido bloqueada por un administrador.');
        }

        // Si el usuario es SuperAdmin, acceso global permitido
        if (user.role == 'superadmin') {
          if (mounted) {
            _completeLogin(user);
          }
          return;
        }

        // Si es usuario regular / admin:
        if (targetId == null || targetId.isEmpty) {
          await FirebaseAuth.instance.signOut();
          final userComp = user.companyId.isNotEmpty ? user.companyId : 'su_empresa';
          throw Exception(
            'Para ingresar debes acceder desde el enlace oficial de tu empresa:\nhttps://pettycashapp-80f5e.web.app/?comp=$userComp',
          );
        }

        if (user.companyId != targetId) {
          await FirebaseAuth.instance.signOut();
          throw Exception(
            'Este usuario no pertenece a la empresa "$targetId". Ingrese desde el enlace provisto por su empresa.',
          );
        }

        // Verificar si la empresa está activa
        final compDoc = await FirebaseFirestore.instance.collection('companies_config').doc(targetId).get();
        if (compDoc.exists && compDoc.data()?['isActive'] == false) {
          await FirebaseAuth.instance.signOut();
          throw Exception('El acceso para esta empresa se encuentra temporalmente suspendido.');
        }

        if (mounted) {
          _completeLogin(user);
        }
      } else {
        if (targetId == null || targetId.isEmpty) {
          await FirebaseAuth.instance.signOut();
          throw Exception('Para iniciar sesión debes ingresar desde el enlace provisto por tu empresa.');
        }

        final displayName = firebaseUser.displayName ?? 
            firebaseUser.email?.split('@').first ?? 'Usuario';
        
        final newUser = UserModel(
          id: firebaseUser.uid,
          name: displayName,
          email: firebaseUser.email ?? email,
          balances: {'Efectivo': 0.0, 'Tarjeta / Débito': 0.0},
          paymentMethods: const ['Efectivo', 'Tarjeta / Débito'],
          establishments: const ['ADMINISTRACIÓN'],
          role: 'user',
          isActive: true, 
          companyId: targetId,
        );
        await userRepo.createUser(newUser);

        if (mounted) {
          _completeLogin(newUser);
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Error de autenticación: ${e.message}';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Usuario o contraseña incorrectos.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.expenseRed));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.expenseRed));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_reset, color: AppTheme.primaryOrange, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Restablecer Contraseña',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingresá tu correo electrónico y te enviaremos un link para restablecer tu contraseña.',
              style: GoogleFonts.montserrat(fontSize: 12, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: const Icon(Icons.email_outlined),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryOrange, width: 2),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Por favor, ingresá tu correo electrónico.')),
                );
                return;
              }
              Navigator.pop(dialogCtx);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Mail de restablecimiento enviado a $email. Revisá también tu carpeta de SPAM.'),
                      backgroundColor: Colors.green.shade700,
                      duration: const Duration(seconds: 6),
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (mounted) {
                  final msg = e.code == 'user-not-found'
                      ? 'No existe una cuenta registrada con ese correo.'
                      : 'Error al enviar el mail: ${e.message}';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
                  );
                }
              }
            },
            child: const Text('ENVIAR MAIL'),
          ),
        ],
      ),
    );
  }

  void _completeLogin(UserModel userModel) {
    ref.read(currentUserIdProvider.notifier).state = userModel.id;
    if (mounted) {
      if (userModel.role == 'superadmin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SuperAdminHomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainLayout()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final companyConfig = ref.watch(companyConfigProvider).value;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.headerGradient),
        child: Column(
          children: [
            Expanded(
              flex: 40,
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (companyConfig?.logoUrl != null && companyConfig!.logoUrl!.trim().isNotEmpty) ...[
                        Container(
                          height: 90,
                          width: 90,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                          ),
                          child: CompanyLogoWidget(
                            logoUrl: companyConfig!.logoUrl,
                            height: 74,
                            width: 74,
                            borderRadius: 14,
                            fallbackIconSize: 45,
                          ),
                        ),
                      ] else if (companyConfig != null) ...[
                        CustomPaint(
                          size: const Size(90, 90),
                          painter: SurgicalLogoPainter(
                            color: theme.colorScheme.secondary,
                            shadowColor: theme.primaryColor,
                          ),
                        ),
                      ] else ...[
                        Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: const Icon(Icons.account_balance_wallet_outlined, size: 42, color: Colors.white),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        (companyConfig?.name ?? 'CONTROL DE\nCAJA CHICA').toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
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
                    BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(_emailCtrl, 'Usuario / Correo', Icons.email_outlined),
                      const SizedBox(height: 20),
                      _buildTextField(_passCtrl, 'Contraseña', Icons.lock_outline,
                        obscure: _obscurePassword, isPassword: true,
                        onToggle: () => setState(() => _obscurePassword = !_obscurePassword)),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(colors: [theme.primaryColor, theme.colorScheme.secondary]),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
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
                              : Text('Ingresar', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("¿No tienes cuenta? ", style: TextStyle(color: Colors.grey, fontSize: 14)),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                            child: Text("Registrarse", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Column(
                        children: [
                          if (companyConfig != null) ...[
                             Text('SISTEMA GESTIONADO POR', style: GoogleFonts.montserrat(color: Colors.black45, fontSize: 11, letterSpacing: 2)),
                             Text(companyConfig.name.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          ] else ...[
                             Text('PLATAFORMA MULTI-EMPRESA', style: GoogleFonts.montserrat(color: Colors.black45, fontSize: 11, letterSpacing: 2)),
                             Text('PETTY CASH SAAS', style: GoogleFonts.montserrat(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          ]
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

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon,
      {bool obscure = false, bool isPassword = false, VoidCallback? onToggle}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: GoogleFonts.montserrat(fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: isPassword ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey),
                onPressed: onToggle,
              ) : null,
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textGrey),
        filled: true,
        fillColor: const Color(0xFFF4F5F7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }
}

class SurgicalLogoPainter extends CustomPainter {
  final Color color;
  final Color shadowColor;
  SurgicalLogoPainter({required this.color, required this.shadowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center + const Offset(0, 5), radius - 5, shadowPaint);

    final ringPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius - 5, ringPaint);

    final innerPaint = Paint()
      ..color = shadowColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 10, innerPaint);

    final leafPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Right leaf
    final rightPath = Path()
      ..moveTo(center.dx, center.dy + 15)
      ..quadraticBezierTo(center.dx + 40, center.dy - 10, center.dx + 25, center.dy - 40)
      ..quadraticBezierTo(center.dx - 10, center.dy - 20, center.dx, center.dy + 15);
    canvas.drawPath(rightPath, leafPaint);

    // Left leaf
    final leftPath = Path()
      ..moveTo(center.dx, center.dy + 15)
      ..quadraticBezierTo(center.dx - 30, center.dy - 5, center.dx - 20, center.dy - 25)
      ..quadraticBezierTo(center.dx, center.dy - 10, center.dx, center.dy + 15);
    canvas.drawPath(leftPath, leafPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
