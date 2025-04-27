import 'package:cloud_firestore/cloud_firestore.dart';

class SettlementModel {
  final String id;
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final DateTime date;
  final String? note;
  final String status; // pending, confirmed, reverted
  final String createdBy;

  SettlementModel({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.date,
    this.note,
    required this.status,
    required this.createdBy,
  });

  factory SettlementModel.fromMap(Map<String, dynamic> map, String id) {
    return SettlementModel(
      id: id,
      groupId: map['groupId'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'],
      status: map['status'] ?? 'pending',
      createdBy: map['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
      'status': status,
      'createdBy': createdBy,
    };
  }
}
