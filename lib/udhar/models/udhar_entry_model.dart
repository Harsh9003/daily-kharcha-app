import 'package:cloud_firestore/cloud_firestore.dart';

class UdharEntryModel {
  final String id;
  final String name;
  final String note;
  final String type; // given / taken
  final double totalAmount;
  final double paidAmount;
  final Timestamp createdAt;

  UdharEntryModel({
    required this.id,
    required this.name,
    required this.note,
    required this.type,
    required this.totalAmount,
    required this.paidAmount,
    required this.createdAt,
  });

  double get remainingAmount => totalAmount - paidAmount;
  bool get isGiven => type == 'given';

  factory UdharEntryModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UdharEntryModel(
      id: doc.id,
      name: data['name'] ?? '',
      note: data['note'] ?? '',
      type: data['type'] ?? 'given',
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      paidAmount: (data['paidAmount'] ?? 0).toDouble(),
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}