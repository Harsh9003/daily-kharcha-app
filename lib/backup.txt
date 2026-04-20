import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';


void main() {
  runApp(DailyKharchaApp());
}

class DailyKharchaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;

  List<Map<String, dynamic>> transactions = [];
  List<String> categories = ["Food", "Travel", "Shopping", "Petrol"];

  String viewMode = "Monthly";
  DateTime selectedDate = DateTime.now();
  int selectedMonth = DateTime.now().month;
  String selectedDayType = "Today";

  String reportView = "Monthly";
  bool showPercentage = false;
  String reportChartType = "List";
  int selectedWeekIndex = 0;

  double dailyLimit = 0;
  double monthlyLimit = 0;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    final encodedTransactions = transactions.map((tx) {
      return {
        'amount': tx['amount'],
        'category': tx['category'],
        'date': (tx['date'] as DateTime).toIso8601String(),
        'mode': tx['mode'],
      };
    }).toList();

    await prefs.setString('transactions', jsonEncode(encodedTransactions));
    await prefs.setStringList('categories', categories);
    await prefs.setString('viewMode', viewMode);
    await prefs.setInt('selectedMonth', selectedMonth);
    await prefs.setString('selectedDayType', selectedDayType);
    await prefs.setDouble('dailyLimit', dailyLimit);
    await prefs.setDouble('monthlyLimit', monthlyLimit);
    await prefs.setString('reportView', reportView);
    await prefs.setString('reportChartType', reportChartType);
    await prefs.setString('selectedDate', selectedDate.toIso8601String());
    await prefs.setInt('selectedWeekIndex', selectedWeekIndex);
    await prefs.setBool('showPercentage', showPercentage);
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final txString = prefs.getString('transactions');
    if (txString != null) {
      final decoded = jsonDecode(txString) as List;
      transactions = decoded.map((item) {
        return {
          'amount': (item['amount'] as num).toDouble(),
          'category': item['category'],
          'date': DateTime.parse(item['date']),
          'mode': item['mode'] ?? "Cash",
        };
      }).toList();
    }

    final savedCategories = prefs.getStringList('categories');
    if (savedCategories != null && savedCategories.isNotEmpty) {
      categories = savedCategories;
    }

    viewMode = prefs.getString('viewMode') ?? viewMode;
    selectedMonth = prefs.getInt('selectedMonth') ?? selectedMonth;
    selectedDayType = prefs.getString('selectedDayType') ?? selectedDayType;
    dailyLimit = prefs.getDouble('dailyLimit') ?? dailyLimit;
    monthlyLimit = prefs.getDouble('monthlyLimit') ?? monthlyLimit;
    reportView = prefs.getString('reportView') ?? reportView;
    reportChartType = prefs.getString('reportChartType') ?? reportChartType;
    selectedWeekIndex = prefs.getInt('selectedWeekIndex') ?? selectedWeekIndex;
    showPercentage = prefs.getBool('showPercentage') ?? showPercentage;

    final savedDate = prefs.getString('selectedDate');
    if (savedDate != null) {
      selectedDate = DateTime.parse(savedDate);
    }

    setState(() {});
  }

  // ================= ADD =================
  void addTransaction(double amount, String category) {
    DateTime finalDate;

    if (viewMode == "Daily") {
      finalDate = selectedDate;
    } else {
      DateTime now = DateTime.now();
      int safeDay = now.day;
      int lastDay = DateTime(now.year, selectedMonth + 1, 0).day;
      if (safeDay > lastDay) safeDay = lastDay;

      finalDate = DateTime(
        now.year,
        selectedMonth,
        safeDay,
        now.hour,
        now.minute,
      );
    }

    setState(() {
      transactions.add({
        'amount': amount,
        'category': category,
        'date': finalDate,
        'mode': "Cash"
      });
    });

    saveData();
  }

  // ================= TOTAL =================
  double get total {
    if (viewMode == "Monthly") {
      return transactions
          .where((t) => t['date'].month == selectedMonth)
          .fold(0.0, (s, i) => s + (i['amount'] as double));
    } else {
      return transactions
          .where((t) =>
              t['date'].day == selectedDate.day &&
              t['date'].month == selectedDate.month &&
              t['date'].year == selectedDate.year)
          .fold(0.0, (s, i) => s + (i['amount'] as double));
    }
  }

  // ================= LIMIT LOGIC =================
  double get currentLimit => viewMode == "Daily" ? dailyLimit : monthlyLimit;
  double get remaining => currentLimit == 0 ? 0 : currentLimit - total;

  Color get limitColor {
    if (currentLimit == 0) {
      return const Color.fromARGB(255, 247, 246, 246);
    }
    if (total > currentLimit) return Colors.red;
    if (total > currentLimit * 0.8) return Colors.orange;
    return const Color.fromARGB(255, 210, 213, 212);
  }

  // ================= FILTER =================
  List<Map<String, dynamic>> get filtered {
    List<Map<String, dynamic>> list;

    if (viewMode == "Monthly") {
      list = transactions
          .where((t) => t['date'].month == selectedMonth)
          .toList();
    } else {
      list = transactions
          .where((t) =>
              t['date'].day == selectedDate.day &&
              t['date'].month == selectedDate.month &&
              t['date'].year == selectedDate.year)
          .toList();
    }

    list.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return list;
  }

  void deleteTx(Map<String, dynamic> tx) {
    setState(() {
      transactions.remove(tx);
    });
    saveData();
  }

  // ================= WEEK HELPERS =================
  String _weekdayShort(DateTime date) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return days[date.weekday - 1];
  }

  String _monthShort(DateTime date) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return months[date.month - 1];
  }

  String _formatWeekRange(DateTime start, DateTime end) {
    return "${_weekdayShort(start)} ${start.day} ${_monthShort(start)} - "
        "${_weekdayShort(end)} ${end.day} ${_monthShort(end)}";
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  List<Map<String, DateTime>> getWeeksForMonth(int year, int month) {
    List<Map<String, DateTime>> weeks = [];

    DateTime start = DateTime(year, month, 1);
    DateTime monthEnd = DateTime(year, month + 1, 0);

    while (!start.isAfter(monthEnd)) {
      DateTime end = start.add(Duration(days: 6));
      if (end.isAfter(monthEnd)) {
        end = monthEnd;
      }

      weeks.add({
        "start": start,
        "end": end,
      });

      start = end.add(Duration(days: 1));
    }

    return weeks;
  }

  List<Map<String, dynamic>> getCurrentReportList() {
    if (reportView == "Monthly") {
      return transactions.where((t) {
        return t['date'].month == selectedMonth;
      }).toList();
    } else if (reportView == "Daily") {
      return transactions.where((t) {
        return t['date'].day == selectedDate.day &&
            t['date'].month == selectedDate.month &&
            t['date'].year == selectedDate.year;
      }).toList();
    } else {
      final weeks = getWeeksForMonth(DateTime.now().year, selectedMonth);
      if (weeks.isEmpty) return [];

      if (selectedWeekIndex >= weeks.length) {
        selectedWeekIndex = 0;
      }

      final selectedWeek = weeks[selectedWeekIndex];
      final start = selectedWeek['start']!;
      final end = selectedWeek['end']!;

      return transactions.where((t) {
        final d = t['date'] as DateTime;
        final onlyDate = DateTime(d.year, d.month, d.day);
        return (onlyDate.isAtSameMomentAs(DateTime(start.year, start.month, start.day)) ||
                onlyDate.isAfter(DateTime(start.year, start.month, start.day))) &&
            (onlyDate.isAtSameMomentAs(DateTime(end.year, end.month, end.day)) ||
                onlyDate.isBefore(DateTime(end.year, end.month, end.day)));
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: currentIndex == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "limit",
                  backgroundColor: Colors.orange,
                  onPressed: () => openLimitDialog(context),
                  child: Icon(Icons.track_changes),
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "add",
                  onPressed: () => openAddDialog(context),
                  child: Icon(Icons.add),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: currentIndex == 0
            ? buildHome()
            : currentIndex == 1
                ? buildReport()
                : Center(child: Text("Profile Coming Soon 👤")),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Color(0xFF1E1E2C),
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.white70,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap: (i) => setState(() => currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: "Reports"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  // ================= HOME =================
  Widget buildHome() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E1E2C),
                Color(0xFF2C2C54),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TITLE + DATE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Daily Kharcha",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: const Color.fromARGB(255, 252, 252, 252),
                    ),
                  ),
                  Text(
                    "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                  )
                ],
              ),
              SizedBox(height: 8),

              // TOTAL + LIMIT
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viewMode == "Monthly"
                            ? "Monthly Expense"
                            : "Today's Expense",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        currentLimit == 0
                            ? "₹ ${total.toStringAsFixed(0)}"
                            : "₹ ${total.toStringAsFixed(0)} / ₹ ${currentLimit.toStringAsFixed(0)}",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: limitColor,
                        ),
                      ),
                      if (currentLimit != 0)
                        total > currentLimit
                            ? TweenAnimationBuilder(
                                tween: Tween(begin: 0.95, end: 1.0),
                                duration: Duration(milliseconds: 400),
                                curve: Curves.easeOutBack,
                                builder: (context, scale, child) {
                                  return Transform.scale(
                                    scale: scale as double,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  margin: EdgeInsets.only(top: 6),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFB00020).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Color(0xFFB00020).withOpacity(0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: Color(0xFFB00020),
                                        size: 18,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "Limit Crossed",
                                        style: TextStyle(
                                          color: Color(0xFFB00020),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Text(
                                "Remaining: ₹ ${remaining.toStringAsFixed(0)}",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                    ],
                  ),
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text("Monthly"),
                        selected: viewMode == "Monthly",
                        onSelected: (_) {
                          setState(() => viewMode = "Monthly");
                          saveData();
                        },
                      ),
                      SizedBox(width: 8),
                      ChoiceChip(
                        label: Text("Daily"),
                        selected: viewMode == "Daily",
                        onSelected: (_) {
                          setState(() => viewMode = "Daily");
                          saveData();
                        },
                      ),
                    ],
                  )
                ],
              ),

              SizedBox(height: 10),

              if (viewMode == "Daily")
                SizedBox(
                  height: 45,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _dailyItem("Custom", "Custom", () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                            selectedDayType = "Custom";
                          });
                          saveData();
                        }
                      }),
                      _dailyItem("Yesterday", "Yesterday", () {
                        setState(() {
                          selectedDate =
                              DateTime.now().subtract(Duration(days: 1));
                          selectedDayType = "Yesterday";
                        });
                        saveData();
                      }),
                      _dailyItem("Today", "Today", () {
                        setState(() {
                          selectedDate = DateTime.now();
                          selectedDayType = "Today";
                        });
                        saveData();
                      }),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 12,
                    itemBuilder: (_, i) {
                      bool sel = selectedMonth == i + 1;
                      return GestureDetector(
                        onTap: () {
                          setState(() => selectedMonth = i + 1);
                          saveData();
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 5),
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: sel ? Colors.white : Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            [
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
                              "Dec"
                            ][i],
                            style: TextStyle(
                              color: sel ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),

        // LIST
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 130),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              var tx = filtered[i];

              return Dismissible(
                key: ValueKey(
                  '${tx['category']}_${(tx['date'] as DateTime).toIso8601String()}_${tx['amount']}',
                ),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(right: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.delete, color: Colors.white),
                      SizedBox(width: 5),
                      Text("Delete", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                onDismissed: (_) => deleteTx(tx),
                child: ListTile(
                  onTap: () => openTransactionDetail(tx),
                  title: Text(tx['category']),
                  subtitle: Text(
                    "${tx['date'].day}/${tx['date'].month} ${tx['date'].hour}:${tx['date'].minute.toString().padLeft(2, '0')}",
                  ),
                  trailing: Text(
                    "₹ ${tx['amount'].toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }

  // ================= REPORT =================
  Widget buildReport() {
    final reportList = getCurrentReportList();
    final weeks = getWeeksForMonth(DateTime.now().year, selectedMonth);

    if (selectedWeekIndex >= weeks.length && weeks.isNotEmpty) {
      selectedWeekIndex = 0;
    }

    double totalAmount =
        reportList.fold(0.0, (s, i) => s + (i['amount'] as double));

    Map<String, double> categoryTotal = {};
    for (var tx in reportList) {
      String cat = tx['category'];
      double amt = tx['amount'];
      categoryTotal[cat] = (categoryTotal[cat] ?? 0) + amt;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Expense Report",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => openSmartInsightsDialog(),
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.amberAccent,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            "Total: ₹ ${totalAmount.toStringAsFixed(0)}",
            style: TextStyle(fontSize: 18, color: Colors.greenAccent),
          ),
          SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Category Breakdown",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: Text("Monthly", style: TextStyle(fontSize: 12)),
                    labelPadding: EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    selected: reportView == "Monthly",
                    onSelected: (_) {
                      setState(() {
                        reportView = "Monthly";
                        selectedWeekIndex = 0;
                      });
                      saveData();
                    },
                  ),
                  SizedBox(width: 4),
                  ChoiceChip(
                    label: Text("Weekly", style: TextStyle(fontSize: 12)),
                    labelPadding: EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    selected: reportView == "Weekly",
                    onSelected: (_) {
                      setState(() {
                        reportView = "Weekly";
                        selectedWeekIndex = 0;
                      });
                      saveData();
                    },
                  ),
                  SizedBox(width: 4),
                    ChoiceChip(
                      label: Text("Daily", style: TextStyle(fontSize: 12)),
                      labelPadding: EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      selected: reportView == "Daily",
                      onSelected: (_) {
                        final now = DateTime.now();

                        setState(() {
                          reportView = "Daily";
                          selectedWeekIndex = 0;

                          int safeDay = now.day;
                          int maxDay = _daysInMonth(now.year, selectedDate.month);
                          if (safeDay > maxDay) safeDay = maxDay;

                          selectedDate = DateTime(now.year, selectedDate.month, safeDay);
                          selectedDayType = "Custom";
                        });

                        saveData();
                      },
                    ),
                ],
              )
            ],
          ),

          SizedBox(height: 10),

          if (reportView == "Monthly")
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 12,
                itemBuilder: (_, i) {
                  bool sel = selectedMonth == i + 1;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedMonth = i + 1;
                      });
                      saveData();
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 250),
                      margin: EdgeInsets.only(right: 8),
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? Color(0xFF40407A) : Colors.white10,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: sel ? Colors.white24 : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          [
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
                            "Dec"
                          ][i],
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          if (reportView == "Monthly") SizedBox(height: 12),

          if (reportView == "Weekly")
            SizedBox(
              height: 46,
              child: weeks.isEmpty
                  ? Center(child: Text("No weeks available"))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: weeks.length,
                      itemBuilder: (_, i) {
                        final week = weeks[i];
                        final start = week['start']!;
                        final end = week['end']!;
                        final selected = selectedWeekIndex == i;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedWeekIndex = i;
                            });
                            saveData();
                          },
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 250),
                            margin: EdgeInsets.only(right: 8),
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? Color(0xFF40407A) : Colors.white10,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected ? Colors.white24 : Colors.transparent,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _formatWeekRange(start, end),
                                style: TextStyle(
                                  color: selected ? Colors.white : Colors.white70,
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

          if (reportView == "Weekly") SizedBox(height: 12),

          if (reportView == "Daily")
            SizedBox(
              height: 58,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalDays =
                      _daysInMonth(selectedDate.year, selectedDate.month);

                  const double itemWidth = 68;
                  final double screenWidth = constraints.maxWidth;

                  double targetOffset =
                      ((selectedDate.day - 1) * itemWidth) -
                      (screenWidth / 2) +
                      (itemWidth / 2);

                  final double maxOffset =
                      ((totalDays * itemWidth) - screenWidth) < 0
                          ? 0
                          : ((totalDays * itemWidth) - screenWidth);

                  if (targetOffset < 0) targetOffset = 0;
                  if (targetOffset > maxOffset) targetOffset = maxOffset;

                  final controller = ScrollController(initialScrollOffset: targetOffset);

                  return ListView.builder(
                    controller: controller,
                    scrollDirection: Axis.horizontal,
                    itemCount: totalDays,
                    itemBuilder: (_, index) {
                      final date = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        index + 1,
                      );

                      final isSelected =
                          selectedDate.day == date.day &&
                          selectedDate.month == date.month &&
                          selectedDate.year == date.year;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedDate = date;
                            selectedDayType = "Custom";
                          });
                          saveData();
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 250),
                          margin: EdgeInsets.only(right: 8),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Color(0xFF40407A) : Colors.white10,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? Colors.white24 : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _weekdayShort(date),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected ? Colors.white : Colors.white70,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "${date.day}",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          if (reportView == "Daily") SizedBox(height: 12),

          Expanded(
            child: reportChartType == "List"
                ? ListView(
                    children: categoryTotal.entries.map((entry) {
                      return GestureDetector(
                        onTap: () {
                          openCategoryTransactionsDialog(entry.key, reportList);
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 6),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    showPercentage = !showPercentage;
                                  });
                                },
                                child: Text(
                                  showPercentage
                                      ? (totalAmount == 0
                                          ? "0.0%"
                                          : "${((entry.value / totalAmount) * 100).toStringAsFixed(1)}%")
                                      : "₹ ${entry.value.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 220,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: categoryTotal.entries.map((entry) {
                              final percentage = totalAmount == 0
                                  ? 0
                                  : (entry.value / totalAmount) * 100;

                              return PieChartSectionData(
                                value: entry.value,
                                title: totalAmount == 0
                                    ? ""
                                    : "${percentage.toStringAsFixed(1)}%",
                                radius: 70,
                                titleStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                color: _getColor(entry.key),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: categoryTotal.entries.map((entry) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getColor(entry.key),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                entry.key,
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
          ),

          SizedBox(height: 12),

          Center(
            child: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        reportChartType = "List";
                      });
                      saveData();
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 250),
                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: reportChartType == "List"
                            ? Color(0xFF40407A)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        "List",
                        style: TextStyle(
                          color: reportChartType == "List"
                              ? Colors.white
                              : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        reportChartType = "Pie";
                      });
                      saveData();
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 250),
                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: reportChartType == "Pie"
                            ? Color(0xFF40407A)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        "Pie",
                        style: TextStyle(
                          color: reportChartType == "Pie"
                              ? Colors.white
                              : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(String category) {
    switch (category) {
      case "Food":
        return Colors.orange;
      case "Travel":
        return Colors.blue;
      case "Shopping":
        return Colors.purple;
      case "Petrol":
        return Colors.green;
      default:
        return Colors.teal;
    }
  }

  void openTransactionDetail(Map<String, dynamic> tx) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Transaction Detail",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "₹ ${(tx['amount'] as double).toStringAsFixed(0)}",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C2C54),
                  ),
                ),
                SizedBox(height: 12),
                _detailRow("Category", tx['category']),
                _detailRow(
                  "Date",
                  "${tx['date'].day}/${tx['date'].month}/${tx['date'].year}",
                ),
                _detailRow(
                  "Time",
                  "${tx['date'].hour.toString().padLeft(2, '0')}:${tx['date'].minute.toString().padLeft(2, '0')}",
                ),
                _detailRow("Mode", tx['mode'] ?? "Cash"),
                SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Color(0xFF2C2C54),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "Close",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void openCategoryTransactionsDialog(
    String category,
    List<Map<String, dynamic>> reportList,
  ) {
    final categoryTransactions = reportList
        .where((tx) => tx['category'] == category)
        .toList();

    categoryTransactions.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );

    final totalCategoryAmount = categoryTransactions.fold(
      0.0,
      (sum, tx) => sum + (tx['amount'] as double),
    );

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$category Transactions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  reportView == "Monthly"
                      ? "Selected month transactions"
                      : reportView == "Weekly"
                          ? "Selected week transactions"
                          : "Selected day transactions",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "₹ ${totalCategoryAmount.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: Color(0xFF2C2C54),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "${categoryTransactions.length} transaction${categoryTransactions.length == 1 ? '' : 's'}",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: categoryTransactions.isEmpty
                      ? Center(
                          child: Text(
                            "No transactions found",
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      : ListView.separated(
                          itemCount: categoryTransactions.length,
                          separatorBuilder: (_, __) => SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final tx = categoryTransactions[index];
                            final date = tx['date'] as DateTime;

                            return Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF2C2C54).withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_rounded,
                                      color: Color(0xFF2C2C54),
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx['category'],
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}",
                                          style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          tx['mode'] ?? "Cash",
                                          style: TextStyle(
                                            color: Colors.black45,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "₹ ${(tx['amount'] as double).toStringAsFixed(0)}",
                                    style: TextStyle(
                                      color: Color(0xFF2C2C54),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF2C2C54),
                          Color(0xFF40407A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "Close",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openSmartInsightsDialog() {
    final reportList = getCurrentReportList();

    double totalAmount =
        reportList.fold(0.0, (sum, tx) => sum + (tx['amount'] as double));

    int totalTransactions = reportList.length;

    double averageAmount =
        totalTransactions == 0 ? 0 : totalAmount / totalTransactions;

    Map<String, double> categoryTotals = {};
    for (var tx in reportList) {
      final category = tx['category'] as String;
      final amount = tx['amount'] as double;
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

    double activeLimit = reportView == "Daily" ? dailyLimit : monthlyLimit;
    bool isLimitCrossed = activeLimit > 0 && totalAmount > activeLimit;

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "Smart Insights",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  reportView == "Monthly"
                      ? "Insights for selected month"
                      : reportView == "Weekly"
                          ? "Insights for selected week"
                          : "Insights for selected day",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 18),
                _insightTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: "Total Expense",
                  value: "₹ ${totalAmount.toStringAsFixed(0)}",
                ),
                SizedBox(height: 10),
                _insightTile(
                  icon: Icons.receipt_long_rounded,
                  title: "Transactions",
                  value: "$totalTransactions",
                ),
                SizedBox(height: 10),
                _insightTile(
                  icon: Icons.bar_chart_rounded,
                  title: "Average Spend",
                  value: "₹ ${averageAmount.toStringAsFixed(0)}",
                ),
                SizedBox(height: 10),
                _insightTile(
                  icon: Icons.local_fire_department_rounded,
                  title: "Top Category",
                  value: topCategory == "No Data"
                      ? topCategory
                      : "$topCategory • ₹ ${topCategoryAmount.toStringAsFixed(0)}",
                ),
                SizedBox(height: 10),
                _insightTile(
                  icon: isLimitCrossed
                      ? Icons.warning_amber_rounded
                      : Icons.verified_rounded,
                  title: "Limit Status",
                  value: activeLimit == 0
                      ? "No limit set"
                      : isLimitCrossed
                          ? "Limit crossed"
                          : "Within limit",
                  valueColor: isLimitCrossed ? Colors.red : Colors.green,
                ),
                SizedBox(height: 18),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF2C2C54),
                          Color(0xFF40407A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "Close",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _insightTile({
    required IconData icon,
    required String title,
    required String value,
    Color valueColor = const Color(0xFF2C2C54),
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF2C2C54).withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Color(0xFF2C2C54),
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _dailyItem(String label, String type, VoidCallback onTap) {
    bool isSelected = selectedDayType == type;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        margin: EdgeInsets.symmetric(horizontal: 6),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ================= ADD DIALOG =================
  void openAddDialog(BuildContext context) {
    TextEditingController amountController = TextEditingController();
    TextEditingController customController = TextEditingController();

    String category = categories[0];
    bool isCustom = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Add Expense",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: "Enter Amount",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...categories.map((cat) {
                        bool isSelected = category == cat;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              category = cat;
                              isCustom = false;
                            });
                          },
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color(0xFF2C2C54)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isCustom = true;
                            category = "Custom";
                          });
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isCustom
                                ? Colors.orange
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Custom",
                            style: TextStyle(
                              color: isCustom ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  if (isCustom)
                    TextField(
                      controller: customController,
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: "Custom Category",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      double amount =
                          double.tryParse(amountController.text) ?? 0;

                      String finalCategory =
                          isCustom ? customController.text.trim() : category;

                      if (amount > 0 && finalCategory.isNotEmpty) {
                        if (!categories.contains(finalCategory)) {
                          categories.add(finalCategory);
                        }
                        addTransaction(amount, finalCategory);
                      }

                      saveData();
                      Navigator.pop(context);
                    },
                    child: TweenAnimationBuilder(
                      tween: Tween(begin: 0.95, end: 1.0),
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale as double,
                          child: child,
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF2C2C54),
                              Color(0xFF40407A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            "Add",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ================= LIMIT DIALOG =================
  void openLimitDialog(BuildContext context) {
    TextEditingController controller = TextEditingController(
      text: viewMode == "Daily"
          ? (dailyLimit == 0 ? "" : dailyLimit.toStringAsFixed(0))
          : (monthlyLimit == 0 ? "" : monthlyLimit.toStringAsFixed(0)),
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Limit Dialog",
      barrierColor: Colors.black54,
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0.92, end: 1.0),
                  duration: Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 24),
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Color(0xFF2C2C54).withOpacity(0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.track_changes_rounded,
                            color: Color(0xFF2C2C54),
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          viewMode == "Daily"
                              ? "Set Daily Limit"
                              : "Set Monthly Limit",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          viewMode == "Daily"
                              ? "Add your daily spending limit"
                              : "Add your monthly spending limit",
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 18),
                        TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            prefixText: "₹ ",
                            prefixStyle: TextStyle(
                              color: Color(0xFF2C2C54),
                              fontWeight: FontWeight.w700,
                            ),
                            hintText: "Enter limit amount",
                            hintStyle: TextStyle(color: Colors.black38),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Color(0xFF40407A),
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 13),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "Cancel",
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  double value =
                                      double.tryParse(controller.text.trim()) ??
                                          0;

                                  setState(() {
                                    if (viewMode == "Daily") {
                                      dailyLimit = value;
                                    } else {
                                      monthlyLimit = value;
                                    }
                                  });

                                  saveData();
                                  Navigator.pop(context);
                                },
                                child: TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 0.96, end: 1.0),
                                  duration: Duration(milliseconds: 250),
                                  curve: Curves.easeOutBack,
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 13),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF2C2C54),
                                          Color(0xFF40407A),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "Save",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
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
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: child,
        );
      },
    );
  }
}