import 'package:cloud_firestore/cloud_firestore.dart';

class RecycleBinService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _transactionsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('transactions');
  }

  static CollectionReference<Map<String, dynamic>> _udharCustomersRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('udharCustomers');
  }

  static CollectionReference<Map<String, dynamic>> _recycleBinRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('recycleBin');
  }

  static DateTime _safeDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static double _safeDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static Future<void> moveTransactionToRecycleBin({
    required String uid,
    required Map<String, dynamic> transaction,
  }) async {
    final String? transactionId = transaction['id']?.toString();

    if (transactionId == null || transactionId.isEmpty) {
      throw Exception("Transaction id missing");
    }

    final DateTime now = DateTime.now();
    final DateTime permanentDeleteAt = now.add(const Duration(days: 5));
    final DateTime transactionDate = _safeDate(transaction['date']);

    await _recycleBinRef(uid).doc('expense_$transactionId').set({
      'itemType': 'expense_transaction',
      'originalId': transactionId,
      'amount': transaction['amount'],
      'category': transaction['category'],
      'date': transactionDate.toIso8601String(),
      'mode': transaction['mode'] ?? 'Cash',
      'note': transaction['note'] ?? '',
      'deletedAt': Timestamp.fromDate(now),
      'permanentDeleteAt': Timestamp.fromDate(permanentDeleteAt),
    });

    await _transactionsRef(uid).doc(transactionId).delete();
  }

  static Future<void> moveUdharCustomerToRecycleBin({
    required String uid,
    required String customerId,
    required Map<String, dynamic> customer,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime permanentDeleteAt = now.add(const Duration(days: 5));
    final double balance = _safeDouble(customer['balance']);

    await _recycleBinRef(uid).doc('udhar_person_$customerId').set({
      'itemType': 'udhar_person',
      'originalId': customerId,
      'name': customer['name'] ?? 'Udhar Person',
      'nameLower': customer['nameLower'] ?? (customer['name'] ?? '').toString().toLowerCase(),
      'phone': customer['phone'] ?? '',
      'balance': balance,
      'amount': balance.abs(),
      'category': (customer['name'] ?? 'Udhar Person').toString(),
      'note': balance >= 0 ? 'You will receive' : 'You have to pay',
      'date': _safeDate(customer['latestTransactionDate'] ?? customer['updatedAt'] ?? customer['createdAt']).toIso8601String(),
      'createdAt': customer['createdAt'],
      'updatedAt': customer['updatedAt'],
      'latestTransactionDate': customer['latestTransactionDate'],
      'transactions': transactions,
      'deletedAt': Timestamp.fromDate(now),
      'permanentDeleteAt': Timestamp.fromDate(permanentDeleteAt),
    });
  }

  static Future<void> moveUdharTransactionToRecycleBin({
    required String uid,
    required String customerId,
    required String customerName,
    required Map<String, dynamic> transaction,
  }) async {
    final String? transactionId = transaction['id']?.toString();

    if (transactionId == null || transactionId.isEmpty) {
      throw Exception("Udhar transaction id missing");
    }

    final DateTime now = DateTime.now();
    final DateTime permanentDeleteAt = now.add(const Duration(days: 5));
    final double amount = _safeDouble(transaction['amount']);
    final String type = (transaction['type'] ?? 'given').toString();

    await _recycleBinRef(uid).doc('udhar_tx_${customerId}_$transactionId').set({
      'itemType': 'udhar_transaction',
      'originalId': transactionId,
      'customerId': customerId,
      'customerName': customerName,
      'type': type,
      'amount': amount,
      'category': type == 'given'
          ? '$customerName - Given'
          : '$customerName - Received',
      'note': transaction['note'] ?? '',
      'date': _safeDate(transaction['selectedDate'] ?? transaction['createdAt']).toIso8601String(),
      'transactionData': transaction,
      'deletedAt': Timestamp.fromDate(now),
      'permanentDeleteAt': Timestamp.fromDate(permanentDeleteAt),
    });
  }

  static Future<List<Map<String, dynamic>>> getRecycleBinItems({
    required String uid,
  }) async {
    await cleanupOldRecycleBinItems(uid: uid);

    final snapshot = await _recycleBinRef(uid)
        .orderBy('deletedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final String itemType = (data['itemType'] ?? 'expense_transaction').toString();

      final String recycleName = (data['name'] ?? '').toString();
      final String recycleCustomerName = (data['customerName'] ?? '').toString();
      final String recycleType = (data['type'] ?? '').toString();

      String displayCategory = (data['category'] ?? '').toString();
      if (itemType == 'udhar_person' && recycleName.isNotEmpty) {
        displayCategory = recycleName;
      } else if (itemType == 'udhar_transaction' && recycleCustomerName.isNotEmpty) {
        displayCategory = recycleType == 'given'
            ? '$recycleCustomerName - Given'
            : '$recycleCustomerName - Received';
      }

      return {
        'binId': doc.id,
        'itemType': itemType,
        'id': data['originalId'] ?? doc.id,
        'originalId': data['originalId'] ?? doc.id,
        'amount': _safeDouble(data['amount']),
        'category': displayCategory,
        'date': _safeDate(data['date']),
        'mode': data['mode'] ?? 'Cash',
        'note': data['note'] ?? '',
        'name': data['name'] ?? data['customerName'] ?? '',
        'phone': data['phone'] ?? '',
        'balance': _safeDouble(data['balance']),
        'customerId': data['customerId'],
        'customerName': data['customerName'],
        'type': data['type'],
        'transactions': data['transactions'] ?? const [],
        'transactionData': data['transactionData'],
        'deletedAt': data['deletedAt'],
        'permanentDeleteAt': data['permanentDeleteAt'],
      };
    }).toList();
  }

  static Future<Map<String, dynamic>> restoreTransaction({
    required String uid,
    required Map<String, dynamic> recycleItem,
  }) async {
    final String itemType = (recycleItem['itemType'] ?? 'expense_transaction').toString();

    if (itemType == 'udhar_person') {
      await restoreUdharCustomer(uid: uid, recycleItem: recycleItem);
      return recycleItem;
    }

    if (itemType == 'udhar_transaction') {
      await restoreUdharTransaction(uid: uid, recycleItem: recycleItem);
      return recycleItem;
    }

    final String binId = recycleItem['binId'].toString();
    final String originalId = recycleItem['id'].toString();

    final restoredData = {
      'amount': recycleItem['amount'],
      'category': recycleItem['category'],
      'date': (recycleItem['date'] as DateTime).toIso8601String(),
      'mode': recycleItem['mode'] ?? 'Cash',
      'note': recycleItem['note'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'restoredAt': FieldValue.serverTimestamp(),
    };

    await _transactionsRef(uid).doc(originalId).set(restoredData);
    await _recycleBinRef(uid).doc(binId).delete();

    return {
      'id': originalId,
      'amount': recycleItem['amount'],
      'category': recycleItem['category'],
      'date': recycleItem['date'],
      'mode': recycleItem['mode'] ?? 'Cash',
      'note': recycleItem['note'] ?? '',
    };
  }

  static Future<void> restoreUdharCustomer({
    required String uid,
    required Map<String, dynamic> recycleItem,
  }) async {
    final String binId = recycleItem['binId'].toString();
    final String customerId = recycleItem['id'].toString();
    final DateTime restoredDate = _safeDate(recycleItem['date']);

    final customerRef = _udharCustomersRef(uid).doc(customerId);

    await customerRef.set({
      'name': recycleItem['name'] ?? 'Udhar Person',
      'nameLower': (recycleItem['name'] ?? 'Udhar Person').toString().toLowerCase(),
      'phone': recycleItem['phone'] ?? '',
      'balance': _safeDouble(recycleItem['balance']),
      'createdAt': recycleItem['createdAt'] ?? Timestamp.fromDate(restoredDate),
      'updatedAt': Timestamp.fromDate(restoredDate),
      'latestTransactionDate': Timestamp.fromDate(restoredDate),
      'restoredAt': FieldValue.serverTimestamp(),
    });

    final rawTransactions = recycleItem['transactions'];
    if (rawTransactions is List) {
      for (final rawTx in rawTransactions) {
        if (rawTx is! Map) continue;
        final tx = Map<String, dynamic>.from(rawTx);
        final String txId = (tx['id'] ?? '').toString();
        tx.remove('id');
        tx['restoredAt'] = FieldValue.serverTimestamp();

        if (txId.isNotEmpty) {
          await customerRef.collection('transactions').doc(txId).set(tx);
        } else {
          await customerRef.collection('transactions').add(tx);
        }
      }
    }

    await _recycleBinRef(uid).doc(binId).delete();
  }

  static Future<void> restoreUdharTransaction({
    required String uid,
    required Map<String, dynamic> recycleItem,
  }) async {
    final String binId = recycleItem['binId'].toString();
    final String transactionId = recycleItem['id'].toString();
    final String customerId = (recycleItem['customerId'] ?? '').toString();

    if (customerId.isEmpty) {
      throw Exception('Customer id missing for Udhar transaction restore');
    }

    final customerRef = _udharCustomersRef(uid).doc(customerId);
    final customerSnapshot = await customerRef.get();

    if (!customerSnapshot.exists) {
      throw Exception('Please restore the Udhar person before restoring this transaction.');
    }

    final Map<String, dynamic> txData = recycleItem['transactionData'] is Map
        ? Map<String, dynamic>.from(recycleItem['transactionData'] as Map)
        : <String, dynamic>{};

    final String type = (txData['type'] ?? recycleItem['type'] ?? 'given').toString();
    final double amount = _safeDouble(txData['amount'] ?? recycleItem['amount']);
    final double balanceChange = type == 'given' ? amount : -amount;
    final DateTime txDate = _safeDate(txData['selectedDate'] ?? txData['createdAt'] ?? recycleItem['date']);

    txData.remove('id');
    txData['type'] = type;
    txData['amount'] = amount;
    txData['createdAt'] = txData['createdAt'] ?? Timestamp.fromDate(txDate);
    txData['selectedDate'] = txData['selectedDate'] ?? Timestamp.fromDate(txDate);
    txData['restoredAt'] = FieldValue.serverTimestamp();

    await customerRef.collection('transactions').doc(transactionId).set(txData);
    await customerRef.update({
      'balance': FieldValue.increment(balanceChange),
      'updatedAt': Timestamp.fromDate(txDate),
      'latestTransactionDate': Timestamp.fromDate(txDate),
    });

    await _recycleBinRef(uid).doc(binId).delete();
  }

  static Future<void> permanentDelete({
    required String uid,
    required String binId,
  }) async {
    await _recycleBinRef(uid).doc(binId).delete();
  }

  static Future<void> cleanupOldRecycleBinItems({
    required String uid,
  }) async {
    final DateTime limitDate = DateTime.now().subtract(const Duration(days: 5));

    final snapshot = await _recycleBinRef(uid)
        .where('deletedAt', isLessThanOrEqualTo: Timestamp.fromDate(limitDate))
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  static Future<void> deleteAllRecycleBinItems({
    required String uid,
  }) async {
    final snapshot = await _recycleBinRef(uid).get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
