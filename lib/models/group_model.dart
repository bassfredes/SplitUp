class GroupModel {
  final String id;
  final String name;
  final String? description;
  final List<String> participantIds;
  final String adminId;
  final List<Map<String, String>> roles; // [{uid: ..., role: ...}]
  final String currency;
  final String? photoUrl;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.participantIds,
    required this.adminId,
    required this.roles,
    this.currency = 'CLP',
    this.photoUrl,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      participantIds: List<String>.from(map['participantIds'] ?? []),
      adminId: map['adminId'] ?? '',
      roles: (map['roles'] as List<dynamic>? ?? [])
        .map((e) => Map<String, String>.from(e as Map)).toList(),
      currency: map['currency'] ?? 'CLP',
      photoUrl: map['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'participantIds': participantIds,
      'adminId': adminId,
      'roles': roles,
      'currency': currency,
      'photoUrl': photoUrl,
    };
  }
}
