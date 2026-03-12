import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../models/user_model.dart'; // Added this import
import '../../models/movement_model.dart';
import '../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/ocr_service.dart';
import 'validation_form_screen.dart';
import 'history_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../../services/pdf_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsyncValue = ref.watch(currentUserProvider);
    final movementsAsyncValue = ref.watch(movementsProvider);
    final userId = ref.watch(currentUserIdProvider);
    final userRepo = ref.watch(userRepositoryProvider);

    // Simplified initialization: Only create if we are sure it's missing and not loading
    ref.listen(currentUserProvider, (previous, next) {
      if (next.value == null && !next.isLoading && !next.hasError) {
        print('>>> Dashboard: User missing, initializing doc for $userId');
        userRepo.createUser(UserModel(
          id: userId,
          name: 'Javier',
          cashBalance: 0.0,
          debitBalance: 0.0,
        ));
      }
    });

    final user = userAsyncValue.value;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(24.0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hola, ${userAsyncValue.value?.name ?? '...'}',
                          style: const TextStyle(fontSize: 16, color: AppTheme.textGrey),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.print, color: AppTheme.primaryBlack),
                              tooltip: 'Imprimir Reporte',
                              onPressed: () => _showReportRangePicker(context, ref),
                            ),
                            IconButton(
                              icon: const Icon(Icons.history, color: AppTheme.primaryBlack),
                              tooltip: 'Ver Historial',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                                );
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildBalanceCards(userAsyncValue),
                    const SizedBox(height: 24),
                    _buildExpensesChart(movementsAsyncValue),
                    const SizedBox(height: 32),
                    const Text(
                      'Últimos Movimientos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildMovementsList(movementsAsyncValue),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: AppTheme.backgroundWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlack, // Or any color you prefer
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ValidationFormScreen(
                        data: ExtractedReceiptData(imagePath: ''), 
                        initialType: MovementType.income,
                      ),
                    ),
                  );
                },
                child: const Text('Ingreso', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.expenseRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => _showEgresoOptions(context),
                child: const Text('Egreso', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEgresoOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Nuevo Egreso', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: AppTheme.backgroundWhite, child: Icon(Icons.edit, color: AppTheme.primaryBlack)),
                  title: const Text('Carga Manual'),
                  subtitle: const Text('Sin comprobante adjunto'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ValidationFormScreen(
                          data: ExtractedReceiptData(imagePath: ''),
                          initialType: MovementType.expense,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: AppTheme.backgroundWhite, child: Icon(Icons.camera_alt, color: AppTheme.primaryBlack)),
                  title: const Text('Escanear Foto'),
                  subtitle: const Text('Cámara o Galería (Autocompletado)'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery);
                    
                    if (image != null && context.mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );

                      final bytes = await image.readAsBytes();
                      final ocrService = OCRService();
                      final data = await ocrService.processImage(image.path, bytes: bytes);
                      ocrService.dispose();
                      
                      if (context.mounted) {
                        Navigator.pop(context); // Close loading dialog
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ValidationFormScreen(data: data, initialType: MovementType.expense),
                        ));
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: AppTheme.backgroundWhite, child: Icon(Icons.picture_as_pdf, color: AppTheme.expenseRed)),
                  title: const Text('Subir Archivo PDF'),
                  subtitle: const Text('Seleccionar desde archivos (.pdf)'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                    );

                    if (result != null && (result.files.single.path != null || result.files.single.bytes != null) && context.mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );

                      final bytes = result.files.single.bytes;
                      final ocrService = OCRService();
                      // On web we use the path from the file object directly if possible, or just the name
                      final path = kIsWeb ? result.files.single.name : result.files.single.path!;
                      final data = await ocrService.processImage(path, bytes: bytes);
                      ocrService.dispose();

                      if (context.mounted) {
                        Navigator.pop(context); // Close loading dialog
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ValidationFormScreen(data: data, initialType: MovementType.expense),
                        ));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  // New balance card structure
  Widget _buildBalanceCards(AsyncValue<UserModel?> userAsyncValue) {
    return userAsyncValue.when(
      data: (user) => _buildBalanceRow(user),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => _buildBalanceRow(null), // Show 0.00 on error instead of nothing
    );
  }

  Widget _buildBalanceRow(UserModel? user) {
    return Row(
      children: [
        Expanded(
          child: _buildBalanceCard(
            'Efectivo', 
            user?.cashBalance ?? 0.0, 
            AppTheme.incomeGreen, 
            Icons.account_balance_wallet
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildBalanceCard(
            'Tarjeta de Débito', 
            user?.debitBalance ?? 0.0, 
            AppTheme.primaryBlack.withOpacity(0.7), 
            Icons.credit_card
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(String title, double amount, Color color, IconData icon) {
    final formatCurrency = NumberFormat.currency(locale: 'es_AR', symbol: r'$');
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24.0),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCurrency.format(amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesChart(AsyncValue<List<MovementModel>> movementsAsync) {
    return movementsAsync.when(
      data: (movements) {
        // Calculate monthly totals per cost center
        final Map<CostCenter, double> totals = {};
        final now = DateTime.now();
        final currentMonthMovements = movements.where((m) => 
          m.type == MovementType.expense && 
          m.date.month == now.month && 
          m.date.year == now.year
        );

        for (var m in currentMonthMovements) {
          totals[m.costCenter] = (totals[m.costCenter] ?? 0) + m.grossAmount;
        }

        final hasData = totals.isNotEmpty;

        return Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gastos por Centro (Mes Actual)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),
              Expanded(
                child: !hasData 
                ? const Center(child: Text('Sin gastos registrados este mes', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)))
                : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: totals.values.isEmpty ? 0 : totals.values.reduce((a, b) => a > b ? a : b) * 1.2,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < CostCenter.values.length) {
                              final cc = CostCenter.values[index];
                              String label = '';
                              switch (cc) {
                                case CostCenter.Administracion: label = 'Adm'; break;
                                case CostCenter.FeedLot: label = 'FL'; break;
                                case CostCenter.PuestoDeLuna: label = 'PDL'; break;
                                case CostCenter.SanIsidro: label = 'SI'; break;
                                case CostCenter.LaCarlota: label = 'LC'; break;
                                case CostCenter.LaHuella: label = 'LH'; break;
                                case CostCenter.ElMoro: label = 'EM'; break;
                                case CostCenter.ElSiete: label = 'E7'; break;
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: CostCenter.values.asMap().entries.map((entry) {
                      final amount = totals[entry.value] ?? 0.0;
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: amount,
                            color: AppTheme.expenseRed,
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                          )
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (e, st) => const SizedBox.shrink(),
    );
  }

  Widget _buildMovementsList(AsyncValue<List<MovementModel>> movementsAsync) {
    return movementsAsync.when(
      data: (movements) {
        if (movements.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(child: Text("No hay movimientos registrados", style: TextStyle(color: AppTheme.textGrey))),
          );
        }
        
        // Ensure LIFO order in the UI as well (Safe ordering)
        final sortedMovements = List<MovementModel>.from(movements)
          ..sort((a, b) => b.date.compareTo(a.date));

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final movement = sortedMovements[index];
              return _MovementItem(movement: movement);
            },
            childCount: sortedMovements.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
      error: (e, st) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
    );
  }

  void _showReportRangePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('Imprimir Reporte de Gastos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _rangeTile(context, ref, 'Hoy (1 día)', 1),
              _rangeTile(context, ref, 'Últimos 2 días', 2),
              _rangeTile(context, ref, 'Últimos 3 días', 3),
              _rangeTile(context, ref, 'Última Semana (7 días)', 7),
              _rangeTile(context, ref, 'Último Mes (30 días)', 30),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  Widget _rangeTile(BuildContext context, WidgetRef ref, String title, int days) {
    return ListTile(
      leading: const Icon(Icons.calendar_today, color: AppTheme.primaryBlack),
      title: Text(title),
      onTap: () async {
        Navigator.pop(context);
        final movements = ref.read(movementsProvider).value ?? [];
        final user = ref.read(currentUserProvider).value;
        
        final now = DateTime.now();
        final threshold = now.subtract(Duration(days: days));
        
        final filtered = movements.where((m) => m.date.isAfter(threshold)).toList();
        
        if (filtered.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay movimientos en este rango.'))
          );
          return;
        }

        await PDFService.generateRangeReport(
          movements: filtered,
          rangeText: title,
          ownerName: user?.name ?? 'Javier',
        );
      },
    );
  }
}

class _MovementItem extends ConsumerWidget {
  final MovementModel movement;

  const _MovementItem({required this.movement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatCurrency = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    final isIncome = movement.type == MovementType.income;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isIncome ? AppTheme.incomeGreen.withOpacity(0.1) : AppTheme.expenseRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.description.isNotEmpty ? movement.description : 'Sin descripción',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (movement.type == MovementType.expense) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlack.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            movement.costCenter.name,
                            style: const TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        DateFormat('dd MMM, HH:mm').format(movement.date),
                        style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${isIncome ? '+' : '-'}${formatCurrency.format(movement.grossAmount)}",
                  style: TextStyle(
                    color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  movement.paymentMethod == PaymentMethod.cash ? 'Efectivo' : 'Tarjeta',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textGrey),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Actions
            if (movement.imageUrl != null && movement.imageUrl!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.receipt_long, size: 20, color: AppTheme.incomeGreen),
                tooltip: 'Ver Comprobante',
                onPressed: () async {
                   final url = Uri.parse(movement.imageUrl!);
                   if (await canLaunchUrl(url)) {
                     await launchUrl(url, mode: LaunchMode.externalApplication);
                   }
                },
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.textGrey),
              onPressed: () => _confirmDelete(context, ref, movement),
            ),
          ],
        ),
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
              final movementRepo = ref.read(movementRepositoryProvider);
              final userRepo = ref.read(userRepositoryProvider);
              final userId = ref.read(currentUserIdProvider);

              try {
                await userRepo.deleteMovementWithBalanceUpdate(movement);
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
