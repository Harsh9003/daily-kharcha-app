import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/udhar_customer_model.dart';
import '../models/udhar_transaction_model.dart';
import '../services/udhar_service.dart';
import '../../services/pdf_service.dart';
import '../widgets/add_customer_transaction_dialog.dart';


class UdharDetailsPage extends StatelessWidget {
  final bool isDark;
  final UdharCustomerModel customer;

  const UdharDetailsPage({
    super.key,
    required this.isDark,
    required this.customer,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: UdharService.customersRef().doc(customer.id).snapshots(),
      builder: (context, customerSnapshot) {
        final liveCustomer = customerSnapshot.hasData && customerSnapshot.data!.exists
            ? UdharCustomerModel.fromDoc(customerSnapshot.data!)
            : customer;

        final balanceColor = liveCustomer.balance > 0
            ? Colors.greenAccent
            : liveCustomer.balance < 0
                ? Colors.orangeAccent
                : Colors.blueGrey;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF050617) : const Color(0xFFF6F7FB),
          appBar: AppBar(
            toolbarHeight: 52,
            backgroundColor: isDark ? const Color(0xFF050617) : const Color(0xFFF6F7FB),
            elevation: 0,
            iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
            title: Text(
              liveCustomer.name,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            actions: [
              IconButton(
                tooltip: "Share statement",
                onPressed: () => _shareUdharStatement(context, liveCustomer),
                icon: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: isDark ? Colors.white : const Color(0xFF2C2C54),
                  size: 21,
                ),
              ),
              IconButton(
                onPressed: () async {
                  await UdharService.deleteCustomer(liveCustomer.id);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 21),
              ),
            ],
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: FloatingActionButton(
                  heroTag: "whatsapp_reminder_${liveCustomer.id}",
                  elevation: 8,
                  backgroundColor: const Color(0xFF25D366),
                  onPressed: () => _sendWhatsAppReminder(context, liveCustomer),
                  child: const Icon(
                    Icons.chat_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 56,
                height: 56,
                child: FloatingActionButton(
                  heroTag: "add_udhar_transaction_${liveCustomer.id}",
                  backgroundColor: const Color(0xFF6C4DFF),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AddCustomerTransactionDialog(
                        isDark: isDark,
                        customer: liveCustomer,
                      ),
                    );
                  },
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 90),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF302D63)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: balanceColor.withOpacity(0.18),
                      child: Icon(
                        liveCustomer.balance > 0
                            ? Icons.arrow_downward_rounded
                            : liveCustomer.balance < 0
                                ? Icons.arrow_upward_rounded
                                : Icons.check_rounded,
                        color: balanceColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        liveCustomer.balance > 0
                            ? "You will receive"
                            : liveCustomer.balance < 0
                                ? "You have to pay"
                                : "Settled",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      "₹ ${liveCustomer.balance.abs().toStringAsFixed(0)}",
                      style: TextStyle(
                        color: balanceColor,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: UdharService.streamTransactions(liveCustomer.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final txDocs = snapshot.data!.docs;

                  if (txDocs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 50),
                      child: Center(
                        child: Text(
                          "No transactions yet",
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: txDocs.map((doc) {
                      final tx = UdharTransactionModel.fromDoc(doc);
                      final txData = doc.data();
                      final currentPaymentMode = (txData['paymentMode'] ?? 'Cash').toString();
                      final dt = tx.createdAt.toDate();
                      final color = tx.isGiven ? Colors.greenAccent : Colors.orangeAccent;

                      return Dismissible(
                        key: ValueKey("${liveCustomer.id}_${tx.id}"),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 18),
                          margin: const EdgeInsets.only(bottom: 9),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.delete_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        confirmDismiss: (_) async {
                          await UdharService.deleteTransactionFromCustomer(
                            customerId: liveCustomer.id,
                            transactionId: tx.id,
                            type: tx.type,
                            amount: tx.amount,
                          );

                          return false;
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openEditTransactionDialog(
                            context,
                            liveCustomer,
                            tx,
                            currentPaymentMode,
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141827) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: color.withOpacity(0.16),
                              child: Icon(
                                tx.isGiven
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                color: color,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.isGiven ? "You gave" : "You received",
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    tx.note.isEmpty
                                        ? "${dt.day}/${dt.month}/${dt.year}"
                                        : "${tx.note} • ${dt.day}/${dt.month}/${dt.year}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black45,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              "₹ ${tx.amount.toStringAsFixed(0)}",
                              style: TextStyle(
                                color: color,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }


  Future<void> _shareUdharStatement(
    BuildContext context,
    UdharCustomerModel liveCustomer,
  ) async {
    try {
      final snapshot = await UdharService.customersRef()
          .doc(liveCustomer.id)
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .get();

      final transactions = snapshot.docs.map((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'];

        DateTime date;
        if (createdAt is Timestamp) {
          date = createdAt.toDate();
        } else if (createdAt is DateTime) {
          date = createdAt;
        } else {
          date = DateTime.now();
        }

        return {
          'date': date,
          'type': (data['type'] ?? 'given').toString(),
          'amount': ((data['amount'] ?? 0) as num).toDouble(),
          'note': (data['note'] ?? '').toString(),
        };
      }).toList();

      await PdfService.shareUdharStatementPdf(
        customerName: liveCustomer.name,
        phone: liveCustomer.phone,
        balance: liveCustomer.balance,
        transactions: transactions,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to create statement: $e'),
        ),
      );
    }
  }
  void _openEditTransactionDialog(
    BuildContext context,
    UdharCustomerModel customer,
    UdharTransactionModel tx,
    String currentPaymentMode,
  ) {
    final amountController = TextEditingController(
      text: tx.amount.toStringAsFixed(tx.amount % 1 == 0 ? 0 : 2),
    );
    final noteController = TextEditingController(text: tx.note);

    String selectedType = tx.type;
    String selectedPaymentMode = currentPaymentMode.isNotEmpty ? currentPaymentMode : "Cash";
    DateTime selectedDate = tx.createdAt.toDate();
    bool isSaving = false;

    final Color panelColor = isDark ? const Color(0xFF111322) : Colors.white;
    final Color fieldColor = isDark
        ? Colors.white.withOpacity(0.07)
        : const Color(0xFFF4F5FB);
    final Color textColor = isDark ? Colors.white : const Color(0xFF161622);
    final Color subTextColor = isDark ? Colors.white60 : Colors.black54;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Transaction',
      barrierColor: Colors.black.withOpacity(0.62),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isGiven = selectedType == 'given';
            final Color accentColor = isGiven
                ? Colors.greenAccent
                : Colors.orangeAccent;
            final String previewText = isGiven
                ? 'This amount will be marked as receivable.'
                : 'This amount will be marked as payable.';

            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.86,
                  constraints: const BoxConstraints(maxWidth: 390),
                  decoration: BoxDecoration(
                    color: panelColor,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.04),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentColor.withOpacity(0.95),
                                  const Color(0xFF6C4DFF),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                                        color: accentColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Icon(
                                        isGiven
                                            ? Icons.arrow_upward_rounded
                                            : Icons.arrow_downward_rounded,
                                        color: accentColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Edit Transaction',
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            customer.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: subTextColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => Navigator.pop(dialogContext),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: fieldColor,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: subTextColor,
                                          size: 19,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                Text(
                                  'Amount',
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: amountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  decoration: InputDecoration(
                                    prefixText: '₹ ',
                                    prefixStyle: TextStyle(
                                      color: textColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    hintText: 'Enter amount',
                                    hintStyle: TextStyle(color: subTextColor),
                                    filled: true,
                                    fillColor: fieldColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(17),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                Text(
                                  'Transaction Type',
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: fieldColor,
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                  child: Row(
                                    children: [
                                      _editTypeChip(
                                        label: 'You gave',
                                        icon: Icons.arrow_upward_rounded,
                                        selected: selectedType == 'given',
                                        color: Colors.greenAccent,
                                        onTap: () => setDialogState(() => selectedType = 'given'),
                                      ),
                                      _editTypeChip(
                                        label: 'You received',
                                        icon: Icons.arrow_downward_rounded,
                                        selected: selectedType == 'taken',
                                        color: Colors.orangeAccent,
                                        onTap: () => setDialogState(() => selectedType = 'taken'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                Text(
                                  'Note',
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: noteController,
                                  maxLines: 2,
                                  minLines: 1,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Add note',
                                    hintStyle: TextStyle(color: subTextColor),
                                    filled: true,
                                    fillColor: fieldColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(17),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                Text(
                                  'Transaction Date',
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  borderRadius: BorderRadius.circular(17),
                                  onTap: () async {
                                    final pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: ColorScheme.dark(
                                              primary: const Color(0xFF6C4DFF),
                                              onPrimary: Colors.white,
                                              surface: panelColor,
                                              onSurface: textColor,
                                            ),
                                            dialogBackgroundColor: panelColor,
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
                                          selectedDate.hour,
                                          selectedDate.minute,
                                          selectedDate.second,
                                        );
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: fieldColor,
                                      borderRadius: BorderRadius.circular(17),
                                      border: Border.all(
                                        color: const Color(0xFF6C4DFF).withOpacity(0.28),
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
                                            "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}",
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: subTextColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                Text(
                                  'Payment Mode',
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: fieldColor,
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                  child: Row(
                                    children: [
                                      _editPaymentModeChip(
                                        label: 'Cash',
                                        icon: Icons.payments_rounded,
                                        selected: selectedPaymentMode == 'Cash',
                                        color: Colors.greenAccent,
                                        onTap: () => setDialogState(() => selectedPaymentMode = 'Cash'),
                                      ),
                                      _editPaymentModeChip(
                                        label: 'UPI',
                                        icon: Icons.account_balance_wallet_rounded,
                                        selected: selectedPaymentMode == 'UPI',
                                        color: const Color(0xFF6C4DFF),
                                        onTap: () => setDialogState(() => selectedPaymentMode = 'UPI'),
                                      ),
                                      _editPaymentModeChip(
                                        label: 'Card',
                                        icon: Icons.credit_card_rounded,
                                        selected: selectedPaymentMode == 'Card',
                                        color: Colors.orangeAccent,
                                        onTap: () => setDialogState(() => selectedPaymentMode = 'Card'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: accentColor.withOpacity(0.18)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_rounded, color: accentColor, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          previewText,
                                          style: TextStyle(
                                            color: isDark ? Colors.white70 : Colors.black54,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),

                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                                        style: TextButton.styleFrom(
                                          foregroundColor: subTextColor,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                        ),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: isSaving
                                            ? null
                                            : () async {
                                                final amount = double.tryParse(
                                                  amountController.text.trim(),
                                                );

                                                if (amount == null || amount <= 0) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Please enter a valid amount.'),
                                                    ),
                                                  );
                                                  return;
                                                }

                                                setDialogState(() => isSaving = true);

                                                await UdharService.updateTransactionFromCustomer(
                                                  customerId: customer.id,
                                                  transactionId: tx.id,
                                                  oldType: tx.type,
                                                  oldAmount: tx.amount,
                                                  newType: selectedType,
                                                  newAmount: amount,
                                                  note: noteController.text,
                                                );

                                                await UdharService.customersRef()
                                                    .doc(customer.id)
                                                    .collection('transactions')
                                                    .doc(tx.id)
                                                    .update({
                                                  'paymentMode': selectedPaymentMode,
                                                  'createdAt': Timestamp.fromDate(selectedDate),
                                                  'selectedDate': Timestamp.fromDate(selectedDate),
                                                  'updatedAt': FieldValue.serverTimestamp(),
                                                });

                                                if (dialogContext.mounted) {
                                                  Navigator.pop(dialogContext);
                                                }
                                              },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF6C4DFF), Color(0xFF8D6BFF)],
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF6C4DFF).withOpacity(0.28),
                                                blurRadius: 16,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: isSaving
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Text(
                                                    'Save Changes',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w900,
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }


  Widget _editPaymentModeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final Color inactiveColor = isDark ? Colors.white54 : Colors.black45;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withOpacity(0.48) : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? color : inactiveColor,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? color : inactiveColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _editTypeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withOpacity(0.45) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? color : (isDark ? Colors.white54 : Colors.black38),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? color : (isDark ? Colors.white60 : Colors.black45),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Future<void> _sendWhatsAppReminder(
    BuildContext context,
    UdharCustomerModel liveCustomer,
  ) async {
    final rawPhone = liveCustomer.phone.trim();

    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mobile number not available for this person."),
        ),
      );
      return;
    }

    var phone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');

    if (phone.length == 10) {
      phone = "91$phone";
    }

    final amount = liveCustomer.balance.abs().toStringAsFixed(0);

    final message = liveCustomer.balance < 0
        ? "Hi ${liveCustomer.name}, reminder regarding ₹$amount pending payment."
        : "Hi ${liveCustomer.name}, gentle reminder for ₹$amount pending amount.";

    final uri = Uri.parse(
      "https://wa.me/$phone?text=${Uri.encodeComponent(message)}",
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to open WhatsApp."),
        ),
      );
    }
  }

}