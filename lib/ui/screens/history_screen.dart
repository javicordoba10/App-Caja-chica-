import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/models/movement_model.dart';
import 'package:petty_cash_app/services/ocr_service.dart';
import 'package:petty_cash_app/ui/screens/validation_form_screen.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final movementsAsync = ref.watch(movementsProvider);

    return Column(
        children: [
          // Filter Section
          _buildFilterHeader(),
          
          Expanded(
            child: movementsAsync.when(
              data: (movements) {
                final filtered = _applyFilters(movements);
                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                // Summary
                final totalExp = filtered.where((m) => m.type == MovementType.expense).fold(0.0, (sum, m) => sum + m.grossAmount);
                final totalInc = filtered.where((m) => m.type == MovementType.income).fold(0.0, (sum, m) => sum + m.grossAmount);

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                        child: _buildSummaryRow(totalInc, totalExp),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildHistoryCard(filtered[index]),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      );
  }

  Widget _buildFilterHeader() {
    return Container(
      color: AppTheme.pureWhite,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Todo', 'Todos'),
                const SizedBox(width: 8),
                _buildFilterChip('Hoy', 'Día'),
                const SizedBox(width: 8),
                _buildFilterChip('Semana', 'Semana'),
                const SizedBox(width: 8),
                _buildFilterChip('Mes', 'Mes'),
                const SizedBox(width: 16),
                Container(height: 24, width: 1, color: Colors.black12),
                const SizedBox(width: 16),
                _buildFilterChip('Ingresos', 'Ingresos'),
                const SizedBox(width: 8),
                _buildFilterChip('Egresos', 'Egresos'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _selectedFilter = value),
      backgroundColor: Colors.transparent,
      selectedColor: AppTheme.pureBlack,
      labelStyle: GoogleFonts.montserrat(
        color: isSelected ? Colors.white : AppTheme.textGrey,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? Colors.transparent : Colors.black12),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildSummaryRow(double inc, double exp) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.orangeCardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('INGRESOS', inc, Colors.white),
          Container(height: 30, width: 1, color: Colors.white24),
          _buildSummaryItem('EGRESOS', exp, Colors.white),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.montserrat(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          '\$ ${NumberFormat('#,##0').format(amount)}',
          style: GoogleFonts.montserrat(color: color, fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(MovementModel m) {
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
        margin: const EdgeInsets.only(bottom: 12),
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
                    maxLines: 1, overflow: TextOverflow.ellipsis,
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
                    color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (m.imageUrl != null && m.imageUrl!.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 22, color: AppTheme.primaryOrange),
                    onPressed: () => _openReceipt(m.imageUrl!),
                    tooltip: 'Ver Comprobante',
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
        color: (isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isIncome ? Icons.keyboard_double_arrow_up : Icons.keyboard_double_arrow_down,
        color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
        size: 18,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: Colors.black12),
          const SizedBox(height: 16),
          Text('No hay movimientos en este periodo', style: TextStyle(color: AppTheme.textGrey)),
        ],
      ),
    );
  }

  List<MovementModel> _applyFilters(List<MovementModel> movements) {
    return movements.where((m) {
      // Type Filter
      if (_selectedFilter == 'Ingresos' && m.type != MovementType.income) return false;
      if (_selectedFilter == 'Egresos' && m.type != MovementType.expense) return false;

      // Time Filter
      final now = DateTime.now();
      if (_selectedFilter == 'Día') {
        return m.date.day == now.day && m.date.month == now.month && m.date.year == now.year;
      }
      if (_selectedFilter == 'Semana') {
        final weekAgo = now.subtract(const Duration(days: 7));
        return m.date.isAfter(weekAgo);
      }
      if (_selectedFilter == 'Mes') {
        return m.date.month == now.month && m.date.year == now.year;
      }
      return true;
    }).toList();
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

  Future<void> _openReceipt(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
