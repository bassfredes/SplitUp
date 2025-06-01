import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart'; // Añadir import

/// Servicio para monitorear el estado de la conectividad y reducir
/// las operaciones de Firestore cuando el usuario está offline
class ConnectivityService with WidgetsBindingObserver {
  // Singleton
  static ConnectivityService _instance = ConnectivityService._internal(Connectivity());
  static ConnectivityService get instance => _instance;

  // Para permitir la anulación en pruebas
  static void setInstance(ConnectivityService service) {
    _instance = service;
  }

  /// Establece una instancia de ConnectivityService con un mock de Connectivity para pruebas.
  @visibleForTesting
  static void setInstanceForTest(Connectivity connectivity) {
    _instance = ConnectivityService._internal(connectivity);
  }

  factory ConnectivityService() => _instance;

  final Connectivity _connectivity; // Modificado para inyección
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  // Estado de la conectividad
  bool _hasConnection = true;
  bool get hasConnection => _hasConnection;
  
  // Controlador de stream para notificar cambios
  final _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionStatusController.stream;
  
  // Constructor modificado para aceptar Connectivity
  ConnectivityService._internal(this._connectivity) {
    _initializeService();
  }

  /// Inicializa el servicio de forma segura
  Future<void> _initializeService() async {
    // Registrar observer para eventos de ciclo de vida
    WidgetsBinding.instance.addObserver(this);
    
    // Verificar estado inicial
    await _checkInitialConnectivity();
    
    // Inicializar suscripción a cambios de conectividad
    _setupSubscription();
  }
  
  /// Configura la suscripción al stream de conectividad
  void _setupSubscription() {
    _subscription = _connectivity.onConnectivityChanged.listen(
      (result) => _processConnectivityResult(result),
      onError: (error) {
        if (kDebugMode) {
          print('Error en stream de conectividad: $error');
        }
      }
    );
  }
  
  /// Verificar el estado inicial de conectividad
  Future<void> _checkInitialConnectivity() async {
    try {
      final List<ConnectivityResult> result = await _connectivity.checkConnectivity();
      _processConnectivityResult(result);
    } catch (e) {
      if (kDebugMode) {
        print('Error al verificar conectividad: $e');
      }
      _hasConnection = false; // Asumimos desconectado en caso de error
      _notifyConnectionChange(); // Notificar el cambio
    }
  }
  
  /// Verificar el estado actual de conectividad (para uso externo)
  Future<void> checkConnectivity() async {
    await _checkInitialConnectivity();
  }
  
  /// Procesa el resultado de conectividad
  void _processConnectivityResult(List<ConnectivityResult> results) {
    final bool isConnected;
    if (results.isEmpty) {
      isConnected = false; // Si la lista está vacía, asumimos que no hay conexión
    } else {
      // Hay conexión si alguno de los resultados no es 'none'
      isConnected = results.any((result) => result != ConnectivityResult.none);
    }
    
    // Solo notificar si hay un cambio
    if (_hasConnection != isConnected) {
      _hasConnection = isConnected;
      _notifyConnectionChange();
      
      // Log para depuración
      if (kDebugMode) {
        print('Estado de conexión cambiado: ${_hasConnection ? 'Conectado' : 'Desconectado'}');
      }
    }
  }
  
  /// Notificar a los listeners sobre cambio de estado
  void _notifyConnectionChange() {
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(_hasConnection);
    }
  }
  
  /// Manejar eventos del ciclo de vida de la aplicación
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // La app volvió a primer plano, verificar conectividad
      checkConnectivity();
    }
  }
  
  /// Liberar recursos y cancelar suscripciones
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.close();
    }
  }
}
