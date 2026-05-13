import 'package:flutter/material.dart';

import '../models/udhar_customer_model.dart';
import '../services/udhar_service.dart';

class AddCustomerTransactionDialog extends StatefulWidget {
  final bool isDark;
  final UdharCustomerModel customer;

  const AddCustomerTransactionDialog({
    super.key,
    required this.isDark,
    required this.customer,
  });

  @override
  State<AddCustomerTransactionDialog> createState() =>
      _AddCustomerTransactionDialogState();
}

class _AddCustomerTransactionDialogState
    extends State<AddCustomerTransactionDialog> {
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  String type = "given";
  bool loading = false;

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF171827) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.customer.name,
            style: TextStyle(
              color: isDark ? const Color.fromARGB(255, 241, 241, 241) : Colors.black45,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Add Transaction",
            style: TextStyle(
              color: isDark ? const Color.fromARGB(155, 117, 115, 115) : Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          children: [
            _field("Amount", amountController, number: true),
            const SizedBox(height: 12),
            _field("Note optional", noteController),
            const SizedBox(height: 14),
            Row(
              children: [
                _typeButton("I Gave", "given"),
                const SizedBox(width: 10),
                _typeButton("I Received", "taken"),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              type == "given"
                  ? "${widget.customer.name} has to pay you."
                  : "Your payable amount will reduce.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C4DFF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: loading ? null : _save,
          child: loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Save", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _field(
    String hint,
    TextEditingController controller, {
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: widget.isDark ? Colors.white38 : Colors.black38,
        ),
        filled: true,
        fillColor: widget.isDark ? Colors.white10 : const Color(0xFFF4F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _typeButton(String text, String value) {
    final selected = type == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => type = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF6C4DFF)
                : widget.isDark
                    ? Colors.white10
                    : const Color(0xFFF1F2F7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF6C4DFF)
                  : widget.isDark
                      ? Colors.white12
                      : Colors.grey.shade300,
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : widget.isDark
                      ? Colors.white70
                      : const Color(0xFF2C2C54),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(amountController.text.trim()) ?? 0;

    if (amount <= 0) return;

    setState(() => loading = true);

    await UdharService.addTransactionToCustomer(
      customerId: widget.customer.id,
      type: type,
      amount: amount,
      note: noteController.text,
    );

    if (mounted) Navigator.pop(context);
  }
}