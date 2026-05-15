import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/recycle_bin_service.dart';

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
    // Do not use orderBy here because older/newly migrated Udhar transactions
    // may have selectedDate but not createdAt. orderBy hides documents where
    // the ordered field is missing. We sort safely in the UI after parsing.
    return customersRef()
        .doc(customerId)
        .collection('transactions')
        .snapshots();
  }

  static Future<void> addTransaction({
    required String name,
    required String phone,
    required String type, // given / taken
    required double amount,
    required String note,
    String paymentMode = 'Cash',
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
        'createdAt': Timestamp.fromDate(finalTransactionDate),
        'updatedAt': Timestamp.fromDate(finalTransactionDate),
        'latestTransactionDate': Timestamp.fromDate(finalTransactionDate),
      });

      await customerDoc.collection('transactions').add({
        'type': type,
        'amount': amount,
        'note': note.trim(),
        'paymentMode': paymentMode,
        'createdAt': Timestamp.fromDate(finalTransactionDate),
        'selectedDate': Timestamp.fromDate(finalTransactionDate),
      });
    } else {
      final customerDoc = existing.docs.first.reference;

      await customerDoc.update({
        'balance': FieldValue.increment(balanceChange),
        'phone': cleanPhone.isNotEmpty ? cleanPhone : existing.docs.first.data()['phone'],
        'updatedAt': Timestamp.fromDate(finalTransactionDate),
        'latestTransactionDate': Timestamp.fromDate(finalTransactionDate),
      });

      await customerDoc.collection('transactions').add({
        'type': type,
        'amount': amount,
        'note': note.trim(),
        'paymentMode': paymentMode,
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
    String paymentMode = 'Cash',
    DateTime? transactionDate,
  }) async {
    if (amount <= 0) return;

    final customerDoc = customersRef().doc(customerId);

    final double balanceChange = type == 'given' ? amount : -amount;
    final DateTime finalTransactionDate = transactionDate ?? DateTime.now();

    await customerDoc.update({
      'balance': FieldValue.increment(balanceChange),
      'updatedAt': Timestamp.fromDate(finalTransactionDate),
      'latestTransactionDate': Timestamp.fromDate(finalTransactionDate),
    });

    await customerDoc.collection('transactions').add({
      'type': type,
      'amount': amount,
      'note': note.trim(),
      'paymentMode': paymentMode,
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
    final customerSnapshot = await customerDoc.get();
    final txDoc = customerDoc.collection('transactions').doc(transactionId);
    final txSnapshot = await txDoc.get();

    if (!txSnapshot.exists) return;

    final txData = txSnapshot.data() ?? <String, dynamic>{};
    txData['id'] = txSnapshot.id;

    final customerName = customerSnapshot.data()?['name']?.toString() ?? 'Udhar Person';

    await RecycleBinService.moveUdharTransactionToRecycleBin(
      uid: _uid,
      customerId: customerId,
      customerName: customerName,
      transaction: txData,
    );

    final double reverseBalance = type == 'given' ? -amount : amount;

    await customerDoc.update({
      'balance': FieldValue.increment(reverseBalance),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await txDoc.delete();
  }

  static Future<void> deleteCustomer(String customerId) async {
    final customerDoc = customersRef().doc(customerId);
    final customerSnapshot = await customerDoc.get();

    if (!customerSnapshot.exists) return;

    final customerData = customerSnapshot.data() ?? <String, dynamic>{};
    final txSnapshot = await customerDoc.collection('transactions').get();

    final transactions = txSnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    await RecycleBinService.moveUdharCustomerToRecycleBin(
      uid: _uid,
      customerId: customerId,
      customer: customerData,
      transactions: transactions,
    );

    final batch = _firestore.batch();

    for (final doc in txSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(customerDoc);

    await batch.commit();
  }
  static Future<void> updateCustomer({
    required String customerId,
    required String name,
    required String phone,
    DateTime? latestTransactionDate,
  }) async {
    final cleanName = name.trim();

    final Map<String, dynamic> updateData = {
      'name': cleanName,
      'nameLower': cleanName.toLowerCase(),
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (latestTransactionDate != null) {
      updateData['latestTransactionDate'] = Timestamp.fromDate(latestTransactionDate);
    }

    await customersRef().doc(customerId).update(updateData);
  }
  static Future<void> updateTransactionFromCustomer({
    required String customerId,
    required String transactionId,
    required String oldType,
    required double oldAmount,
    required String newType,
    required double newAmount,
    required String note,
    String? paymentMode,
    DateTime? transactionDate,
  }) async {
    final customerDoc = customersRef().doc(customerId);
    final txDoc = customerDoc.collection('transactions').doc(transactionId);

    final double oldBalanceEffect = oldType == 'given' ? oldAmount : -oldAmount;
    final double newBalanceEffect = newType == 'given' ? newAmount : -newAmount;
    final double balanceDifference = newBalanceEffect - oldBalanceEffect;

    final DateTime? finalTransactionDate = transactionDate;

    final Map<String, dynamic> customerUpdateData = {
      'balance': FieldValue.increment(balanceDifference),
      'updatedAt': finalTransactionDate != null
          ? Timestamp.fromDate(finalTransactionDate)
          : FieldValue.serverTimestamp(),
    };

    if (finalTransactionDate != null) {
      customerUpdateData['latestTransactionDate'] = Timestamp.fromDate(finalTransactionDate);
    }

    await customerDoc.update(customerUpdateData);

    final Map<String, dynamic> txUpdateData = {
      'type': newType,
      'amount': newAmount,
      'note': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (paymentMode != null && paymentMode.trim().isNotEmpty) {
      txUpdateData['paymentMode'] = paymentMode.trim();
    }

    if (finalTransactionDate != null) {
      txUpdateData['createdAt'] = Timestamp.fromDate(finalTransactionDate);
      txUpdateData['selectedDate'] = Timestamp.fromDate(finalTransactionDate);
    }

    await txDoc.update(txUpdateData);
  }
}