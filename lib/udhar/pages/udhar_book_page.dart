import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                children: [
                  /// FIXED HEADER
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

                  /// FIXED SUMMARY
                  UdharSummaryCard(
                    isDark: isDark,
                    customers: customers,
                  ),

                  const SizedBox(height: 10),

                  /// FIXED FILTERS
                  _filterBar(),

                  const SizedBox(height: 10),

                  /// ONLY CUSTOMER LIST WILL SCROLL
                  Expanded(
                    child: !snapshot.hasData
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : filtered.isEmpty
                            ? _emptyBox()
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.only(bottom: 86),
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final customer = filtered[index];

                                  return Dismissible(
                                    key: ValueKey("customer_${customer.id}"),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding:
                                          const EdgeInsets.only(right: 18),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius:
                                            BorderRadius.circular(18),
                                      ),
                                      child: const Icon(
                                        Icons.delete_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    confirmDismiss: (_) async {
                                      await UdharService.deleteCustomer(
                                        customer.id,
                                      );
                                      return false;
                                    },
                                    child: GestureDetector(
                                      behavior:
                                          HitTestBehavior.translucent,
                                      onTapDown: (details) {
                                        final width =
                                            MediaQuery.of(context)
                                                .size
                                                .width;

                                        if (details.localPosition.dx <
                                            width * 0.55) {
                                          _openEditCustomerDialog(
                                            customer,
                                          );
                                        }
                                      },
                                      child: UdharCard(
                                        isDark: isDark,
                                        customer: customer,
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );          },
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


  Widget _whatsAppReminderButton() {
    return SizedBox(
      width: 50,
      height: 50,
      child: FloatingActionButton(
        heroTag: "whatsapp_reminder",
        elevation: 8,
        backgroundColor: const Color(0xFF25D366),
        onPressed: _openWhatsAppReminderSheet,
        child: const Icon(
          Icons.chat_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  void _openWhatsAppReminderSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF171827) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: UdharService.streamCustomers(),
            builder: (context, snapshot) {
              final customers = snapshot.hasData
                  ? snapshot.data!.docs
                      .map((e) => UdharCustomerModel.fromDoc(e))
                      .where((c) => c.balance != 0)
                      .toList()
                  : <UdharCustomerModel>[];

              customers.sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withOpacity(0.16),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.chat_rounded,
                            color: Color(0xFF25D366),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "WhatsApp Reminder",
                                style: TextStyle(
                                  color: widget.isDark ? Colors.white : Colors.black87,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Send a quick payment reminder",
                                style: TextStyle(
                                  color: widget.isDark ? Colors.white54 : Colors.black45,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (!snapshot.hasData)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 22),
                        child: CircularProgressIndicator(),
                      )
                    else if (customers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        child: Text(
                          "No pending udhar reminder found",
                          style: TextStyle(
                            color: widget.isDark ? Colors.white54 : Colors.black45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: customers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final customer = customers[index];
                            final isPay = customer.balance < 0;
                            final amount = customer.balance.abs();

                            return InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _sendWhatsAppReminder(customer),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: widget.isDark
                                      ? Colors.white.withOpacity(0.07)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 21,
                                      backgroundColor: isPay
                                          ? const Color(0xFFFFA726).withOpacity(0.18)
                                          : const Color(0xFF2EE59D).withOpacity(0.18),
                                      child: Text(
                                        customer.name.isNotEmpty
                                            ? customer.name[0].toUpperCase()
                                            : "U",
                                        style: TextStyle(
                                          color: isPay
                                              ? const Color(0xFFFFA726)
                                              : const Color(0xFF2EE59D),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            customer.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: widget.isDark ? Colors.white : Colors.black87,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            isPay ? "You need to pay" : "You will receive",
                                            style: TextStyle(
                                              color: widget.isDark ? Colors.white54 : Colors.black45,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      "₹ ${amount.toStringAsFixed(0)}",
                                      style: TextStyle(
                                        color: isPay ? const Color(0xFFFFA726) : const Color(0xFF2EE59D),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: widget.isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _sendWhatsAppReminder(UdharCustomerModel customer) async {
    final rawPhone = customer.phone.trim();

    if (rawPhone.isEmpty) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mobile number is missing for this person.")),
      );
      return;
    }

    var phone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length == 10) {
      phone = "91$phone";
    }

    final amount = customer.balance.abs().toStringAsFixed(0);
    final message = customer.balance < 0
        ? "Hi ${customer.name}, I wanted to remind you that I need to pay ₹$amount. I will update you once it is settled."
        : "Hi ${customer.name}, gentle reminder for the pending amount of ₹$amount. Please settle it when possible.";

    final uri = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

    Navigator.pop(context);

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to open WhatsApp.")),
      );
    }
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
  void _openEditCustomerDialog(
    UdharCustomerModel customer,
  ) {
    final nameController =
        TextEditingController(text: customer.name);

    final phoneController =
        TextEditingController(text: customer.phone);
    DateTime selectedDate = customer.latestTransactionDate.toDate();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF171827)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Edit Person",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: widget.isDark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),

                    GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? Colors.white10
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: widget.isDark
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                TextField(
                  controller: nameController,
                  style: TextStyle(
                    color: widget.isDark
                        ? Colors.white
                        : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: "Person name",
                    filled: true,
                    fillColor: widget.isDark
                        ? Colors.white10
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    color: widget.isDark
                        ? Colors.white
                        : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: "Mobile number",
                    filled: true,
                    fillColor: widget.isDark
                        ? Colors.white10
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                GestureDetector(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        final baseTheme = Theme.of(context);
                        return Theme(
                          data: baseTheme.copyWith(
                            colorScheme: baseTheme.colorScheme.copyWith(
                              primary: const Color(0xFF6C4DFF),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (pickedDate != null) {
                      setDialogState(() {
                        selectedDate = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                        );
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white10
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6C4DFF).withOpacity(0.22),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFF8D6BFF),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                            style: TextStyle(
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: widget.isDark
                              ? Colors.white54
                              : Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF6C4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      await UdharService.updateCustomer(
                        customerId: customer.id,
                        name: nameController.text,
                        phone: phoneController.text,
                        latestTransactionDate: selectedDate,
                      );

                      if (mounted) {
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Person updated successfully",
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      "Save Changes",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
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
      },
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