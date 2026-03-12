import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/movement_model.dart';

class PDFService {
  static Future<void> generateAndPrint(double cashBalance, double debitBalance, List<MovementModel> movements) async {
    final pdf = pw.Document();
    final format = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

    // Calculate totals and initial balances for each method
    double totalCashExpenses = 0.0;
    double totalCashIncomes = 0.0;
    double totalDebitExpenses = 0.0;
    double totalDebitIncomes = 0.0;

    for (var m in movements) {
      if (m.type == MovementType.expense) {
        if(m.paymentMethod == PaymentMethod.cash) totalCashExpenses += m.grossAmount;
        else totalDebitExpenses += m.grossAmount;
      } else {
        if(m.paymentMethod == PaymentMethod.cash) totalCashIncomes += m.grossAmount;
        else totalDebitIncomes += m.grossAmount;
      }
    }

    final initialCashBalance = cashBalance - totalCashIncomes + totalCashExpenses;
    final initialDebitBalance = debitBalance - totalDebitIncomes + totalDebitExpenses;

    final totalExpenses = totalCashExpenses + totalDebitExpenses;
    final totalIncomes = totalCashIncomes + totalDebitIncomes;
    final finalTotalBalance = cashBalance + debitBalance;

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
              pw.Text('Fecha Generacion: \${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now())}'),
              pw.Divider(),
              pw.SizedBox(height: 16),

              // Summary
              pw.Text('Resumen', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              
              // Cash section
              pw.Text('Billetera Efectivo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Saldo Inicial Efectivo:'),
                  pw.Text(format.format(initialCashBalance)),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Saldo Final Efectivo:'),
                  pw.Text(format.format(cashBalance), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]
              ),
              pw.SizedBox(height: 8),

              // Debit section
              pw.Text('Billetera Tarjeta/Débito', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Saldo Inicial Tarjeta:'),
                  pw.Text(format.format(initialDebitBalance)),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Saldo Final Tarjeta:'),
                  pw.Text(format.format(debitBalance), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]
              ),
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
                  m.costCenter.name,
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
                m.costCenter.name,
                m.paymentMethod == PaymentMethod.cash ? 'Efectivo' : 'Tarjeta',
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

            pw.SizedBox(height: 100),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 200,
                  height: 60,
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
                  alignment: pw.Alignment.bottomLeft,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Firma:', style: const pw.TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat form) async => pdf.save());
  }
}
