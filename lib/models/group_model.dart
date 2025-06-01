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
  final DateTime createdAt; // Nuevo campo
  final DateTime updatedAt; // Nuevo campo

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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(), // Inicializar aquí
       updatedAt = updatedAt ?? DateTime.now(); // Inicializar aquí

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

    Map<String, dynamic>? parsedLastExpense;
    if (map['lastExpense'] != null && map['lastExpense'] is Map) {
      parsedLastExpense = Map<String, dynamic>.from(map['lastExpense'] as Map);
      if (parsedLastExpense['date'] is int) {
        // Convertir int (caché) a DateTime para el modelo
        parsedLastExpense['date'] = DateTime.fromMillisecondsSinceEpoch(parsedLastExpense['date'] as int);
      } else if (parsedLastExpense['date'] is Timestamp) {
        // Convertir Timestamp (Firestore) a DateTime para el modelo
        parsedLastExpense['date'] = (parsedLastExpense['date'] as Timestamp).toDate();
      }
      // Si ya es DateTime o otro formato, será manejado por el constructor o podría ser un problema.
      // Por ahora, solo manejamos explícitamente int y Timestamp del mapa.
    }

    DateTime parseDate(dynamic dateInput) {
      if (dateInput is Timestamp) {
        return dateInput.toDate();
      }
      if (dateInput is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateInput);
      }
      if (dateInput is String) {
        return DateTime.tryParse(dateInput) ?? DateTime.now();
      }
      return DateTime.now(); // Valor por defecto si no se puede parsear
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
      lastExpense: parsedLastExpense, // Usar el lastExpense procesado
      createdAt: parseDate(map['createdAt']), // Parsear createdAt
      updatedAt: parseDate(map['updatedAt']), // Parsear updatedAt
    );
  }

  Map<String, dynamic> toMap({bool forCache = false}) { // Añadido parámetro opcional
    Map<String, dynamic>? processedLastExpense;
    if (lastExpense != null) {
      // Aseguramos que lastExpense no sea null antes de usarlo con Map.from
      processedLastExpense = Map<String, dynamic>.from(lastExpense!);
      final dateValue = processedLastExpense['date'];

      if (forCache) {
        if (dateValue is Timestamp) {
          processedLastExpense['date'] = dateValue.toDate().millisecondsSinceEpoch;
        } else if (dateValue is DateTime) { // Added to handle DateTime for cache
          processedLastExpense['date'] = dateValue.millisecondsSinceEpoch;
        }
        // Si ya es int, no se hace nada para la caché
      } else { // for Firestore
        if (dateValue is int) {
          processedLastExpense['date'] = Timestamp.fromMillisecondsSinceEpoch(dateValue);
        } else if (dateValue is DateTime) { // Added to handle DateTime for Firestore
          processedLastExpense['date'] = Timestamp.fromDate(dateValue);
        }
        // Si ya es Timestamp, no se hace nada para Firestore
      }
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
      'lastExpense': processedLastExpense, // Usar el lastExpense procesado
      'createdAt': forCache ? createdAt.millisecondsSinceEpoch : Timestamp.fromDate(createdAt),
      'updatedAt': forCache ? updatedAt.millisecondsSinceEpoch : Timestamp.fromDate(updatedAt),
    };
  }
}
