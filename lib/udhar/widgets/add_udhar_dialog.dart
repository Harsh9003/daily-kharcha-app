import 'package:flutter/material.dart';

import '../services/udhar_service.dart';

class AddUdharDialog extends StatefulWidget {
  final bool isDark;

  const AddUdharDialog({
    super.key,
    required this.isDark,
  });

  @override
  State<AddUdharDialog> createState() => _AddUdharDialogState();
}

class _AddUdharDialogState extends State<AddUdharDialog> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  String type = "given";
  bool loading = false;
  DateTime selectedDate = DateTime.now();

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
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
      title: Text(
        "Add Udhar Transaction",
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          children: [
            _field("Person name", nameController),
            const SizedBox(height: 12),
            _field("Phone optional", phoneController, number: true),
            const SizedBox(height: 12),
            _field("Amount", amountController, number: true),
            const SizedBox(height: 12),
            _field("Note optional", noteController),
            const SizedBox(height: 12),
            _datePickerTile(),
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
                  ? "This means this person has to pay you."
                  : "This means you have to pay this person.",
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

  Widget _datePickerTile() {
    final isDark = widget.isDark;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _pickDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 20,
              color: isDark ? Colors.white70 : const Color(0xFF6C4DFF),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Transaction Date",
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDate(selectedDate),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: widget.isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF6C4DFF),
                    surface: Color(0xFF171827),
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF6C4DFF),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        selectedDate.hour,
        selectedDate.minute,
        selectedDate.second,
      );
    });
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return "$day/$month/${date.year}";
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
    final name = nameController.text.trim();
    final amount = double.tryParse(amountController.text.trim()) ?? 0;

    if (name.isEmpty || amount <= 0) return;

    setState(() => loading = true);

    await UdharService.addTransaction(
      name: name,
      phone: phoneController.text,
      type: type,
      amount: amount,
      note: noteController.text,
      transactionDate: selectedDate,
    );

    if (mounted) Navigator.pop(context);
  }
}