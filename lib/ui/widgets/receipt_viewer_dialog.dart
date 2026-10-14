import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:petty_cash_app/models/movement_model.dart';
import 'package:petty_cash_app/services/pdf_service.dart';
import 'package:petty_cash_app/services/ocr_service.dart';
import 'package:petty_cash_app/ui/theme/app_theme.dart';
import 'package:petty_cash_app/ui/screens/validation_form_screen.dart';

class ReceiptViewerDialog extends StatelessWidget {
  final MovementModel movement;
  final String? companyName;

  const ReceiptViewerDialog({
    super.key,
    required this.movement,
    this.companyName,
  });

  static Future<void> show(
    BuildContext context, {
    required MovementModel movement,
    String? companyName,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReceiptViewerDialog(
        movement: movement,
        companyName: companyName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = movement.type == MovementType.income;
    final primaryColor = isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed;
    final url = movement.imageUrl ?? '';
    final isPdf = url.startsWith('data:application/pdf') || url.toLowerCase().contains('.pdf');
    final hasReceipt = url.isNotEmpty;

    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 32,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: mediaQuery.size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── TOP HEADER ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isIncome ? Icons.arrow_upward : Icons.receipt_long_outlined,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movement.description.isNotEmpty ? movement.description : 'Comprobante',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.pureBlack,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${movement.establishment} • ${movement.paymentMethod} • ${DateFormat('dd/MM/yyyy').format(movement.invoiceDate ?? movement.date)}',
                          style: GoogleFonts.montserrat(
                            color: AppTheme.textGrey,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),

            // ── SCROLLABLE CONTENT (Receipt & Summary) ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Amount and details chip row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${movement.invoiceType} ${movement.invoiceNumber?.isNotEmpty == true ? movement.invoiceNumber! : ''}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              if (movement.userName != null)
                                Text(
                                  'Por: ${movement.userName}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            "${isIncome ? '+' : '-'} \$ ${NumberFormat('#,##0.00', 'es_AR').format(movement.grossAmount)}",
                            style: GoogleFonts.montserrat(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Receipt image or preview container
                    if (hasReceipt) ...[
                      if (isPdf)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.picture_as_pdf, size: 54, color: AppTheme.expenseRed),
                              const SizedBox(height: 12),
                              Text(
                                'Comprobante Digital (PDF)',
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.expenseRed,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Abrir / Ver PDF'),
                                onPressed: () async {
                                  try {
                                    final uri = Uri.parse(url);
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error al abrir PDF: $e')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: isSmallScreen ? 320 : 400,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Stack(
                              children: [
                                InteractiveViewer(
                                  minScale: 0.8,
                                  maxScale: 4.5,
                                  child: Center(
                                    child: url.startsWith('data:image')
                                        ? Image.memory(
                                            base64Decode(url.split(',').last),
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => const Center(
                                              child: Icon(Icons.broken_image, color: Colors.white, size: 48),
                                            ),
                                          )
                                        : Image.network(
                                            url,
                                            fit: BoxFit.contain,
                                            loadingBuilder: (ctx, child, progress) {
                                              if (progress == null) return child;
                                              return const Center(
                                                child: CircularProgressIndicator(color: AppTheme.primaryOrange),
                                              );
                                            },
                                            errorBuilder: (_, __, ___) => const Center(
                                              child: Icon(Icons.broken_image, color: Colors.white, size: 48),
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Pellizca o usa la rueda para hacer zoom',
                                        style: GoogleFonts.montserrat(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Sin Comprobante Fotográfico',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Este movimiento fue registrado sin foto adjunta.',
                              style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── BOTTOM ACTIONS ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'CERRAR',
                      style: GoogleFonts.montserrat(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.pureBlack,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: Text(
                      'DETALLES',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ValidationFormScreen(
                            data: ExtractedReceiptData(imagePath: movement.imageUrl ?? ''),
                            existingMovement: movement,
                            isReadOnly: true,
                          ),
                        ),
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: Text(
                      'IMPRIMIR COMPROBANTE',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                    onPressed: () {
                      PDFService.printMovementReceipt(movement, companyName: companyName);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
