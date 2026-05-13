import 'package:cloud_firestore/cloud_firestore.dart';

class UdharTransactionModel {
  final String id;
  final String type; // given / taken
  final double amount;
  final String note;
  final Timestamp createdAt;

  UdharTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.note,
    required this.createdAt,
  });

  bool get isGiven => type == 'given';

  factory UdharTransactionModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UdharTransactionModel(
      id: doc.id,
      type: data['type'] ?? 'given',
      amount: ((data['amount'] ?? 0) as num).toDouble(),
      note: data['note'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}