import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para monitorear y registrar las operaciones de lectura de Firestore
/// Ayuda a identificar puntos críticos de uso y verificar el éxito de las optimizaciones
class FirestoreMonitor extends ChangeNotifier {
  static final FirestoreMonitor _instance = FirestoreMonitor._internal();
  
  // Contadores
  int _readCount = 0;
  int _writeCount = 0;
  int _cacheHitCount = 0;
  int _cacheMissCount = 0;
  final Map<String, int> _readsByCollection = {};
  late Future<void> _loadFuture;
  bool _loaded = false;
  
  // Timestamp para reseteo diario
  late DateTime _lastResetTime;
  
  // Singleton
  factory FirestoreMonitor() => _instance;
  
  FirestoreMonitor._internal() {
    _loadFuture = _loadStats().then((_) => _loaded = true);
    _lastResetTime = DateTime.now();
    
    // Opcional: resetear contadores cada día
    Timer.periodic(const Duration(hours: 1), (_) {
      final now = DateTime.now();
      if (now.day != _lastResetTime.day) {
        _saveBeforeReset();
        _resetCounters();
        _lastResetTime = now;
      }
    });
  }
  
  // Getters
  int get readCount => _readCount;
  int get writeCount => _writeCount;
  int get cacheHitCount => _cacheHitCount;
  int get cacheMissCount => _cacheMissCount;
  Map<String, int> get readsByCollection => Map.unmodifiable(_readsByCollection);
  double get cacheHitRate => _readCount > 0 ? _cacheHitCount / (_cacheHitCount + _cacheMissCount) : 0;

  @visibleForTesting
  Future<void> waitForLoad() => _loadFuture;

  @visibleForTesting
  Future<void> resetForTesting() async {
    await _loadFuture;
    _readCount = 0;
    _writeCount = 0;
    _cacheHitCount = 0;
    _cacheMissCount = 0;
    _readsByCollection.clear();
    _lastResetTime = DateTime.now();
    _loaded = true;
    _loadFuture = Future.value();
  }
  
  /// Registra una operación de lectura
  void logRead(String collection) {
    // Esperar carga inicial para evitar sobrescribir contadores si aún no se han cargado
    if (!_loaded) {
      _loadFuture.whenComplete(() => logRead(collection));
      return;
    }
    _readCount++;
    _readsByCollection[collection] = (_readsByCollection[collection] ?? 0) + 1;
    if (kDebugMode && _readCount % 50 == 0) {
      print('Lecturas de Firestore: $_readCount');
    }
    _saveStats();
    notifyListeners();
  }
  
  /// Registra una operación de escritura
  void logWrite() {
    if (!_loaded) {
      _loadFuture.whenComplete(() => logWrite());
      return;
    }
    _writeCount++;
    _saveStats();
    notifyListeners();
  }
  
  /// Registra un acierto en la caché
  void logCacheHit() {
    if (!_loaded) {
      _loadFuture.whenComplete(() => logCacheHit());
      return;
    }
    _cacheHitCount++;
    _saveStats();
    notifyListeners();
  }
  
  /// Registra un fallo en la caché
  void logCacheMiss() {
    if (!_loaded) {
      _loadFuture.whenComplete(() => logCacheMiss());
      return;
    }
    _cacheMissCount++;
    _saveStats();
    notifyListeners();
  }
  
  /// Guarda las estadísticas actuales antes de un reseteo
  Future<void> _saveBeforeReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('firestore_previous_day_reads', _readCount);
    await prefs.setInt('firestore_previous_day_writes', _writeCount);
    await prefs.setDouble('firestore_previous_day_cache_hit_rate', cacheHitRate);
  }
  
  /// Guarda las estadísticas actuales
  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('firestore_read_count', _readCount);
    await prefs.setInt('firestore_write_count', _writeCount);
    await prefs.setInt('firestore_cache_hits', _cacheHitCount);
    await prefs.setInt('firestore_cache_misses', _cacheMissCount);
    await prefs.setString('firestore_reads_by_collection', 
      _readsByCollection.toString());
  }
  
  /// Carga estadísticas guardadas
  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    _readCount += prefs.getInt('firestore_read_count') ?? 0;
    _writeCount += prefs.getInt('firestore_write_count') ?? 0;
    _cacheHitCount += prefs.getInt('firestore_cache_hits') ?? 0;
    _cacheMissCount += prefs.getInt('firestore_cache_misses') ?? 0;
  }
  
  /// Resetea contadores para un nuevo período
  void _resetCounters() {
    _readCount = 0;
    _writeCount = 0;
    _cacheHitCount = 0;
    _cacheMissCount = 0;
    _readsByCollection.clear();
    _saveStats();
    notifyListeners();
  }
  
  /// Genera un informe de uso
  String generateReport() {
    final sb = StringBuffer();
    sb.writeln('===== INFORME DE USO DE FIRESTORE =====');
    sb.writeln('Lecturas totales: $_readCount');
    sb.writeln('Escrituras totales: $_writeCount');
    sb.writeln('Tasa de aciertos de caché: ${(cacheHitRate * 100).toStringAsFixed(2)}%');
    sb.writeln('Lecturas por colección:');
    _readsByCollection.forEach((collection, count) {
      sb.writeln('  - $collection: $count (${(count / _readCount * 100).toStringAsFixed(2)}%)');
    });
    return sb.toString();
  }
}
