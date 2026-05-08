import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/admin_service.dart';

class AdminUserDetailsPage extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> userData;

  const AdminUserDetailsPage({
    super.key,
    required this.uid,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();

    final name = (userData['name'] ?? 'No Name').toString();
    final email = (userData['email'] ?? 'No Email').toString();
    final role = (userData['role'] ?? 'user').toString();
    final photoUrl = (userData['photoUrl'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151526),
        title: const Text(
          "User Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          final liveData = userSnapshot.data?.data() ?? userData;
          final isBlocked = liveData['isBlocked'] == true;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('transactions')
                .snapshots(),
            builder: (context, txSnapshot) {
              final txDocs = txSnapshot.data?.docs ?? [];

              double totalExpense = 0;
              for (final doc in txDocs) {
                final data = doc.data();
                final amount = data['amount'];
                if (amount is num) {
                  totalExpense += amount.toDouble();
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _profileCard(
                      name: name,
                      email: email,
                      uid: uid,
                      role: role,
                      photoUrl: photoUrl,
                      isBlocked: isBlocked,
                      onBlockToggle: role == "admin"
                          ? null
                          : () async {
                              await adminService.setUserBlocked(uid, !isBlocked);
                            },
                    ),

                    const SizedBox(height: 18),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 700;

                        return GridView.count(
                          crossAxisCount: isWide ? 3 : 1,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: isWide ? 2.8 : 3.8,
                          children: [
                            _infoCard(
                              title: "Transactions",
                              value: txDocs.length.toString(),
                              icon: Icons.receipt_long_rounded,
                              color: const Color(0xFF40407A),
                            ),
                            _infoCard(
                              title: "Total Expense",
                              value: "₹ ${totalExpense.toStringAsFixed(0)}",
                              icon: Icons.currency_rupee_rounded,
                              color: Colors.green,
                            ),
                            _infoCard(
                              title: "Status",
                              value: isBlocked ? "Blocked" : "Active",
                              icon: isBlocked
                                  ? Icons.block_rounded
                                  : Icons.verified_user_rounded,
                              color: isBlocked ? Colors.red : Colors.green,
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      "Latest Transactions",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF151526),
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (txDocs.isEmpty)
                      _emptyBox()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: txDocs.length > 10 ? 10 : txDocs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final tx = txDocs[index].data();
                          final txId = txDocs[index].id;

                          final category = (tx['category'] ?? 'Unknown').toString();
                          final mode = (tx['mode'] ?? 'Cash').toString();
                          final note = (tx['note'] ?? '').toString();
                          final amount = tx['amount'] ?? 0;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF40407A).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag_rounded,
                                    color: Color(0xFF40407A),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        category,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        mode,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (note.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.sticky_note_2_rounded,
                                                size: 14,
                                                color: Colors.orange,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  note,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  "₹ $amount",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  tooltip: "Edit transaction",
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: Color(0xFF40407A),
                                  ),
                                  onPressed: () {
                                    _openEditTransactionDialog(
                                      context: context,
                                      adminService: adminService,
                                      uid: uid,
                                      txId: txId,
                                      tx: tx,
                                    );
                                  },
                                ),

                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: "Delete transaction",
                                  icon: const Icon(
                                    Icons.delete_rounded,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("Delete Transaction?"),
                                        content: const Text(
                                          "Ye transaction permanently delete ho jayegi.",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text("Cancel"),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text("Delete"),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await adminService.deleteUserTransaction(
                                        uid: uid,
                                        txId: txId,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openEditTransactionDialog({
    required BuildContext context,
    required AdminService adminService,
    required String uid,
    required String txId,
    required Map<String, dynamic> tx,
  }) {
    final amountController = TextEditingController(
      text: (tx['amount'] ?? '').toString(),
    );

    final categoryController = TextEditingController(
      text: (tx['category'] ?? '').toString(),
    );

    final noteController = TextEditingController(
      text: (tx['note'] ?? '').toString(),
    );

    String mode = (tx['mode'] ?? 'Cash').toString();

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                width: 460,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1E1E2C),
                      Color(0xFF2C2C54),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          color: Color(0xFF6C63FF),
                          size: 30,
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Edit Transaction",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    _adminEditField(
                      controller: amountController,
                      label: "Amount",
                      icon: Icons.currency_rupee_rounded,
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 14),

                    _adminEditField(
                      controller: categoryController,
                      label: "Category",
                      icon: Icons.category_rounded,
                    ),

                    const SizedBox(height: 14),

                    _adminEditField(
                      controller: noteController,
                      label: "Note",
                      icon: Icons.sticky_note_2_rounded,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "Payment Mode",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _adminModeChip(
                          label: "Cash",
                          selected: mode == "Cash",
                          onTap: () => setDialogState(() => mode = "Cash"),
                        ),
                        _adminModeChip(
                          label: "UPI",
                          selected: mode == "UPI",
                          onTap: () => setDialogState(() => mode = "UPI"),
                        ),
                        _adminModeChip(
                          label: "Card",
                          selected: mode == "Card",
                          onTap: () => setDialogState(() => mode = "Card"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text(
                            "Save",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          onPressed: () async {
                            final amount = double.tryParse(
                              amountController.text.trim(),
                            );

                            final category = categoryController.text.trim();
                            final note = noteController.text.trim();

                            if (amount == null ||
                                amount <= 0 ||
                                category.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Enter valid amount and category",
                                  ),
                                ),
                              );
                              return;
                            }

                            await adminService.updateUserTransaction(
                              uid: uid,
                              txId: txId,
                              data: {
                                'amount': amount,
                                'category': category,
                                'mode': mode,
                                'note': note,
                                'updatedAt': FieldValue.serverTimestamp(),
                              },
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
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
  }
  Widget _adminEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF6C63FF),
            width: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _adminModeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF)
                : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _profileCard({
    required String name,
    required String email,
    required String uid,
    required String role,
    required String photoUrl,
    required bool isBlocked,
    required VoidCallback? onBlockToggle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF151526), Color(0xFF40407A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF40407A).withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white24,
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : "U",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 5),
                Text(
                  "UID: $uid",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Chip(
                label: Text(role.toUpperCase()),
                backgroundColor: Colors.white.withOpacity(0.16),
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: onBlockToggle,
                icon: Icon(isBlocked ? Icons.lock_open_rounded : Icons.block_rounded),
                label: Text(isBlocked ? "Unblock" : "Block"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isBlocked ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF151526),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        "No transactions found",
        style: TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}