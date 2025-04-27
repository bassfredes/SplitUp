class SplitModel {
  final String userId;
  final double amount;
  final double? percent;
  final double? weight;

  SplitModel({
    required this.userId,
    required this.amount,
    this.percent,
    this.weight,
  });

  factory SplitModel.fromMap(Map<String, dynamic> map) {
    return SplitModel(
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      percent: map['percent'] != null ? (map['percent'] as num).toDouble() : null,
      weight: map['weight'] != null ? (map['weight'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'percent': percent,
      'weight': weight,
    };
  }
}
