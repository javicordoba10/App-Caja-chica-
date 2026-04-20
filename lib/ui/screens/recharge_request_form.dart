import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:petty_cash_app/models/recharge_request_model.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:uuid/uuid.dart';

class RechargeRequestForm extends ConsumerStatefulWidget {
  const RechargeRequestForm({super.key});

  @override
  ConsumerState<RechargeRequestForm> createState() => _RechargeRequestFormState();
}

class _RechargeRequestFormState extends ConsumerState<RechargeRequestForm> {
  final _amountCtrl = TextEditingController();
  late String _selectedPayment;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    _selectedPayment = (user?.paymentMethods.isNotEmpty == true) 
        ? user!.paymentMethods.first 
        : 'Efectivo';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountTxt = _amountCtrl.text.replaceAll(',', '.');
    final amount = double.tryParse(amountTxt) ?? 0.0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido mayor a 0')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final request = RechargeRequestModel(
      id: const Uuid().v4(),
      userId: user.id,
      companyId: user.companyId ?? 'alm_agro',
      userName: user.name,
      amount: amount,
      paymentMethod: _selectedPayment,
      status: RechargeStatus.solicitado,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final repo = ref.read(rechargeRepositoryProvider);
      await repo.createRequest(request);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud enviada correctamente', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.incomeGreen),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userMethods = ref.watch(currentUserProvider).value?.paymentMethods ?? ['Efectivo'];

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'SOLICITAR RECARGA',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.pureBlack,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.pureBlack),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.whiteCardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Datos de Solicitud',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Se creará un pedido formal al administrador para transferir fondos a tu caja.',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Monto a solicitar (ARS)',
                          prefixIcon: const Icon(Icons.attach_money, color: AppTheme.primaryOrange),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: userMethods.contains(_selectedPayment) ? _selectedPayment : userMethods.first,
                        decoration: InputDecoration(
                          labelText: 'Forma de Pago de destino',
                          prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryOrange),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: userMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (v) => setState(() => _selectedPayment = v!),
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: AppTheme.textDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.pureBlack,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'ENVIAR SOLICITUD',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryOrange),
              ),
            ),
        ],
      ),
    );
  }
}
