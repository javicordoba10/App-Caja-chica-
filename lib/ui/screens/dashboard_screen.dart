import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/app_providers.dart';
import '../../models/user_model.dart';
import '../../models/movement_model.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final movementsAsync = ref.watch(movementsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeader(),
            const SizedBox(height: 32),
            
            // Main Balance Card
            _buildMainBalanceCard(userAsync),
            const SizedBox(height: 32),

            // Metric cards (4 columns)
            _buildMetricGrid(movementsAsync),
            const SizedBox(height: 32),

            // Charts and Recent list
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildMonthlySummary(movementsAsync)),
                const SizedBox(width: 32),
                Expanded(flex: 2, child: _buildRecentTransactions(movementsAsync)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Panel de Control',
          style: TextStyle(
            color: AppTheme.textDark,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Registro de Caja Chica — Agropecuaria Las Marías',
          style: TextStyle(
            color: AppTheme.textGrey.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildMainBalanceCard(AsyncValue<UserModel?> userAsync) {
    return userAsync.when(
      data: (user) => Container(
        padding: const EdgeInsets.all(32),
        decoration: AppTheme.orangeCardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Saldo Caja Chica',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'L ${NumberFormat('#,##0.00').format((user?.cashBalance ?? 0.0) + (user?.debitBalance ?? 0.0))}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildAmountInfo(Icons.trending_up, 'INGRESOS', user?.cashBalance ?? 0.0),
                const SizedBox(width: 40),
                _buildAmountInfo(Icons.trending_down, 'EGRESOS', user?.debitBalance ?? 0.0),
              ],
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Error al cargar saldo'),
    );
  }

  Widget _buildAmountInfo(IconData icon, String label, double amount) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
            Text(
              'L ${NumberFormat('#,##0.00').format(amount)}',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricGrid(AsyncValue<List<MovementModel>> movementsAsync) {
    return movementsAsync.when(
      data: (movements) {
        final incomes = movements.where((m) => m.type == MovementType.income).fold(0.0, (sum, m) => sum + m.grossAmount);
        final expenses = movements.where((m) => m.type == MovementType.expense).fold(0.0, (sum, m) => sum + m.grossAmount);
        final count = movements.length;
        
        // Month calculations
        final now = DateTime.now();
        final monthExpenses = movements
            .where((m) => m.type == MovementType.expense && m.date.month == now.month && m.date.year == now.year)
            .fold(0.0, (sum, m) => sum + m.grossAmount);

        return GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 24,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.8,
          children: [
            _buildStatCard('TRANSACCIONES', count.toString(), Icons.receipt_outlined, Colors.blue),
            _buildStatCard('INGRESOS', 'L ${NumberFormat('#,##0.00').format(incomes)}', Icons.arrow_upward, Colors.green),
            _buildStatCard('EGRESOS', 'L ${NumberFormat('#,##0.00').format(expenses)}', Icons.arrow_downward, Colors.red),
            _buildStatCard('GASTOS DEL MES', 'L ${NumberFormat('#,##0.00').format(monthExpenses)}', Icons.calendar_month_outlined, Colors.purple),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummary(AsyncValue<List<MovementModel>> movementsAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen Mensual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 80000,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: AppTheme.textGrey, fontSize: 10);
                        String text = '';
                        switch (value.toInt()) {
                          case 0: text = 'oct'; break;
                          case 1: text = 'nov'; break;
                          case 2: text = 'dic'; break;
                          case 3: text = 'ene'; break;
                          case 4: text = 'feb'; break;
                          case 5: text = 'mar'; break;
                        }
                        return SideTitleWidget(meta: meta, child: Text(text, style: style));
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBarGroup(0, 5000, 1000),
                  _makeBarGroup(1, 8000, 2000),
                  _makeBarGroup(2, 3000, 500),
                  _makeBarGroup(3, 10000, 4000),
                  _makeBarGroup(4, 45000, 15000),
                  _makeBarGroup(5, 62000, 22000),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y1, double y2) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(toY: y1, color: Colors.greenAccent[400], width: 14, borderRadius: BorderRadius.circular(4)),
        BarChartRodData(toY: y2, color: Colors.redAccent[400], width: 14, borderRadius: BorderRadius.circular(4)),
      ],
    );
  }

  Widget _buildRecentTransactions(AsyncValue<List<MovementModel>> movementsAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transacciones Recientes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          movementsAsync.when(
            data: (movements) {
              final latest = movements.take(5).toList();
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: latest.length,
                separatorBuilder: (_, __) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final m = latest[index];
                  final isIncome = m.type == MovementType.income;
                  return _buildTransactionItem(m, isIncome);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Error'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(MovementModel m, bool isIncome) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isIncome ? Colors.green : Colors.red).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isIncome ? Icons.arrow_upward : Icons.arrow_downward,
            color: isIncome ? Colors.green : Colors.red,
            size: 16,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
              Text(DateFormat('dd MMM yyyy').format(m.date), style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "${isIncome ? '+' : '-'} L ${NumberFormat('#,##0.00').format(m.grossAmount)}",
              style: TextStyle(
                color: isIncome ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (m.imageUrl != null && m.imageUrl!.isNotEmpty)
              GestureDetector(
                onTap: () async {
                  final url = Uri.parse(m.imageUrl!);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.attachment, size: 10, color: AppTheme.primaryOrange),
                      SizedBox(width: 4),
                      Text('VER', style: TextStyle(color: AppTheme.primaryOrange, fontSize: 8, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
