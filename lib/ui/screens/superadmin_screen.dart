import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:petty_cash_app/models/company_config_model.dart';
import 'package:petty_cash_app/ui/widgets/tenant_dialog.dart';
import 'package:petty_cash_app/providers/app_providers.dart';
import 'package:petty_cash_app/ui/widgets/main_layout.dart';

final saasListProvider = StreamProvider<List<CompanyConfigModel>>((ref) {
  return FirebaseFirestore.instance.collection('companies_config').snapshots().map((snapshot) {
    return snapshot.docs.map((doc) => CompanyConfigModel.fromMap(doc.data(), doc.id)).toList();
  });
});

class SuperadminScreen extends ConsumerWidget {
  const SuperadminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(saasListProvider);

    return listAsync.when(
      data: (companies) {
        if (companies.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_outlined, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text("No hay empresas configuradas.", style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                Text("Usá el botón + para crear la primera.", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: companies.length,
          itemBuilder: (context, index) {
            final comp = companies[index];
            final link = 'https://pettycashapp-80f5e.web.app/?comp=${comp.id}';
            return _TenantMetricsCard(comp: comp, link: link);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text("Error: $err")),
    );
  }
}


class _TenantMetricsCard extends ConsumerWidget {
  final CompanyConfigModel comp;
  final String link;

  const _TenantMetricsCard({required this.comp, required this.link});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);

    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('users').where('companyId', isEqualTo: comp.id).snapshots(),
      builder: (context, usersSnapshot) {
        final usersCount = usersSnapshot.data?.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['role'] != 'superadmin';
        }).length ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: firestore.collection('movements').where('companyId', isEqualTo: comp.id).snapshots(),
          builder: (context, movementsSnapshot) {
            final movementsCount = movementsSnapshot.data?.docs.length ?? 0;
            final estimatedMB = (movementsCount * 0.12).toStringAsFixed(1);
            final estimatedOcrTokens = (movementsCount * 1.5).toInt();

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (comp.logoUrl != null && comp.logoUrl!.trim().isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              comp.logoUrl!.trim(),
                              height: 36,
                              width: 36,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 28),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: comp.primaryColor),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: comp.secondaryColor),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () async {
                            final newStatus = !comp.isActive;
                            await firestore.collection('companies_config').doc(comp.id).update({'isActive': newStatus});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(newStatus ? 'Empresa ${comp.name} Activada' : 'Empresa ${comp.name} Suspendida'),
                                  backgroundColor: newStatus ? AppTheme.incomeGreen : AppTheme.expenseRed,
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: comp.isActive ? AppTheme.incomeGreen.withOpacity(0.12) : AppTheme.expenseRed.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: comp.isActive ? AppTheme.incomeGreen : AppTheme.expenseRed),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(comp.isActive ? Icons.check_circle : Icons.block, size: 14, color: comp.isActive ? AppTheme.incomeGreen : AppTheme.expenseRed),
                                const SizedBox(width: 4),
                                Text(
                                  comp.isActive ? 'LICENCIA ACTIVA' : 'SUSPENDIDO',
                                  style: TextStyle(
                                    color: comp.isActive ? AppTheme.incomeGreen : AppTheme.expenseRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      comp.name,
                      style: GoogleFonts.montserrat(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'ID de URL: ${comp.id}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    
                    // Live SaaS Metrics Grid
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MetricItem(label: 'Usuarios', value: '$usersCount', icon: Icons.people_outline, color: Colors.blue),
                          _MetricItem(label: 'Movimientos', value: '$movementsCount', icon: Icons.receipt_long_outlined, color: AppTheme.primaryOrange),
                          _MetricItem(label: 'Disco Estim.', value: '$estimatedMB MB', icon: Icons.sd_storage_outlined, color: Colors.purple),
                          _MetricItem(label: 'Tokens OCR', value: '$estimatedOcrTokens', icon: Icons.auto_awesome, color: Colors.teal),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Expanded(child: Text(link, style: const TextStyle(color: Colors.black54, fontSize: 12), overflow: TextOverflow.ellipsis)),
                          IconButton(
                            tooltip: 'Editar Configuración / Logo',
                            icon: const Icon(Icons.edit, size: 20, color: Colors.black54),
                            onPressed: () {
                              showDialog(context: context, builder: (_) => TenantDialog(company: comp));
                            },
                          ),
                          IconButton(
                            tooltip: 'Copiar Enlace',
                            icon: const Icon(Icons.copy, size: 20, color: Colors.blueGrey),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: link));
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enlace copiado para ${comp.name}')));
                            },
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
        Text(label, style: GoogleFonts.montserrat(fontSize: 10, color: AppTheme.textGrey)),
      ],
    );
  }
}
