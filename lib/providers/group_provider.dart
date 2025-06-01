import 'dart:async'; // Necesario para StreamSubscription

import 'package:flutter/material.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
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

  Future<GroupModel> addParticipantToGroup(String groupId, UserModel invitedUser) async {
    _loading = true;
    if (!_isDisposed) notifyListeners();
    try {
      // Llama al servicio de Firestore para añadir el participante
      final updatedGroup = await _firestoreService.addParticipantToGroup(groupId, invitedUser);
      
      // Actualizar el grupo en la lista local o recargar la lista de grupos.
      final index = _groups.indexWhere((g) => g.id == groupId);
      if (index != -1) {
        _groups[index] = updatedGroup;
      } else {
        // Si el grupo no estaba en la lista (poco probable en este flujo),
        // podríamos añadirlo o decidir recargar todo dependiendo de la lógica de la app.
        // Por ahora, si no se encuentra, no hacemos nada con la lista local,
        // asumiendo que una futura carga/stream lo traerá.
        // Opcionalmente, se podría añadir: _groups.add(updatedGroup);
        // pero esto podría llevar a duplicados si la carga general ocurre después.
        // La opción más segura si no se encuentra es forzar un refresh completo,
        // aunque esto es menos eficiente.
        // await loadUserGroups(authProvider.user!.id, forceRefresh: true); // Necesitaría userId
      }
      return updatedGroup; // Devolver el grupo actualizado
    } catch (e) {
      print("Error al añadir participante en GroupProvider: $e");
      rethrow;
    } finally {
      _loading = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<GroupModel> removeParticipantFromGroup(String groupId, String userIdToRemove, String currentUserId) async {
    _loading = true;
    if (!_isDisposed) notifyListeners();
    try {
      final updatedGroup = await _firestoreService.removeParticipantFromGroup(groupId, userIdToRemove, currentUserId);

      // Actualizar el grupo en la lista local
      final index = _groups.indexWhere((g) => g.id == groupId);
      if (index != -1) {
        _groups[index] = updatedGroup;
      }
      // Si el currentUserId es el mismo que userIdToRemove, y el usuario fue removido exitosamente
      // (lo cual no debería pasar si es admin, pero por si acaso),
      // entonces ese grupo ya no debería estar en su lista.
      if (currentUserId == userIdToRemove) {
        _groups.removeWhere((g) => g.id == groupId);
      }
      return updatedGroup; // Devolver el grupo actualizado
      
    } catch (e) {
      print("Error al remover participante en GroupProvider: $e");
      rethrow; // Para que la UI pueda manejarlo
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
