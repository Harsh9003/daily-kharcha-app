import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../udhar/services/udhar_service.dart';
import '../services/pdf_service.dart';

class ReportsPage extends StatefulWidget {
  final List<Map<String, dynamic>> reportList;
  final String reportView;
  final int selectedMonth;
  final int selectedWeekIndex;
  final DateTime selectedDate;
  final bool showPercentage;

  final Function(String value) onReportViewChanged;
  final Function(int month) onMonthChanged;
  final Function(int weekIndex) onWeekChanged;
  final Function(DateTime date) onDateChanged;
  final VoidCallback onTogglePercentage;
  final VoidCallback onSmartInsightsTap;
  final VoidCallback onExportTap;
  final Function(String category, List<Map<String, dynamic>> reportList)
      onCategoryTap;

  const ReportsPage({
    super.key,
    required this.reportList,
    required this.reportView,
    required this.selectedMonth,
    required this.selectedWeekIndex,
    required this.selectedDate,
    required this.showPercentage,
    required this.onReportViewChanged,
    required this.onMonthChanged,
    required this.onWeekChanged,
    required this.onDateChanged,
    required this.onTogglePercentage,
    required this.onSmartInsightsTap,
    required this.onExportTap,
    required this.onCategoryTap,
  });

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String selectedSection = "Transactions";
  String selectedPaymentMode = "All";

  static const List<String> _paymentModes = ["All", "Cash", "UPI", "Card"];

  static const Color _darkBg = Color(0xFF020817);
  static const Color _cardDark = Color(0xFF1F2030);
  static const Color _primary = Color(0xFF5B55A7);
  static const Color _headerStart = Color(0xFF6C5CE7);
  static const Color _headerEnd = Color(0xFF4B3F8F);

  final List<String> months = const [
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reportList = _filterTransactionsByPaymentMode(widget.reportList);

    final double totalAmount = reportList.fold(
      0.0,
      (sum, item) => sum + ((item['amount'] ?? 0) as num).toDouble(),
    );

    final Map<String, double> categoryTotal = {};
    for (final tx in reportList) {
      final cat = (tx['category'] ?? "Other").toString();
      final amt = ((tx['amount'] ?? 0) as num).toDouble();
      categoryTotal[cat] = (categoryTotal[cat] ?? 0) + amt;
    }

    final weeks = getWeeksForMonth(DateTime.now().year, widget.selectedMonth);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: UdharService.streamCustomers(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final allCustomers = docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'phone': data['phone'] ?? '',
            'balance': ((data['balance'] ?? 0) as num).toDouble(),
            'updatedAt': data['updatedAt'],
          };
        }).toList();

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _buildUdharCustomersForSelectedPaymentMode(allCustomers),
          builder: (context, udharSnapshot) {
            final customers = udharSnapshot.data ??
                (selectedPaymentMode == "All" ? allCustomers : <Map<String, dynamic>>[]);

            final willReceive = customers
                .where((e) => ((e['balance'] ?? 0) as num).toDouble() > 0)
                .fold<double>(
                  0,
                  (s, e) => s + ((e['balance'] ?? 0) as num).toDouble(),
                );

            final needToPay = customers
                .where((e) => ((e['balance'] ?? 0) as num).toDouble() < 0)
                .fold<double>(
                  0,
                  (s, e) => s + (((e['balance'] ?? 0) as num).toDouble().abs()),
                );

            return Container(
              color: isDark ? _darkBg : const Color(0xFFF6F7FB),
              child: Column(
                children: [
                  _buildHeader(
                    isDark: isDark,
                    totalAmount: totalAmount,
                    willReceive: willReceive,
                    needToPay: needToPay,
                    customers: customers,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopRow(isDark),
                          if (selectedSection == "Transactions") ...[
                            const SizedBox(height: 10),
                            _buildDateFilters(isDark, weeks),
                          ] else
                            const SizedBox(height: 12),
                          Expanded(
                            child: selectedSection == "Transactions"
                                ? _buildTransactionReport(
                                    isDark,
                                    categoryTotal,
                                    totalAmount,
                                    reportList,
                                  )
                                : _buildUdharReport(
                                    isDark: isDark,
                                    isLoading: snapshot.connectionState ==
                                            ConnectionState.waiting ||
                                        udharSnapshot.connectionState ==
                                            ConnectionState.waiting,
                                    customers: customers,
                                    willReceive: willReceive,
                                    needToPay: needToPay,
                                  ),
                          ),
                          const SizedBox(height: 12),
                          _buildBottomToggle(isDark),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader({
    required bool isDark,
    required double totalAmount,
    required double willReceive,
    required double needToPay,
    required List<Map<String, dynamic>> customers,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_headerStart, _headerEnd],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Report",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _handleSmartInsightsTap(
                        customers: customers,
                        totalAmount: totalAmount,
                        willReceive: willReceive,
                        needToPay: needToPay,
                      ),
                      child: _headerIcon(
                        Icons.auto_awesome_rounded,
                        Colors.amberAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _handleHeaderExport(customers),
                      child: _headerIcon(
                        Icons.ios_share_rounded,
                        Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: selectedSection == "Transactions"
                  ? Text(
                      "Total: ₹ ${totalAmount.toStringAsFixed(0)}",
                      key: const ValueKey('transaction_total'),
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Row(
                      key: const ValueKey('udhar_total'),
                      children: [
                        _miniHeaderAmount(
                          icon: Icons.south_west_rounded,
                          label: "Receive",
                          amount: willReceive,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(width: 18),
                        _miniHeaderAmount(
                          icon: Icons.north_east_rounded,
                          label: "Pay",
                          amount: needToPay,
                          color: Colors.orangeAccent,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            _buildPaymentModeFilter(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentModeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Payment Mode",
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.30),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            children: _paymentModes.map((mode) {
              return Expanded(child: _paymentModeChip(mode));
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _paymentModeChip(String mode) {
    final selected = selectedPaymentMode == mode;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPaymentMode = mode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7C5CFF), Color(0xFF4B35C8)],
                )
              : null,
          color: selected ? null : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.white.withOpacity(0.14)
                : Colors.white.withOpacity(0.06),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF7C5CFF).withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _paymentModeIcon(mode),
                size: 16,
                color: _paymentModeIconColor(mode, selected),
              ),
              const SizedBox(width: 6),
              Text(
                mode,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _paymentModeIcon(String mode) {
    switch (mode) {
      case "Cash":
        return Icons.payments_rounded;
      case "UPI":
        return Icons.bolt_rounded;
      case "Card":
        return Icons.credit_card_rounded;
      default:
        return Icons.grid_view_rounded;
    }
  }

  Color _paymentModeIconColor(String mode, bool selected) {
    if (selected) return Colors.white;

    switch (mode) {
      case "Cash":
        return Colors.lightGreenAccent;
      case "UPI":
        return Colors.orangeAccent;
      case "Card":
        return Colors.orangeAccent;
      default:
        return Colors.white70;
    }
  }

  List<Map<String, dynamic>> _filterTransactionsByPaymentMode(
    List<Map<String, dynamic>> items,
  ) {
    if (selectedPaymentMode == "All") return items;

    return items.where((tx) {
      final mode = _readPaymentMode(tx);
      return mode == selectedPaymentMode.toLowerCase();
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _buildUdharCustomersForSelectedPaymentMode(
    List<Map<String, dynamic>> customers,
  ) async {
    if (selectedPaymentMode == "All") return customers;

    final selectedMode = selectedPaymentMode.toLowerCase();
    final List<Map<String, dynamic>> filteredCustomers = [];

    for (final customer in customers) {
      final customerId = (customer['id'] ?? '').toString();
      if (customerId.isEmpty) continue;

      final txSnapshot = await UdharService.customersRef()
          .doc(customerId)
          .collection('transactions')
          .get();

      double filteredBalance = 0;
      Timestamp? latestUpdatedAt;

      for (final txDoc in txSnapshot.docs) {
        final tx = txDoc.data();
        final mode = _readPaymentMode(tx);

        if (mode != selectedMode) continue;

        final amount = ((tx['amount'] ?? 0) as num).toDouble();
        final type = (tx['type'] ?? '').toString().trim().toLowerCase();

        if (_isUdharReceivedType(type)) {
          filteredBalance -= amount;
        } else if (_isUdharGivenType(type)) {
          filteredBalance += amount;
        } else {
          // Existing/old entries usually store only amount + paymentMode.
          // Keep them receivable by default so filtering does not hide or flip them.
          filteredBalance += amount;
        }

        final updatedAt = tx['updatedAt'] ?? tx['createdAt'];
        if (updatedAt is Timestamp &&
            (latestUpdatedAt == null ||
                updatedAt.compareTo(latestUpdatedAt) > 0)) {
          latestUpdatedAt = updatedAt;
        }
      }

      if (filteredBalance != 0) {
        filteredCustomers.add({
          ...customer,
          'balance': filteredBalance,
          if (latestUpdatedAt != null) 'updatedAt': latestUpdatedAt,
        });
      }
    }

    return filteredCustomers;
  }

  String _readPaymentMode(Map<String, dynamic> data) {
    final value = data['paymentMode'] ??
        data['payment_mode'] ??
        data['paymentType'] ??
        data['payment_type'] ??
        data['mode'] ??
        data['type'];

    final mode = value?.toString().trim().toLowerCase() ?? '';

    if (mode.contains('cash')) return 'cash';
    if (mode.contains('upi')) return 'upi';
    if (mode.contains('card') || mode.contains('credit')) return 'card';

    return mode;
  }

  bool _isUdharGivenType(String rawType) {
    final type = rawType.trim().toLowerCase();
    return type == 'given' ||
        type == 'give' ||
        type.contains('gave') ||
        type.contains('given');
  }

  bool _isUdharReceivedType(String rawType) {
    final type = rawType.trim().toLowerCase();
    return type == 'taken' ||
        type == 'received' ||
        type == 'receive' ||
        type.contains('taken') ||
        type.contains('received') ||
        type.contains('receive');
  }


  Future<void> _handleHeaderExport(List<Map<String, dynamic>> customers) async {
    if (selectedSection == "Transactions") {
      widget.onExportTap();
      return;
    }

    _openUdharExportSheet(customers);
  }

  void _openUdharExportSheet(List<Map<String, dynamic>> customers) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final panelColor = isDark ? const Color(0xFF171827) : Colors.white;
        final titleColor = isDark ? Colors.white : const Color(0xFF24242C);
        final subColor = isDark ? Colors.white54 : Colors.black45;
        final tileColor = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF7F7FA);
        final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

        Future<void> exportUdharReport() async {
          Navigator.pop(sheetContext);
          try {
            await PdfService.shareUdharBookReportPdf(customers: customers);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Unable to generate Udhar Book report: $e")),
            );
          }
        }

        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Export Report",
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Udhar Book Report",
                  style: TextStyle(
                    color: subColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                _exportSheetTile(
                  isDark: isDark,
                  tileColor: tileColor,
                  borderColor: borderColor,
                  icon: Icons.picture_as_pdf_rounded,
                  title: "Export PDF",
                  subtitle: "Open print / save PDF dialog",
                  onTap: exportUdharReport,
                ),
                const SizedBox(height: 10),
                _exportSheetTile(
                  isDark: isDark,
                  tileColor: tileColor,
                  borderColor: borderColor,
                  icon: Icons.share_rounded,
                  title: "Share Report",
                  subtitle: "Share the PDF report instantly",
                  onTap: exportUdharReport,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _exportSheetTile({
    required bool isDark,
    required Color tileColor,
    required Color borderColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(isDark ? 0.22 : 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: const Color(0xFF4B3F8F),
                size: 22,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF24242C),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  void _handleSmartInsightsTap({
    required List<Map<String, dynamic>> customers,
    required double totalAmount,
    required double willReceive,
    required double needToPay,
  }) {
    if (selectedSection == "Transactions") {
      widget.onSmartInsightsTap();
      return;
    }

    _openUdharSmartInsightsDialog(
      customers: customers,
      willReceive: willReceive,
      needToPay: needToPay,
    );
  }

  void _openUdharSmartInsightsDialog({
    required List<Map<String, dynamic>> customers,
    required double willReceive,
    required double needToPay,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final receiveList = customers
        .where((e) => (e['balance'] as double) > 0)
        .toList()
      ..sort((a, b) =>
          (b['balance'] as double).compareTo(a['balance'] as double));

    final payList = customers
        .where((e) => (e['balance'] as double) < 0)
        .toList()
      ..sort((a, b) =>
          (a['balance'] as double).compareTo(b['balance'] as double));

    final settledCount = customers
        .where((e) => (e['balance'] as double) == 0)
        .length;
    final activeCount = customers.length - settledCount;
    final netBalance = willReceive - needToPay;
    final highestReceive = receiveList.isNotEmpty ? receiveList.first : null;
    final highestPay = payList.isNotEmpty ? payList.first : null;

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111322) : Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.45 : 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C5CE7), Color(0xFF4B3F8F)],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.amberAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Udhar Book Insights",
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF151526),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Smart summary of pending balances",
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black45,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.07)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white70 : Colors.black54,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _udharInsightTile(
                          isDark: isDark,
                          title: "Receive",
                          value: "₹ ${willReceive.toStringAsFixed(0)}",
                          icon: Icons.south_west_rounded,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _udharInsightTile(
                          isDark: isDark,
                          title: "Pay",
                          value: "₹ ${needToPay.toStringAsFixed(0)}",
                          icon: Icons.north_east_rounded,
                          color: Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _udharInsightTile(
                    isDark: isDark,
                    title: netBalance >= 0 ? "Net Positive" : "Net Payable",
                    value: "₹ ${netBalance.abs().toStringAsFixed(0)}",
                    icon: Icons.account_balance_wallet_rounded,
                    color: netBalance >= 0 ? Colors.greenAccent : Colors.orangeAccent,
                    fullWidth: true,
                  ),
                  const SizedBox(height: 14),
                  _insightPersonRow(
                    isDark: isDark,
                    title: "Highest Receivable",
                    person: highestReceive,
                    emptyText: "No pending receiving",
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(height: 8),
                  _insightPersonRow(
                    isDark: isDark,
                    title: "Highest Payable",
                    person: highestPay,
                    emptyText: "No pending payment",
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _smallInsightStat(
                          isDark: isDark,
                          label: "Active People",
                          value: "$activeCount",
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _smallInsightStat(
                          isDark: isDark,
                          label: "Settled",
                          value: "$settledCount",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _udharInsightTile({
    required bool isDark,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.055) : const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF151526),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightPersonRow({
    required bool isDark,
    required String title,
    required Map<String, dynamic>? person,
    required String emptyText,
    required Color color,
  }) {
    final name = person == null ? emptyText : person['name'].toString();
    final balance = person == null ? 0.0 : (person['balance'] as double).abs();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.045) : const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.055) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: color.withOpacity(0.16),
            child: Icon(Icons.person_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF151526),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (person != null) ...[
            const SizedBox(width: 8),
            Text(
              "₹ ${balance.toStringAsFixed(0)}",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _smallInsightStat({
    required bool isDark,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.045) : const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF151526),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniHeaderAmount({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
  }) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              "$label ₹ ${amount.toStringAsFixed(0)}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildTopRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Text(
            selectedSection == "Transactions"
                ? "Transaction Report"
                : "Udhar Book Report",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (selectedSection == "Transactions") ...[
          const SizedBox(width: 8),
          Row(
            children: [
              _viewChip("Monthly"),
              const SizedBox(width: 4),
              _viewChip("Weekly"),
              const SizedBox(width: 4),
              _viewChip("Daily"),
            ],
          ),
        ],
      ],
    );
  }

  Widget _viewChip(String value) {
    final selected = widget.reportView == value;

    return GestureDetector(
      onTap: () => widget.onReportViewChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white.withOpacity(0.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilters(bool isDark, List<Map<String, DateTime>> weeks) {
    if (widget.reportView == "Monthly") {
      return Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 12,
              itemBuilder: (_, i) {
                final selected = widget.selectedMonth == i + 1;
                return GestureDetector(
                  onTap: () => widget.onMonthChanged(i + 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? _primary
                          : (isDark ? Colors.white10 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        months[i],
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black54),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    if (widget.reportView == "Weekly") {
      return Column(
        children: [
          SizedBox(
            height: 46,
            child: weeks.isEmpty
                ? Center(
                    child: Text(
                      "No weeks available",
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: weeks.length,
                    itemBuilder: (_, i) {
                      final week = weeks[i];
                      final start = week['start']!;
                      final end = week['end']!;
                      final selected = widget.selectedWeekIndex == i;

                      return GestureDetector(
                        onTap: () => widget.onWeekChanged(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? _primary
                                : (isDark ? Colors.white10 : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              _formatWeekRange(start, end),
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : Colors.black54),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 58,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _daysInMonth(
              widget.selectedDate.year,
              widget.selectedDate.month,
            ),
            itemBuilder: (_, index) {
              final date = DateTime(
                widget.selectedDate.year,
                widget.selectedDate.month,
                index + 1,
              );
              final selected = widget.selectedDate.day == date.day &&
                  widget.selectedDate.month == date.month &&
                  widget.selectedDate.year == date.year;

              return GestureDetector(
                onTap: () => widget.onDateChanged(date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? _primary
                        : (isDark ? Colors.white10 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _weekdayShort(date),
                        style: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${date.day}",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildTransactionReport(
    bool isDark,
    Map<String, double> categoryTotal,
    double totalAmount,
    List<Map<String, dynamic>> reportList,
  ) {
    if (categoryTotal.isEmpty) {
      return Center(
        child: Text(
          "No transactions found",
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView(
      children: categoryTotal.entries.map((entry) {
        return GestureDetector(
          onTap: () => widget.onCategoryTap(entry.key, reportList),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? _cardDark : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: widget.onTogglePercentage,
                  child: Text(
                    widget.showPercentage
                        ? (totalAmount == 0
                            ? "0.0%"
                            : "${((entry.value / totalAmount) * 100).toStringAsFixed(1)}%")
                        : "₹ ${entry.value.toStringAsFixed(0)}",
                    style: TextStyle(
                      color: isDark ? Colors.greenAccent : _headerEnd,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUdharReport({
    required bool isDark,
    required bool isLoading,
    required List<Map<String, dynamic>> customers,
    required double willReceive,
    required double needToPay,
  }) {
    if (isLoading && customers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (customers.isEmpty) {
      return Center(
        child: Text(
          "No udhar records found",
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final receiveList = customers
        .where((e) => (e['balance'] as double) > 0)
        .toList()
      ..sort((a, b) => (b['balance'] as double).compareTo(a['balance'] as double));

    final payList = customers
        .where((e) => (e['balance'] as double) < 0)
        .toList()
      ..sort((a, b) => (a['balance'] as double).compareTo(b['balance'] as double));

    return ListView(
      children: [
        _compactBalanceStrip(
          isDark: isDark,
          willReceive: willReceive,
          needToPay: needToPay,
        ),
        const SizedBox(height: 12),
        _udharGroup(
          isDark: isDark,
          title: "You Will Receive",
          amount: willReceive,
          color: Colors.greenAccent,
          emptyText: "No receiving pending",
          items: receiveList,
          isReceive: true,
        ),
        const SizedBox(height: 12),
        _udharGroup(
          isDark: isDark,
          title: "You Need To Pay",
          amount: needToPay,
          color: Colors.orangeAccent,
          emptyText: "No payment pending",
          items: payList,
          isReceive: false,
        ),
      ],
    );
  }

  Widget _compactBalanceStrip({
    required bool isDark,
    required double willReceive,
    required double needToPay,
  }) {
    final net = willReceive - needToPay;
    final netColor = net >= 0 ? Colors.greenAccent : Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? _cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_rounded, color: netColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Net Balance",
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            "₹ ${net.abs().toStringAsFixed(0)}",
            style: TextStyle(
              color: netColor,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _udharGroup({
    required bool isDark,
    required String title,
    required double amount,
    required Color color,
    required String emptyText,
    required List<Map<String, dynamic>> items,
    required bool isReceive,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? _cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                "₹ ${amount.toStringAsFixed(0)}",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                emptyText,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ...items.map(
              (item) => _udharPersonTile(
                isDark: isDark,
                item: item,
                color: color,
                isReceive: isReceive,
              ),
            ),
        ],
      ),
    );
  }

  Widget _udharPersonTile({
    required bool isDark,
    required Map<String, dynamic> item,
    required Color color,
    required bool isReceive,
  }) {
    final name = item['name'].toString();
    final phone = item['phone'].toString();
    final balance = (item['balance'] as double).abs();
    final updatedAt = item['updatedAt'];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.20),
            child: Text(
              _initials(name),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phone.isNotEmpty
                      ? phone
                      : (isReceive ? "Owes you" : "You owe"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₹ ${balance.toStringAsFixed(0)}",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatTimestamp(updatedAt),
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black45,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToggle(bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bottomToggleItem(isDark, "Transactions"),
            const SizedBox(width: 6),
            _bottomToggleItem(isDark, "Udhar Book"),
          ],
        ),
      ),
    );
  }

  Widget _bottomToggleItem(bool isDark, String value) {
    final selected = selectedSection == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedSection = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black54),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  String _weekdayShort(DateTime date) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return days[date.weekday - 1];
  }

  String _formatWeekRange(DateTime start, DateTime end) {
    return "${start.day} ${months[start.month - 1]} - ${end.day} ${months[end.month - 1]}";
  }

  List<Map<String, DateTime>> getWeeksForMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);

    final List<Map<String, DateTime>> weeks = [];
    DateTime start = firstDay;

    while (start.isBefore(lastDay) || start.isAtSameMomentAs(lastDay)) {
      DateTime end = start.add(const Duration(days: 6));
      if (end.isAfter(lastDay)) end = lastDay;

      weeks.add({"start": start, "end": end});
      start = end.add(const Duration(days: 1));
    }

    return weeks;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return "?";
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _formatTimestamp(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return "";

    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    return "$day $month";
  }
}
