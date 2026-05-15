// Limit modes update applied
// UPDATED_WEB_DASHBOARD_V4_PREMIUM_FILTER_DROPDOWN_PROFILE_FIXED
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WebDashboardPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onThemeToggle;

  const WebDashboardPage({
    super.key,
    required this.isDark,
    required this.onThemeToggle,
  });

  @override
  State<WebDashboardPage> createState() => _WebDashboardPageState();
}

class _WebDashboardPageState extends State<WebDashboardPage> {
  int selectedMenu = 0;
  DashboardFilter selectedFilter = DashboardFilter.today;
  DateTime selectedDate = DateTime.now();
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedWeekStart = _startOfWeek(DateTime.now());
  DateTime? customStart;
  DateTime? customEnd;
  String searchQuery = '';
  String _typingSearchQuery = '';
  Timer? _searchDebounce;
  String? _cachedUid;
  Stream<QuerySnapshot>? _transactionsStream;
  bool _recycleCleanupStarted = false;

  static DateTime _startOfWeek(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    return clean.subtract(Duration(days: clean.weekday - 1));
  }

  Stream<QuerySnapshot> _userTransactionsStream(String uid) {
    if (_cachedUid != uid || _transactionsStream == null) {
      _cachedUid = uid;
      _transactionsStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .snapshots();
    }
    return _transactionsStream!;
  }

  void _onSearchTyping(String value) {
    _typingSearchQuery = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      if (searchQuery == _typingSearchQuery) return;
      setState(() => searchQuery = _typingSearchQuery);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login first')),
      );
    }

    _cleanupOldRecycleBinItems(user.uid);

    return StreamBuilder<QuerySnapshot>(
      stream: _userTransactionsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final allTransactions = (snapshot.data?.docs ?? []).map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final rawDate = data['date'];

          DateTime txDate;
          if (rawDate is Timestamp) {
            txDate = rawDate.toDate();
          } else {
            txDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
          }

          return WebTx(
            id: doc.id,
            amount: (data['amount'] as num?)?.toDouble() ?? 0,
            category: (data['category'] ?? 'Other').toString(),
            mode: (data['mode'] ?? 'Cash').toString(),
            note: (data['note'] ?? data['description'] ?? '').toString(),
            date: txDate,
          );
        }).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final filteredTransactions = _applySearch(_applyFilter(allTransactions));
        final categories = _buildCategories(allTransactions);
        final totalExpense = filteredTransactions.fold<double>(0, (sum, tx) => sum + tx.amount);
        final categoryTotals = _categoryTotals(filteredTransactions);
        final topCategories = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        return Scaffold(
          backgroundColor: widget.isDark ? const Color(0xFF080B16) : const Color(0xFFF6F8FC),
          body: Row(
            children: [
              _Sidebar(
                isDark: widget.isDark,
                userName: user.displayName ?? 'User',
                photoUrl: _bestPhotoUrl(user),
                selectedIndex: selectedMenu,
                onMenuTap: (index) {
                  if (selectedMenu == index) return;
                  setState(() => selectedMenu = index);
                },
              ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      isDark: widget.isDark,
                      userName: user.displayName ?? 'User',
                      photoUrl: _bestPhotoUrl(user),
                      searchQuery: searchQuery,
                      onSearchChanged: _onSearchTyping,
                      onThemeToggle: widget.onThemeToggle,
                      onAddExpense: () => _openAddExpenseDialog(categories),
                      onSetLimit: _openLimitDialog,
                      onLogout: _logoutUser,
                      notificationButton: _adminNotificationBell(),
                    ),
                    Expanded(
                      child: RepaintBoundary(
                        child: _buildSelectedPage(
                          allTransactions: allTransactions,
                          filteredTransactions: filteredTransactions,
                          totalExpense: totalExpense,
                          topCategories: topCategories,
                          categories: categories,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectedPage({
    required List<WebTx> allTransactions,
    required List<WebTx> filteredTransactions,
    required double totalExpense,
    required List<MapEntry<String, double>> topCategories,
    required List<String> categories,
  }) {
    final filterBar = _FilterBar(
      selectedFilter: selectedFilter,
      selectedDate: selectedDate,
      selectedMonth: selectedMonth,
      selectedWeekStart: selectedWeekStart,
      customStart: customStart,
      customEnd: customEnd,
      onFilterChanged: (value) => setState(() => selectedFilter = value),
      onDateChanged: (date) => setState(() => selectedDate = date),
      onMonthChanged: (date) => setState(() => selectedMonth = date),
      onWeekChanged: (date) => setState(() => selectedWeekStart = date),
      onPickDate: _pickParticularDate,
      onPickRange: _pickCustomRange,
      onAddExpense: () => _openAddExpenseDialog(categories),
    );

    switch (selectedMenu) {
      case 1:
        return _TransactionsPage(
          key: const ValueKey('transactions'),
          transactions: filteredTransactions,
          filterBar: filterBar,
          onTransactionTap: _openTransactionDetails,
        );
      case 2:
        return _WebUdharBookPage(
          key: const ValueKey('udhar-book'),
          isDark: widget.isDark,
        );
      case 3:
        return _CategoriesPage(
          key: const ValueKey('categories'),
          topCategories: topCategories,
          totalExpense: totalExpense,
        );
      case 4:
        return _ReportsPage(
          key: const ValueKey('reports'),
          transactions: filteredTransactions,
          topCategories: topCategories,
          totalExpense: totalExpense,
          filterBar: filterBar,
          onTransactionTap: _openTransactionDetails,
        );
      case 5:
        return _SimpleInfoPage(
          key: const ValueKey('reminders'),
          title: 'Reminders',
          message: 'Reminder summary and scheduling controls will be connected here. Existing mobile reminder settings will remain safe.',
          icon: Icons.notifications_active_rounded,
        );
      case 6:
        return _SimpleInfoPage(
          key: const ValueKey('settings'),
          title: 'Settings',
          message: 'Theme, profile, and app preferences will be managed here in a web-friendly settings layout.',
          icon: Icons.settings_rounded,
        );
      case 7:
        return _RecycleBinPage(
          key: const ValueKey('recycle-bin'),
          onRestore: _restoreDeletedTransaction,
          onPermanentDelete: _permanentDeleteTransaction,
          onDeleteAll: _permanentDeleteAllRecycleBin,
        );
      default:
        return _DashboardPage(
          key: const ValueKey('dashboard'),
          filterBar: filterBar,
          allTransactions: allTransactions,
          filteredTransactions: filteredTransactions,
          totalExpense: totalExpense,
          topCategories: topCategories,
          onTransactionTap: _openTransactionDetails,
          onSetLimit: _openLimitDialog,
          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
          selectedMonth: selectedMonth,
        );
    }
  }

  List<String> _buildCategories(List<WebTx> transactions) {
    final set = <String>{'Food', 'Travel', 'Shopping', 'Petrol'};
    for (final tx in transactions) {
      if (tx.category.trim().isNotEmpty) set.add(tx.category.trim());
    }
    return set.toList()..sort();
  }

  Map<String, double> _categoryTotals(List<WebTx> transactions) {
    final map = <String, double>{};
    for (final tx in transactions) {
      map[tx.category] = (map[tx.category] ?? 0) + tx.amount;
    }
    return map;
  }

  List<WebTx> _applySearch(List<WebTx> transactions) {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return transactions;
    return transactions.where((tx) {
      return tx.category.toLowerCase().contains(q) ||
          tx.mode.toLowerCase().contains(q) ||
          tx.note.toLowerCase().contains(q) ||
          tx.amount.toStringAsFixed(0).contains(q) ||
          _formatDate(tx.date).contains(q);
    }).toList();
  }

  List<WebTx> _applyFilter(List<WebTx> transactions) {
    final now = DateTime.now();
    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

    switch (selectedFilter) {
      case DashboardFilter.today:
        return transactions.where((tx) => sameDay(tx.date, now)).toList();
      case DashboardFilter.particularDate:
        return transactions.where((tx) => sameDay(tx.date, selectedDate)).toList();
      case DashboardFilter.thisWeek:
        final end = selectedWeekStart.add(const Duration(days: 7));
        return transactions.where((tx) => !tx.date.isBefore(selectedWeekStart) && tx.date.isBefore(end)).toList();
      case DashboardFilter.thisMonth:
        return transactions.where((tx) => tx.date.year == now.year && tx.date.month == now.month).toList();
      case DashboardFilter.particularMonth:
        return transactions.where((tx) => tx.date.year == selectedMonth.year && tx.date.month == selectedMonth.month).toList();
      case DashboardFilter.customRange:
        if (customStart == null || customEnd == null) return transactions;
        final end = DateTime(customEnd!.year, customEnd!.month, customEnd!.day, 23, 59, 59);
        return transactions.where((tx) => !tx.date.isBefore(customStart!) && !tx.date.isAfter(end)).toList();
      case DashboardFilter.allTime:
        return transactions;
    }
  }

  Future<void> _pickParticularDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDate: selectedDate.isAfter(now) ? now : selectedDate,
      helpText: 'Select transaction date',
      cancelText: 'Cancel',
      confirmText: 'Apply',
      builder: _premiumDatePickerBuilder,
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedFilter = DashboardFilter.particularDate;
      });
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final safeStart = customStart ?? now.subtract(const Duration(days: 7));
    final safeEnd = customEnd ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: safeStart.isAfter(now) ? now : safeStart,
        end: safeEnd.isAfter(now) ? now : safeEnd,
      ),
      helpText: 'Select custom range',
      cancelText: 'Cancel',
      confirmText: 'Apply',
      saveText: 'Apply Range',
      builder: _premiumDatePickerBuilder,
    );

    if (picked != null) {
      setState(() {
        customStart = picked.start;
        customEnd = picked.end;
        selectedFilter = DashboardFilter.customRange;
      });
    }
  }

  Widget _premiumDatePickerBuilder(BuildContext context, Widget? child) {
    final base = Theme.of(context);

    return Theme(
      data: base.copyWith(
        dialogBackgroundColor: const Color(0xFF101320),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          onPrimary: Colors.white,
          surface: Color(0xFF101320),
          onSurface: Color(0xFFF4F1FF),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFD7C5FF),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
            ),
          ),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: const Color(0xFF101320),
          surfaceTintColor: Colors.transparent,
          elevation: 28,
          shadowColor: Colors.black.withOpacity(.50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          headerBackgroundColor: const Color(0xFF181B2B),
          headerForegroundColor: const Color(0xFFF4F1FF),
          headerHelpStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFFB9B4C8),
          ),
          headerHeadlineStyle: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -.8,
            color: Color(0xFFF4F1FF),
          ),
          weekdayStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFFD7C5FF),
          ),
          dayStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          yearStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          dayShape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          todayBorder: const BorderSide(color: Color(0xFF8B5CF6), width: 1.2),
          todayForegroundColor: WidgetStateProperty.all(const Color(0xFFD7C5FF)),
          dayOverlayColor: WidgetStateProperty.all(const Color(0xFF8B5CF6).withOpacity(.12)),
          rangeSelectionBackgroundColor: const Color(0xFF8B5CF6).withOpacity(.22),
          rangePickerBackgroundColor: const Color(0xFF101320),
          rangePickerHeaderBackgroundColor: const Color(0xFF181B2B),
          rangePickerHeaderForegroundColor: const Color(0xFFF4F1FF),
          rangePickerHeaderHelpStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFFB9B4C8),
          ),
          rangePickerHeaderHeadlineStyle: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -.7,
            color: Color(0xFFF4F1FF),
          ),
          rangeSelectionOverlayColor: WidgetStateProperty.all(
            const Color(0xFF8B5CF6).withOpacity(.14),
          ),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return const Color(0xFF8B5CF6);
            return Colors.transparent;
          }),
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            if (states.contains(WidgetState.disabled)) return const Color(0xFF6D687A);
            return const Color(0xFFE9E4F5);
          }),
        ),
      ),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 360),
        tween: Tween(begin: .94, end: 1),
        curve: Curves.easeOutExpo,
        builder: (context, value, animatedChild) {
          return Transform.scale(
            scale: value,
            child: Opacity(opacity: value.clamp(0, 1), child: animatedChild),
          );
        },
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _openLimitDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() ?? <String, dynamic>{};
    final monthKey = _limitMonthKey(selectedMonth);
    final globalMonthlyLimit = _limitToDouble(data['monthlyLimit']);
    final selectedMonthLimit = _monthLimitFromUserData(data, selectedMonth);
    final dailyLimit = _limitToDouble(data['dailyLimit']);

    var limitMode = selectedMonthLimit > 0 ? 'month' : 'all';
    final monthlyController = TextEditingController(
      text: (limitMode == 'month' ? selectedMonthLimit : globalMonthlyLimit) > 0
          ? (limitMode == 'month' ? selectedMonthLimit : globalMonthlyLimit).toStringAsFixed(0)
          : '',
    );
    final dailyController = TextEditingController(text: dailyLimit > 0 ? dailyLimit.toStringAsFixed(0) : '');

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final monthLabel = _monthName(selectedMonth);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void switchLimitMode(String mode) {
              if (limitMode == mode) return;
              setDialogState(() {
                limitMode = mode;
                final newValue = mode == 'month' ? selectedMonthLimit : globalMonthlyLimit;
                monthlyController.text = newValue > 0 ? newValue.toStringAsFixed(0) : '';
              });
            }

            Widget modeChip({
              required String mode,
              required String title,
              required String subtitle,
              required IconData icon,
            }) {
              final selected = limitMode == mode;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => switchLimitMode(mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)])
                          : null,
                      color: selected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? Colors.white.withOpacity(.10) : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: selected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF4B3F72))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: selected ? Colors.white : (isDark ? Colors.white : const Color(0xFF211B3C)))),
                              const SizedBox(height: 2),
                              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: selected ? Colors.white.withOpacity(.82) : (isDark ? Colors.white54 : Colors.black45))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                width: 520,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151B2E) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(.06)),
                  boxShadow: [BoxShadow(color: const Color(0xFF6C3BFF).withOpacity(.24), blurRadius: 38, offset: const Offset(0, 18))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 52,
                          width: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF14B8A6)]),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.savings_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(child: Text('Set Expense Limit', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900))),
                        IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(.055) : const Color(0xFFF3F0FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2D8FF)),
                      ),
                      child: Row(
                        children: [
                          modeChip(mode: 'all', title: 'All Months', subtitle: 'Global monthly limit', icon: Icons.public_rounded),
                          const SizedBox(width: 6),
                          modeChip(mode: 'month', title: 'This Month', subtitle: '$monthLabel only', icon: Icons.calendar_month_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PremiumField(
                      child: TextField(
                        controller: monthlyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: limitMode == 'all' ? 'Monthly Limit for All Months' : 'Monthly Limit for $monthLabel',
                          prefixText: '₹ ',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PremiumField(
                      child: TextField(
                        controller: dailyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Daily Limit', prefixText: '₹ ', border: InputBorder.none),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      limitMode == 'all'
                          ? 'This monthly limit will apply to every month unless a month-specific limit is saved.'
                          : 'This limit will apply only to $monthLabel. Other months will keep the global limit.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54, height: 1.35),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final monthly = double.tryParse(monthlyController.text.trim()) ?? 0;
                              final daily = double.tryParse(dailyController.text.trim()) ?? 0;
                              final updateData = <String, dynamic>{
                                'dailyLimit': daily,
                                'limitMode': limitMode == 'month' ? 'thisMonth' : 'allMonths',
                                'limitUpdatedAt': FieldValue.serverTimestamp(),
                              };

                              if (limitMode == 'all') {
                                updateData['monthlyLimit'] = monthly;
                              } else {
                                final freshDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                                final freshData = freshDoc.data() ?? <String, dynamic>{};

                                final monthlyLimitsByMonth = freshData['monthlyLimitsByMonth'] is Map
                                    ? Map<String, dynamic>.from(freshData['monthlyLimitsByMonth'] as Map)
                                    : <String, dynamic>{};
                                final monthlyLimits = freshData['monthlyLimits'] is Map
                                    ? Map<String, dynamic>.from(freshData['monthlyLimits'] as Map)
                                    : <String, dynamic>{};
                                final monthLimits = freshData['monthLimits'] is Map
                                    ? Map<String, dynamic>.from(freshData['monthLimits'] as Map)
                                    : <String, dynamic>{};

                                monthlyLimitsByMonth[monthKey] = monthly;
                                monthlyLimits[monthKey] = monthly;
                                monthLimits[monthKey] = monthly;

                                updateData['monthlyLimitsByMonth'] = monthlyLimitsByMonth;
                                updateData['monthlyLimits'] = monthlyLimits;
                                updateData['monthLimits'] = monthLimits;
                                updateData['selectedMonthLimit'] = monthly;
                                updateData['selectedMonthLimitKey'] = monthKey;
                              }

                              await FirebaseFirestore.instance.collection('users').doc(user.uid).set(updateData, SetOptions(merge: true));

                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                              if (!mounted) return;
                              _showPremiumToast(
                                title: 'Limit updated',
                                message: limitMode == 'month'
                                    ? '$monthLabel ki monthly limit save ho gayi hai.'
                                    : 'All months ke liye monthly limit save ho gayi hai.',
                                icon: Icons.check_circle_rounded,
                              );
                            },
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Save Limit'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFF6C3BFF),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    monthlyController.dispose();
    dailyController.dispose();
  }

  Future<void> _logoutUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(.72),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: 430,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF151827),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(.10)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.45), blurRadius: 40, offset: const Offset(0, 22))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF4D57), Color(0xFFFF7A59)]),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(Icons.logout_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: Text('Logout?', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Colors.white))),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Aap current account se sign out ho jaoge. Baad me dobara login kar sakte ho.', style: TextStyle(color: Color(0xFFD7D9E4), height: 1.45, fontWeight: FontWeight.w600)),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D57), foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _openAddExpenseDialog(List<String> categories) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final dialogCategories = categories.toSet().toList()..sort();
    String selectedCategory = dialogCategories.isNotEmpty ? dialogCategories.first : 'Food';
    if (!dialogCategories.contains(selectedCategory)) dialogCategories.add(selectedCategory);
    String selectedMode = 'Cash';
    DateTime selectedTxDate = DateTime.now();
    final modes = ['Cash', 'UPI', 'Card'];

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                width: 540,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151B2E) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C3BFF).withOpacity(0.25),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF3278FF), Color(0xFF7A3CFF)]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.add_card_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Add Expense', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                              SizedBox(height: 3),
                              // Text('New transaction ko safely Firestore me save karega'),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _PremiumField(
                      child: TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixText: '₹ ',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _PremiumSelectField(
                            label: 'Category',
                            value: selectedCategory,
                            icon: Icons.category_rounded,
                            items: dialogCategories,
                            onChanged: (v) => setDialogState(() => selectedCategory = v),
                            onAddCustom: () async {
                              final newCategory = await _openCustomCategoryDialog(dialogContext);
                              if (newCategory == null) return;
                              setDialogState(() {
                                if (!dialogCategories.contains(newCategory)) {
                                  dialogCategories.add(newCategory);
                                  dialogCategories.sort();
                                }
                                selectedCategory = newCategory;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PremiumSelectField(
                            label: 'Payment Mode',
                            value: selectedMode,
                            icon: selectedMode == 'UPI'
                                ? Icons.qr_code_2_rounded
                                : selectedMode == 'Card'
                                    ? Icons.credit_card_rounded
                                    : Icons.payments_rounded,
                            items: modes,
                            onChanged: (v) => setDialogState(() => selectedMode = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDate: selectedTxDate.isAfter(DateTime.now()) ? DateTime.now() : selectedTxDate,
                          helpText: 'Select expense date',
                          cancelText: 'Cancel',
                          confirmText: 'Apply',
                          builder: _premiumDatePickerBuilder,
                        );
                        if (picked != null) setDialogState(() => selectedTxDate = picked);
                      },
                      child: _PremiumField(
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date', border: InputBorder.none),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 18),
                              const SizedBox(width: 10),
                              Text(_formatDate(selectedTxDate), style: const TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PremiumField(
                      child: TextField(
                        controller: noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Note / Description', border: InputBorder.none),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final user = FirebaseAuth.instance.currentUser;
                              final amount = double.tryParse(amountController.text.trim());
                              if (user == null || amount == null || amount <= 0) return;

                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('transactions')
                                  .add({
                                'amount': amount,
                                'category': selectedCategory,
                                'mode': selectedMode,
                                'note': noteController.text.trim(),
                                'date': selectedTxDate.toIso8601String(),
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                            },
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Save Expense'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFF6C3BFF),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
    noteController.dispose();
  }


  Future<String?> _openCustomCategoryDialog(BuildContext parentContext) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: parentContext,
      barrierDismissible: true,
      builder: (customContext) {
        final isDark = Theme.of(customContext).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151B2E) : Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C3BFF).withOpacity(0.25),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF3278FF), Color(0xFF7A3CFF)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Add Custom Category', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    ),
                    IconButton(onPressed: () => Navigator.pop(customContext), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 18),
                _PremiumField(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Category name',
                      hintText: 'Example: Bike EMI, Rent, Medicine',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) {
                      final clean = value.trim();
                      if (clean.isNotEmpty) Navigator.pop(customContext, clean);
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(customContext),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final clean = controller.text.trim();
                          if (clean.isEmpty) return;
                          Navigator.pop(customContext, clean);
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: const Color(0xFF6C3BFF),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();
    final clean = result?.trim();
    if (clean == null || clean.isEmpty) return null;
    return clean;
  }

  Future<void> _cleanupOldRecycleBinItems(String uid) async {
    if (_recycleCleanupStarted) return;
    _recycleCleanupStarted = true;

    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 5));
      final oldItems = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('recycleBin')
          .where('deletedAt', isLessThan: Timestamp.fromDate(cutoff))
          .get();

      if (oldItems.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in oldItems.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {
      // Silent cleanup failure should not block the user flow.
    }
  }

  Future<void> _openTransactionDetails(WebTx tx) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151B2E) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(.06)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C3BFF).withOpacity(.24),
                  blurRadius: 38,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF7A3CFF), Color(0xFF4F46E5)]),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(_formatDate(tx.date), style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(.055) : const Color(0xFFF6F8FC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(.05)),
                  ),
                  child: Column(
                    children: [
                      _detailRow('Amount', '₹ ${tx.amount.toStringAsFixed(0)}'),
                      _detailRow('Payment Mode', tx.mode),
                      _detailRow('Date', _formatDate(tx.date)),
                      _detailRow('Description', tx.note.trim().isEmpty ? 'No description added' : tx.note.trim()),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _openEditExpenseDialog(tx);
                        },
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _softDeleteTransaction(tx);
                        },
                        icon: const Icon(Icons.delete_rounded),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF)))),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }

  Future<void> _openEditExpenseDialog(WebTx tx) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final amountController = TextEditingController(text: tx.amount.toStringAsFixed(tx.amount.truncateToDouble() == tx.amount ? 0 : 2));
    final noteController = TextEditingController(text: tx.note);
    String selectedCategory = tx.category;
    String selectedMode = tx.mode;
    DateTime selectedTxDate = tx.date;
    final categories = _buildCategories([])..add(tx.category);
    final dialogCategories = categories.toSet().toList()..sort();
    final modes = ['Cash', 'UPI', 'Card'];
    if (!modes.contains(selectedMode)) modes.add(selectedMode);

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                width: 540,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151B2E) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
                  boxShadow: [BoxShadow(color: const Color(0xFF6C3BFF).withOpacity(0.25), blurRadius: 40, offset: const Offset(0, 18))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF3278FF), Color(0xFF7A3CFF)]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.edit_note_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(child: Text('Edit Transaction', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                        IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _PremiumField(
                      child: TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ', border: InputBorder.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _PremiumSelectField(
                            label: 'Category',
                            value: selectedCategory,
                            icon: Icons.category_rounded,
                            items: dialogCategories,
                            onChanged: (v) => setDialogState(() => selectedCategory = v),
                            onAddCustom: () async {
                              final newCategory = await _openCustomCategoryDialog(dialogContext);
                              if (newCategory == null) return;
                              setDialogState(() {
                                if (!dialogCategories.contains(newCategory)) {
                                  dialogCategories.add(newCategory);
                                  dialogCategories.sort();
                                }
                                selectedCategory = newCategory;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PremiumSelectField(
                            label: 'Payment Mode',
                            value: selectedMode,
                            icon: selectedMode == 'UPI' ? Icons.qr_code_2_rounded : selectedMode == 'Card' ? Icons.credit_card_rounded : Icons.payments_rounded,
                            items: modes,
                            onChanged: (v) => setDialogState(() => selectedMode = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDate: selectedTxDate.isAfter(DateTime.now()) ? DateTime.now() : selectedTxDate,
                          helpText: 'Select expense date',
                          cancelText: 'Cancel',
                          confirmText: 'Apply',
                          builder: _premiumDatePickerBuilder,
                        );
                        if (picked != null) setDialogState(() => selectedTxDate = picked);
                      },
                      child: _PremiumField(
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date', border: InputBorder.none),
                          child: Row(children: [const Icon(Icons.calendar_month_rounded, size: 18), const SizedBox(width: 10), Text(_formatDate(selectedTxDate), style: const TextStyle(fontWeight: FontWeight.w800))]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PremiumField(child: TextField(controller: noteController, maxLines: 2, decoration: const InputDecoration(labelText: 'Note / Description', border: InputBorder.none))),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(dialogContext), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Cancel'))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final amount = double.tryParse(amountController.text.trim());
                              if (amount == null || amount <= 0) return;

                              await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').doc(tx.id).update({
                                'amount': amount,
                                'category': selectedCategory,
                                'mode': selectedMode,
                                'note': noteController.text.trim(),
                                'date': selectedTxDate.toIso8601String(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                            },
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Update'),
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: const Color(0xFF6C3BFF), foregroundColor: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
    noteController.dispose();
  }

  Future<void> _softDeleteTransaction(WebTx tx) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final txRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').doc(tx.id);
    final recycleRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('recycleBin').doc(tx.id);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(txRef);
      final originalData = snapshot.data() ?? <String, dynamic>{};
      transaction.set(recycleRef, {
        ...originalData,
        'originalTransactionId': tx.id,
        'amount': tx.amount,
        'category': tx.category,
        'mode': tx.mode,
        'note': tx.note,
        'date': tx.date.toIso8601String(),
        'deletedAt': FieldValue.serverTimestamp(),
        'autoDeleteAfter': Timestamp.fromDate(DateTime.now().add(const Duration(days: 5))),
      });
      transaction.delete(txRef);
    });

    if (!mounted) return;
    _showPremiumToast(
      title: 'Moved to Recycle Bin',
      message: 'Transaction will be auto-deleted permanently after 5 days.',
      icon: Icons.delete_outline_rounded,
      actionLabel: 'Open',
      onAction: () => setState(() => selectedMenu = 7),
    );
  }

  Future<void> _restoreDeletedTransaction(RecycledTx tx) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final recycleRef = userRef.collection('recycleBin').doc(tx.id);

    if (tx.isUdharPerson) {
      final customerId = tx.originalCustomerId.isEmpty ? tx.id.replaceFirst('udhar_person_', '') : tx.originalCustomerId;
      final customerRef = userRef.collection('udharCustomers').doc(customerId);
      final customerData = Map<String, dynamic>.from((tx.rawData['customerData'] as Map?) ?? tx.rawData);
      final rawTransactions = tx.rawData['transactions'];

      customerData.remove('recycleType');
      customerData.remove('deletedType');
      customerData.remove('deletedAt');
      customerData.remove('autoDeleteAfter');
      customerData.remove('originalCustomerId');
      customerData.remove('customerData');
      customerData.remove('transactions');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.set(customerRef, {
          ...customerData,
          'name': tx.category,
          'phone': tx.note,
          'balance': tx.amount == 0 ? (customerData['balance'] ?? 0) : (customerData['balance'] ?? tx.amount),
          'updatedAt': FieldValue.serverTimestamp(),
          'restoredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (rawTransactions is List) {
          for (final item in rawTransactions) {
            if (item is! Map) continue;
            final txId = (item['id'] ?? '').toString();
            if (txId.isEmpty) continue;

            final data = Map<String, dynamic>.from(item);
            data.remove('id');
            transaction.set(customerRef.collection('transactions').doc(txId), {
              ...data,
              'restoredAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }

        transaction.delete(recycleRef);
      });
    } else if (tx.isUdharTransaction) {
      final customerId = tx.originalCustomerId;
      if (customerId.isEmpty) return;

      final customerRef = userRef.collection('udharCustomers').doc(customerId);
      final transactionId = tx.originalTransactionId.isEmpty ? tx.id.replaceFirst('udhar_tx_', '') : tx.originalTransactionId;
      final transactionData = Map<String, dynamic>.from((tx.rawData['transactionData'] as Map?) ?? tx.rawData);
      transactionData.remove('recycleType');
      transactionData.remove('deletedType');
      transactionData.remove('deletedAt');
      transactionData.remove('autoDeleteAfter');
      transactionData.remove('originalCustomerId');
      transactionData.remove('originalTransactionId');
      transactionData.remove('customerName');
      transactionData.remove('transactionData');

      final type = (transactionData['type'] ?? tx.rawData['type'] ?? 'given').toString();
      final balanceEffect = type == 'given' ? tx.amount : -tx.amount;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.set(customerRef.collection('transactions').doc(transactionId), {
          ...transactionData,
          'type': type,
          'amount': tx.amount,
          'note': tx.note,
          'transactionDate': Timestamp.fromDate(tx.date),
          'restoredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.update(customerRef, {
          'balance': FieldValue.increment(balanceEffect),
          'latestTransactionDate': Timestamp.fromDate(tx.date),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.delete(recycleRef);
      });
    } else {
      final txRef = userRef.collection('transactions').doc(tx.originalTransactionId.isEmpty ? tx.id : tx.originalTransactionId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.set(txRef, {
          'amount': tx.amount,
          'category': tx.category,
          'mode': tx.mode,
          'note': tx.note,
          'date': tx.date.toIso8601String(),
          'restoredAt': FieldValue.serverTimestamp(),
        });
        transaction.delete(recycleRef);
      });
    }

    if (!mounted) return;
    _showPremiumToast(
      title: 'Restored successfully',
      message: '${tx.displayTitle} has been restored.',
      icon: Icons.restore_rounded,
    );
  }

  Future<void> _permanentDeleteTransaction(RecycledTx tx) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('recycleBin').doc(tx.id).delete();
    if (!mounted) return;
    _showPremiumToast(
      title: 'Deleted permanently',
      message: 'Item has been removed from Recycle Bin.',
      icon: Icons.delete_forever_rounded,
    );
  }

  Future<void> _permanentDeleteAllRecycleBin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docs = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('recycleBin')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    if (!mounted) return;
    _showPremiumToast(
      title: 'Recycle Bin cleared',
      message: '${docs.docs.length} deleted item(s) removed permanently.',
      icon: Icons.cleaning_services_rounded,
    );
  }

  void _showPremiumToast({
    required String title,
    required String message,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 24,
        right: 24,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 360),
          tween: Tween(begin: 0, end: 1),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(36 * (1 - value), 0),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 390,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827).withOpacity(.96),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(.10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.35),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: const Color(0xFF7A3CFF).withOpacity(.18),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF7A3CFF), Color(0xFF22D3EE)]),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                        const SizedBox(height: 3),
                        Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFC7C9D4), fontWeight: FontWeight.w600, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () {
                        entry.remove();
                        onAction();
                      },
                      child: Text(actionLabel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  String? _bestPhotoUrl(User user) {
    final direct = user.photoURL;
    if (direct != null && direct.trim().isNotEmpty) return direct;
    for (final provider in user.providerData) {
      final url = provider.photoURL;
      if (url != null && url.trim().isNotEmpty) return url;
    }
    return null;
  }

  Widget _adminNotificationBell() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (uid == null) {
      return IconButton(
        onPressed: _openAdminNotificationsSheet,
        icon: const Icon(Icons.notifications_none_rounded),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnapshot) {
        final lastOpenedAt = userSnapshot.data?.data()?['notificationsOpenedAt'];
        DateTime? lastOpenedDate;
        if (lastOpenedAt is Timestamp) lastOpenedDate = lastOpenedAt.toDate();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('dismissedNotifications')
              .snapshots(),
          builder: (context, dismissedSnapshot) {
            final dismissedIds = dismissedSnapshot.hasData
                ? dismissedSnapshot.data!.docs.map((e) => e.id).toSet()
                : <String>{};

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                int unreadCount = 0;
                if (snapshot.hasData) {
                  final docs = _visibleAdminNotifications(snapshot.data!.docs, dismissedIds, uid);
                  for (final doc in docs) {
                    final createdAt = doc.data()['createdAt'];
                    if (createdAt is Timestamp) {
                      if (lastOpenedDate == null || createdAt.toDate().isAfter(lastOpenedDate)) unreadCount++;
                    } else if (lastOpenedDate == null) {
                      unreadCount++;
                    }
                  }
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: _openAdminNotificationsSheet,
                      icon: Icon(unreadCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7A3CFF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _visibleAdminNotifications(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Set<String> dismissedIds,
    String uid,
  ) {
    final now = DateTime.now();
    return docs.where((doc) {
      if (dismissedIds.contains(doc.id)) return false;
      final data = doc.data();
      final scheduledAt = data['scheduledAt'];
      if (scheduledAt is Timestamp && scheduledAt.toDate().isAfter(now)) return false;
      final targetType = (data['targetType'] ?? 'all').toString();
      final targetUserId = (data['targetUserId'] ?? '').toString();
      return targetType == 'all' || (targetType == 'single' && targetUserId == uid);
    }).toList();
  }

  Future<void> _dismissNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('dismissedNotifications')
        .doc(notificationId)
        .set({'dismissedAt': FieldValue.serverTimestamp()});
  }

  Future<void> _dismissAllNotifications(List<String> ids) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || ids.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    final base = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('dismissedNotifications');
    for (final id in ids) {
      batch.set(base.doc(id), {'dismissedAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  void _openAdminNotificationsSheet() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'notificationsOpenedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.76),
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF10182B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.28), blurRadius: 28, offset: const Offset(0, 16))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF3278FF), Color(0xFF7A3CFF)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.campaign_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          SizedBox(height: 2),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 14),
                if (uid == null)
                  const Expanded(child: Center(child: Text('Please login first')))
                else
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('dismissedNotifications')
                          .snapshots(),
                      builder: (context, dismissedSnapshot) {
                        final dismissedIds = dismissedSnapshot.hasData
                            ? dismissedSnapshot.data!.docs.map((e) => e.id).toSet()
                            : <String>{};

                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('notifications')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) return const Center(child: Text('Notifications load nahi ho paayi'));
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                            final docs = _visibleAdminNotifications(snapshot.data!.docs, dismissedIds, uid);
                            if (docs.isEmpty) {
                              return const Center(child: Text('No admin notifications yet'));
                            }

                            return Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _dismissAllNotifications(docs.map((e) => e.id).toList()),
                                    icon: const Icon(Icons.delete_sweep_rounded),
                                    label: const Text('Delete All'),
                                  ),
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    primary: false,
                                    itemCount: docs.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final doc = docs[index];
                                      final data = doc.data();
                                      final title = (data['title'] ?? 'Notification').toString();
                                      final body = (data['body'] ?? '').toString();
                                      final createdAt = data['createdAt'];
                                      String timeText = '';
                                      if (createdAt is Timestamp) {
                                        final dt = createdAt.toDate();
                                        timeText = '${_formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                      }

                                      return Dismissible(
                                        key: ValueKey(doc.id),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(right: 18),
                                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(18)),
                                          child: const Icon(Icons.delete_rounded, color: Colors.white),
                                        ),
                                        onDismissed: (_) => _dismissNotification(doc.id),
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF7F8FC),
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                height: 42,
                                                width: 42,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF7A3CFF).withOpacity(0.16),
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                child: const Icon(Icons.campaign_rounded, color: Color(0xFF8B5CF6)),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                                                    if (body.isNotEmpty) ...[
                                                      const SizedBox(height: 5),
                                                      Text(body, style: const TextStyle(height: 1.35)),
                                                    ],
                                                    if (timeText.isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      Text(timeText, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete',
                                                onPressed: () => _dismissNotification(doc.id),
                                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

}

enum DashboardFilter { today, particularDate, thisWeek, thisMonth, particularMonth, customRange, allTime }

class WebTx {
  final String id;
  final double amount;
  final String category;
  final String mode;
  final String note;
  final DateTime date;

  WebTx({
    required this.id,
    required this.amount,
    required this.category,
    required this.mode,
    required this.note,
    required this.date,
  });
}

class RecycledTx {
  final String id;
  final String recycleType;
  final String originalTransactionId;
  final String originalCustomerId;
  final double amount;
  final String category;
  final String mode;
  final String note;
  final DateTime date;
  final DateTime? deletedAt;
  final DateTime? autoDeleteAfter;
  final Map<String, dynamic> rawData;

  RecycledTx({
    required this.id,
    required this.recycleType,
    required this.originalTransactionId,
    required this.originalCustomerId,
    required this.amount,
    required this.category,
    required this.mode,
    required this.note,
    required this.date,
    required this.deletedAt,
    required this.autoDeleteAfter,
    required this.rawData,
  });

  bool get isUdharPerson => recycleType == 'udhar_person';
  bool get isUdharTransaction => recycleType == 'udhar_transaction';

  String get displayTitle {
    if (isUdharPerson) {
      return category.trim().isEmpty ? 'Udhar Person' : category.trim();
    }

    if (isUdharTransaction) {
      final cleanName = category.trim().isEmpty ? 'Udhar' : category.trim();
      final action = mode.toLowerCase().contains('received') ? 'Received' : 'Given';
      return '$cleanName - $action';
    }

    return category.trim().isEmpty ? 'Transaction' : category.trim();
  }

  String get displayMeta {
    if (isUdharPerson) return note.trim().isEmpty ? 'Udhar person record' : note.trim();
    if (isUdharTransaction) return note.trim().isEmpty ? 'Udhar transaction' : note.trim();
    return mode;
  }

  factory RecycledTx.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    DateTime parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return DateTime.tryParse(raw.toString()) ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return DateTime.tryParse(raw.toString());
    }

    final recycleType = (data['recycleType'] ?? data['deletedType'] ?? 'transaction').toString();

    String category;
    String mode;
    String note;
    DateTime date;
    double amount;

    if (recycleType == 'udhar_person') {
      category = (data['name'] ?? data['personName'] ?? data['category'] ?? 'Udhar Person').toString();
      mode = 'Udhar Person';
      note = (data['phone'] ?? data['note'] ?? '').toString();
      amount = (data['balance'] as num?)?.toDouble().abs() ?? (data['amount'] as num?)?.toDouble() ?? 0;
      date = parseDate(data['latestTransactionDate'] ?? data['date'] ?? data['deletedAt']);
    } else if (recycleType == 'udhar_transaction') {
      category = (data['customerName'] ?? data['personName'] ?? data['category'] ?? 'Udhar').toString();
      final txType = (data['type'] ?? '').toString();
      mode = txType == 'given' ? 'Given' : 'Received';
      note = (data['note'] ?? data['description'] ?? '').toString();
      amount = (data['amount'] as num?)?.toDouble() ?? 0;
      date = parseDate(data['transactionDate'] ?? data['date'] ?? data['deletedAt']);
    } else {
      category = (data['category'] ?? 'Other').toString();
      mode = (data['mode'] ?? 'Cash').toString();
      note = (data['note'] ?? data['description'] ?? '').toString();
      amount = (data['amount'] as num?)?.toDouble() ?? 0;
      date = parseDate(data['date']);
    }

    return RecycledTx(
      id: doc.id,
      recycleType: recycleType,
      originalTransactionId: (data['originalTransactionId'] ?? data['transactionId'] ?? doc.id).toString(),
      originalCustomerId: (data['originalCustomerId'] ?? data['customerId'] ?? '').toString(),
      amount: amount,
      category: category,
      mode: mode,
      note: note,
      date: date,
      deletedAt: parseNullableDate(data['deletedAt']),
      autoDeleteAfter: parseNullableDate(data['autoDeleteAfter']),
      rawData: data,
    );
  }
}

class _DashboardPage extends StatelessWidget {
  final Widget filterBar;
  final List<WebTx> allTransactions;
  final List<WebTx> filteredTransactions;
  final double totalExpense;
  final List<MapEntry<String, double>> topCategories;
  final ValueChanged<WebTx> onTransactionTap;
  final VoidCallback onSetLimit;
  final String userId;
  final DateTime selectedMonth;

  const _DashboardPage({
    super.key,
    required this.filterBar,
    required this.allTransactions,
    required this.filteredTransactions,
    required this.totalExpense,
    required this.topCategories,
    required this.onTransactionTap,
    required this.onSetLimit,
    required this.userId,
    required this.selectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    final topCategory = topCategories.isEmpty ? null : topCategories.first;

    final int currentStreak = _calculateLatestTransactionStreak(allTransactions);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          filterBar,
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _SummaryCard(title: 'Filtered Expense', amount: '₹ ${totalExpense.toStringAsFixed(0)}', subtitle: 'Selected period total', icon: Icons.payments_rounded, gradientColors: const [Color(0xFF7C3AED), Color(0xFF4F46E5)])),
              const SizedBox(width: 18),
              Expanded(child: _LimitSummaryCard(userId: userId, totalExpense: totalExpense, selectedMonth: selectedMonth, onSetLimit: onSetLimit)),
              const SizedBox(width: 18),
              Expanded(child: _SummaryCard(title: 'Streak', amount: '$currentStreak Days', subtitle: currentStreak > 0 ? 'Active expense streak' : 'Keep adding daily expense', icon: Icons.local_fire_department_rounded, gradientColors: const [Color(0xFFFF7A18), Color(0xFFFF3D81)])),
              const SizedBox(width: 18),
              Expanded(child: _SummaryCard(title: 'Top Category', amount: topCategory?.key ?? '-', subtitle: topCategory == null ? 'No data' : '₹ ${topCategory.value.toStringAsFixed(0)}', icon: Icons.category_rounded, gradientColors: const [Color(0xFFFB7185), Color(0xFFF97316)])),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 11, child: _Panel(child: _RecentTransactions(transactions: filteredTransactions, showViewAll: true, onTap: onTransactionTap))),
                const SizedBox(width: 22),
                Expanded(flex: 10, child: _Panel(child: _CategorySummary(topCategories: topCategories, totalExpense: totalExpense))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitSummaryCard extends StatelessWidget {
  final String userId;
  final double totalExpense;
  final DateTime selectedMonth;
  final VoidCallback onSetLimit;

  const _LimitSummaryCard({required this.userId, required this.totalExpense, required this.selectedMonth, required this.onSetLimit});

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return _SummaryCard(
        title: 'Limit',
        amount: 'Not set',
        subtitle: 'Set spending limit',
        icon: Icons.savings_rounded,
        gradientColors: const [Color(0xFF22C55E), Color(0xFF14B8A6)],
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final dailyLimit = _limitToDouble(data['dailyLimit']);
        final globalMonthlyLimit = _limitToDouble(data['monthlyLimit']);
        final monthSpecificLimit = _monthLimitFromUserData(data, selectedMonth);
        final monthlyLimit = monthSpecificLimit > 0 ? monthSpecificLimit : globalMonthlyLimit;
        final displayLimit = monthlyLimit > 0 ? monthlyLimit : dailyLimit;
        final isMonthSpecific = monthSpecificLimit > 0;
        final isCrossed = displayLimit > 0 && totalExpense > displayLimit;
        final remaining = displayLimit > 0 ? (displayLimit - totalExpense) : 0;

        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onSetLimit,
          child: _SummaryCard(
            title: monthlyLimit > 0 ? (isMonthSpecific ? '${_monthName(selectedMonth)} Limit' : 'Monthly Limit') : 'Daily Limit',
            amount: displayLimit > 0 ? '₹ ${displayLimit.toStringAsFixed(0)}' : 'Not set',
            subtitle: displayLimit <= 0
                ? 'Tap to set limit'
                : isCrossed
                    ? 'Limit crossed ₹ ${(-remaining).toStringAsFixed(0)}'
                    : 'Remaining ₹ ${remaining.toStringAsFixed(0)}',
            icon: isCrossed ? Icons.warning_amber_rounded : Icons.savings_rounded,
            gradientColors: isCrossed
                ? const [Color(0xFFFF4D57), Color(0xFFF97316)]
                : const [Color(0xFF22C55E), Color(0xFF14B8A6)],
          ),
        );
      },
    );
  }
}

class _TransactionsPage extends StatelessWidget {
  final List<WebTx> transactions;
  final Widget filterBar;
  final ValueChanged<WebTx> onTransactionTap;

  const _TransactionsPage({super.key, required this.transactions, required this.filterBar, required this.onTransactionTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        children: [
          filterBar,
          const SizedBox(height: 18),
          Expanded(child: _Panel(child: _RecentTransactions(transactions: transactions, showNote: true, onTap: onTransactionTap))),
        ],
      ),
    );
  }
}

class _CategoriesPage extends StatelessWidget {
  final List<MapEntry<String, double>> topCategories;
  final double totalExpense;

  const _CategoriesPage({super.key, required this.topCategories, required this.totalExpense});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: _Panel(child: _CategorySummary(topCategories: topCategories, totalExpense: totalExpense)),
    );
  }
}

class _ReportsPage extends StatelessWidget {
  final List<WebTx> transactions;
  final List<MapEntry<String, double>> topCategories;
  final double totalExpense;
  final Widget filterBar;
  final ValueChanged<WebTx> onTransactionTap;

  const _ReportsPage({
    super.key,
    required this.transactions,
    required this.topCategories,
    required this.totalExpense,
    required this.filterBar,
    required this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        children: [
          filterBar,
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _Panel(child: _CategorySummary(topCategories: topCategories, totalExpense: totalExpense))),
                const SizedBox(width: 22),
                Expanded(child: _Panel(child: _RecentTransactions(transactions: transactions, showNote: true, onTap: onTransactionTap))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecycleBinPage extends StatelessWidget {
  final ValueChanged<RecycledTx> onRestore;
  final ValueChanged<RecycledTx> onPermanentDelete;
  final Future<void> Function() onDeleteAll;

  const _RecycleBinPage({
    super.key,
    required this.onRestore,
    required this.onPermanentDelete,
    required this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Please login first'));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFF8B5CF6)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Recycle Bin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ),
                ElevatedButton.icon(
                  onPressed: () => _confirmDeleteAll(context),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: const Text('Delete All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D57),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Deleted transactions and Udhar records stay here for 5 days. You can restore them or delete them permanently.'),
            const SizedBox(height: 18),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('recycleBin')
                    .orderBy('deletedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = (snapshot.data?.docs ?? []).map(RecycledTx.fromDoc).toList();

                  if (items.isEmpty) {
                    return const Center(child: Text('Recycle Bin is empty'));
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(.06)),
                    itemBuilder: (context, index) {
                      final tx = items[index];
                      final deleteAfter = tx.autoDeleteAfter == null ? '5 days' : _formatDate(tx.autoDeleteAfter!);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.045),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(.08)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 46,
                              width: 46,
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(.15),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tx.displayTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('${_formatDate(tx.date)} • ${tx.displayMeta} • Auto delete after $deleteAfter', maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (tx.note.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(tx.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF9CA3AF))),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('₹ ${tx.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF62F0A8))),
                            const SizedBox(width: 14),
                            OutlinedButton.icon(
                              onPressed: () => onRestore(tx),
                              icon: const Icon(Icons.restore_rounded, size: 18),
                              label: const Text('Restore'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _confirmPermanentDelete(context, tx),
                              icon: const Icon(Icons.delete_forever_rounded, size: 18),
                              label: const Text('Delete'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPermanentDelete(BuildContext context, RecycledTx tx) async {
    final confirm = await _premiumConfirmDialog(
      context: context,
      title: 'Delete permanently?',
      message: 'This item will be permanently removed and cannot be restored later.',
      confirmText: 'Delete',
      icon: Icons.delete_forever_rounded,
    );

    if (confirm == true) onPermanentDelete(tx);
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final confirm = await _premiumConfirmDialog(
      context: context,
      title: 'Clear Recycle Bin?',
      message: 'All deleted items in Recycle Bin will be permanently removed. This action cannot be undone.',
      confirmText: 'Delete All',
      icon: Icons.delete_sweep_rounded,
    );

    if (confirm == true) await onDeleteAll();
  }

  Future<bool?> _premiumConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    required IconData icon,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(.72),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 280),
            tween: Tween(begin: .92, end: 1),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF151827),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(.10)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(.45), blurRadius: 40, offset: const Offset(0, 22)),
                  BoxShadow(color: const Color(0xFFFF4D57).withOpacity(.16), blurRadius: 34, offset: const Offset(0, 16)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF4D57), Color(0xFFFF7A59)]),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(icon, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(message, style: const TextStyle(height: 1.5, color: Color(0xFFD7D9E4), fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFD7C5FF)),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D57),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(confirmText),
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
}
class _SimpleInfoPage extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _SimpleInfoPage({super.key, required this.title, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 560,
        height: 280,
        child: _Panel(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 54, color: const Color(0xFF6C3BFF)),
              const SizedBox(height: 18),
              Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}


class _WebUdharCustomer {
  final String id;
  final String name;
  final String phone;
  final double balance;
  final DateTime updatedAt;
  final DateTime latestTransactionDate;

  const _WebUdharCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.balance,
    required this.updatedAt,
    required this.latestTransactionDate,
  });

  factory _WebUdharCustomer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final updated = data['updatedAt'];
    final latestDate = data['latestTransactionDate'];

    return _WebUdharCustomer(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      balance: ((data['balance'] ?? 0) as num).toDouble(),
      updatedAt: updated is Timestamp ? updated.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
      latestTransactionDate: latestDate is Timestamp
          ? latestDate.toDate()
          : updated is Timestamp
              ? updated.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _WebUdharTransaction {
  final String id;
  final String type;
  final double amount;
  final String note;
  final DateTime createdAt;
  final DateTime transactionDate;

  const _WebUdharTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.note,
    required this.createdAt,
    required this.transactionDate,
  });

  factory _WebUdharTransaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final created = data['createdAt'];
    final rawTransactionDate = data['transactionDate'] ?? data['date'] ?? data['createdAt'];

    DateTime parsedTransactionDate;
    if (rawTransactionDate is Timestamp) {
      parsedTransactionDate = rawTransactionDate.toDate();
    } else if (rawTransactionDate is DateTime) {
      parsedTransactionDate = rawTransactionDate;
    } else {
      parsedTransactionDate = DateTime.tryParse(rawTransactionDate.toString()) ??
          (created is Timestamp ? created.toDate() : DateTime.fromMillisecondsSinceEpoch(0));
    }

    return _WebUdharTransaction(
      id: doc.id,
      type: (data['type'] ?? 'given').toString(),
      amount: ((data['amount'] ?? 0) as num).toDouble(),
      note: (data['note'] ?? '').toString(),
      createdAt: created is Timestamp ? created.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
      transactionDate: parsedTransactionDate,
    );
  }
}

class _WebUdharBookPage extends StatefulWidget {
  final bool isDark;

  const _WebUdharBookPage({
    super.key,
    required this.isDark,
  });

  @override
  State<_WebUdharBookPage> createState() => _WebUdharBookPageState();
}

class _WebUdharBookPageState extends State<_WebUdharBookPage> {
  String? selectedCustomerId;
  String searchQuery = '';
  String filter = 'all';

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _customersRef {
    return FirebaseFirestore.instance.collection('users').doc(_uid).collection('udharCustomers');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _customersStream() {
    return _customersRef.orderBy('updatedAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _transactionsStream(String customerId) {
    return _customersRef.doc(customerId).collection('transactions').orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> _addCustomerTransaction({
    required String name,
    required String phone,
    required String type,
    required double amount,
    required String note,
    required DateTime selectedDate,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    if (cleanName.isEmpty || amount <= 0) return;

    final existing = await _customersRef.where('nameLower', isEqualTo: cleanName.toLowerCase()).limit(1).get();
    final balanceChange = type == 'given' ? amount : -amount;

    if (existing.docs.isEmpty) {
      final doc = _customersRef.doc();
      await doc.set({
        'name': cleanName,
        'nameLower': cleanName.toLowerCase(),
        'phone': cleanPhone,
        'balance': balanceChange,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'latestTransactionDate': Timestamp.fromDate(selectedDate),
      });

      await doc.collection('transactions').add({
        'type': type,
        'amount': amount,
        'note': note.trim(),
        'transactionDate': Timestamp.fromDate(selectedDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() => selectedCustomerId = doc.id);
    } else {
      final doc = existing.docs.first.reference;
      await doc.update({
        'balance': FieldValue.increment(balanceChange),
        'phone': cleanPhone.isNotEmpty ? cleanPhone : (existing.docs.first.data()['phone'] ?? ''),
        'updatedAt': FieldValue.serverTimestamp(),
        'latestTransactionDate': Timestamp.fromDate(selectedDate),
      });

      await doc.collection('transactions').add({
        'type': type,
        'amount': amount,
        'note': note.trim(),
        'transactionDate': Timestamp.fromDate(selectedDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() => selectedCustomerId = doc.id);
    }
  }

  Future<void> _addTransactionToCustomer({
    required _WebUdharCustomer customer,
    required String type,
    required double amount,
    required String note,
    required DateTime selectedDate,
  }) async {
    if (amount <= 0) return;

    final doc = _customersRef.doc(customer.id);
    final balanceChange = type == 'given' ? amount : -amount;

    await doc.update({
      'balance': FieldValue.increment(balanceChange),
      'updatedAt': FieldValue.serverTimestamp(),
      'latestTransactionDate': Timestamp.fromDate(selectedDate),
    });

    await doc.collection('transactions').add({
      'type': type,
      'amount': amount,
      'note': note.trim(),
      'transactionDate': Timestamp.fromDate(selectedDate),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateCustomer({
    required _WebUdharCustomer customer,
    required String name,
    required String phone,
    required DateTime selectedDate,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    await _customersRef.doc(customer.id).update({
      'name': cleanName,
      'nameLower': cleanName.toLowerCase(),
      'phone': phone.trim(),
      'latestTransactionDate': Timestamp.fromDate(selectedDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteCustomer(_WebUdharCustomer customer) async {
    final customerRef = _customersRef.doc(customer.id);
    final customerSnapshot = await customerRef.get();
    final transactionsSnapshot = await customerRef.collection('transactions').get();

    final customerData = customerSnapshot.data() ?? <String, dynamic>{
      'name': customer.name,
      'nameLower': customer.name.toLowerCase(),
      'phone': customer.phone,
      'balance': customer.balance,
      'latestTransactionDate': Timestamp.fromDate(customer.latestTransactionDate),
    };

    final transactionsData = transactionsSnapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();

    final recycleRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('recycleBin')
        .doc('udhar_person_${customer.id}');

    final batch = FirebaseFirestore.instance.batch();

    batch.set(recycleRef, {
      'recycleType': 'udhar_person',
      'originalCustomerId': customer.id,
      'name': customer.name,
      'personName': customer.name,
      'phone': customer.phone,
      'balance': customer.balance,
      'amount': customer.balance.abs(),
      'category': customer.name,
      'mode': 'Udhar Person',
      'note': customer.phone,
      'date': Timestamp.fromDate(customer.latestTransactionDate),
      'latestTransactionDate': Timestamp.fromDate(customer.latestTransactionDate),
      'customerData': customerData,
      'transactions': transactionsData,
      'deletedAt': FieldValue.serverTimestamp(),
      'autoDeleteAfter': Timestamp.fromDate(DateTime.now().add(const Duration(days: 5))),
    });

    for (final doc in transactionsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(customerRef);
    await batch.commit();

    if (selectedCustomerId == customer.id && mounted) {
      setState(() => selectedCustomerId = null);
    }

    _showSnack('${customer.name} moved to Recycle Bin.');
  }

  Future<void> _deleteTransaction({
    required _WebUdharCustomer customer,
    required _WebUdharTransaction transaction,
  }) async {
    final reverseBalance = transaction.type == 'given' ? -transaction.amount : transaction.amount;
    final customerDoc = _customersRef.doc(customer.id);
    final transactionRef = customerDoc.collection('transactions').doc(transaction.id);
    final transactionSnapshot = await transactionRef.get();
    final transactionData = transactionSnapshot.data() ?? <String, dynamic>{
      'type': transaction.type,
      'amount': transaction.amount,
      'note': transaction.note,
      'transactionDate': Timestamp.fromDate(transaction.transactionDate),
      'createdAt': Timestamp.fromDate(transaction.createdAt),
    };

    final recycleRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('recycleBin')
        .doc('udhar_tx_${customer.id}_${transaction.id}');

    await FirebaseFirestore.instance.runTransaction((firestoreTx) async {
      firestoreTx.set(recycleRef, {
        'recycleType': 'udhar_transaction',
        'originalCustomerId': customer.id,
        'originalTransactionId': transaction.id,
        'customerName': customer.name,
        'personName': customer.name,
        'category': customer.name,
        'type': transaction.type,
        'mode': transaction.type == 'given' ? 'Given' : 'Received',
        'amount': transaction.amount,
        'note': transaction.note,
        'date': Timestamp.fromDate(transaction.transactionDate),
        'transactionDate': Timestamp.fromDate(transaction.transactionDate),
        'transactionData': transactionData,
        'deletedAt': FieldValue.serverTimestamp(),
        'autoDeleteAfter': Timestamp.fromDate(DateTime.now().add(const Duration(days: 5))),
      });

      firestoreTx.update(customerDoc, {
        'balance': FieldValue.increment(reverseBalance),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      firestoreTx.delete(transactionRef);
    });

    _showSnack('${customer.name} - ${transaction.type == 'given' ? 'Given' : 'Received'} moved to Recycle Bin.');
  }

  Future<void> _updateTransaction({
    required _WebUdharCustomer customer,
    required _WebUdharTransaction transaction,
    required String newType,
    required double newAmount,
    required String note,
    required DateTime selectedDate,
  }) async {
    if (newAmount <= 0) return;

    final oldEffect = transaction.type == 'given' ? transaction.amount : -transaction.amount;
    final newEffect = newType == 'given' ? newAmount : -newAmount;
    final difference = newEffect - oldEffect;

    final customerDoc = _customersRef.doc(customer.id);

    await customerDoc.update({
      'balance': FieldValue.increment(difference),
      'latestTransactionDate': Timestamp.fromDate(selectedDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await customerDoc.collection('transactions').doc(transaction.id).update({
      'type': newType,
      'amount': newAmount,
      'note': note.trim(),
      'transactionDate': Timestamp.fromDate(selectedDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendWhatsAppReminder(_WebUdharCustomer customer) async {
    final rawPhone = customer.phone.trim();

    if (rawPhone.isEmpty) {
      _showSnack('Mobile number is missing for this person.');
      return;
    }

    var phone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length == 10) phone = '91$phone';

    final amount = customer.balance.abs().toStringAsFixed(0);
    final message = customer.balance < 0
        ? 'Hi ${customer.name}, reminder regarding ₹$amount pending payment.'
        : 'Hi ${customer.name}, gentle reminder for ₹$amount pending amount. Please settle it when possible.';

    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      _showSnack('Unable to open WhatsApp.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(double value) => '₹ ${value.abs().toStringAsFixed(0)}';

  String _dateText(DateTime date) {
    if (date.year < 2001) return 'Just now';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _customersStream(),
      builder: (context, snapshot) {
        final customers = snapshot.hasData ? snapshot.data!.docs.map(_WebUdharCustomer.fromDoc).toList() : <_WebUdharCustomer>[];

        var filtered = customers.where((c) {
          if (filter == 'receive' && c.balance <= 0) return false;
          if (filter == 'pay' && c.balance >= 0) return false;
          if (filter == 'settled' && c.balance != 0) return false;

          final q = searchQuery.trim().toLowerCase();
          if (q.isEmpty) return true;
          return c.name.toLowerCase().contains(q) || c.phone.toLowerCase().contains(q);
        }).toList();

        if (selectedCustomerId == null && filtered.isNotEmpty) {
          selectedCustomerId = filtered.first.id;
        }

        _WebUdharCustomer? selected;
        for (final item in filtered) {
          if (item.id == selectedCustomerId) {
            selected = item;
            break;
          }
        }
        selected ??= filtered.isNotEmpty ? filtered.first : null;

        final totalReceive = customers.where((e) => e.balance > 0).fold<double>(0, (sum, e) => sum + e.balance);
        final totalPay = customers.where((e) => e.balance < 0).fold<double>(0, (sum, e) => sum + e.balance.abs());

        return Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                width: 390,
                child: Column(
                  children: [
                    _udharHeader(isDark),
                    const SizedBox(height: 14),
                    _summaryStrip(isDark, totalReceive, totalPay, customers.length),
                    const SizedBox(height: 14),
                    _searchAndFilter(isDark),
                    const SizedBox(height: 14),
                    Expanded(
                      child: snapshot.hasData
                          ? _customersList(isDark, filtered, selected?.id)
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: selected == null
                    ? _emptyDetail(isDark)
                    : _customerDetailPanel(isDark, selected),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _udharHeader(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Udhar Book',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF101828),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _roundIconButton(
          icon: Icons.add_rounded,
          color: const Color(0xFF6C4DFF),
          onTap: () => _openAddCustomerTransactionDialog(),
        ),
      ],
    );
  }

  Widget _summaryStrip(bool isDark, double totalReceive, double totalPay, int people) {
    return Row(
      children: [
        Expanded(child: _summaryTile(isDark, 'Receive', _money(totalReceive), const Color(0xFF20C997))),
        const SizedBox(width: 10),
        Expanded(child: _summaryTile(isDark, 'Pay', _money(totalPay), const Color(0xFFFFA726))),
        const SizedBox(width: 10),
        Expanded(child: _summaryTile(isDark, 'People', '$people', const Color(0xFF6C4DFF))),
      ],
    );
  }

  Widget _summaryTile(bool isDark, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _searchAndFilter(bool isDark) {
    return Column(
      children: [
        TextField(
          onChanged: (v) => setState(() => searchQuery = v),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: 'Search person...',
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white54 : Colors.black45),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _filterChip('All', 'all'),
            _filterChip('Receive', 'receive'),
            _filterChip('Pay', 'pay'),
            _filterChip('Settled', 'settled'),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = filter == value;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 7),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => filter = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF6C4DFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? Colors.transparent : Colors.white10),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: selected ? Colors.white : null, fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }

  Widget _customersList(bool isDark, List<_WebUdharCustomer> customers, String? activeId) {
    if (customers.isEmpty) {
      return _emptyText(isDark, 'No udhar records found');
    }

    return ListView.builder(
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        final selected = customer.id == activeId;
        final isPay = customer.balance < 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Dismissible(
            key: ValueKey('web_udhar_customer_${customer.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              await _deleteCustomer(customer);
              return false;
            },
            background: _deleteBackground(),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => selectedCustomerId = customer.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF6C4DFF).withOpacity(isDark ? 0.20 : 0.10)
                      : isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? const Color(0xFF6C4DFF) : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: (isPay ? const Color(0xFFFFA726) : const Color(0xFF20C997)).withOpacity(0.16),
                      child: Text(
                        customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'U',
                        style: TextStyle(color: isPay ? const Color(0xFFFFA726) : const Color(0xFF20C997), fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _openEditCustomerDialog(customer),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customer.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 3),
                              Text(
                                '${customer.phone.isEmpty ? 'No mobile number' : customer.phone} • ${_dateText(customer.latestTransactionDate)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_money(customer.balance), style: TextStyle(color: isPay ? const Color(0xFFFFA726) : const Color(0xFF20C997), fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        IconButton(
                          tooltip: 'Edit person',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _openEditCustomerDialog(customer),
                          icon: Icon(Icons.edit_rounded, size: 17, color: isDark ? Colors.white54 : Colors.black45),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _customerDetailPanel(bool isDark, _WebUdharCustomer customer) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1020) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.20 : 0.05), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          _detailHeader(isDark, customer),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _transactionsStream(customer.id),
              builder: (context, snapshot) {
                final txs = snapshot.hasData
                    ? (snapshot.data!.docs.map(_WebUdharTransaction.fromDoc).toList()
                      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate)))
                    : <_WebUdharTransaction>[];

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (txs.isEmpty) {
                  return _emptyText(isDark, 'No transactions yet');
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: txs.length,
                  itemBuilder: (context, index) {
                    final tx = txs[index];
                    return _transactionTile(isDark, customer, tx);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailHeader(bool isDark, _WebUdharCustomer customer) {
    final isPay = customer.balance < 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: (isPay ? const Color(0xFFFFA726) : const Color(0xFF20C997)).withOpacity(0.16),
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'U',
              style: TextStyle(color: isPay ? const Color(0xFFFFA726) : const Color(0xFF20C997), fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${customer.phone.isEmpty ? 'No mobile number' : customer.phone} • ${_dateText(customer.latestTransactionDate)}', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          _headerAction(Icons.chat_rounded, const Color(0xFF25D366), () => _sendWhatsAppReminder(customer)),
          const SizedBox(width: 10),
          _headerAction(Icons.add_rounded, const Color(0xFF6C4DFF), () => _openAddTransactionDialog(customer)),
          const SizedBox(width: 10),
          _headerAction(Icons.edit_rounded, const Color(0xFF3278FF), () => _openEditCustomerDialog(customer)),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (isPay ? const Color(0xFFFFA726) : const Color(0xFF20C997)).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${isPay ? 'Pay' : 'Receive'} ${_money(customer.balance)}',
              style: TextStyle(color: isPay ? const Color(0xFFFFA726) : const Color(0xFF20C997), fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerAction(IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 44,
      height: 44,
      child: FloatingActionButton(
        heroTag: 'web_udhar_${icon.codePoint}',
        elevation: 0,
        backgroundColor: color,
        onPressed: onTap,
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }

  Widget _transactionTile(bool isDark, _WebUdharCustomer customer, _WebUdharTransaction tx) {
    final given = tx.type == 'given';
    final color = given ? const Color(0xFF20C997) : const Color(0xFFFFA726);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('web_udhar_tx_${customer.id}_${tx.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          await _deleteTransaction(customer: customer, transaction: tx);
          return false;
        },
        background: _deleteBackground(),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openEditTransactionDialog(customer, tx),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(15)),
                  child: Icon(given ? Icons.south_west_rounded : Icons.north_east_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(given ? 'You received' : 'You paid', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(tx.note.isEmpty ? _dateText(tx.transactionDate) : '${tx.note} • ${_dateText(tx.transactionDate)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Text(_money(tx.amount), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(width: 10),
                Icon(Icons.edit_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _deleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.delete_rounded, color: Colors.white),
    );
  }

  Widget _emptyDetail(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1020) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: _emptyText(isDark, 'Select or add a person to view udhar details'),
    );
  }

  Widget _emptyText(bool isDark, String text) {
    return Center(
      child: Text(
        text,
        style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 46,
      height: 46,
      child: FloatingActionButton(
        heroTag: 'web_udhar_main_${icon.codePoint}',
        backgroundColor: color,
        elevation: 0,
        onPressed: onTap,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Future<void> _openAddCustomerTransactionDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String type = 'given';

    await _showUdharTransactionDialog(
      title: 'Add Udhar Transaction',
      nameController: nameController,
      phoneController: phoneController,
      amountController: amountController,
      noteController: noteController,
      initialType: type,
      showPersonFields: true,
      initialSelectedDate: DateTime.now(),
      onSave: (selectedType, selectedDate) async {
        final amount = double.tryParse(amountController.text.trim()) ?? 0;
        await _addCustomerTransaction(
          name: nameController.text,
          phone: phoneController.text,
          type: selectedType,
          amount: amount,
          note: noteController.text,
          selectedDate: selectedDate,
        );
      },
    );
  }

  Future<void> _openAddTransactionDialog(_WebUdharCustomer customer) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    await _showUdharTransactionDialog(
      title: 'Add Transaction',
      amountController: amountController,
      noteController: noteController,
      initialType: 'given',
      showPersonFields: false,
      initialSelectedDate: DateTime.now(),
      onSave: (selectedType, selectedDate) async {
        final amount = double.tryParse(amountController.text.trim()) ?? 0;
        await _addTransactionToCustomer(
          customer: customer,
          type: selectedType,
          amount: amount,
          note: noteController.text,
          selectedDate: selectedDate,
        );
      },
    );
  }

  Future<void> _openEditTransactionDialog(_WebUdharCustomer customer, _WebUdharTransaction transaction) async {
    final amountController = TextEditingController(text: transaction.amount.toStringAsFixed(0));
    final noteController = TextEditingController(text: transaction.note);

    await _showUdharTransactionDialog(
      title: 'Edit Transaction',
      amountController: amountController,
      noteController: noteController,
      initialType: transaction.type,
      showPersonFields: false,
      initialSelectedDate: transaction.transactionDate,
      onSave: (selectedType, selectedDate) async {
        final amount = double.tryParse(amountController.text.trim()) ?? 0;
        await _updateTransaction(
          customer: customer,
          transaction: transaction,
          newType: selectedType,
          newAmount: amount,
          note: noteController.text,
          selectedDate: selectedDate,
        );
      },
    );
  }

  Future<void> _showUdharTransactionDialog({
    required String title,
    TextEditingController? nameController,
    TextEditingController? phoneController,
    required TextEditingController amountController,
    required TextEditingController noteController,
    required String initialType,
    required bool showPersonFields,
    DateTime? initialSelectedDate,
    required Future<void> Function(String selectedType, DateTime selectedDate) onSave,
  }) async {
    String selectedType = initialType;
    DateTime selectedDate = initialSelectedDate ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (context) {
        final isDark = widget.isDark;
        final panel = isDark ? const Color(0xFF121827) : Colors.white;
        final field = isDark ? Colors.white.withOpacity(0.07) : const Color(0xFFF4F6FB);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                width: 430,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 34, offset: const Offset(0, 14))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 20, fontWeight: FontWeight.w900))),
                        IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.black45)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (showPersonFields) ...[
                      _dialogField(nameController!, 'Person name', Icons.person_rounded, field),
                      const SizedBox(height: 12),
                      _dialogField(phoneController!, 'Mobile number', Icons.phone_rounded, field, keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(child: _typeButton('given', 'You received', Icons.south_west_rounded, selectedType, (v) => setDialogState(() => selectedType = v))),
                        const SizedBox(width: 10),
                        Expanded(child: _typeButton('taken', 'You paid', Icons.north_east_rounded, selectedType, (v) => setDialogState(() => selectedType = v))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _dialogDatePickerField(
                      selectedDate: selectedDate,
                      fill: field,
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: now,
                          initialDate: selectedDate.isAfter(now) ? now : selectedDate,
                          helpText: 'Select udhar transaction date',
                          builder: (context, child) {
                            final base = Theme.of(context);
                            return Theme(
                              data: base.copyWith(
                                colorScheme: base.colorScheme.copyWith(
                                  primary: const Color(0xFF6C4DFF),
                                  onPrimary: Colors.white,
                                ),
                              ),
                              child: child ?? const SizedBox.shrink(),
                            );
                          },
                        );

                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _dialogField(amountController, 'Amount', Icons.currency_rupee_rounded, field, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    const SizedBox(height: 12),
                    _dialogField(noteController, 'Note', Icons.notes_rounded, field),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C4DFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          await onSave(selectedType, selectedDate);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _typeButton(String value, String label, IconData icon, String selected, ValueChanged<String> onTap) {
    final active = selected == value;
    final color = value == 'given' ? const Color(0xFF20C997) : const Color(0xFFFFA726);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.16) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? color : Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: active ? color : null),
            const SizedBox(width: 7),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? color : null, fontWeight: FontWeight.w900, fontSize: 12))),
          ],
        ),
      ),
    );
  }

  Widget _dialogDatePickerField({
    required DateTime selectedDate,
    required Color fill,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _dateText(selectedDate),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String hint,
    IconData icon,
    Color fill, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 19),
        hintText: hint,
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Future<void> _openEditCustomerDialog(_WebUdharCustomer customer) async {
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone);
    DateTime selectedDate = customer.latestTransactionDate;

    await showDialog(
      context: context,
      builder: (context) {
        final isDark = widget.isDark;
        final field = isDark ? Colors.white.withOpacity(0.07) : const Color(0xFFF4F6FB);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121827) : Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 30, offset: const Offset(0, 12))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Edit Person', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 20, fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 14),
                _dialogField(nameController, 'Person name', Icons.person_rounded, field),
                const SizedBox(height: 12),
                _dialogField(phoneController, 'Mobile number', Icons.phone_rounded, field, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _dialogDatePickerField(
                  selectedDate: selectedDate,
                  fill: field,
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: now,
                      initialDate: selectedDate.isAfter(now) ? now : selectedDate,
                      helpText: 'Select udhar date',
                    );

                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C4DFF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () async {
                      await _updateCustomer(customer: customer, name: nameController.text, phone: phoneController.text, selectedDate: selectedDate);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
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


class _Sidebar extends StatelessWidget {
  final bool isDark;
  final String userName;
  final String? photoUrl;
  final int selectedIndex;
  final ValueChanged<int> onMenuTap;

  const _Sidebar({
    required this.isDark,
    required this.userName,
    required this.photoUrl,
    required this.selectedIndex,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.dashboard_rounded, 'Dashboard'),
      (Icons.receipt_long_rounded, 'Transactions'),
      (Icons.menu_book_rounded, 'Udhar Book'),
      (Icons.category_rounded, 'Categories'),
      (Icons.pie_chart_rounded, 'Reports'),
      (Icons.notifications_rounded, 'Reminders'),
      (Icons.settings_rounded, 'Settings'),
      (Icons.delete_outline_rounded, 'Recycle Bin'),
    ];

    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1020) : Colors.white,
        border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              children: [
                TextSpan(text: 'Daily ', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'Kharcha', style: TextStyle(color: Color(0xFF7A3CFF))),
              ],
            ),
          ),
          const SizedBox(height: 30),
          for (int i = 0; i < items.length; i++)
            _sideItem(items[i].$1, items[i].$2, selectedIndex == i, () => onMenuTap(i)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F4F9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                _UserAvatar(photoUrl: photoUrl, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      const Text('View Profile', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideItem(IconData icon, String title, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              gradient: selected ? const LinearGradient(colors: [Color(0xFF3278FF), Color(0xFF7A3CFF)]) : null,
              color: selected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? Colors.white : null),
                const SizedBox(width: 12),
                Text(title, style: TextStyle(color: selected ? Colors.white : null, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool isDark;
  final String userName;
  final String? photoUrl;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onThemeToggle;
  final VoidCallback onAddExpense;
  final VoidCallback onSetLimit;
  final Future<void> Function() onLogout;
  final Widget notificationButton;

  const _TopBar({
    required this.isDark,
    required this.userName,
    required this.photoUrl,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onThemeToggle,
    required this.onAddExpense,
    required this.onSetLimit,
    required this.onLogout,
    required this.notificationButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Welcome back, $userName 👋',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260, minWidth: 180),
            child: SizedBox(
              height: 46,
              child: TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.055) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onSetLimit,
            icon: const Icon(Icons.savings_rounded, size: 18),
            label: const Text('Set Limit'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: onAddExpense,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Expense'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C3BFF),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(onPressed: onThemeToggle, icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode)),
          notificationButton,
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Profile',
            offset: const Offset(0, 46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onSelected: (value) {
              if (value == 'logout') onLogout();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 19),
                    SizedBox(width: 10),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            child: _UserAvatar(photoUrl: photoUrl, radius: 20),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final DashboardFilter selectedFilter;
  final DateTime selectedDate;
  final DateTime selectedMonth;
  final DateTime selectedWeekStart;
  final DateTime? customStart;
  final DateTime? customEnd;
  final ValueChanged<DashboardFilter> onFilterChanged;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onWeekChanged;
  final VoidCallback onPickDate;
  final VoidCallback onPickRange;
  final VoidCallback onAddExpense;

  const _FilterBar({
    required this.selectedFilter,
    required this.selectedDate,
    required this.selectedMonth,
    required this.selectedWeekStart,
    required this.customStart,
    required this.customEnd,
    required this.onFilterChanged,
    required this.onDateChanged,
    required this.onMonthChanged,
    required this.onWeekChanged,
    required this.onPickDate,
    required this.onPickRange,
    required this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(24, (i) => DateTime(now.year, now.month - i));

    return SizedBox(
      height: 70,
      child: _Panel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _chip('Today', DashboardFilter.today),
            _gap(),
            _chip('Select Date', DashboardFilter.particularDate, onTap: onPickDate),
            _gap(),
            _chip('Week', DashboardFilter.thisWeek),
            _gap(),
            _chip('Current Month', DashboardFilter.thisMonth),
            _gap(),
            _chip('Select Month', DashboardFilter.particularMonth),
            _gap(),
            _chip('Custom Range', DashboardFilter.customRange, onTap: onPickRange),
            _gap(),
            _chip('All Time', DashboardFilter.allTime),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutExpo,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(.04, 0), end: Offset.zero).animate(animation),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: .96, end: 1).animate(animation),
                      child: child,
                    ),
                  ),
                );
              },
              child: _rightFilterControl(months),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rightFilterControl(List<DateTime> months) {
    switch (selectedFilter) {
      case DashboardFilter.particularDate:
        return _MiniPremiumButton(key: const ValueKey('date'), icon: Icons.calendar_month_rounded, text: _formatDate(selectedDate), onTap: onPickDate);
      case DashboardFilter.particularMonth:
        final currentMonth = months.firstWhere((m) => m.year == selectedMonth.year && m.month == selectedMonth.month, orElse: () => months.first);
        return PopupMenuButton<DateTime>(
          key: const ValueKey('month'),
          tooltip: 'Select month',
          color: const Color(0xFF151B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          itemBuilder: (context) => months
              .map((m) => PopupMenuItem<DateTime>(
                    value: m,
                    child: Row(
                      children: [
                        Icon(
                          m.year == currentMonth.year && m.month == currentMonth.month ? Icons.check_circle_rounded : Icons.calendar_month_rounded,
                          size: 18,
                          color: const Color(0xFF8B5CF6),
                        ),
                        const SizedBox(width: 10),
                        Text(_monthName(m)),
                      ],
                    ),
                  ))
              .toList(),
          onSelected: onMonthChanged,
          child: _MiniPremiumButton(icon: Icons.calendar_month_rounded, text: _monthName(currentMonth)),
        );
      case DashboardFilter.thisWeek:
        return Row(
          key: const ValueKey('week'),
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(onPressed: () => onWeekChanged(selectedWeekStart.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left)),
            Text('${_formatDate(selectedWeekStart)} - ${_formatDate(selectedWeekStart.add(const Duration(days: 6)))}'),
            IconButton(onPressed: () => onWeekChanged(selectedWeekStart.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right)),
          ],
        );
      case DashboardFilter.customRange:
        return _MiniPremiumButton(key: const ValueKey('range'), icon: Icons.date_range_rounded, text: customStart == null || customEnd == null ? 'Select Range' : '${_formatDate(customStart!)} - ${_formatDate(customEnd!)}', onTap: onPickRange);
      default:
        return const SizedBox(key: ValueKey('empty'));
    }
  }

  SizedBox _gap() => const SizedBox(width: 8);

  Widget _chip(String label, DashboardFilter value, {VoidCallback? onTap}) {
    final selected = selectedFilter == value;

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      scale: selected ? 1.02 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          splashColor: const Color(0xFF8B5CF6).withOpacity(.12),
          highlightColor: const Color(0xFF8B5CF6).withOpacity(.08),
          onTap: () {
            if (onTap != null) {
              onTap();
            } else {
              onFilterChanged(value);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: selected ? 19 : 17,
              vertical: selected ? 13 : 12,
            ),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4F46E5), Color(0xFF8B5CF6), Color(0xFFA855F7)],
                    )
                  : null,
              color: selected ? null : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? const Color(0xFFD7C5FF).withOpacity(.65) : Colors.white.withOpacity(0.12),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.34),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  child: selected
                      ? const Padding(
                          key: ValueKey('selected-icon'),
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.check_rounded, size: 17, color: Colors.white),
                        )
                      : const SizedBox(key: ValueKey('empty-icon')),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .1,
                    color: selected ? Colors.white : const Color(0xFFD9D6E5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Panel({required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: padding,
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF10182B), Color(0xFF171226)])
            : null,
        color: isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.28 : 0.06), blurRadius: 22, offset: const Offset(0, 10))],
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
      ),
      child: child,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: _Panel(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(amount, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(subtitle, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF62F0A8), fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: gradientColors.last.withOpacity(0.35), blurRadius: 18)],
              ),
              child: Icon(icon, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  final List<WebTx> transactions;
  final bool showNote;
  final bool showViewAll;
  final ValueChanged<WebTx>? onTap;

  const _RecentTransactions({required this.transactions, this.showNote = false, this.showViewAll = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Spacer(),
            Text('${transactions.length} items'),
            if (showViewAll) ...[
              const SizedBox(width: 10),
              OutlinedButton(onPressed: () {}, child: const Text('View All')),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (transactions.isEmpty)
          const Expanded(child: Center(child: Text('No transactions found')))
        else
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.separated(
                primary: false,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: transactions.length,
                separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.06), height: 18),
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: onTap == null ? null : () => onTap!(tx),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(right: 12),
                          leading: Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF7A3CFF), Color(0xFF4F46E5)]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                          ),
                          title: Text(tx.category, style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text(showNote && tx.note.isNotEmpty ? '${_formatDate(tx.date)} • ${tx.mode} • ${tx.note}' : '${_formatDate(tx.date)} • ${tx.mode}'),
                          trailing: Text('₹ ${tx.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF62F0A8))),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _CategorySummary extends StatelessWidget {
  final List<MapEntry<String, double>> topCategories;
  final double totalExpense;

  const _CategorySummary({required this.topCategories, required this.totalExpense});

  @override
  Widget build(BuildContext context) {
    final items = topCategories.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Expense by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [Text('Amount'), SizedBox(width: 6), Icon(Icons.keyboard_arrow_down_rounded, size: 18)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (items.isEmpty)
          const Expanded(child: Center(child: Text('No category data')))
        else
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _CategoryBarChart(items: items, totalExpense: totalExpense),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.055), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: items.take(3).map((e) {
                      final percent = totalExpense <= 0 ? 0.0 : (e.value / totalExpense) * 100;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFF7A3CFF), shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(e.key, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                            Text('${percent.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(width: 26),
                            Text('₹${e.value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryBarChart extends StatelessWidget {
  final List<MapEntry<String, double>> items;
  final double totalExpense;

  const _CategoryBarChart({required this.items, required this.totalExpense});

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<double>(0, (max, item) => math.max(max, item.value));
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.separated(
          primary: false,
          physics: const ClampingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final item = items[index];
            final ratio = maxValue <= 0 ? 0.0 : item.value / maxValue;
            return Row(
              children: [
                SizedBox(width: 92, child: Text(item.key, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                Expanded(
                  child: Stack(
                    children: [
                      Container(height: 36, decoration: BoxDecoration(color: Colors.white.withOpacity(0.055), borderRadius: BorderRadius.circular(10))),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        width: math.max(8, constraints.maxWidth * 0.66 * ratio),
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF7A3CFF), Color(0xFF4F46E5)]),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: const Color(0xFF7A3CFF).withOpacity(0.25), blurRadius: 14)],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 74, child: Text('₹${item.value.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900))),
              ],
            );
          },
        );
      },
    );
  }
}

class _PremiumSelectField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final Future<void> Function()? onAddCustom;

  const _PremiumSelectField({
    required this.label,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.onAddCustom,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      tooltip: label,
      color: isDark ? const Color(0xFF101827) : Colors.white,
      elevation: 18,
      offset: const Offset(0, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
      ),
      itemBuilder: (context) {
        final menuItems = <PopupMenuEntry<String>>[
          ...items.map((item) {
          final selected = item == value;
          return PopupMenuItem<String>(
            value: item,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF7A3CFF).withOpacity(0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, size: 18, color: selected ? const Color(0xFF8B5CF6) : null),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item, style: TextStyle(fontWeight: selected ? FontWeight.w900 : FontWeight.w600))),
                ],
              ),
            ),
          );
        }),
        ];

        if (onAddCustom != null) {
          menuItems.add(
            PopupMenuItem<String>(
              value: '__add_custom_category__',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7A3CFF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_circle_rounded, size: 19, color: Color(0xFF8B5CF6)),
                    SizedBox(width: 10),
                    Expanded(child: Text('Add Custom Category', style: TextStyle(fontWeight: FontWeight.w900))),
                  ],
                ),
              ),
            ),
          );
        }

        return menuItems;
      },
      onSelected: (item) {
        if (item == '__add_custom_category__') {
          onAddCustom?.call();
          return;
        }
        onChanged(item);
      },
      child: _PremiumField(
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF3278FF), Color(0xFF7A3CFF)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPremiumButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _MiniPremiumButton({super.key, required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.055),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
            if (onTap != null) ...[const SizedBox(width: 8), const Icon(Icons.keyboard_arrow_down_rounded, size: 18)],
          ],
        ),
      ),
    );
  }
}

class _PremiumField extends StatelessWidget {
  final Widget child;

  const _PremiumField({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.055) : const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
      ),
      child: child,
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final double radius;

  const _UserAvatar({required this.photoUrl, required this.radius});

  @override
  Widget build(BuildContext context) {
    final direct = photoUrl?.trim();
    if (direct != null && direct.isNotEmpty) {
      return _NetworkAvatar(url: direct, radius: radius);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _InitialAvatar(radius: radius);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        String? firestoreUrl;
        if (data is Map<String, dynamic>) {
          firestoreUrl = (data['photoUrl'] ?? data['photoURL'] ?? data['profileImage'] ?? data['imageUrl'])?.toString().trim();
        }
        if (firestoreUrl != null && firestoreUrl.isNotEmpty) {
          return _NetworkAvatar(url: firestoreUrl, radius: radius);
        }
        return _InitialAvatar(radius: radius);
      },
    );
  }
}

class _NetworkAvatar extends StatelessWidget {
  final String url;
  final double radius;

  const _NetworkAvatar({required this.url, required this.radius});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _InitialAvatar(radius: radius),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final double radius;

  const _InitialAvatar({required this.radius});

  @override
  Widget build(BuildContext context) {
    final name = FirebaseAuth.instance.currentUser?.displayName ?? 'U';
    final initial = name.trim().isEmpty ? 'U' : name.trim().substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF6C3BFF),
      child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
    );
  }
}


double _limitToDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _limitMonthKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}';

String _dateKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

double _monthLimitFromUserData(Map<String, dynamic> data, DateTime selectedMonth) {
  final monthKey = _limitMonthKey(selectedMonth);
  final possibleMaps = [
    data['monthlyLimitsByMonth'],
    data['monthlyLimits'],
    data['monthLimits'],
  ];

  for (final raw in possibleMaps) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final value = _limitToDouble(map[monthKey]);
      if (value > 0) return value;
    }
  }

  if ((data['selectedMonthLimitKey'] ?? '').toString() == monthKey) {
    final value = _limitToDouble(data['selectedMonthLimit']);
    if (value > 0) return value;
  }

  return 0;
}

int _calculateLatestTransactionStreak(List<WebTx> transactions) {
  if (transactions.isEmpty) return 0;

  final days = <String>{};
  DateTime? latestDay;

  for (final tx in transactions) {
    final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
    days.add(_dateKey(day));
    if (latestDay == null || day.isAfter(latestDay)) {
      latestDay = day;
    }
  }

  if (latestDay == null) return 0;

  var cursor = latestDay;
  var streak = 0;
  while (days.contains(_dateKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

String _monthName(DateTime date) {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${names[date.month - 1]} ${date.year}';
}
