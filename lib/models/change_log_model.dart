import 'package:cloud_firestore/cloud_firestore.dart';

class ChangeLogModel {
  final String id;
  final String actionType; // create, update, delete, etc.
  final String userId;
  final String entityType; // expense, group, settlement, user
  final String entityId;
  final DateTime date;
  final String? details;

  ChangeLogModel({
    required this.id,
    required this.actionType,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.date,
    this.details,
  });

  factory ChangeLogModel.fromMap(Map<String, dynamic> map, String id) {
    return ChangeLogModel(
      id: id,
      actionType: map['actionType'] ?? '',
      userId: map['userId'] ?? '',
      entityType: map['entityType'] ?? '',
      entityId: map['entityId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      details: map['details'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actionType': actionType,
      'userId': userId,
      'entityType': entityType,
      'entityId': entityId,
      'date': Timestamp.fromDate(date),
      'details': details,
    };
  }
}
