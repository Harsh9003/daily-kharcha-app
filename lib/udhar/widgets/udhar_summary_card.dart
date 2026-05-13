import 'package:flutter/material.dart';
import '../models/udhar_customer_model.dart';

class UdharSummaryCard extends StatelessWidget {
  final bool isDark;
  final List<UdharCustomerModel> customers;

  const UdharSummaryCard({
    super.key,
    required this.isDark,
    required this.customers,
  });

  @override
  Widget build(BuildContext context) {
    final totalReceive = customers.where((c) => c.balance > 0).fold<double>(0, (s, c) => s + c.balance);
    final totalPay = customers.where((c) => c.balance < 0).fold<double>(0, (s, c) => s + c.balance.abs());
    final net = totalReceive - totalPay;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF211D52), Color(0xFF302D63)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          _item("Receive", "₹ ${totalReceive.toStringAsFixed(0)}", Colors.greenAccent, Icons.call_received_rounded),
          _line(),
          _item("Pay", "₹ ${totalPay.toStringAsFixed(0)}", Colors.orangeAccent, Icons.call_made_rounded),
          _line(),
          _item("Net", "₹ ${net.abs().toStringAsFixed(0)}", const Color(0xFF8B7CFF), Icons.account_balance_wallet_rounded),
        ],
      ),
    );
  }

  Widget _line() => Container(width: 1, height: 42, margin: const EdgeInsets.symmetric(horizontal: 8), color: Colors.white12);

  Widget _item(String title, String amount, Color color, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: color.withOpacity(0.17),
            child: Icon(icon, color: color, size: 13),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount,
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}