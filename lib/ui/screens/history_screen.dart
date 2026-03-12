import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../models/movement_model.dart';
import '../theme/app_theme.dart';
import '../../services/pdf_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(movementsProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Movimientos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: AppTheme.expenseRed),
            tooltip: 'Exportar a PDF',
            onPressed: () {
              final movements = movementsAsync.value;
              final user = userAsync.value;
              if (movements != null && movements.isNotEmpty && user != null) {
                PDFService.generateAndPrint(user.cashBalance, user.debitBalance, movements);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No hay datos suficientes para el reporte.')),
                );
              }
            },
          )
        ],
      ),
      body: movementsAsync.when(
        data: (movements) {
          if (movements.isEmpty) {
            return const Center(child: Text('Sin movimientos registrados.'));
          }

          // Sort client-side
          final sortedMovements = List<MovementModel>.from(movements)
            ..sort((a, b) => b.date.compareTo(a.date));

          // Agrupamos por día para mostrar en el historial
          final grouped = <String, List<MovementModel>>{};
          for (var m in sortedMovements) {
            final dateKey = DateFormat('yyyy-MM-dd').format(m.date);
            grouped.putIfAbsent(dateKey, () => []).add(m);
          }

          final sortedKeys = grouped.keys.toList()..sort((a,b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final dateKey = sortedKeys[index];
              final dayMovements = grouped[dateKey]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      DateFormat('EEEE, dd MMMM yyyy').format(DateTime.parse(dateKey)),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textGrey),
                    ),
                  ),
                  ...dayMovements.map((movement) {
                    final isIncome = movement.type == MovementType.income;
                    final format = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isIncome ? AppTheme.incomeGreen.withOpacity(0.2) : AppTheme.expenseRed.withOpacity(0.2),
                          child: Icon(
                            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
                          ),
                        ),
                        title: Text(movement.description),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(movement.invoiceType),
                            Text(
                              movement.paymentMethod == PaymentMethod.cash ? 'Efectivo' : 'Tarjeta',
                              style: const TextStyle(fontSize: 10, color: AppTheme.textGrey),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (movement.imageUrl?.isNotEmpty ?? false)
                              IconButton(
                                icon: const Icon(Icons.receipt_long, color: AppTheme.primaryBlack),
                                tooltip: 'Ver Comprobante',
                                onPressed: () async {
                                  final url = Uri.parse(movement.imageUrl!);
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('No se pudo abrir el archivo adjunto.')),
                                      );
                                    }
                                  }
                                },
                              ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${isIncome ? '+' : '-'}${format.format(movement.grossAmount)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
                                  ),
                                ),
                                Text(
                                  movement.costCenter.name,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.textGrey),
                              onPressed: () => _confirmDelete(context, ref, movement),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: \$err')),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, MovementModel movement) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar Movimiento'),
        content: const Text('¿Deseas eliminar este registro? El saldo se actualizará.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userRepo = ref.read(userRepositoryProvider);
              try {
                await userRepo.deleteMovementWithBalanceUpdate(movement);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Registro eliminado y saldo actualizado')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Borrar', style: TextStyle(color: AppTheme.expenseRed)),
          ),
        ],
      ),
    );
  }
}
