import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/models/user_model.dart';
import 'package:petty_cash_app/models/movement_model.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:petty_cash_app/services/pdf_service.dart';
import 'package:petty_cash_app/services/ocr_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:petty_cash_app/ui/screens/history_screen.dart';
import 'package:petty_cash_app/ui/screens/validation_form_screen.dart';
import 'package:petty_cash_app/ui/widgets/main_layout.dart';
// Conditional import for web/native compatibility
import 'dart:html' as html if (dart.library.io) 'package:petty_cash_app/services/html_stub.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final movementsAsync = ref.watch(movementsProvider);

    return RefreshIndicator(
        onRefresh: () async => ref.refresh(movementsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Section
              userAsync.when(
                data: (user) => _buildGreeting(user?.name ?? 'Usuario', user?.role ?? 'user'),
                loading: () => _buildGreeting('...', 'user'),
                error: (_, __) => _buildGreeting('Invitado', 'user'),
              ),
              const SizedBox(height: 24),
              
              // Balance Cards (2 Columns)
              userAsync.when(
                data: (user) => Row(
                  children: [
                    Expanded(
                      child: _buildBalanceCard(
                        'Efectivo', 
                        user?.cashBalance ?? 0.0, 
                        Icons.payments_outlined, 
                        AppTheme.primaryOrange,
                        onSync: () async {
                          await ref.read(userRepositoryProvider).recalculateBalances(user!.id);
                          await ref.read(movementRepositoryProvider).cleanupOldAttachments();
                        },
                        gradientColors: [AppTheme.primaryOrange, AppTheme.primaryYellow],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildBalanceCard(
                        'Tarjeta', 
                        user?.debitBalance ?? 0.0, 
                        Icons.credit_card_outlined, 
                        const Color(0xFF1A237E),
                        gradientColors: [const Color(0xFF1A237E), const Color(0xFF3949AB)],
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error al cargar saldos'),
              ),
              const SizedBox(height: 24),

              // Metric Grid (2x2 for mobile)
              _buildMetricGrid(movementsAsync),
              const SizedBox(height: 24),

              // Export/Print Actions
              userAsync.when(
                data: (user) => _buildActionButtons(context, user, movementsAsync.value ?? []),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              // Charts
              _buildMainChartSection(ref, movementsAsync),
              const SizedBox(height: 24),

              // Recent list
              _buildRecentTransactions(context, ref, movementsAsync),
            ],
          ),
        ),
    );
  }

  Widget _buildGreeting(String name, String role) {
    final hour = DateTime.now().hour;
    String greeting = 'Buenos días';
    if (hour >= 12 && hour < 20) greeting = 'Buenas tardes';
    if (hour >= 20 || hour < 5) greeting = 'Buenas noches';

    final displayName = role == 'admin' ? 'Administrador $name' : name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting,',
          style: GoogleFonts.montserrat(
            color: AppTheme.textGrey,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          displayName,
          style: GoogleFonts.montserrat(
            color: AppTheme.textDark,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
  
  Widget _buildBalanceCard(String title, double amount, IconData icon, Color mainColor, {VoidCallback? onSync, List<Color>? gradientColors}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors ?? [mainColor, mainColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: mainColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (onSync != null)
                GestureDetector(
                  onTap: onSync,
                  child: const Icon(Icons.sync, color: Colors.white, size: 14),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '\$ ${NumberFormat('#,##0.00').format(amount)}',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(AsyncValue<List<MovementModel>> movementsAsync) {
    return movementsAsync.when(
      data: (movements) {
        final incomes = movements.where((m) => m.type == MovementType.income).fold(0.0, (sum, m) => sum + m.grossAmount);
        final expenses = movements.where((m) => m.type == MovementType.expense).fold(0.0, (sum, m) => sum + m.grossAmount);
        final net = incomes - expenses;
        final count = movements.length;

        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            _buildStatCard('INGRESOS', '\$ ${NumberFormat('#,##0').format(incomes)}', Icons.add_chart, Colors.green),
            _buildStatCard('SALDO NETO', '\$ ${NumberFormat('#,##0').format(net)}', Icons.account_balance_wallet_outlined, AppTheme.primaryOrange),
            _buildStatCard('CANTIDAD MOVIMIENTOS', count.toString(), Icons.receipt_long_outlined, Colors.blue),
            _buildStatCard('GASTOS', '\$ ${NumberFormat('#,##0').format(expenses)}', Icons.bar_chart, Colors.red),
          ],
        );
      },
      loading: () => const SizedBox(height: 100),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)))),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        label, 
                        style: GoogleFonts.montserrat(
                          color: AppTheme.textGrey, 
                          fontSize: 9, 
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(icon, color: color, size: 14),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: GoogleFonts.montserrat(
                      color: AppTheme.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, UserModel? user, List<MovementModel> movements) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _exportToExcel(movements),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Exportar Excel'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: AppTheme.textDark,
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                   if (user != null) {
                     PDFService.generateAndPrint(user.cashBalance, user.debitBalance, movements);
                   }
                },
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Imprimir Todo'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: AppTheme.textDark,
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () {
             if (user != null) {
               final expensesOnly = movements.where((m) => m.type == MovementType.expense).toList();
               PDFService.generateAndPrint(user.cashBalance, user.debitBalance, expensesOnly);
             }
          },
          icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
          label: const Text('IMPRIMIR SOLO GASTOS'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.expenseRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
        )),
      ],
    );
  }

  Future<void> _exportToExcel(List<MovementModel> movements) async {
    final excel = excel_lib.Excel.createExcel();
    final sheet = excel['Movimientos'];
    excel.setDefaultSheet('Movimientos');

    sheet.appendRow([excel_lib.TextCellValue('Fecha'), excel_lib.TextCellValue('Descripción'),
      excel_lib.TextCellValue('Tipo'), excel_lib.TextCellValue('Establecimiento'),
      excel_lib.TextCellValue('Monto BRUTO'), excel_lib.TextCellValue('Subtotal (NETO)'),
      excel_lib.TextCellValue('IVA Total'), excel_lib.TextCellValue('Forma Pago')]);

    for (final m in movements) {
      sheet.appendRow([excel_lib.TextCellValue(DateFormat('dd/MM/yyyy').format(m.date)),
        excel_lib.TextCellValue(m.description), excel_lib.TextCellValue(m.type == MovementType.income ? 'Ingreso' : 'Egreso'),
        excel_lib.TextCellValue(m.costCenter.name), excel_lib.DoubleCellValue(m.grossAmount),
        excel_lib.DoubleCellValue(m.netAmount), excel_lib.DoubleCellValue(m.vat),
        excel_lib.TextCellValue(m.paymentMethod == PaymentMethod.cash ? 'Efectivo' : 'Tarjeta')]);
    }

    final bytes = excel.save();
    if (bytes != null) {
      if (kIsWeb) {
        Future.microtask(() {
          final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute("download", "movimientos_${DateTime.now().millisecondsSinceEpoch}.xlsx")
            ..click();
          html.Url.revokeObjectUrl(url);
        });
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = io.File('${directory.path}/movimientos.xlsx');
        await file.writeAsBytes(bytes);
      }
    }
  }


  Widget _buildMainChartSection(WidgetRef ref, AsyncValue<List<MovementModel>> movementsAsync) {
    final selectedRange = ref.watch(dashboardChartRangeProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gastos por Campo',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.textDark,
                ),
              ),
              _buildRangeSelector(ref, selectedRange),
            ],
          ),
          const SizedBox(height: 24),
          movementsAsync.when(
            data: (movements) {
              final establishments = ['ADM', 'PL', 'FL', 'SI', 'LC', 'LH', 'E7', 'EM'];
              final dataMap = { for (var e in establishments) e : 0.0 };
              
              final now = DateTime.now();
              final filteredMovements = movements.where((m) {
                if (m.type != MovementType.expense) return false;
                
                switch (selectedRange) {
                  case 'Diario':
                    return m.date.day == now.day && m.date.month == now.month && m.date.year == now.year;
                  case 'Semanal':
                    return m.date.isAfter(now.subtract(const Duration(days: 7)));
                  case 'Mensual':
                    return m.date.month == now.month && m.date.year == now.year;
                  case 'Anual':
                    return m.date.year == now.year;
                  default:
                    return true;
                }
              });

              for (var m in filteredMovements) {
                final code = _getEstablishmentCode(m.costCenter);
                if (dataMap.containsKey(code)) {
                  dataMap[code] = dataMap[code]! + m.grossAmount;
                }
              }

              return SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: dataMap.values.fold(0.0, (max, v) => v > max ? v : max) * 1.2 + 1,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= establishments.length) return const SizedBox.shrink();
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                establishments[index],
                                style: GoogleFonts.montserrat(color: AppTheme.textGrey, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: establishments.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: dataMap[e.value] ?? 0,
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryOrange, AppTheme.primaryYellow],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            width: 16,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
            loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const Text('Error al procesar gráfico'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context, WidgetRef ref, AsyncValue<List<MovementModel>> movementsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Últimos Movimientos',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            TextButton(
              onPressed: () {
                ref.read(navigationProvider.notifier).state = 'history';
              },
              child: Text('Ver Todo', style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        movementsAsync.when(
          data: (movements) {
            final latest = movements.take(5).toList();
            if (latest.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text('No hay movimientos registrados', style: TextStyle(color: AppTheme.textGrey)),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: latest.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final m = latest[index];
                return _buildTransactionCard(context, ref, m);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Error al cargar movimientos'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildTransactionCard(BuildContext context, WidgetRef ref, MovementModel m) {
    final isIncome = m.type == MovementType.income;
    return InkWell(
      onTap: () => Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => ValidationFormScreen(
          data: ExtractedReceiptData(imagePath: m.imageUrl ?? ''), 
          existingMovement: m,
          isReadOnly: true,
        ))
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.whiteCardDecoration,
        child: Row(
          children: [
            _buildTypeIndicator(isIncome),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.description, 
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${DateFormat('dd MMM').format(m.date)} • ${_getEstablishmentCode(m.costCenter)} • ${m.paymentMethod == PaymentMethod.cash ? 'Efectivo' : 'Tarjeta'}', 
                    style: GoogleFonts.montserrat(color: AppTheme.textGrey, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${isIncome ? '+' : '-'} \$ ${NumberFormat('#,##0').format(m.grossAmount)}",
                  style: GoogleFonts.montserrat(
                    color: isIncome ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (m.imageUrl != null && m.imageUrl!.isNotEmpty)
                      const Icon(Icons.confirmation_number_outlined, size: 18, color: AppTheme.textGrey),
                    const SizedBox(width: 12),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(context, ref, m),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIndicator(bool isIncome) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (isIncome ? Colors.green : Colors.red).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isIncome ? Icons.keyboard_double_arrow_up : Icons.keyboard_double_arrow_down,
        color: isIncome ? Colors.green : Colors.red,
        size: 18,
      ),
    );
  }

  String _getEstablishmentCode(CostCenter c) {
    switch (c) {
      case CostCenter.Administracion: return 'ADM';
      case CostCenter.PuestoDeLuna: return 'PL';
      case CostCenter.FeedLot: return 'FL';
      case CostCenter.SanIsidro: return 'SI';
      case CostCenter.LaCarlota: return 'LC';
      case CostCenter.LaHuella: return 'LH';
      case CostCenter.ElSiete: return 'E7';
      case CostCenter.ElMoro: return 'EM';
      default: return 'OTR';
    }
  }

  Widget _buildRangeSelector(WidgetRef ref, String selected) {
    final ranges = ['Diario', 'Semanal', 'Mensual', 'Anual'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ranges.map((r) {
          final isSelected = selected == r;
          return GestureDetector(
            onTap: () => ref.read(dashboardChartRangeProvider.notifier).state = r,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.pureWhite : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
              ),
              child: Text(
                r,
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryOrange : AppTheme.textGrey,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, MovementModel movement) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar movimiento?'),
        content: Text('¿Estás seguro de que deseas eliminar "${movement.description}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
               try {
                  await ref.read(userRepositoryProvider).deleteMovementWithBalanceUpdate(movement);
                  ref.refresh(movementsProvider);
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Movimiento eliminado correctamente')),
                   );
                 }
              } catch (e) {
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Error al eliminar: $e')),
                   );
                 }
              }
            }, 
            child: const Text('ELIMINAR')
          ),
        ],
      ),
    );
  }
}
