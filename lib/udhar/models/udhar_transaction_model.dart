import 'package:cloud_firestore/cloud_firestore.dart';

class UdharTransactionModel {
  final String id;
  final String type; // given / taken
  final double amount;
  final String note;
  final String paymentMode;
  final Timestamp createdAt;
  final Timestamp selectedDate;

  UdharTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.note,
    required this.paymentMode,
    required this.createdAt,
    required this.selectedDate,
  });

  bool get isGiven => type == 'given';

  static Timestamp _readTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return Timestamp.fromDate(parsed);
    }
    return Timestamp.now();
  }

  factory UdharTransactionModel.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

    final createdAtValue = data['createdAt'] ?? data['selectedDate'];
    final selectedDateValue = data['selectedDate'] ?? data['createdAt'];

    return UdharTransactionModel(
      id: doc.id,
      type: (data['type'] ?? 'given').toString(),
      amount: ((data['amount'] ?? 0) as num).toDouble(),
      note: (data['note'] ?? '').toString(),
      paymentMode: (data['paymentMode'] ?? 'Cash').toString(),
      createdAt: _readTimestamp(createdAtValue),
      selectedDate: _readTimestamp(selectedDateValue),
    );
  }
}
