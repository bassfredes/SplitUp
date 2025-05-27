import 'package:cloud_firestore/cloud_firestore.dart'; // Importación añadida

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
  final double totalExpenses; // Nuevo campo
  final int expensesCount; // Nuevo campo
  final Map<String, dynamic>? lastExpense; // Nuevo campo

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
    this.totalExpenses = 0.0, // Valor por defecto
    this.expensesCount = 0, // Valor por defecto
    this.lastExpense, // Valor por defecto
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
      participantBalances: balancesList,
      totalExpenses: (map['totalExpenses'] as num?)?.toDouble() ?? 0.0, // Parsear nuevo campo
      expensesCount: (map['expensesCount'] as num?)?.toInt() ?? 0, // Parsear nuevo campo
      lastExpense: map['lastExpense'] == null ? null : Map<String, dynamic>.from(map['lastExpense'] as Map), // Parsear nuevo campo
    );
  }

  Map<String, dynamic> toMap({bool forCache = false}) { // Añadido parámetro opcional
    Map<String, dynamic>? cacheLastExpense;
    if (lastExpense != null) {
      cacheLastExpense = Map<String, dynamic>.from(lastExpense!);
      if (forCache && cacheLastExpense['date'] is Timestamp) {
        cacheLastExpense['date'] = (cacheLastExpense['date'] as Timestamp).toDate().millisecondsSinceEpoch;
      } else if (!forCache && cacheLastExpense['date'] is int) {
        // Esto no debería ocurrir si el flujo es Firestore -> Modelo -> Cache -> Modelo
        // Pero por seguridad, si estamos convirtiendo a Firestore y la fecha es int, la convertimos a Timestamp
         cacheLastExpense['date'] = Timestamp.fromMillisecondsSinceEpoch(cacheLastExpense['date'] as int);
      }
       // Si lastExpense['date'] ya es un int (de la caché) y forCache es true, no se hace nada.
       // Si lastExpense['date'] ya es Timestamp y forCache es false, no se hace nada.
    }

    return {
      'name': name,
      'description': description,
      'participantIds': participantIds,
      'adminId': adminId,
      'roles': roles,
      'currency': currency,
      'photoUrl': photoUrl,
      'participantBalances': participantBalances,
      'totalExpenses': totalExpenses,
      'expensesCount': expensesCount,
      'lastExpense': forCache ? cacheLastExpense : lastExpense, // Usar el lastExpense procesado para caché
    };
  }
}
