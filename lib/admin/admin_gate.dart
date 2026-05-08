import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_dashboard.dart';

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});

  Future<bool> isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return doc.data()?['role'] == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      body: FutureBuilder<bool>(
        future: isAdmin(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.data == true) {
            return const AdminDashboard();
          }

          return const Center(
            child: Text(
              "Access Denied",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }
}