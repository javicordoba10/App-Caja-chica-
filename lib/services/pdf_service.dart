import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/movement_model.dart';

class PDFService {
  static Future<void> generateAndPrint(Map<String, double> balances, List<MovementModel> movements) async {
    final pdf = pw.Document();
    final format = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

    // Aggregate data by payment method
    final methodStats = <String, Map<String, double>>{};
    
    for (var m in movements) {
      final method = m.paymentMethod;
      if (!methodStats.containsKey(method)) {
        methodStats[method] = {'expenses': 0.0, 'incomes': 0.0};
      }
      if (m.type == MovementType.expense) {
        methodStats[method]!['expenses'] = methodStats[method]!['expenses']! + m.grossAmount;
      } else {
        methodStats[method]!['incomes'] = methodStats[method]!['incomes']! + m.grossAmount;
      }
    }

    final totalExpenses = movements.where((m) => m.type == MovementType.expense).fold(0.0, (sum, m) => sum + m.grossAmount);
    final totalIncomes = movements.where((m) => m.type == MovementType.income).fold(0.0, (sum, m) => sum + m.grossAmount);
    final finalTotalBalance = balances.values.fold(0.0, (sum, b) => sum + b);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text('Reporte de Caja Chica', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Fecha Generación: ${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now())}'),
              pw.Divider(),
              pw.SizedBox(height: 16),

              // Summary
              pw.Text('Resumen', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              
              // Dynamic Sections for each method
              ...balances.entries.map((entry) {
                final method = entry.key;
                final finalBal = entry.value;
                final stats = methodStats[method] ?? {'expenses': 0.0, 'incomes': 0.0};
                final initialBal = finalBal - stats['incomes']! + stats['expenses']!;

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Billetera $method', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Saldo Inicial:'),
                        pw.Text(format.format(initialBal)),
                      ]
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Saldo Final $method:'),
                        pw.Text(format.format(finalBal), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ]
                    ),
                    pw.SizedBox(height: 12),
                  ]
                );
              }),
              pw.Divider(color: PdfColors.grey300),
              
              // Totals
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Ingresos:'),
                  pw.Text(format.format(totalIncomes), style: const pw.TextStyle(color: PdfColors.green)),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Egresos:'),
                  pw.Text(format.format(totalExpenses), style: const pw.TextStyle(color: PdfColors.red)),
                ]
              ),
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Consolidado de todas las billeteras remanente:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(format.format(finalTotalBalance), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]
              ),
              
              pw.SizedBox(height: 24),
              
              // Detail List
              pw.Text('Detalle de Gastos e Ingresos', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              
              pw.Table.fromTextArray(
                headers: ['Fecha', 'Tipo', 'Descripción', 'C. Costo', 'Monto'],
                data: movements.map((m) => [
                  DateFormat('dd/MM/yy').format(m.date),
                  m.type == MovementType.income ? 'Ingreso' : 'Egreso',
                  m.description,
                  m.establishment,
                  format.format(m.grossAmount)
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                }
              ),
              pw.SizedBox(height: 48),
              // Firma en la parte inferior izquierda
              pw.Container(
                width: 180,
                height: 50,
                decoration: pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 1.0)),
                ),
                alignment: pw.Alignment.topLeft,
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text('Firma del Empleado', style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
          );
        },
      ),
    );

    // Prompt user to print/save PDF
    await Printing.layoutPdf(onLayout: (PdfPageFormat form) async => pdf.save());
  }

  static Future<void> generateRangeReport({
    required List<MovementModel> movements,
    required String rangeText,
    required String ownerName,
  }) async {
    final pdf = pw.Document();
    final format = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

    final expenses = movements.where((m) => m.type == MovementType.expense).toList();
    final totalExpenses = expenses.fold(0.0, (sum, m) => sum + m.grossAmount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Reporte de Gastos', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Caja Chica: $ownerName', style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Rango seleccionado: $rangeText'),
            pw.Text('Fecha Emisión: ${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now())}'),
            pw.Divider(),
            pw.SizedBox(height: 16),

            pw.Table.fromTextArray(
              headers: ['Fecha', 'Descripción', 'C. Costo', 'Método', 'Monto'],
              data: expenses.map((m) => [
                DateFormat('dd/MM/yy').format(m.date),
                m.description,
                m.establishment,
                m.paymentMethod,
                format.format(m.grossAmount)
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              }
            ),

            pw.SizedBox(height: 24),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('TOTAL GASTOS: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text(format.format(totalExpenses), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.red)),
              ],
            ),

            pw.SizedBox(height: 48),
            // Firma en la parte inferior izquierda
            pw.Container(
              width: 180,
              height: 50,
              decoration: pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 1.0)),
              ),
              alignment: pw.Alignment.topLeft,
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text('Firma del Empleado', style: const pw.TextStyle(fontSize: 10)),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat form) async => pdf.save());
  }

  static Future<void> generateSelectedExpensesReport({
    required List<MovementModel> movements,
    required String userName,
    String? title,
  }) async {
    final pdf = pw.Document();
    final format = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

    final expenses = movements.where((m) => m.type == MovementType.expense).toList();
    final incomes  = movements.where((m) => m.type == MovementType.income).toList();

    final totalExpenses = expenses.fold(0.0, (sum, m) => sum + m.grossAmount);
    final totalIncomes  = incomes.fold(0.0, (sum, m) => sum + m.grossAmount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(title ?? 'Rendición de Gastos Seleccionados', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Solicitante: $userName', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Fecha de Emisión: ${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Total de comprobantes: ${movements.length}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 12),

            pw.Table.fromTextArray(
              headers: ['Fecha', 'Tipo', 'Comprobante', 'Descripción', 'C. Costo', 'Forma Pago', 'Monto'],
              data: movements.map((m) => [
                DateFormat('dd/MM/yy').format(m.invoiceDate ?? m.date),
                m.type == MovementType.income ? 'Ingreso' : 'Egreso',
                m.invoiceType,
                m.description,
                m.establishment,
                m.paymentMethod,
                format.format(m.grossAmount)
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
              cellStyle: const pw.TextStyle(fontSize: 9),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.centerLeft,
                6: pw.Alignment.centerRight,
              }
            ),

            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (totalIncomes > 0)
                  pw.Text('Ingresos: ${format.format(totalIncomes)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                pw.Text('TOTAL RENDICIÓN: ${format.format(totalExpenses)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.black)),
              ],
            ),

            pw.SizedBox(height: 48),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(
                  width: 180,
                  height: 50,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 1.0)),
                  ),
                  alignment: pw.Alignment.topLeft,
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text('Firma del Empleado / Rendidor', style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Container(
                  width: 180,
                  height: 50,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 1.0)),
                  ),
                  alignment: pw.Alignment.topLeft,
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text('Aprobado por Administración', style: const pw.TextStyle(fontSize: 9)),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat form) async => pdf.save());
  }

  static Future<void> printMovementReceipt(MovementModel movement, {String? companyName}) async {
    final pdf = pw.Document();
    final format = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

    pw.MemoryImage? receiptImage;
    if (movement.imageUrl != null && movement.imageUrl!.isNotEmpty) {
      try {
        final url = movement.imageUrl!;
        if (url.startsWith('data:image')) {
          final base64String = url.split(',').last;
          final bytes = base64Decode(base64String);
          receiptImage = pw.MemoryImage(bytes);
        } else if (url.startsWith('http')) {
          final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
          if (response.statusCode == 200) {
            receiptImage = pw.MemoryImage(response.bodyBytes);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error loading receipt image for print: $e');
        }
      }
    }

    final isIncome = movement.type == MovementType.income;
    final primaryColor = isIncome ? PdfColors.green800 : PdfColors.red800;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        build: (pw.Context context) {
          return [
            // ── HEADER ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      (companyName != null && companyName.isNotEmpty) ? companyName.toUpperCase() : 'CAJA CHICA',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'COMPROBANTE DE MOVIMIENTO',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'COMPROBANTE N°',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        movement.invoiceNumber?.isNotEmpty == true ? movement.invoiceNumber! : 'S/N',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(movement.date)}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1, color: primaryColor),
            pw.SizedBox(height: 12),

            // ── DETAILS GRID ──
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                color: PdfColors.grey50,
              ),
              child: pw.Column(
                children: [
                  _pdfRow('Tipo de Operación:', isIncome ? 'INGRESO' : 'EGRESO', isBoldVal: true, valColor: primaryColor),
                  pw.SizedBox(height: 6),
                  _pdfRow('Concepto / Descripción:', movement.description),
                  pw.SizedBox(height: 6),
                  _pdfRow('Tipo de Comprobante:', movement.invoiceType),
                  pw.SizedBox(height: 6),
                  _pdfRow('Fecha del Comprobante:', DateFormat('dd/MM/yyyy').format(movement.invoiceDate ?? movement.date)),
                  pw.SizedBox(height: 6),
                  _pdfRow('Solicitante / Rendidor:', movement.userName ?? 'Usuario'),
                  pw.SizedBox(height: 6),
                  _pdfRow('Centro de Costo / Sucursal:', movement.establishment),
                  pw.SizedBox(height: 6),
                  _pdfRow('Método de Pago:', movement.paymentMethod),
                  if (movement.category != null) ...[
                    pw.SizedBox(height: 6),
                    _pdfRow('Rubro / Categoría:', movement.category!.displayName),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // ── TAX & AMOUNT BREAKDOWN ──
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                children: [
                  if (movement.type == MovementType.expense && movement.netAmount > 0) ...[
                    _pdfRow('Subtotal (Neto gravado):', format.format(movement.netAmount)),
                    pw.SizedBox(height: 4),
                  ],
                  if (movement.vat > 0) ...[
                    _pdfRow('IVA Liquidado:', format.format(movement.vat)),
                    pw.SizedBox(height: 4),
                  ],
                  if (movement.otherTaxes > 0) ...[
                    _pdfRow('Otros Impuestos / Percepciones:', format.format(movement.otherTaxes)),
                    pw.SizedBox(height: 4),
                  ],
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('MONTO TOTAL:', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        format.format(movement.grossAmount),
                        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // ── RECEIPT IMAGE / ATTACHMENT ──
            if (receiptImage != null) ...[
              pw.Text('COMPROBANTE ADJUNTO:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
              pw.SizedBox(height: 6),
              pw.Container(
                alignment: pw.Alignment.center,
                height: 280,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Image(receiptImage, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 20),
            ] else if (movement.imageUrl != null && movement.imageUrl!.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  color: PdfColors.grey100,
                ),
                child: pw.Row(
                  children: [
                    pw.Text('Adjunto digital: Comprobante registrado en el sistema.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // ── SIGNATURES ──
            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(
                  width: 200,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text('Firma del Solicitante / Rendidor', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text(movement.userName ?? 'Usuario', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Container(
                  width: 200,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text('Aprobado por Administración', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Firma y Sello', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.Text(
                'Documento emitido por Sistema de Caja Chica • Desarrollado por Javier Córdoba',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat form) async => pdf.save(),
      name: 'Comprobante_${movement.invoiceNumber ?? movement.id}.pdf',
    );
  }

  static pw.Widget _pdfRow(String label, String value, {bool isBoldVal = false, PdfColor? valColor}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 150,
          child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: isBoldVal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valColor ?? PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }
}
