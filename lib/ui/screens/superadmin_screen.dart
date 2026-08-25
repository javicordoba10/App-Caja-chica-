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
import 'package:petty_cash_app/ui/widgets/company_logo_widget.dart';

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
            final double mbUsed = movementsCount * 0.04;
            final String estimatedMB = mbUsed.toStringAsFixed(2);
            final String storageGB = (mbUsed / 1024).toStringAsFixed(3);
            final int estimatedOcrTokens = movementsCount;
            final int estReads = movementsCount * 10;
            final int estWrites = movementsCount * 2;

            // Calculo de sobreconsumo / costo extra Firebase
            final double overOcr = movementsCount > 1000 ? (movementsCount - 1000) * 0.0015 : 0.0;
            final double overStorage = mbUsed > 5000 ? ((mbUsed - 5000) / 1024) * 0.026 : 0.0;
            final double totalOverCostUSD = overOcr + overStorage;
            final bool hasOverages = totalOverCostUSD > 0.0;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: comp.isActive ? Colors.grey.shade200 : Colors.red.shade200, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (comp.logoUrl != null && comp.logoUrl!.trim().isNotEmpty) ...[
                          CompanyLogoWidget(
                            logoUrl: comp.logoUrl,
                            height: 38,
                            width: 38,
                            borderRadius: 8,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: comp.primaryColor),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 18, height: 18,
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
                                  content: Text(newStatus ? 'Empresa "${comp.name}" Habilitada' : 'Empresa "${comp.name}" Suspendida'),
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
                          _MetricItem(label: 'Créditos OCR', value: '$estimatedOcrTokens', icon: Icons.auto_awesome, color: Colors.teal),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Detailed Firebase Resource & Billing panel
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: hasOverages ? Colors.amber.shade50 : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: hasOverages ? Colors.amber.shade300 : Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cloud_done_outlined, size: 16, color: hasOverages ? Colors.amber.shade800 : Colors.blueGrey),
                              const SizedBox(width: 6),
                              Text(
                                'Consumo de Recursos Firebase (Hosting & Backend)',
                                style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('📁 Almacenamiento comprobantes:', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                              Text('$estimatedMB MB ($storageGB GB)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('⚡ Escaneos IA (OCR):', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                              Text('$estimatedOcrTokens créditos ($movementsCount comprobantes)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('📊 Operaciones Firestore est.:', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                              Text('~$estReads lecturas / ~$estWrites escrituras', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('💳 Estado de Facturación / Excesos:', style: TextStyle(fontSize: 11, color: Colors.grey[800], fontWeight: FontWeight.w600)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: hasOverages ? Colors.amber.shade100 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: hasOverages ? Colors.amber.shade700 : Colors.green.shade300),
                                ),
                                child: Text(
                                  hasOverages ? '⚠️ Exceso: \$${totalOverCostUSD.toStringAsFixed(2)} USD' : '✅ Cuota Base (Sin costo excedente)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: hasOverages ? Colors.amber.shade900 : Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                          ),
                          IconButton(
                            tooltip: 'Limpiar Movimientos de esta Empresa',
                            icon: const Icon(Icons.cleaning_services_outlined, size: 20, color: AppTheme.primaryOrange),
                            onPressed: () => _cleanCompanyData(context, comp),
                          ),
                          IconButton(
                            tooltip: 'Eliminar Empresa Definitivamente',
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                            onPressed: () => _deleteCompanyEntirely(context, comp),
                          ),
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

  Future<void> _cleanCompanyData(BuildContext context, CompanyConfigModel comp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cleaning_services_rounded, color: AppTheme.primaryOrange),
            const SizedBox(width: 8),
            Expanded(child: Text('Limpiar "${comp.name}"', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        content: Text(
          '¿Deseas eliminar todos los movimientos, comprobantes y solicitudes de recarga de la empresa "${comp.name}"?\n\n'
          '• Se restablecerán los saldos de sus usuarios a \$0.00.\n'
          '• La configuración y el logo de la empresa se conservarán.\n'
          '• Las demás empresas no serán afectadas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpiar Empresa'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final firestore = FirebaseFirestore.instance;
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 1. Borrar movimientos de esta empresa
      final movs = await firestore.collection('movements').where('companyId', isEqualTo: comp.id).get();
      for (var d in movs.docs) {
        await d.reference.delete();
      }

      // 2. Borrar recargas de esta empresa
      final recharges = await firestore.collection('recharge_requests').where('companyId', isEqualTo: comp.id).get();
      for (var d in recharges.docs) {
        await d.reference.delete();
      }

      // 3. Resetear saldos de usuarios de esta empresa
      final users = await firestore.collection('users').where('companyId', isEqualTo: comp.id).get();
      for (var d in users.docs) {
        await d.reference.update({
          'balances': {'Efectivo': 0.0, 'Tarjeta / Débito': 0.0},
        });
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ Datos de "${comp.name}" limpiados correctamente.'),
          backgroundColor: AppTheme.incomeGreen,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error al limpiar datos: $e'), backgroundColor: AppTheme.expenseRed),
      );
    }
  }

  Future<void> _deleteCompanyEntirely(BuildContext context, CompanyConfigModel comp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('¿Eliminar Empresa?'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar COMPLETAMENTE la empresa "${comp.name}"?\n\n'
          'Se borrará su configuración, accesos, movimientos y usuarios asociados.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar Definitivamente'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final firestore = FirebaseFirestore.instance;
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 1. Borrar movimientos
      final movs = await firestore.collection('movements').where('companyId', isEqualTo: comp.id).get();
      for (var d in movs.docs) {
        await d.reference.delete();
      }

      // 2. Borrar recargas
      final recharges = await firestore.collection('recharge_requests').where('companyId', isEqualTo: comp.id).get();
      for (var d in recharges.docs) {
        await d.reference.delete();
      }

      // 3. Borrar usuarios de esta empresa
      final users = await firestore.collection('users').where('companyId', isEqualTo: comp.id).get();
      for (var d in users.docs) {
        final email = (d.data()['email'] ?? '').toString().toLowerCase().trim();
        if (email != 'javicordoba10@gmail.com') {
          await d.reference.delete();
        }
      }

      // 4. Borrar documento de empresa
      await firestore.collection('companies_config').doc(comp.id).delete();

      messenger.showSnackBar(
        SnackBar(
          content: Text('🗑️ Empresa "${comp.name}" eliminada por completo.'),
          backgroundColor: AppTheme.expenseRed,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error al eliminar empresa: $e'), backgroundColor: AppTheme.expenseRed),
      );
    }
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
