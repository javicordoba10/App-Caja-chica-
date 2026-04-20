import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petty_cash_app/models/recharge_request_model.dart';
import 'package:petty_cash_app/models/movement_model.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class AdminRechargesScreen extends ConsumerWidget {
  const AdminRechargesScreen({super.key});

  Future<void> _updateStatus(
    BuildContext context, 
    WidgetRef ref, 
    RechargeRequestModel request, 
    RechargeStatus newStatus
  ) async {
    try {
      final repo = ref.read(rechargeRepositoryProvider);
      
      // Si se acredita la solicitud por primera vez, creamos el ingreso automático
      if (newStatus == RechargeStatus.acreditado && request.status != RechargeStatus.acreditado) {
        final userRepo = ref.read(userRepositoryProvider);
        
        final movement = MovementModel(
          id: const Uuid().v4(),
          userId: request.userId,
          companyId: request.companyId,
          userName: request.userName,
          type: MovementType.income,
          netAmount: request.amount,
          grossAmount: request.amount,
          vat: 0.0,
          invoiceType: 'Acreditación Automática',
          description: 'Recarga de Dinero Aprobada',
          establishment: 'ADMINISTRACIÓN',
          paymentMethod: request.paymentMethod,
          date: DateTime.now(),
          category: MovementCategory.otros,
        );
        
        await userRepo.saveMovementWithBalanceUpdate(movement);
      }
      
      await repo.updateRequestStatus(request.id, newStatus);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado actualizado a ${newStatus.name}', style: const TextStyle(color: Colors.white)), backgroundColor: AppTheme.incomeGreen),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.expenseRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(allRechargeRequestsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'GESTIÓN DE RECARGAS',
          style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
        centerTitle: true,
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text('No hay solicitudes registradas'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.whiteCardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            req.userName,
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                        Text(
                          '\$ ${NumberFormat('#,##0').format(req.amount)}',
                          style: GoogleFonts.montserrat(color: AppTheme.incomeGreen, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        if (req.status == RechargeStatus.denegado || req.status == RechargeStatus.acreditado)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.expenseRed, size: 22),
                            tooltip: 'Eliminar solicitud',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('¿Eliminar solicitud?', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                                  content: const Text('Esta acción es permanente y no se puede deshacer.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
                                    ElevatedButton(
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        try {
                                          await ref.read(rechargeRepositoryProvider).deleteRequest(req.id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Solicitud eliminada'), backgroundColor: AppTheme.incomeGreen),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.expenseRed),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.expenseRed),
                                      child: const Text('ELIMINAR', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${req.paymentMethod} • ${DateFormat('dd MMM yyyy, HH:mm').format(req.createdAt)}',
                      style: GoogleFonts.montserrat(color: AppTheme.textGrey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildStatusButton(context, ref, req, RechargeStatus.solicitado, 'Solicitado', Colors.blueGrey)),
                        const SizedBox(width: 4),
                        Expanded(child: _buildStatusButton(context, ref, req, RechargeStatus.pedido, 'Pedido', const Color(0xFFFFA000))),
                        const SizedBox(width: 4),
                        Expanded(child: _buildStatusButton(context, ref, req, RechargeStatus.acreditado, 'Acreditado', const Color(0xFF1976D2))),
                        const SizedBox(width: 4),
                        Expanded(child: _buildStatusButton(context, ref, req, RechargeStatus.denegado, 'Denegado', AppTheme.expenseRed)),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
      ),
    );
  }


  Widget _buildStatusButton(BuildContext context, WidgetRef ref, RechargeRequestModel req, RechargeStatus targetStatus, String label, Color color) {
    final isSelected = req.status == targetStatus;
    return InkWell(
      onTap: isSelected ? null : () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('¿Cambiar a $label?', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
            content: targetStatus == RechargeStatus.acreditado 
                ? const Text('Al pasarlo a Acreditado, se generará el INGRESO automáticamente en la caja del usuario. ¿Confirmás?')
                : (targetStatus == RechargeStatus.denegado 
                    ? const Text('¿Estás seguro de que querés denegar y cancelar esta solicitud?') 
                    : const Text('¿Cambiar el estado de la solicitud?')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _updateStatus(context, ref, req, targetStatus);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.pureBlack),
                child: const Text('SÍ, CAMBIAR', style: TextStyle(color: Colors.white)),
              )
            ],
          )
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.montserrat(
            color: isSelected ? Colors.white : color,
            fontSize: 8, // Reducido ligeramente para evitar overflow horizontal
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
