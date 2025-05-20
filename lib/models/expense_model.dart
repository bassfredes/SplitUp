import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final DateTime date;
  final List<String> participantIds;
  final List<Map<String, dynamic>> payers; // [{userId, amount}]
  final String createdBy;
  final String? category;
  final List<String>? attachments;
  final String splitType; // equal, fixed, percent, weight
  final List<Map<String, dynamic>>? customSplits; // [{userId, amount/percent/weight}]
  final bool isRecurring;
  final String? recurringRule;
  final bool isLocked;
  final String currency;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.date,
    required this.participantIds,
    required this.payers,
    required this.createdBy,
    this.category,
    this.attachments,
    required this.splitType,
    this.customSplits,
    this.isRecurring = false,
    this.recurringRule,
    this.isLocked = false,
    this.currency = 'CLP',
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    return ExpenseModel(
      id: id,
      groupId: map['groupId'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: map['date'] is Timestamp
          ? (map['date'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      participantIds: List<String>.from(map['participantIds'] ?? []),
      payers: (map['payers'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      createdBy: map['createdBy'] ?? '',
      category: map['category'],
      attachments: map['attachments'] != null ? List<String>.from(map['attachments']) : null,
      splitType: map['splitType'] ?? 'equal',
      customSplits: map['customSplits'] != null
          ? (map['customSplits'] as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : null,
      isRecurring: map['isRecurring'] ?? false,
      recurringRule: map['recurringRule'],
      isLocked: map['isLocked'] ?? false,
      currency: map['currency'] ?? 'CLP',
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'participantIds': participantIds,
      'payers': payers,
      'createdBy': createdBy,
      'splitType': splitType,
      'isRecurring': isRecurring,
      'isLocked': isLocked,
      'currency': currency,
    };
    if (category != null) map['category'] = category;
    if (attachments != null) map['attachments'] = attachments;
    if (customSplits != null) map['customSplits'] = customSplits;
    if (recurringRule != null) map['recurringRule'] = recurringRule;
    return map;
  }

  ExpenseModel copyWith({
    String? id,
    String? groupId,
    String? description,
    double? amount,
    DateTime? date,
    List<String>? participantIds,
    List<Map<String, dynamic>>? payers,
    String? createdBy,
    String? category,
    List<String>? attachments,
    String? splitType,
    List<Map<String, dynamic>>? customSplits,
    bool? isRecurring,
    String? recurringRule,
    bool? isLocked,
    String? currency,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      participantIds: participantIds ?? this.participantIds,
      payers: payers ?? this.payers,
      createdBy: createdBy ?? this.createdBy,
      category: category ?? this.category,
      attachments: attachments ?? this.attachments,
      splitType: splitType ?? this.splitType,
      customSplits: customSplits ?? this.customSplits,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringRule: recurringRule ?? this.recurringRule,
      isLocked: isLocked ?? this.isLocked,
      currency: currency ?? this.currency,
    );
  }
}
