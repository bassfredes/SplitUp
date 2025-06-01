import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/group_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import '../models/expense_model.dart';
import '../models/settlement_model.dart';
import '../models/user_model.dart';
import 'package:clock/clock.dart';

/// Servicio para manejar el caché de datos y reducir las llamadas a Firestore
class CacheService {
  static final CacheService _instance = CacheService._internal();
  late SharedPreferences _prefs;
  final Map<String, dynamic> _memoryCache = {};
  bool _initialized = false;

  // Tiempo de expiración por defecto para la caché (10 minutos)
  static const Duration defaultExpiration = Duration(minutes: 10);

  // Singleton
  factory CacheService() => _instance;

  CacheService._internal();

  // Getter para verificar si el servicio está inicializado
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  // Guarda datos en la caché (tanto en memoria como persistente)
  Future<void> setData(String key, dynamic data, {Duration? expiration}) async {
    await init();
    final expiresAt = clock.now().add(expiration ?? defaultExpiration).millisecondsSinceEpoch;
    
    // Prepara los datos para la caché, convirtiendo Timestamps si es necesario.
    dynamic dataToCache;
    if (data is GroupModel) {
      dataToCache = data.toMap(forCache: true);
    } else if (data is List<GroupModel>) {
      dataToCache = data.map((g) => g.toMap(forCache: true)).toList();
    } else if (data is ExpenseModel) {
      dataToCache = data.toMap(forCache: true);
    } else if (data is List<ExpenseModel>) {
      dataToCache = data.map((e) => e.toMap(forCache: true)).toList();
    } else {
      dataToCache = _convertTimestamps(data); // Usar función de ayuda para otros tipos
    }

    final cachePayload = {
      'data': dataToCache,
      'expiresAt': expiresAt,
    };
    
    _memoryCache[key] = cachePayload;
    
    // Guardar en SharedPreferences
    // Solo se guardan Map o List (que ahora contienen datos JSON-compatibles)
    // u otros tipos primitivos que jsonEncode maneja.
    if (dataToCache is Map || dataToCache is List || dataToCache is String || dataToCache is bool || dataToCache is int || dataToCache is double || dataToCache == null) {
      await _prefs.setString(key, jsonEncode(cachePayload));
    } else {
      // Si después de la conversión sigue sin ser un tipo básico, podría haber un problema.
      // Por ahora, intentamos codificarlo directamente, pero esto podría fallar si _convertTimestamps no lo manejó.
      print('Advertencia: Intentando guardar un tipo no primitivo en caché para la clave $key: ${dataToCache.runtimeType}');
      try {
        await _prefs.setString(key, jsonEncode(cachePayload));
      } catch (e) {
        print('Error al codificar datos complejos para caché ($key): $e. El tipo era ${dataToCache.runtimeType}');
      }
    }
  }

  // Obtiene datos de la caché (primero de memoria, luego de persistente)
  dynamic getData(String key, {bool bypassExpiration = false}) {
    if (!_initialized) return null;
    
    // Verificar memoria primero
    if (_memoryCache.containsKey(key)) {
      final cachedData = _memoryCache[key];
      final expiresAt = cachedData['expiresAt'] as int;
      
      if (bypassExpiration || expiresAt > clock.now().millisecondsSinceEpoch) {
        return cachedData['data'];
      } else {
        _memoryCache.remove(key); // Remover si expiró
      }
    }
    
    // Si no está en memoria o ha expirado, verificar SharedPreferences
    final persistentData = _prefs.getString(key);
    if (persistentData != null) {
      try {
        final decodedData = jsonDecode(persistentData);
        final expiresAt = decodedData['expiresAt'] as int;
        
        if (bypassExpiration || expiresAt > clock.now().millisecondsSinceEpoch) {
          // Guardar en memoria para futuros accesos
          _memoryCache[key] = decodedData;
          return decodedData['data'];
        } else {
          _prefs.remove(key); // Remover si expiró
        }
      } catch (e) {
        print('Error al decodificar datos de caché: $e');
      }
    }
    
    return null;
  }

  // Verifica si una clave existe en la caché y no ha expirado
  bool hasValidData(String key, {bool bypassOverride = false}) { // Renombrado el parámetro para evitar confusión
    if (!_initialized) return false;
    dynamic cachedItem = _memoryCache[key];
    String? persistentDataString;

    if (cachedItem == null) {
      persistentDataString = _prefs.getString(key);
      if (persistentDataString == null) return false;
      try {
        cachedItem = jsonDecode(persistentDataString);
      } catch (e) {
        print('Error al decodificar datos de caché para hasValidData: $e');
        return false;
      }
    }
    
    final expiresAt = cachedItem['expiresAt'] as int?;
    if (expiresAt == null) return false;

    return bypassOverride || expiresAt > clock.now().millisecondsSinceEpoch; // Usar el parámetro renombrado
  }

  // Elimina una clave de la caché
  Future<void> removeData(String key) async {
    await init();
    _memoryCache.remove(key);
    await _prefs.remove(key);
  }
  
  // Elimina una clave de la caché que contiene un patrón
  Future<void> removeKeysWithPattern(String pattern) async {
    await init();
    
    // Eliminar de memoria
    _memoryCache.removeWhere((key, value) => key.contains(pattern));
    
    // Eliminar de SharedPreferences
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.contains(pattern)) {
        await _prefs.remove(key);
      }
    }
  }

  // Elimina todas las claves de la caché
  Future<void> clearAll() async {
    await init();
    _memoryCache.clear();
    await _prefs.clear();
  }
  
  // Métodos específicos de la aplicación para manejar datos
  
  // Grupos
  Future<void> cacheGroups(List<GroupModel> groups, String userId) async {
    // Incluir el 'id' en cada mapa para poder reconstruir el modelo
    final list = groups.map((g) {
      final map = g.toMap();
      // Incluir id y sanitizar posibles Timestamps
      map['id'] = g.id;
      map.updateAll((key, value) {
        if (value is Timestamp) return value.toDate().millisecondsSinceEpoch;
        return value;
      });
      return map;
    }).toList();
    await setData('user_groups_$userId', list);
  }
  
  List<GroupModel>? getGroupsFromCache(String userId) {
    final cachedData = getData('user_groups_$userId');
    if (cachedData != null) {
      // Filtrar solo aquellos mapas con id válido
      return (cachedData as List)
        .map((map) => Map<String, dynamic>.from(map))
        .where((m) => m['id'] != null && m['id'] is String)
        .map((m) => GroupModel.fromMap(m, m['id'] as String))
        .toList();
    }
    return null;
  }
  
  // Gastos
  Future<void> cacheExpenses(List<ExpenseModel> expenses, String groupId) async {
    // Incluir el 'id' en cada mapa para evitar valor nulo al leer del caché
    final list = expenses.map((e) {
      final map = e.toMap();
      // Incluir id y sanitizar posibles Timestamps
      map['id'] = e.id;
      map.updateAll((key, value) {
        if (value is Timestamp) return value.toDate().millisecondsSinceEpoch;
        return value;
      });
      return map;
    }).toList();
    await setData('group_expenses_$groupId', list,
        // Usar una duración más larga para los datos si el usuario está activamente interactuando
        expiration: Duration(minutes: 20));
  }
  
  List<ExpenseModel>? getExpensesFromCache(String groupId) {
    final cachedData = getData('group_expenses_$groupId');
    if (cachedData != null) {
      if ((cachedData as List).isEmpty) {
        return []; // Devolver lista vacía explícitamente
      }
      return cachedData.map((map) => 
          ExpenseModel.fromMap(Map<String, dynamic>.from(map), map['id'] as String)).toList();
    }
    return null;
  }
  
  // Liquidaciones
  Future<void> cacheSettlements(List<SettlementModel> settlements, String groupId) async {
    final list = settlements.map((s) {
      final map = s.toMap();
      map['id'] = s.id; // Asegurar que el ID está en el mapa
      // Convertir Timestamps si es necesario, aunque SettlementModel.toMap ya debería devolver Timestamps
      // y _convertTimestamps en setData se encargará de convertirlos a epoch para JSON.
      // No obstante, si SettlementModel.toMap() devolviera DateTime, necesitaríamos convertirlos aquí.
      // Por ahora, asumimos que toMap() es consistente.
      return map;
    }).toList();
    await setData('group_settlements_$groupId', list);
  }
  
  List<SettlementModel>? getSettlementsFromCache(String groupId) {
    final cachedData = getData('group_settlements_$groupId');
    if (cachedData != null) {
      return (cachedData as List).map((map) {
        final settlementMap = Map<String, dynamic>.from(map);
        // Asegurarse de que el id se pasa correctamente a fromMap
        return SettlementModel.fromMap(settlementMap, settlementMap['id'] as String);
      }).toList();
    }
    return null;
  }
  
  // Usuarios
  Future<void> cacheUsers(List<UserModel> users) async {
    final usersMap = <String, dynamic>{};
    for (final user in users) {
      usersMap[user.id] = user.toMap();
    }
    await setData('users_data', usersMap);
  }
  
  UserModel? getUserFromCache(String userId) {
    final cachedData = getData('users_data');
    if (cachedData != null && cachedData[userId] != null) {
      return UserModel.fromMap(
          Map<String, dynamic>.from(cachedData[userId]), userId);
    }
    return null;
  }
  
  List<UserModel>? getUsersFromCache(List<String> userIds) {
    final cachedData = getData('users_data');
    if (cachedData != null) {
      final result = <UserModel>[];
      for (final userId in userIds) {
        if (cachedData[userId] != null) {
          result.add(UserModel.fromMap(
              Map<String, dynamic>.from(cachedData[userId]), userId));
        }
      }
      return result.isNotEmpty ? result : null;
    }
    return null;
  }

  // Función de ayuda para convertir Timestamps anidados.
  dynamic _convertTimestamps(dynamic item) {
    if (item is Timestamp) {
      return item.millisecondsSinceEpoch;
    } else if (item is Map) {
      return item.map((key, value) => MapEntry(key, _convertTimestamps(value)));
    } else if (item is List) {
      return item.map((element) => _convertTimestamps(element)).toList();
    }
    return item;
  }
}
