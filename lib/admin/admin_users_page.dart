import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/admin_service.dart';
import 'admin_user_details_page.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final AdminService adminService = AdminService();
  final TextEditingController searchController = TextEditingController();
  String searchText = "";

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151526),
        title: const Text(
          "Users",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: adminService.usersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Users load failed"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs.where((doc) {
            final data = doc.data();
            final name = (data['name'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final role = (data['role'] ?? '').toString().toLowerCase();
            final uid = doc.id.toLowerCase();
            final q = searchText.toLowerCase();

            return name.contains(q) ||
                email.contains(q) ||
                role.contains(q) ||
                uid.contains(q);
          }).toList();

          users.sort((a, b) {
            final aRole = (a.data()['role'] ?? 'user').toString();
            final bRole = (b.data()['role'] ?? 'user').toString();

            if (aRole == 'admin' && bRole != 'admin') return -1;
            if (aRole != 'admin' && bRole == 'admin') return 1;
            return 0;
          });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "User Details",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF151526),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 360,
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setState(() => searchText = value.trim());
                        },
                        style: const TextStyle(
                          color: Color(0xFF151526),
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search user, email, role or UID...",
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.grey.shade600,
                          ),
                          suffixIcon: searchText.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    searchController.clear();
                                    setState(() => searchText = "");
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
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: Colors.grey.shade200),
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
              ),

              Expanded(
                child: users.isEmpty
                    ? const Center(child: Text("No users found"))
                    : GridView.builder(
                        padding: const EdgeInsets.all(18),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 430,
                          mainAxisExtent: 330,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 18,
                        ),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final doc = users[index];
                          final data = doc.data();

                          return _UserCard(
                            uid: doc.id,
                            data: data,
                            adminService: adminService,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  final AdminService adminService;

  const _UserCard({
    required this.uid,
    required this.data,
    required this.adminService,
  });

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'No Name').toString();
    final email = (data['email'] ?? 'No Email').toString();
    final role = (data['role'] ?? 'user').toString();
    final isAdmin = role == 'admin';
    final isBlocked = data['isBlocked'] == true;
    final photoUrl = (data['photoUrl'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isAdmin
              ? const Color(0xFF6C63FF).withOpacity(0.22)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: const Color(0xFF151526),
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : "U",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 12),

          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF151526),
            ),
          ),

          const SizedBox(height: 5),

          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            "UID: $uid",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Badge(
                text: role.toUpperCase(),
                color: isAdmin ? const Color(0xFF6C63FF) : Colors.blueGrey,
              ),
              const SizedBox(width: 10),
              _Badge(
                text: isBlocked ? "BLOCKED" : "ACTIVE",
                color: isBlocked ? Colors.redAccent : Colors.green,
              ),
            ],
          ),

          const Spacer(),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminUserDetailsPage(
                          uid: uid,
                          userData: data,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text("View Details"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isBlocked
                      ? Colors.red.withOpacity(0.08)
                      : Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(
                      isBlocked ? "Unblock" : "Block",
                      style: TextStyle(
                        color: isBlocked ? Colors.redAccent : Colors.green,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Switch(
                      value: !isBlocked,
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.redAccent,
                      onChanged: isAdmin
                          ? null
                          : (value) async {
                              await adminService.setUserBlocked(uid, !value);
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}