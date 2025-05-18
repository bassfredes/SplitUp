import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/group_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import '../models/expense_model.dart';
import '../models/settlement_model.dart';
import '../models/user_model.dart';

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

  Future<void> init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  // Guarda datos en la caché (tanto en memoria como persistente)
  Future<void> setData(String key, dynamic data, {Duration? expiration}) async {
    await init();
    final expiresAt = DateTime.now().add(expiration ?? defaultExpiration).millisecondsSinceEpoch;
    final cacheData = {
      'data': data,
      'expiresAt': expiresAt,
    };
    
    // Guardar en memoria
    _memoryCache[key] = cacheData;
    
    // Guardar en SharedPreferences
    if (data is Map || data is List) {
      await _prefs.setString(key, jsonEncode(cacheData));
    } else if (data is String) {
      final Map<String, dynamic> wrappedData = {
        'data': data,
        'expiresAt': expiresAt,
      };
      await _prefs.setString(key, jsonEncode(wrappedData));
    } else if (data is bool) {
      await _prefs.setBool(key, data);
    } else if (data is int) {
      await _prefs.setInt(key, data);
    } else if (data is double) {
      await _prefs.setDouble(key, data);
    }
  }

  // Obtiene datos de la caché (primero de memoria, luego de persistente)
  dynamic getData(String key, {bool bypassExpiration = false}) {
    if (!_initialized) return null;
    
    // Verificar memoria primero
    if (_memoryCache.containsKey(key)) {
      final cachedData = _memoryCache[key];
      final expiresAt = cachedData['expiresAt'] as int;
      
      if (bypassExpiration || expiresAt > DateTime.now().millisecondsSinceEpoch) {
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
        
        if (bypassExpiration || expiresAt > DateTime.now().millisecondsSinceEpoch) {
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
  bool hasValidData(String key) {
    if (!_initialized) return false;
    
    // Verificar memoria primero
    if (_memoryCache.containsKey(key)) {
      final cachedData = _memoryCache[key];
      final expiresAt = cachedData['expiresAt'] as int;
      
      if (expiresAt > DateTime.now().millisecondsSinceEpoch) {
        return true;
      } else {
        _memoryCache.remove(key);
      }
    }
    
    // Verificar SharedPreferences
    final persistentData = _prefs.getString(key);
    if (persistentData != null) {
      try {
        final decodedData = jsonDecode(persistentData);
        final expiresAt = decodedData['expiresAt'] as int;
        
        if (expiresAt > DateTime.now().millisecondsSinceEpoch) {
          // Guardar en memoria para futuros accesos
          _memoryCache[key] = decodedData;
          return true;
        } else {
          _prefs.remove(key);
        }
      } catch (e) {
        print('Error al decodificar datos de caché: $e');
      }
    }
    
    return false;
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
    await setData('group_settlements_$groupId', settlements.map((s) => s.toMap()).toList());
  }
  
  List<SettlementModel>? getSettlementsFromCache(String groupId) {
    final cachedData = getData('group_settlements_$groupId');
    if (cachedData != null) {
      return (cachedData as List).map((map) => 
          SettlementModel.fromMap(Map<String, dynamic>.from(map), map['id'] as String)).toList();
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
}
