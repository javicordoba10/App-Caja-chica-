import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../models/movement_model.dart';
import '../theme/app_theme.dart';
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

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Historial',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                _buildFilterButton(),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar
            _buildSearchBar(),
            const SizedBox(height: 32),

            // List Title
            const Text(
              'Movimientos Registrados',
              style: TextStyle(
                color: AppTheme.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Movements List
            Expanded(
              child: movementsAsync.when(
                data: (movements) {
                  final filtered = movements.where((m) {
                    final matchSearch = m.description.toLowerCase().contains(_searchQuery.toLowerCase());
                    final matchFilter = _selectedFilter == 'Todos' || 
                                       (_selectedFilter == 'Ingresos' && m.type == MovementType.income) ||
                                       (_selectedFilter == 'Egresos' && m.type == MovementType.expense);
                    return matchSearch && matchFilter;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No se encontraron movimientos.'));
                  }

                  // Group by date
                  final groups = <String, List<MovementModel>>{};
                  for (var m in filtered) {
                    final dateKey = DateFormat('EEEE, d MMMM', 'es').format(m.date);
                    groups.putIfAbsent(dateKey, () => []).add(m);
                  }

                  return ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final dateKey = groups.keys.elementAt(index);
                      final items = groups[dateKey]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              dateKey.toUpperCase(),
                              style: const TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...items.map((m) => _buildHistoryItem(m)),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, __) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton() {
    return PopupMenuButton<String>(
      onSelected: (val) => setState(() => _selectedFilter = val),
      itemBuilder: (context) => ['Todos', 'Ingresos', 'Egresos']
          .map((f) => PopupMenuItem(value: f, child: Text(f)))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_list, size: 18, color: AppTheme.textGrey),
            const SizedBox(width: 8),
            Text(_selectedFilter, style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: AppTheme.whiteCardDecoration,
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Buscar por descripción...',
          prefixIcon: const Icon(Icons.search, color: AppTheme.textGrey),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildHistoryItem(MovementModel m) {
    final isIncome = m.type == MovementType.income;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.whiteCardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isIncome ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncome ? Icons.keyboard_double_arrow_up : Icons.keyboard_double_arrow_down,
              color: isIncome ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      DateFormat('HH:mm').format(m.date),
                      style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        m.costCenter.name,
                        style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
                      ),
                    ),
                  ],
                ),
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
                  fontSize: 16,
                ),
              ),
              if (m.imageUrl != null && m.imageUrl!.isNotEmpty)
                const SizedBox(height: 8),
              if (m.imageUrl != null && m.imageUrl!.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse(m.imageUrl!);
                    if (await canLaunchUrl(url)) {
                       await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.attachment, size: 14),
                  label: const Text('VER', style: TextStyle(fontSize: 10)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                    foregroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(60, 24),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
