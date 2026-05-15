import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UdharService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser!.uid;

  static CollectionReference<Map<String, dynamic>> customersRef() {
    return _firestore.collection('users').doc(_uid).collection('udharCustomers');
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamCustomers() {
    return customersRef().orderBy('updatedAt', descending: true).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamTransactions(String customerId) {
    return customersRef()
        .doc(customerId)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> addTransaction({
    required String name,
    required String phone,
    required String type, // given / taken
    required double amount,
    required String note,
    DateTime? transactionDate,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    final nameLower = cleanName.toLowerCase();

    if (cleanName.isEmpty || amount <= 0) return;

    final existing = await customersRef()
        .where('nameLower', isEqualTo: nameLower)
        .limit(1)
        .get();

    final double balanceChange = type == 'given' ? amount : -amount;
    final DateTime finalTransactionDate = transactionDate ?? DateTime.now();

    if (existing.docs.isEmpty) {
      final customerDoc = customersRef().doc();

      await customerDoc.set({
        'name': cleanName,
        'nameLower': nameLower,
        'phone': cleanPhone,
        'balance': balanceChange,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await customerDoc.collection('transactions').add({
        'type': type,
        'amount': amount,
        'note': note.trim(),
        'createdAt': Timestamp.fromDate(finalTransactionDate),
        'selectedDate': Timestamp.fromDate(finalTransactionDate),
      });
    } else {
      final customerDoc = existing.docs.first.reference;

      await customerDoc.update({
        'balance': FieldValue.increment(balanceChange),
        'phone': cleanPhone.isNotEmpty ? cleanPhone : existing.docs.first.data()['phone'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await customerDoc.collection('transactions').add({
        'type': type,
        'amount': amount,
        'note': note.trim(),
        'createdAt': Timestamp.fromDate(finalTransactionDate),
        'selectedDate': Timestamp.fromDate(finalTransactionDate),
      });
    }
  }
  static Future<void> addTransactionToCustomer({
    required String customerId,
    required String type, // given / taken
    required double amount,
    required String note,
    DateTime? transactionDate,
  }) async {
    if (amount <= 0) return;

    final customerDoc = customersRef().doc(customerId);

    final double balanceChange = type == 'given' ? amount : -amount;
    final DateTime finalTransactionDate = transactionDate ?? DateTime.now();

    await customerDoc.update({
      'balance': FieldValue.increment(balanceChange),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await customerDoc.collection('transactions').add({
      'type': type,
      'amount': amount,
      'note': note.trim(),
      'createdAt': Timestamp.fromDate(finalTransactionDate),
      'selectedDate': Timestamp.fromDate(finalTransactionDate),
    });
  }

  static Future<void> deleteTransactionFromCustomer({
    required String customerId,
    required String transactionId,
    required String type,
    required double amount,
  }) async {
    final customerDoc = customersRef().doc(customerId);
    final txDoc = customerDoc.collection('transactions').doc(transactionId);

    final double reverseBalance = type == 'given' ? -amount : amount;

    await customerDoc.update({
      'balance': FieldValue.increment(reverseBalance),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await txDoc.delete();
  }
  static Future<void> deleteCustomer(String customerId) async {
    final tx = await customersRef().doc(customerId).collection('transactions').get();

    for (final doc in tx.docs) {
      await doc.reference.delete();
    }

    await customersRef().doc(customerId).delete();
  }
  static Future<void> updateCustomer({
    required String customerId,
    required String name,
    required String phone,
  }) async {
    final cleanName = name.trim();

    await customersRef().doc(customerId).update({
      'name': cleanName,
      'nameLower': cleanName.toLowerCase(),
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  static Future<void> updateTransactionFromCustomer({
    required String customerId,
    required String transactionId,
    required String oldType,
    required double oldAmount,
    required String newType,
    required double newAmount,
    required String note,
  }) async {
    final customerDoc = customersRef().doc(customerId);
    final txDoc = customerDoc.collection('transactions').doc(transactionId);

    final double oldBalanceEffect = oldType == 'given' ? oldAmount : -oldAmount;
    final double newBalanceEffect = newType == 'given' ? newAmount : -newAmount;
    final double balanceDifference = newBalanceEffect - oldBalanceEffect;

    await customerDoc.update({
      'balance': FieldValue.increment(balanceDifference),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await txDoc.update({
      'type': newType,
      'amount': newAmount,
      'note': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}