class GroupModel {
  final String id;
  final String name;
  final String? description;
  final List<String> participantIds;
  final String adminId;
  final List<Map<String, String>> roles; // [{uid: ..., role: ...}]
  final String currency;
  final String? photoUrl;
  // Corregido: Lista de mapas para los balances
  // Cada mapa: { 'userId': String, 'balances': Map<String, double> }
  final List<Map<String, dynamic>> participantBalances;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.participantIds,
    required this.adminId,
    required this.roles,
    this.currency = 'CLP',
    this.photoUrl,
    // Valor por defecto es una lista vacía
    this.participantBalances = const [],
  });

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    // Parsear la lista de balances
    List<Map<String, dynamic>> balancesList = [];
    if (map['participantBalances'] is List) {
      for (var item in (map['participantBalances'] as List)) {
        if (item is Map) {
          final userId = item['userId'] as String?;
          final balancesMapRaw = item['balances'];
          if (userId != null && balancesMapRaw is Map) {
            Map<String, double> currencyBalances = {};
            // No es necesario el cast a Map aquí, ya se comprobó con 'is Map'
            balancesMapRaw.forEach((currency, balance) {
              if (balance is num) {
                currencyBalances[currency as String] = balance.toDouble();
              }
            });
            // Solo añadir si el mapa de balances no está vacío
            if (currencyBalances.isNotEmpty) {
              balancesList.add({
                'userId': userId,
                'balances': currencyBalances,
              });
            }
          }
        }
      }
    }

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
      // Asignar la lista parseada
      participantBalances: balancesList,
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
      'participantBalances': participantBalances,
    };
  }
}
