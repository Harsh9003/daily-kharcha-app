import 'package:cloud_firestore/cloud_firestore.dart';

class RecycleBinService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _transactionsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('transactions');
  }

  static CollectionReference<Map<String, dynamic>> _recycleBinRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('recycleBin');
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

    await _recycleBinRef(uid).doc(transactionId).set({
      'originalId': transactionId,
      'amount': transaction['amount'],
      'category': transaction['category'],
      'date': (transaction['date'] as DateTime).toIso8601String(),
      'mode': transaction['mode'] ?? 'Cash',
      'note': transaction['note'] ?? '',
      'deletedAt': Timestamp.fromDate(now),
      'permanentDeleteAt': Timestamp.fromDate(permanentDeleteAt),
    });

    await _transactionsRef(uid).doc(transactionId).delete();
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

      return {
        'binId': doc.id,
        'id': data['originalId'] ?? doc.id,
        'amount': (data['amount'] as num).toDouble(),
        'category': data['category'] ?? '',
        'date': DateTime.parse(data['date']),
        'mode': data['mode'] ?? 'Cash',
        'note': data['note'] ?? '',
        'deletedAt': data['deletedAt'],
        'permanentDeleteAt': data['permanentDeleteAt'],
      };
    }).toList();
  }

  static Future<Map<String, dynamic>> restoreTransaction({
    required String uid,
    required Map<String, dynamic> recycleItem,
  }) async {
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