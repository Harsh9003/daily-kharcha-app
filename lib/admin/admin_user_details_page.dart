import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/admin_service.dart';

class AdminUserDetailsPage extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> userData;

  const AdminUserDetailsPage({
    super.key,
    required this.uid,
    required this.userData,
  });

  @override
  State<AdminUserDetailsPage> createState() => _AdminUserDetailsPageState();
}

class _AdminUserDetailsPageState extends State<AdminUserDetailsPage> {
  final AdminService adminService = AdminService();
  final TextEditingController searchController = TextEditingController();
  String searchText = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151526),
        title: const Text(
          'User Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          final liveData = userSnapshot.data?.data() ?? widget.userData;
          final name = (liveData['name'] ?? 'No Name').toString();
          final email = (liveData['email'] ?? 'No Email').toString();
          final role = (liveData['role'] ?? 'user').toString();
          final photoUrl = (liveData['photoUrl'] ?? '').toString();
          final isBlocked = liveData['isBlocked'] == true;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.uid)
                .collection('transactions')
                .snapshots(),
            builder: (context, txSnapshot) {
              final allTxDocs = txSnapshot.data?.docs ?? [];

              double totalExpense = 0;
              for (final doc in allTxDocs) {
                final amount = doc.data()['amount'];
                if (amount is num) totalExpense += amount.toDouble();
              }

              final txDocs = allTxDocs.where((doc) {
                final tx = doc.data();
                final q = searchText.trim().toLowerCase();
                if (q.isEmpty) return true;

                final category = (tx['category'] ?? '').toString().toLowerCase();
                final mode = (tx['mode'] ?? '').toString().toLowerCase();
                final note = (tx['note'] ?? '').toString().toLowerCase();
                final amount = (tx['amount'] ?? '').toString().toLowerCase();
                final dateText = _formatDateTime(tx['date']).toLowerCase();

                return category.contains(q) ||
                    mode.contains(q) ||
                    note.contains(q) ||
                    amount.contains(q) ||
                    dateText.contains(q);
              }).toList();

              txDocs.sort((a, b) {
                final aDate = _dateFromValue(a.data()['date']);
                final bDate = _dateFromValue(b.data()['date']);
                return bDate.compareTo(aDate);
              });

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;

                  if (!isWide) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _leftPanel(
                            name: name,
                            email: email,
                            uid: widget.uid,
                            role: role,
                            photoUrl: photoUrl,
                            isBlocked: isBlocked,
                            totalTransactions: allTxDocs.length,
                            totalExpense: totalExpense,
                            onBlockToggle: role == 'admin'
                                ? null
                                : () async {
                                    await adminService.setUserBlocked(
                                      widget.uid,
                                      !isBlocked,
                                    );
                                  },
                          ),
                          const SizedBox(height: 18),
                          _transactionsPanel(txDocs),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 440,
                          child: _leftPanel(
                            name: name,
                            email: email,
                            uid: widget.uid,
                            role: role,
                            photoUrl: photoUrl,
                            isBlocked: isBlocked,
                            totalTransactions: allTxDocs.length,
                            totalExpense: totalExpense,
                            onBlockToggle: role == 'admin'
                                ? null
                                : () async {
                                    await adminService.setUserBlocked(
                                      widget.uid,
                                      !isBlocked,
                                    );
                                  },
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(child: _transactionsPanel(txDocs)),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _leftPanel({
    required String name,
    required String email,
    required String uid,
    required String role,
    required String photoUrl,
    required bool isBlocked,
    required int totalTransactions,
    required double totalExpense,
    required VoidCallback? onBlockToggle,
  }) {
    return Column(
      children: [
        _profileCard(
          name: name,
          email: email,
          uid: uid,
          role: role,
          photoUrl: photoUrl,
          isBlocked: isBlocked,
          onBlockToggle: onBlockToggle,
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _statTile(
                title: 'Transactions',
                value: totalTransactions.toString(),
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF40407A),
              ),
              Divider(height: 24, color: Colors.grey.shade200),
              _statTile(
                title: 'Total Expense',
                value: '₹ ${totalExpense.toStringAsFixed(0)}',
                icon: Icons.currency_rupee_rounded,
                color: Colors.green,
              ),
              Divider(height: 24, color: Colors.grey.shade200),
              _statTile(
                title: 'Status',
                value: isBlocked ? 'Blocked' : 'Active',
                icon: isBlocked ? Icons.block_rounded : Icons.verified_user_rounded,
                color: isBlocked ? Colors.redAccent : Colors.green,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _transactionsPanel(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> txDocs,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Latest Transactions',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF151526),
                  ),
                ),
              ),
              SizedBox(
                width: 330,
                child: TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => searchText = value),
                  style: const TextStyle(
                    color: Color(0xFF151526),
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search transaction, type or amount...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade600,
                    ),
                    suffixIcon: searchText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              searchController.clear();
                              setState(() => searchText = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFF6C63FF),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (txDocs.isEmpty)
            Expanded(child: Center(child: _emptyBox()))
          else
            Expanded(
              child: ListView.separated(
                itemCount: txDocs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final tx = txDocs[index].data();
                  final txId = txDocs[index].id;
                  return _transactionCard(tx: tx, txId: txId);
                },
              ),
            ),
          if (txDocs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              searchText.trim().isEmpty
                  ? 'Showing all transactions'
                  : 'Showing ${txDocs.length} matching transactions',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _transactionCard({
    required Map<String, dynamic> tx,
    required String txId,
  }) {
    final category = (tx['category'] ?? 'Unknown').toString();
    final mode = (tx['mode'] ?? 'Cash').toString();
    final note = (tx['note'] ?? '').toString();
    final amount = tx['amount'] ?? 0;
    final dateText = _formatDate(tx['date']);
    final timeText = _formatTime(tx['date']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF40407A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              color: Color(0xFF40407A),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF151526),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mode,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _metaText(Icons.calendar_today_rounded, dateText),
                    _metaText(Icons.access_time_rounded, timeText),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₹ $amount',
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(width: 14),
          IconButton(
            tooltip: 'Edit transaction',
            icon: const Icon(Icons.edit_rounded, color: Color(0xFF40407A)),
            onPressed: () {
              _openEditTransactionDialog(
                context: context,
                adminService: adminService,
                uid: widget.uid,
                txId: txId,
                tx: tx,
              );
            },
          ),
          IconButton(
            tooltip: 'Delete transaction',
            icon: const Icon(Icons.delete_rounded, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete Transaction?'),
                  content: const Text(
                    'This transaction will be permanently deleted for this user. This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await adminService.deleteUserTransaction(
                  uid: widget.uid,
                  txId: txId,
                );
              }
            },
          ),
        ],
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
            color: const Color(0xFF40407A).withOpacity(0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white24,
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 18),
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
                const SizedBox(height: 7),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'UID: $uid',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: onBlockToggle,
                icon: Icon(isBlocked ? Icons.lock_open_rounded : Icons.block_rounded),
                label: Text(isBlocked ? 'Unblock' : 'Block'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isBlocked ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
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
              const SizedBox(height: 3),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaText(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _emptyBox() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Text(
        'No transactions found',
        style: TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.w700,
        ),
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
                    colors: [Color(0xFF1E1E2C), Color(0xFF2C2C54)],
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
                          'Edit Transaction',
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
                      label: 'Amount',
                      icon: Icons.currency_rupee_rounded,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    _adminEditField(
                      controller: categoryController,
                      label: 'Category',
                      icon: Icons.category_rounded,
                    ),
                    const SizedBox(height: 14),
                    _adminEditField(
                      controller: noteController,
                      label: 'Note',
                      icon: Icons.sticky_note_2_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Payment Mode',
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
                          label: 'Cash',
                          selected: mode == 'Cash',
                          onTap: () => setDialogState(() => mode = 'Cash'),
                        ),
                        _adminModeChip(
                          label: 'UPI',
                          selected: mode == 'UPI',
                          onTap: () => setDialogState(() => mode = 'UPI'),
                        ),
                        _adminModeChip(
                          label: 'Card',
                          selected: mode == 'Card',
                          onTap: () => setDialogState(() => mode = 'Card'),
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
                            'Cancel',
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
                            'Save',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          onPressed: () async {
                            final amount = double.tryParse(
                              amountController.text.trim(),
                            );

                            final category = categoryController.text.trim();
                            final note = noteController.text.trim();

                            if (amount == null || amount <= 0 || category.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter valid amount and category'),
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

                            if (context.mounted) Navigator.pop(context);
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
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.6),
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
          color: selected ? const Color(0xFF6C63FF) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF6C63FF) : Colors.white.withOpacity(0.15),
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _dateFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDate(dynamic value) {
    final date = _dateFromValue(value);
    if (date.millisecondsSinceEpoch == 0) return 'No date';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(dynamic value) {
    final date = _dateFromValue(value);
    if (date.millisecondsSinceEpoch == 0) return 'No time';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDateTime(dynamic value) {
    return '${_formatDate(value)} ${_formatTime(value)}';
  }
}
