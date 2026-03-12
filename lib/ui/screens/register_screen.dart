import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
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
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  
  // Example predefined areas (Cost Centers)
  final List<String> _areas = [
    'Administracion',
    'FeedLot',
    'PuestoDeLuna',
    'SanIsidro',
    'LaCarlota',
    'LaHuella',
    'ElMoro',
    'ElSiete',
  ];
  String? _selectedArea;
  bool _isLoading = false;

  Future<void> _register() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty || _selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, completa todos los campos requeridos.')));
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Future integration: Firebase Auth user creation and Firestore document initialization
      // await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _emailCtrl.text, password: _passCtrl.text);
      // await userRepo.createUser(UserModel(id: result.user!.uid, name: _nameCtrl.text, role: 'user', area: _selectedArea, ...));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Registro simulado exitoso.'), backgroundColor: AppTheme.incomeGreen),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.expenseRed));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Curved blue header
            ClipPath(
              clipper: _HeaderClipper(),
              child: Container(
                width: double.infinity,
                height: 250,
                color: const Color(0xFF1E88E5), // Corporate blue
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 40),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 60, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      'REGISTRARSE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Register Form Card
            Transform.translate(
              offset: const Offset(0, -40),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(_nameCtrl, 'Nombre Completo', Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildTextField(_emailCtrl, 'Email Corporativo', Icons.email_outlined),
                    const SizedBox(height: 16),
                    _buildTextField(_passCtrl, 'Contraseña', Icons.lock_outline, obscure: true),
                    const SizedBox(height: 16),
                    
                    // Dropdown for Area
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.business_center_outlined, color: Colors.grey),
                        hintText: 'Área de la Empresa',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      value: _selectedArea,
                      items: _areas.map((area) {
                        return DropdownMenuItem(value: area, child: Text(area));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedArea = val;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isLoading ? null : _register,
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                        : const Text('Registrarse', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("¿Ya eres miembro? ", style: TextStyle(color: Colors.grey)),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const Text("Ingresar", style: TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
