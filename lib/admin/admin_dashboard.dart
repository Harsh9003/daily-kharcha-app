import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_users_page.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151526),
        elevation: 0,
        title: const Text(
          "Daily Kharcha Admin",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          final users = snapshot.data?.docs ?? [];

          final totalUsers = users.length;

          final blockedUsers =
              users.where((e) => e.data()['isBlocked'] == true).length;

          final activeUsers = totalUsers - blockedUsers;

          final admins =
              users.where((e) => e.data()['role'] == 'admin').length;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroCard(),

                    const SizedBox(height: 18),

                    GridView.count(
                      crossAxisCount: isWide ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isWide ? 3.6 : 2.0,
                      children: [
                        _statCard(
                          "Total Users",
                          "$totalUsers",
                          Icons.people_alt_rounded,
                          const Color(0xFF40407A),
                        ),

                        _statCard(
                          "Active Users",
                          "$activeUsers",
                          Icons.verified_user_rounded,
                          Colors.green,
                        ),

                        _statCard(
                          "Blocked Users",
                          "$blockedUsers",
                          Icons.block_rounded,
                          Colors.red,
                        ),

                        _statCard(
                          "Admins",
                          "$admins",
                          Icons.admin_panel_settings_rounded,
                          Colors.orange,
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      "Admin Tools",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF151526),
                      ),
                    ),

                    const SizedBox(height: 12),

                    GridView.count(
                      crossAxisCount: isWide ? 3 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: isWide ? 4.2 : 1.7,
                      children: [
                        _toolCard(
                          context,
                          "Users",
                          "View, block and manage users",
                          Icons.people_alt_rounded,
                          const Color(0xFF40407A),
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminUsersPage(),
                            ),
                          ),
                        ),

                        _toolCard(
                          context,
                          "Notifications",
                          "Send alert to users",
                          Icons.notifications_active_rounded,
                          const Color(0xFF009688),
                          () => _comingSoon(context),
                        ),

                        _toolCard(
                          context,
                          "Transactions",
                          "Review user expenses",
                          Icons.receipt_long_rounded,
                          const Color(0xFFFF9800),
                          () => _comingSoon(context),
                        ),

                        _toolCard(
                          context,
                          "Categories",
                          "Manage user categories",
                          Icons.category_rounded,
                          const Color(0xFFE91E63),
                          () => _comingSoon(context),
                        ),

                        _toolCard(
                          context,
                          "Blocked Users",
                          "Check restricted accounts",
                          Icons.block_rounded,
                          const Color(0xFFB00020),
                          () => _comingSoon(context),
                        ),

                        _toolCard(
                          context,
                          "Analytics",
                          "App usage overview",
                          Icons.analytics_rounded,
                          const Color(0xFF3F51B5),
                          () => _comingSoon(context),
                        ),
                      ],
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

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF151526),
            Color(0xFF40407A),
          ],
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Admin Dashboard",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),

          SizedBox(height: 6),

          Text(
            "Control users, notifications, transactions and app settings from one premium admin panel.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
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
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
              size: 34,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF151526),
                  ),
                ),

                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
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
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 34,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF151526),
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "Ye feature next step me add karenge",
        ),
        backgroundColor: const Color(0xFF151526),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}