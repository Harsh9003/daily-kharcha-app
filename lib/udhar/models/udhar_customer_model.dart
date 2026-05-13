import 'package:cloud_firestore/cloud_firestore.dart';

class UdharCustomerModel {
  final String id;
  final String name;
  final String phone;
  final double balance;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  UdharCustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get youWillReceive => balance > 0;
  bool get youHaveToPay => balance < 0;

  factory UdharCustomerModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UdharCustomerModel(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      balance: ((data['balance'] ?? 0) as num).toDouble(),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }
}