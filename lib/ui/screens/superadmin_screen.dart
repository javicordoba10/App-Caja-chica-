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

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.pureBlack,
        icon: const Icon(Icons.domain_add, color: Colors.white),
        label: Text('Nueva Empresa', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          showDialog(context: context, builder: (_) => const TenantDialog());
        },
      ),
      body: listAsync.when(
        data: (companies) {
          if (companies.isEmpty) {
            return const Center(child: Text("No hay inquilinos configurados."));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: companies.length,
            itemBuilder: (context, index) {
              final comp = companies[index];
              final link = 'https://pettycashapp-80f5e.web.app/?comp=${comp.id}';
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
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: comp.primaryColor),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: comp.secondaryColor),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: comp.isActive ? AppTheme.incomeGreen.withOpacity(0.1) : AppTheme.expenseRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              comp.isActive ? 'ACTIVO' : 'INACTIVO',
                              style: TextStyle(
                                color: comp.isActive ? AppTheme.incomeGreen : AppTheme.expenseRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        comp.name,
                        style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'ID de URL: ${comp.id}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Expanded(child: Text(link, style: const TextStyle(color: Colors.black54, fontSize: 12), overflow: TextOverflow.ellipsis)),
                            IconButton(
                              tooltip: 'Auditar Empresa',
                              icon: const Icon(Icons.remove_red_eye, size: 20, color: AppTheme.primaryOrange),
                              onPressed: () {
                                ref.read(superAdminInspectTenantProvider.notifier).state = comp.id;
                                ref.read(navigationProvider.notifier).state = 'dashboard';
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ingresando como auditor a ${comp.name}...'), backgroundColor: AppTheme.incomeGreen));
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }
}
