import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static String _monthShort(DateTime date) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[date.month - 1];
  }

  static String _formatDateForPdf(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')} ${_monthShort(date)} ${date.year}";
  }

  static String getReportRangeLabel({
    required String reportView,
    required DateTime selectedDate,
    required int selectedMonth,
  }) {
    if (reportView == "Daily") {
      return _formatDateForPdf(selectedDate);
    }

    if (reportView == "Weekly") {
      final weeks = getWeeksForMonth(DateTime.now().year, selectedMonth);
      if (weeks.isNotEmpty) {
        final start = weeks.first['start']!;
        final end = weeks.last['end']!;
        return "${_formatDateForPdf(start)} - ${_formatDateForPdf(end)}";
      }
    }

    final start = DateTime(DateTime.now().year, selectedMonth, 1);
    final end = DateTime(DateTime.now().year, selectedMonth + 1, 0);
    return "${_formatDateForPdf(start)} - ${_formatDateForPdf(end)}";
  }

  static List<Map<String, DateTime>> getWeeksForMonth(int year, int month) {
    List<Map<String, DateTime>> weeks = [];

    DateTime start = DateTime(year, month, 1);
    DateTime monthEnd = DateTime(year, month + 1, 0);

    while (!start.isAfter(monthEnd)) {
      DateTime end = start.add(const Duration(days: 6));
      if (end.isAfter(monthEnd)) {
        end = monthEnd;
      }

      weeks.add({
        "start": start,
        "end": end,
      });

      start = end.add(const Duration(days: 1));
    }

    return weeks;
  }

  static pw.Widget _pdfLabelValue(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
            ),
            pw.TextSpan(
              text: value,
              style: const pw.TextStyle(
                color: PdfColors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _pdfSummaryCard(String title, String value) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF5F5FA),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE1E1EF)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static Future<Uint8List> generateReportPdf({
    required List<Map<String, dynamic>> reportList,
    required String reportView,
    required DateTime selectedDate,
    required int selectedMonth,
    required double dailyLimit,
    required double monthlyLimit,
    String userName = "Daily Kharcha User",
    // String developerName = "Harshender Singh",
  }) async {
    final pdf = pw.Document();

    final fontData =
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final baseFont = pw.Font.ttf(fontData);

    final totalAmount = reportList.fold(
      0.0,
      (sum, tx) => sum + (tx['amount'] as double),
    );

    final totalTransactions = reportList.length;
    final averageAmount =
        totalTransactions == 0 ? 0 : totalAmount / totalTransactions;

    final Map<String, double> categoryTotals = {};
    for (final tx in reportList) {
      final category = (tx['category'] ?? '').toString();
      final amount = (tx['amount'] as num).toDouble();
      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
    }

    String topCategory = "No Data";
    double topCategoryAmount = 0;
    if (categoryTotals.isNotEmpty) {
      final topEntry = categoryTotals.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      topCategory = topEntry.key;
      topCategoryAmount = topEntry.value;
    }

    final activeLimit = reportView == "Daily" ? dailyLimit : monthlyLimit;
    final isLimitCrossed = activeLimit > 0 && totalAmount > activeLimit;

    final motivationalLine = activeLimit == 0
        ? "Every rupee you track is a step toward smarter financial decisions."
        : isLimitCrossed
            ? "You crossed your limit this time, but consistent tracking today can build stronger saving habits tomorrow."
            : "Amazing job! You stayed within your limit. Small disciplined savings today create big freedom tomorrow.";

    final categoryRows = categoryTotals.entries.map((entry) {
      final percent = totalAmount == 0 ? 0 : (entry.value / totalAmount) * 100;
      return [
        entry.key,
        "₹ ${entry.value.toStringAsFixed(0)}",
        "${percent.toStringAsFixed(1)}%",
      ];
    }).toList();
    final sortedReportList = [...reportList];

    sortedReportList.sort((a, b) {
      final dateA = a['date'] as DateTime;
      final dateB = b['date'] as DateTime;
      return dateB.compareTo(dateA);
    });
    final txRows = sortedReportList.map((tx) {
      final date = tx['date'] as DateTime;
      return [
        "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}",
        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}",
        (tx['category'] ?? '').toString(),
        (tx['mode'] ?? 'Cash').toString(),
        "₹ ${(tx['amount'] as double).toStringAsFixed(0)}",
      ];
    }).toList();

    final reportTypeLabel = reportView;
    final reportRangeLabel = getReportRangeLabel(
      reportView: reportView,
      selectedDate: selectedDate,
      selectedMonth: selectedMonth,
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(
            base: baseFont,
            bold: baseFont,
          ),
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(16),
              gradient: const pw.LinearGradient(
                colors: [
                  PdfColor.fromInt(0xFF1E1E2C),
                  PdfColor.fromInt(0xFF2C2C54),
                ],
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Daily Kharcha',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Premium Expense Report',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfLabelValue('User', userName),
                        _pdfLabelValue('Report Type', reportTypeLabel),
                        _pdfLabelValue('Date Range', reportRangeLabel),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfLabelValue(
                          'Generated',
                          _formatDateForPdf(DateTime.now()),
                        ),
                        _pdfLabelValue(
                          'Transactions',
                          '$totalTransactions',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pdfSummaryCard(
                'Total Expense',
                '₹ ${totalAmount.toStringAsFixed(0)}',
              ),
              _pdfSummaryCard(
                'Average Spend',
                '₹ ${averageAmount.toStringAsFixed(0)}',
              ),
              _pdfSummaryCard(
                'Top Category',
                topCategory == 'No Data'
                    ? topCategory
                    : '$topCategory • ₹ ${topCategoryAmount.toStringAsFixed(0)}',
              ),
              _pdfSummaryCard(
                'Limit Status',
                activeLimit == 0
                    ? 'No limit set'
                    : isLimitCrossed
                        ? 'Limit crossed'
                        : 'Within limit',
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Category Breakdown',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Category', 'Amount', 'Share'],
            data: categoryRows.isEmpty
                ? [
                    ['-', '-', '-']
                  ]
                : categoryRows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF40407A),
            ),
            cellStyle: const pw.TextStyle(fontSize: 11),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Transaction Details',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Time', 'Category', 'Mode', 'Amount'],
            data: txRows.isEmpty
                ? [
                    ['-', '-', 'No transactions', '-', '-']
                  ]
                : txRows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF2C2C54),
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: isLimitCrossed
                  ? PdfColor.fromInt(0xFFFFF1F1)
                  : PdfColor.fromInt(0xFFF2FFF5),
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(
                color: isLimitCrossed
                    ? PdfColor.fromInt(0xFFFFC9C9)
                    : PdfColor.fromInt(0xFFBFE8C8),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Motivation',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  motivationalLine,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Generated by Daily Kharcha',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<void> exportPdf({
    required List<Map<String, dynamic>> reportList,
    required String reportView,
    required DateTime selectedDate,
    required int selectedMonth,
    required double dailyLimit,
    required double monthlyLimit,
    String userName = "Daily Kharcha User",
    // String developerName = "Harshender Singh",
  }) async {
    final bytes = await generateReportPdf(
      reportList: reportList,
      reportView: reportView,
      selectedDate: selectedDate,
      selectedMonth: selectedMonth,
      dailyLimit: dailyLimit,
      monthlyLimit: monthlyLimit,
      userName: userName,
      // developerName: developerName,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'daily_kharcha_${reportView.toLowerCase()}_report',
    );
  }

  static Future<void> sharePdf({
    required List<Map<String, dynamic>> reportList,
    required String reportView,
    required DateTime selectedDate,
    required int selectedMonth,
    required double dailyLimit,
    required double monthlyLimit,
    String userName = "Daily Kharcha User",
    // String developerName = "Harshender Singh",
  }) async {
    final bytes = await generateReportPdf(
      reportList: reportList,
      reportView: reportView,
      selectedDate: selectedDate,
      selectedMonth: selectedMonth,
      dailyLimit: dailyLimit,
      monthlyLimit: monthlyLimit,
      userName: userName,
      // developerName: developerName,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'daily_kharcha_${reportView.toLowerCase()}_report.pdf',
    );
  }
}