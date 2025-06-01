import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

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
    // Reset initialization state for the new test instance
    _instance._isInitialized = false; 
  }

  factory ConnectivityService() => _instance;

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  bool _hasConnection = true; // Asumir conexión inicialmente hasta que se verifique
  bool get hasConnection => _hasConnection;
  
  final _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionStatusController.stream;
  
  bool _isInitialized = false; // Flag de inicialización

  // Constructor modificado para solo almacenar dependencias
  ConnectivityService._internal(this._connectivity);

  /// Inicializa el servicio. Debe llamarse antes de usar el servicio.
  Future<void> init() async {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);
    await _checkInitialConnectivity();
    _setupSubscription();
    _isInitialized = true;
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
        print('Error al verificar conectividad inicial: $e');
      }
      // Solo actualiza y notifica si el estado realmente necesita cambiar desde la presunción inicial
      if (_hasConnection) { // Si se asumía conectado y falla, ahora está desconectado
        _hasConnection = false;
        _notifyConnectionChange(); 
      }
    }
  }
  
  /// Verificar el estado actual de conectividad (para uso externo)
  Future<void> checkConnectivity() async {
    // Asegurarse de que el servicio esté inicializado si se llama externamente
    // aunque típicamente init() ya se habrá llamado.
    if (!_isInitialized) {
      if (kDebugMode) {
        print("Advertencia: checkConnectivity llamado antes de init en ConnectivityService.");
      }
      // Podríamos forzar una inicialización aquí o lanzar un error.
      // Por ahora, solo procederá a _checkInitialConnectivity.
    }
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
