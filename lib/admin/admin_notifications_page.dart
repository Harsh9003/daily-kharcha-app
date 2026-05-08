import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();

  String targetType = "all";
  String selectedUserId = "";

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<void> sendNotification() async {
    final title = titleController.text.trim();
    final body = bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title aur message dono likho")),
      );
      return;
    }

    if (targetType == "single" && selectedUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User select karo")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('notifications').add({
      'title': title,
      'body': body,
      'targetType': targetType,
      'targetUserId': targetType == "single" ? selectedUserId : null,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'created',
    });

    titleController.clear();
    bodyController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notification created")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151526),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _composeCard(),
            const SizedBox(height: 22),
            const Text(
              "Notification History",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF151526),
              ),
            ),
            const SizedBox(height: 12),
            _historyList(),
          ],
        ),
      ),
    );
  }

  Widget _composeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF151526), Color(0xFF40407A)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF40407A).withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Send Notification",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Create app notification for all users or a specific user.",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),

              if (isWide)
                Row(
                  children: [
                    Expanded(child: _darkField(titleController, "Title")),
                    const SizedBox(width: 14),
                    Expanded(child: _targetSelector()),
                  ],
                )
              else ...[
                _darkField(titleController, "Title"),
                const SizedBox(height: 14),
                _targetSelector(),
              ],

              const SizedBox(height: 14),

              _darkField(
                bodyController,
                "Message",
                maxLines: 4,
              ),

              if (targetType == "single") ...[
                const SizedBox(height: 14),
                _userDropdown(),
              ],

              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: sendNotification,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text(
                    "Create Notification",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _darkField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
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

  Widget _targetSelector() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _targetChip("All Users", "all"),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _targetChip("Single User", "single"),
          ),
        ],
      ),
    );
  }

  Widget _targetChip(String label, String value) {
    final selected = targetType == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          targetType = value;
          if (value == "all") selectedUserId = "";
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6C63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _userDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        final users = snapshot.data?.docs ?? [];

        return DropdownButtonFormField<String>(
          value: selectedUserId.isEmpty ? null : selectedUserId,
          dropdownColor: const Color(0xFF2C2C54),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Select User",
            labelStyle: const TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFF6C63FF), width: 1.6),
            ),
          ),
          items: users.map((doc) {
            final data = doc.data();
            final name = (data['name'] ?? 'No Name').toString();
            final email = (data['email'] ?? 'No Email').toString();

            return DropdownMenuItem(
              value: doc.id,
              child: Text("$name • $email"),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedUserId = value ?? "";
            });
          },
        );
      },
    );
  }

  Widget _historyList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              "No notifications yet",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700),
            ),
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data();

            final title = (data['title'] ?? '').toString();
            final body = (data['body'] ?? '').toString();
            final target = (data['targetType'] ?? 'all').toString();
            final status = (data['status'] ?? 'created').toString();

            return Container(
              padding: const EdgeInsets.all(16),
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF009688).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFF009688),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF151526),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Target: ${target == 'all' ? 'All Users' : 'Single User'} • Status: $status",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}