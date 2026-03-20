import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/models/movement_model.dart';
import 'package:petty_cash_app/models/user_model.dart';
import 'package:petty_cash_app/ui/screens/validation_form_screen.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:petty_cash_app/services/ocr_service.dart';

class UserHistoryScreen extends ConsumerStatefulWidget {
  final UserModel user;
  const UserHistoryScreen({super.key, required this.user});

  @override
  ConsumerState<UserHistoryScreen> createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends ConsumerState<UserHistoryScreen> {
  String _selectedFilter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final movementsAsync = ref.watch(selectedUserMovementsProvider(widget.user.id));

    return Scaffold(
      backgroundColor: AppTheme.pureWhite,
      appBar: AppBar(
        title: Column(
          children: [
            Text('SUPERVISIÓN', style: GoogleFonts.montserrat(fontSize: 10, letterSpacing: 2, color: AppTheme.primaryOrange)),
            Text(widget.user.name.toUpperCase(), style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterHeader(),
          Expanded(
            child: movementsAsync.when(
              data: (movements) {
                final filtered = _applyFilters(movements);
                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

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
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      color: AppTheme.pureWhite,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('Todo', 'Todos'),
            const SizedBox(width: 8),
            _buildFilterChip('Hoy', 'Día'),
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
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _selectedFilter = value),
      backgroundColor: Colors.transparent,
      selectedColor: AppTheme.textDark,
      labelStyle: GoogleFonts.montserrat(
        color: isSelected ? Colors.white : AppTheme.textGrey,
        fontSize: 11,
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
      decoration: BoxDecoration(
        color: AppTheme.textDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('INGRESOS', inc, Colors.greenAccent),
          Container(height: 30, width: 1, color: Colors.white24),
          _buildSummaryItem('EGRESOS', exp, Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.montserrat(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          '\$ ${NumberFormat('#,##0').format(amount)}',
          style: GoogleFonts.montserrat(color: color, fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(MovementModel m) {
    final isIncome = m.type == MovementType.income;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.whiteCardDecoration,
      child: Row(
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
                Text(m.description, 
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${DateFormat('dd MMM yyyy').format(m.date)} • ${m.costCenter.name}', 
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
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
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.imageUrl != null && m.imageUrl!.isNotEmpty)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.receipt_long_outlined, size: 20, color: AppTheme.primaryOrange),
                      onPressed: () => _viewReceipt(m),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                    onPressed: () => _confirmDelete(m),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(MovementModel movement) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar registro?', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: Text('¿Deseas eliminar "${movement.description}"? El saldo del usuario se recalculará automáticamente.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(userRepositoryProvider).deleteMovementWithBalanceUpdate(movement);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro eliminado ✓'), backgroundColor: AppTheme.incomeGreen));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.expenseRed));
                }
              }
            },
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
  }

  void _viewReceipt(MovementModel m) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ValidationFormScreen(
        data: ExtractedReceiptData(imagePath: m.imageUrl ?? ''),
        existingMovement: m,
        isReadOnly: true,
      )),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text('No hay movimientos registrados para este usuario.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  List<MovementModel> _applyFilters(List<MovementModel> movements) {
    return movements.where((m) {
      if (_selectedFilter == 'Ingresos' && m.type != MovementType.income) return false;
      if (_selectedFilter == 'Egresos' && m.type != MovementType.expense) return false;
      final now = DateTime.now();
      if (_selectedFilter == 'Día' && (m.date.day != now.day || m.date.month != now.month || m.date.year != now.year)) return false;
      if (_selectedFilter == 'Mes' && (m.date.month != now.month || m.date.year != now.year)) return false;
      return true;
    }).toList();
  }
}
