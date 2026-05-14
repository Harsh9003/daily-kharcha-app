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
  final searchController = TextEditingController();

  String targetType = "all";
  String selectedUserId = "";
  bool isScheduled = false;
  DateTime? scheduledAt;

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> sendNotification() async {
    final title = titleController.text.trim();
    final body = bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both a title and a message.")),
      );
      return;
    }

    if (targetType == "single" && selectedUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a user before creating the notification.")),
      );
      return;
    }

    if (isScheduled && scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a date and time for the scheduled notification.")),
      );
      return;
    }

    if (isScheduled && scheduledAt!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a future date and time.")),
      );
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final notificationRef = firestore.collection('notifications').doc();
    final pushQueueRef = firestore.collection('notification_push_queue').doc();
    final wasScheduled = isScheduled;
    final scheduledTimestamp = wasScheduled ? Timestamp.fromDate(scheduledAt!) : null;
    final targetUserId = targetType == "single" ? selectedUserId : null;

    final notificationData = {
      'title': title,
      'body': body,
      'targetType': targetType,
      'targetUserId': targetUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'scheduledAt': scheduledTimestamp,
      'status': wasScheduled ? 'scheduled' : 'created',

      // FCM delivery fields. A Firebase Cloud Function should watch this
      // notification or the notification_push_queue document and send the
      // actual push notification to saved user FCM tokens.
      'pushEnabled': true,
      'pushStatus': wasScheduled ? 'scheduled' : 'pending',
      'pushRequestedAt': FieldValue.serverTimestamp(),
    };

    final pushQueueData = {
      'notificationId': notificationRef.id,
      'title': title,
      'body': body,
      'targetType': targetType,
      'targetUserId': targetUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'scheduledAt': scheduledTimestamp,
      'status': wasScheduled ? 'scheduled' : 'pending',
      'source': 'admin_panel',
      'type': 'admin_notification',
      'data': {
        'notificationId': notificationRef.id,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'screen': 'notifications',
      },
    };

    final batch = firestore.batch();
    batch.set(notificationRef, notificationData);
    batch.set(pushQueueRef, pushQueueData);
    await batch.commit();

    titleController.clear();
    bodyController.clear();

    setState(() {
      isScheduled = false;
      scheduledAt = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasScheduled ? "Notification scheduled successfully." : "Notification created successfully."),
        ),
      );
    }
  }

  Future<void> pickScheduleDateTime() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: scheduledAt ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: scheduledAt != null
          ? TimeOfDay.fromDateTime(scheduledAt!)
          : TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    final dateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      scheduledAt = dateTime;
    });
  }

  String formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : dateTime.hour == 0
            ? 12
            : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} • $hour:$minute $amPm";
  }

  Future<void> deleteNotification(String notificationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete notification?"),
        content: const Text("This notification will be permanently deleted for all users. This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notification deleted")),
      );
    }
  }

  Future<void> deleteAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete all notifications?"),
        content: const Text(
          "All notifications will be permanently deleted for every user. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete All", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final snapshot = await FirebaseFirestore.instance.collection('notifications').get();

    if (snapshot.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("There are no notifications to delete.")),
        );
      }
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All notifications have been deleted successfully.")),
      );
    }
  }

  Future<void> openEditNotificationDialog({
    required String notificationId,
    required String oldTitle,
    required String oldBody,
  }) async {
    final editTitleController = TextEditingController(text: oldTitle);
    final editBodyController = TextEditingController(text: oldBody);

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Notification"),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editTitleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: editBodyController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Message",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Update"),
          ),
        ],
      ),
    );

    if (shouldUpdate != true) {
      editTitleController.dispose();
      editBodyController.dispose();
      return;
    }

    final newTitle = editTitleController.text.trim();
    final newBody = editBodyController.text.trim();

    editTitleController.dispose();
    editBodyController.dispose();

    if (newTitle.isEmpty || newBody.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter both a title and a message.")),
        );
      }
      return;
    }

    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({
      'title': newTitle,
      'body': newBody,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notification updated successfully.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF151526),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1050;

          if (isWide) {
            final availableHistoryWidth = constraints.maxWidth - 472;
            final historyWidth = availableHistoryWidth > 920
                ? 920.0
                : availableHistoryWidth;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 440, child: _composeCard(compact: true)),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: historyWidth,
                    height: constraints.maxHeight - 32,
                    child: _historyPanel(scrollOnlyList: true),
                  ),
                  const Spacer(),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _composeCard(compact: false),
                const SizedBox(height: 16),
                _historyPanel(scrollOnlyList: false),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _composeCard({required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151526), Color(0xFF35356D)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF35356D).withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Send Notification",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Create or schedule user alerts",
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _darkField(titleController, "Title"),
          const SizedBox(height: 12),
          _darkField(bodyController, "Message", maxLines: compact ? 3 : 4),
          const SizedBox(height: 12),
          _targetSelector(),
          if (targetType == "single") ...[
            const SizedBox(height: 12),
            _userDropdown(),
          ],
          const SizedBox(height: 12),
          _scheduleBox(compact: compact),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: sendNotification,
              icon: Icon(isScheduled ? Icons.schedule_send_rounded : Icons.send_rounded),
              label: Text(
                isScheduled ? "Schedule Notification" : "Create Notification",
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
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
        isDense: true,
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF8E87FF), width: 1.5),
        ),
      ),
    );
  }

  Widget _targetSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(child: _targetChip("All Users", "all")),
          const SizedBox(width: 6),
          Expanded(child: _targetChip("Single User", "single")),
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
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6C63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w900,
              fontSize: 13,
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
          isExpanded: true,
          dropdownColor: const Color(0xFF2C2C54),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            isDense: true,
            labelText: "Select User",
            labelStyle: const TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFF8E87FF), width: 1.5),
            ),
          ),
          items: users.map((doc) {
            final data = doc.data();
            final name = (data['name'] ?? 'No Name').toString();
            final email = (data['email'] ?? 'No Email').toString();

            return DropdownMenuItem(
              value: doc.id,
              child: Text(
                "$name • $email",
                overflow: TextOverflow.ellipsis,
              ),
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

  Widget _scheduleBox({required bool compact}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isScheduled ? Icons.event_available_rounded : Icons.schedule_rounded,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Schedule",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
              Switch(
                value: isScheduled,
                activeColor: const Color(0xFF8E87FF),
                onChanged: (value) {
                  setState(() {
                    isScheduled = value;
                    if (!value) scheduledAt = null;
                  });
                },
              ),
            ],
          ),
          if (isScheduled) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: pickScheduleDateTime,
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text(
                  scheduledAt == null ? "Pick date & time" : formatDateTime(scheduledAt!),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.18)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyPanel({required bool scrollOnlyList}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: scrollOnlyList ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _historyHeader(),
          const SizedBox(height: 12),
          _searchBar(),
          const SizedBox(height: 12),
          scrollOnlyList
              ? Expanded(child: _historyList(scrollable: true))
              : _historyList(scrollable: false),
        ],
      ),
    );
  }

  Widget _historyHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.history_rounded, color: Color(0xFF6C63FF)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Notification History",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF151526),
                ),
              ),
              SizedBox(height: 2),
              Text(
                "Search, edit or delete alerts",
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: deleteAllNotifications,
          icon: const Icon(Icons.delete_sweep_rounded, size: 18),
          label: const Text("Delete All"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: searchController,
      onChanged: (_) => setState(() {}),
      cursorColor: const Color(0xFF6C63FF),
      style: const TextStyle(
        color: Color(0xFF111827),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: "Search title, message, target or status...",
        hintStyle: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Color(0xFF8B90A0),
        ),
        suffixIcon: searchController.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  searchController.clear();
                  setState(() {});
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF8B90A0),
                ),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE6E9F2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE6E9F2)),
        ),
      ),
    );
  }

  Widget _historyList({required bool scrollable}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final query = searchController.text.trim().toLowerCase();
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final title = (data['title'] ?? '').toString().toLowerCase();
          final body = (data['body'] ?? '').toString().toLowerCase();
          final target = (data['targetType'] ?? '').toString().toLowerCase();
          final status = (data['status'] ?? '').toString().toLowerCase();
          return query.isEmpty ||
              title.contains(query) ||
              body.contains(query) ||
              target.contains(query) ||
              status.contains(query);
        }).toList();

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              searchController.text.trim().isEmpty
                  ? "No notifications yet"
                  : "No matching notifications found",
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w800),
            ),
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          shrinkWrap: !scrollable,
          physics: scrollable
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data();

            final title = (data['title'] ?? '').toString();
            final body = (data['body'] ?? '').toString();
            final target = (data['targetType'] ?? 'all').toString();
            final status = (data['status'] ?? 'created').toString();
            final scheduledTimestamp = data['scheduledAt'];
            final scheduledDate = scheduledTimestamp is Timestamp
                ? scheduledTimestamp.toDate()
                : null;

            return _notificationTile(
              notificationId: docs[index].id,
              title: title,
              body: body,
              target: target,
              status: status,
              scheduledDate: scheduledDate,
            );
          },
        );
      },
    );
  }

  Widget _notificationTile({
    required String notificationId,
    required String title,
    required String body,
    required String target,
    required String status,
    required DateTime? scheduledDate,
  }) {
    final isScheduledNotification = status == 'scheduled';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFF),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE9ECF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (isScheduledNotification ? const Color(0xFF6C63FF) : const Color(0xFF009688)).withOpacity(0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isScheduledNotification ? Icons.schedule_send_rounded : Icons.notifications_active_rounded,
              color: isScheduledNotification ? const Color(0xFF6C63FF) : const Color(0xFF009688),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF151526),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  children: [
                    _miniInfo(
                      Icons.group_rounded,
                      target == 'all' ? 'All Users' : 'Single User',
                    ),
                    if (scheduledDate != null)
                      _miniInfo(Icons.event_rounded, formatDateTime(scheduledDate)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: "Edit",
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () {
                  openEditNotificationDialog(
                    notificationId: notificationId,
                    oldTitle: title,
                    oldBody: body,
                  );
                },
                icon: const Icon(Icons.edit_rounded, color: Color(0xFFB993FF), size: 20),
              ),
              IconButton(
                tooltip: "Delete",
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () => deleteNotification(notificationId),
                icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isScheduledStatus = status == 'scheduled';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isScheduledStatus ? const Color(0xFF6C63FF) : const Color(0xFF009688)).withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isScheduledStatus ? "Scheduled" : "Created",
        style: TextStyle(
          color: isScheduledStatus ? const Color(0xFF6C63FF) : const Color(0xFF009688),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
