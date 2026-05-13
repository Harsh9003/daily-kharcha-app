import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/udhar_customer_model.dart';
import '../services/udhar_service.dart';
import '../widgets/add_udhar_dialog.dart';
import '../widgets/udhar_card.dart';
import '../widgets/udhar_summary_card.dart';

class UdharBookPage extends StatefulWidget {
  final bool isDark;

  const UdharBookPage({
    super.key,
    required this.isDark,
  });

  @override
  State<UdharBookPage> createState() => _UdharBookPageState();
}

class _UdharBookPageState extends State<UdharBookPage> {
  String selectedFilter = "all";
  String sortBy = "recent";
  bool showSearch = false;

  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF050617)
          : const Color(0xFFF6F7FB),

      floatingActionButton: SizedBox(
        width: 54,
        height: 54,
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF6C4DFF),
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => AddUdharDialog(isDark: isDark),
            );
          },
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),
      ),

      body: GestureDetector(
        onTap: () {
          searchFocusNode.unfocus();
        },
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: UdharService.streamCustomers(),
          builder: (context, snapshot) {
            final customers = snapshot.hasData
                ? snapshot.data!.docs
                    .map((e) => UdharCustomerModel.fromDoc(e))
                    .toList()
                : <UdharCustomerModel>[];

            List<UdharCustomerModel> filtered = customers.where((c) {
              if (selectedFilter == "receive" && c.balance <= 0) {
                return false;
              }

              if (selectedFilter == "pay" && c.balance >= 0) {
                return false;
              }

              if (selectedFilter == "settled" && c.balance != 0) {
                return false;
              }

              final query = searchController.text
                  .trim()
                  .toLowerCase();

              if (query.isNotEmpty) {
                return c.name.toLowerCase().contains(query) ||
                    c.phone.toLowerCase().contains(query);
              }

              return true;
            }).toList();

            if (sortBy == "name") {
              filtered.sort(
                (a, b) => a.name
                    .toLowerCase()
                    .compareTo(b.name.toLowerCase()),
              );
            } else if (sortBy == "amount") {
              filtered.sort(
                (a, b) => b.balance
                    .abs()
                    .compareTo(a.balance.abs()),
              );
            } else {
              filtered.sort(
                (a, b) => b.updatedAt.compareTo(a.updatedAt),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 86),
              children: [

                /// HEADER
                Row(
                  children: [
                    Expanded(
                      child: showSearch
                          ? TextField(
                              controller: searchController,
                              focusNode: searchFocusNode,
                              autofocus: true,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: "Search person...",
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white10
                                    : Colors.white,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            )
                          : Text(
                              "Udhar Book",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E1E2C),
                              ),
                            ),
                    ),

                    const SizedBox(width: 8),

                    _topButton(
                      showSearch
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                      () {
                        setState(() {
                          showSearch = !showSearch;

                          if (!showSearch) {
                            searchController.clear();
                            searchFocusNode.unfocus();
                          }
                        });
                      },
                    ),

                    const SizedBox(width: 7),

                    _topButton(
                      Icons.tune_rounded,
                      _openSortSheet,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                /// SUMMARY
                UdharSummaryCard(
                  isDark: isDark,
                  customers: customers,
                ),

                const SizedBox(height: 10),

                /// FILTERS
                _filterBar(),

                const SizedBox(height: 10),

                /// LIST
                if (!snapshot.hasData)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (filtered.isEmpty)
                  _emptyBox()
                else
                  ...filtered.map(
                    (customer) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Dismissible(
                        key: ValueKey("customer_${customer.id}"),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 18),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.delete_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        confirmDismiss: (_) async {
                          await UdharService.deleteCustomer(customer.id);
                          return false;
                        },
                        child: UdharCard(
                          isDark: isDark,
                          customer: customer,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topButton(
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: widget.isDark
              ? Colors.white10
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          size: 19,
          color: widget.isDark
              ? Colors.white
              : const Color(0xFF2C2C54),
        ),
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: widget.isDark
              ? Colors.white10
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          _filter("All", "all"),
          _filter("Receive", "receive"),
          _filter("Pay", "pay"),
          _filter("Settled", "settled"),
        ],
      ),
    );
  }

  Widget _filter(
    String text,
    String value,
  ) {
    final selected = selectedFilter == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          selectedFilter = value;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF6C4DFF)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : widget.isDark
                      ? Colors.white70
                      : Colors.black54,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }

  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark
          ? const Color(0xFF171827)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white24
                        : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 16),

                _sortTile(
                  "Recent first",
                  "recent",
                  Icons.schedule_rounded,
                ),

                _sortTile(
                  "Name A-Z",
                  "name",
                  Icons.sort_by_alpha_rounded,
                ),

                _sortTile(
                  "Highest amount",
                  "amount",
                  Icons.trending_up_rounded,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sortTile(
    String title,
    String value,
    IconData icon,
  ) {
    final selected = sortBy == value;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      onTap: () {
        setState(() => sortBy = value);
        Navigator.pop(context);
      },
      leading: Icon(
        icon,
        size: 20,
        color: selected
            ? const Color(0xFF6C4DFF)
            : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: widget.isDark
              ? Colors.white
              : Colors.black87,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
      trailing: selected
          ? const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF6C4DFF),
              size: 20,
            )
          : null,
    );
  }

  Widget _emptyBox() {
    return Padding(
      padding: const EdgeInsets.only(top: 45),
      child: Center(
        child: Text(
          "No udhar records found",
          style: TextStyle(
            color: widget.isDark
                ? Colors.white54
                : Colors.black45,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}