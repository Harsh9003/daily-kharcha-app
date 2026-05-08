import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data();

    return data?['role'] == 'admin';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> usersStream() {
    return _db.collection('users').snapshots();
  }

  Future<void> setUserBlocked(String uid, bool blocked) async {
    await _db.collection('users').doc(uid).set({
      'isBlocked': blocked,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}