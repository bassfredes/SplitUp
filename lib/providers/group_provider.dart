import 'dart:async'; // Necesario para StreamSubscription

import 'package:flutter/material.dart';
import '../models/group_model.dart';
import '../services/firestore_service.dart';

class GroupProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<GroupModel> _groups = [];
  bool _loading = false;
  bool _isDisposed = false; // Bandera para controlar el estado de dispose
  StreamSubscription? _userGroupsSubscription; // Para manejar la suscripción
  // DateTime _lastLoadTime = DateTime(1970); // Comentado para reducir la complejidad del refresco automático

  List<GroupModel> get groups => _groups;
  bool get loading => _loading;

  // Añadir una instancia de ConnectivityService si se quiere usar directamente aquí
  // final ConnectivityService _connectivity = ConnectivityService();

  Future<void> loadUserGroups(String userId, {bool forceRefresh = false}) async {
    if (_loading && !forceRefresh) return; // Evitar cargas concurrentes a menos que se fuerce

    _loading = true;
    if (!_isDisposed) notifyListeners();

    bool loadedFromCacheSuccessfully = false;

    // 1. Intento de carga desde caché si no se fuerza el refresco
    if (!forceRefresh) {
      try {
        final cachedGroups = await _firestoreService.getUserGroupsOnce(userId);
        if (!_isDisposed && cachedGroups.isNotEmpty) {
          _groups = cachedGroups;
          loadedFromCacheSuccessfully = true;
          print("GroupProvider: Grupos cargados desde caché.");
        } else if (!_isDisposed && cachedGroups.isEmpty && _groups.isNotEmpty) {
          // La caché está vacía, pero teníamos datos previos (quizás de un stream anterior).
          // Mantenemos los datos previos y esperamos al stream/fetch si es necesario.
          print("GroupProvider: Caché vacía, pero se conservan grupos previos. Se considera carga exitosa desde perspectiva de datos disponibles.");
          loadedFromCacheSuccessfully = true; 
        }
      } catch (e) {
        print("Error al cargar grupos desde caché en Provider: $e");
        // Continuar para intentar cargar desde Firestore directamente.
      }
    }

    // 2. Decidir si se necesita el stream o una carga única desde la red.
    bool shouldFetchFromNetwork = forceRefresh || !loadedFromCacheSuccessfully;

    if (shouldFetchFromNetwork) {
      print("GroupProvider: Necesita obtener datos de la red. Forzado: $forceRefresh, Éxito Caché: $loadedFromCacheSuccessfully");
      
      await _userGroupsSubscription?.cancel();
      _userGroupsSubscription = null; 

      _userGroupsSubscription = _firestoreService.getUserGroups(userId).listen((groupList) {
        if (_isDisposed) return;
        _groups = groupList;
        _loading = false;
        print("GroupProvider: Grupos actualizados desde stream.");
        if (!_isDisposed) notifyListeners();
      }, onError: (error) {
        if (_isDisposed) return;
        print("Error en stream de grupos: $error");
        _loading = false;
        if (!_isDisposed) notifyListeners();
      });
    } else {
      // Datos cargados desde caché y no se fuerza refresco.
      _loading = false; // Asegurar que loading sea false.
      print("GroupProvider: Usando datos de caché, no se inicia nuevo stream/fetch.");
      if (!_isDisposed) notifyListeners(); // Notificar por si el estado de loading cambió.
    }
  }

  Future<void> createGroup(GroupModel group, String userId) async {
    _loading = true;
    if (!_isDisposed) notifyListeners();
    try {
      await _firestoreService.createGroup(group);
      await loadUserGroups(userId, forceRefresh: true); // Forzar refresco
    } catch (e) {
      print("Error al crear grupo: $e");
      _loading = false; // Asegurar que loading se actualice en caso de error
      if (!_isDisposed) notifyListeners();
    }
    // El loading se manejará dentro de loadUserGroups o al finalizar si no hay error
  }

  Future<void> deleteGroup(String groupId, String userId) async {
    _loading = true;
    if (!_isDisposed) notifyListeners();
    try {
      await _firestoreService.cleanGroupExpensesAndSettlements(groupId);
      await _firestoreService.deleteGroup(groupId);
      await loadUserGroups(userId, forceRefresh: true); // Forzar refresco
    } catch (e) {
      print("Error al eliminar grupo: $e");
      _loading = false; // Asegurar que loading se actualice en caso de error
      if (!_isDisposed) notifyListeners();
    }
    // El loading se manejará dentro de loadUserGroups
  }

  Future<void> removeParticipantAndRedistribute(String groupId, String userId) async {
    // Considerar si esta operación debe forzar un refresco de la lista de grupos
    // o si los cambios se reflejarán adecuadamente a través del stream existente (si está activo).
    // Por ahora, se asume que un refresco podría ser necesario si los datos del grupo cambian.
    _loading = true;
    if(!_isDisposed) notifyListeners();
    try {
      await _firestoreService.removeParticipantFromExpenses(groupId, userId);
      // Opcional: Forzar refresco si es probable que la información del grupo (participantes, etc.) cambie.
      // await loadUserGroups(userId, forceRefresh: true); 
    } catch (e) {
      print("Error al remover participante y redistribuir: $e");
    } finally {
      _loading = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _userGroupsSubscription?.cancel(); 
    _userGroupsSubscription = null;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}
