import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/udhar_customer_model.dart';
import '../models/udhar_transaction_model.dart';
import '../services/udhar_service.dart';
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
                onPressed: () async {
                  await UdharService.deleteCustomer(liveCustomer.id);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 21),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
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

                  final txs = snapshot.data!.docs
                      .map((e) => UdharTransactionModel.fromDoc(e))
                      .toList();

                  if (txs.isEmpty) {
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
                    children: txs.map((tx) {
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
}