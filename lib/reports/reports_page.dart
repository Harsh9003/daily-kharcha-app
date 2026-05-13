import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../udhar/services/udhar_service.dart';

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
    final reportList = widget.reportList;

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
        final customers = docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'phone': data['phone'] ?? '',
            'balance': ((data['balance'] ?? 0) as num).toDouble(),
            'updatedAt': data['updatedAt'],
          };
        }).toList();

        final willReceive = customers
            .where((e) => (e['balance'] as double) > 0)
            .fold<double>(0, (s, e) => s + (e['balance'] as double));

        final needToPay = customers
            .where((e) => (e['balance'] as double) < 0)
            .fold<double>(0, (s, e) => s + ((e['balance'] as double).abs()));

        return Container(
          color: isDark ? _darkBg : const Color(0xFFF6F7FB),
          child: Column(
            children: [
              _buildHeader(
                isDark: isDark,
                totalAmount: totalAmount,
                willReceive: willReceive,
                needToPay: needToPay,
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
  }

  Widget _buildHeader({
    required bool isDark,
    required double totalAmount,
    required double willReceive,
    required double needToPay,
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
                      onTap: widget.onSmartInsightsTap,
                      child: _headerIcon(
                        Icons.auto_awesome_rounded,
                        Colors.amberAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: widget.onExportTap,
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
          ],
        ),
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
    return ChoiceChip(
      label: Text(value, style: const TextStyle(fontSize: 12)),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      selected: widget.reportView == value,
      onSelected: (_) => widget.onReportViewChanged(value),
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
