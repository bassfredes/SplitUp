import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../models/settlement_model.dart';
import '../models/user_model.dart';
import './cache_service.dart';
import './firestore_monitor.dart';
import './connectivity_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CacheService _cache = CacheService();
  final FirestoreMonitor _monitor = FirestoreMonitor();
  final ConnectivityService _connectivity = ConnectivityService();
  
  // Constructor con inicialización de persistencia de Firestore
  FirestoreService() {
    // Habilitar persistencia offline
    _db.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  }

  // Grupos
  Future<void> createGroup(GroupModel group) async {
    await _db.collection('groups').doc(group.id).set(group.toMap());
    _monitor.logWrite();
    // Invalidar caché de grupos del usuario
    await _cache.removeKeysWithPattern('user_groups_');
  }

  Future<void> deleteGroup(String groupId) async {
    await _db.collection('groups').doc(groupId).delete();
    _monitor.logWrite();
    // Limpiar caché asociada al grupo eliminado
    await _cache.removeKeysWithPattern('group_${groupId}_');
    await _cache.removeData('group_$groupId');
    await _cache.removeKeysWithPattern('user_groups_');
  }

  // Obtener un grupo específico - ahora con caché y monitoreo
  Future<GroupModel> getGroupOnce(String groupId) async {
    // Verificar caché primero
    final cacheKey = 'group_$groupId';
    final cachedGroup = _cache.getData(cacheKey);
    if (cachedGroup != null) {
      _monitor.logCacheHit();
      _monitor.logRead('groups');
      return GroupModel.fromMap(Map<String, dynamic>.from(cachedGroup), groupId);
    }
    
    _monitor.logCacheMiss();
    
    // Si estamos sin conexión, no intentamos cargar desde Firestore
    if (!_connectivity.hasConnection) {
      throw Exception('Sin conexión y sin datos en caché');
    }
    
    // Si no está en caché, obtener de Firestore
    _monitor.logRead('groups');
    final doc = await _db.collection('groups').doc(groupId).get();
    if (doc.exists && doc.data() != null) {
      final group = GroupModel.fromMap(doc.data()!, doc.id);
      // Guardar en caché por 10 minutos
      await _cache.setData(cacheKey, doc.data());
      return group;
    } else {
      throw Exception('Grupo no encontrado');
    }
  }

  // Mantener el stream para actualizaciones en tiempo real, pero con optimizaciones
  Stream<GroupModel> getGroup(String groupId) {
    // Crear un controlador para gestionar el stream manualmente
    final controller = StreamController<GroupModel>();
    
    // Intentar entregar datos desde caché inmediatamente
    final cachedData = _cache.getData('group_$groupId');
    if (cachedData != null) {
      _monitor.logCacheHit();
      _monitor.logRead('groups');
      controller.add(GroupModel.fromMap(Map<String, dynamic>.from(cachedData), groupId));
    }
    
    // Suscribirse a cambios remotos
    final subscription = _db.collection('groups').doc(groupId).snapshots().listen(
      (doc) {
        if (!doc.metadata.isFromCache) {
          _monitor.logRead('groups');
        }
        if (doc.exists && doc.data() != null) {
          final group = GroupModel.fromMap(doc.data()!, doc.id);
          // Actualizar caché
          _cache.setData('group_$groupId', doc.data());
          // Entregar al stream
          controller.add(group);
        }
      },
      onError: (e) => controller.addError(e),
    );
    
    // Limpiar cuando se cierra el stream
    controller.onCancel = () => subscription.cancel();
    
    return controller.stream;
  }

  // Grupos del usuario - optimizado con caché
  Future<List<GroupModel>> getUserGroupsOnce(String userId) async {
    if (userId.isEmpty) {
      return [];
    }
    
    // Verificar caché primero
    final cachedGroups = _cache.getGroupsFromCache(userId);
    if (cachedGroups != null) {
      _monitor.logCacheHit();
      _monitor.logRead('groups');
      return cachedGroups;
    }
    
    _monitor.logCacheMiss();
    // Si no está en caché, obtener de Firestore
    _monitor.logRead('groups');
    final snapshot = await _db.collection('groups')
      .where('participantIds', arrayContains: userId)
      .get();
    
    final groups = snapshot.docs
      .map((doc) => GroupModel.fromMap(doc.data(), doc.id)).toList();
    
    // Guardar en caché
    await _cache.cacheGroups(groups, userId);
    
    return groups;
  }

  Stream<List<GroupModel>> getUserGroups(String userId) {
    if (userId.isEmpty) {
      // Retorna un stream vacío si el userId es inválido
      return Stream.value([]);
    }
    
    // Crear un controlador para gestionar el stream manualmente
    final controller = StreamController<List<GroupModel>>();
    
    // Intenta entregar datos desde caché inmediatamente
    final cachedGroups = _cache.getGroupsFromCache(userId);
    if (cachedGroups != null) {
      _monitor.logCacheHit();
      _monitor.logRead('groups');
      controller.add(cachedGroups);
    }
    
    // Suscribirse a cambios remotos
    final subscription = _db.collection('groups')
      .where('participantIds', arrayContains: userId)
      .snapshots()
      .listen((snapshot) {
        if (!snapshot.metadata.isFromCache) {
          _monitor.logRead('groups');
        }
        final groups = snapshot.docs
          .map((doc) => GroupModel.fromMap(doc.data(), doc.id)).toList();
        // Actualizar caché
        _cache.cacheGroups(groups, userId);
        // Entregar al stream
        controller.add(groups);
      },
      onError: (e) => controller.addError(e),
    );
    
    // Limpiar cuando se cierra el stream
    controller.onCancel = () => subscription.cancel();
    
    return controller.stream;
  }

  Future<GroupModel> addParticipantToGroup(String groupId, UserModel invitedUser) async {
    final groupRef = _db.collection('groups').doc(groupId);
    final newRole = {
      'uid': invitedUser.id,
      'role': 'member', // Default role
      // Considerar añadir más detalles del usuario aquí si es necesario para 'roles'
      // 'name': invitedUser.name,
      // 'email': invitedUser.email,
    };

    await groupRef.update({
      'participantIds': FieldValue.arrayUnion([invitedUser.id]),
      'roles': FieldValue.arrayUnion([newRole])
    });
    _monitor.logWrite();

    // Invalidar caché para este grupo específico
    await _cache.removeData('group_$groupId');
    print("Cache invalidated for group: $groupId after adding participant.");

    // Opcional: Invalidar la lista de grupos en caché para el usuario invitado,
    // ya que su lista de grupos ha cambiado.
    await _cache.removeData('user_groups_${invitedUser.id}');
    print("Cache invalidated for user_groups list for user: ${invitedUser.id}");

    // Devolver el grupo actualizado obteniéndolo de nuevo (lo que también actualizará la caché si es necesario)
    return await getGroupOnce(groupId);
  }

  // Gastos
  Future<void> addExpense(ExpenseModel expense) async {
    await _db.collection('groups').doc(expense.groupId)
      .collection('expenses').doc(expense.id).set(expense.toMap());
    _monitor.logWrite();
    // Invalidar caché de gastos
    await _cache.removeData('group_expenses_${expense.groupId}');
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await _db
        .collection('groups')
        .doc(expense.groupId)
        .collection('expenses')
        .doc(expense.id)
        .update(expense.toMap());
    _monitor.logWrite();
    // Invalidar caché de gastos
    await _cache.removeData('group_expenses_${expense.groupId}');
  }
  
  // Método para obtener gastos una sola vez (sin stream) - con monitor y optimizaciones
  Future<List<ExpenseModel>> getExpensesOnce(String groupId) async {
    // Verificar caché primero
    final cachedExpenses = _cache.getExpensesFromCache(groupId);
    if (cachedExpenses != null) {
      _monitor.logCacheHit();
      _monitor.logRead('expenses');
      return cachedExpenses;
    }
    
    _monitor.logCacheMiss();
    
    // Si estamos sin conexión y no tenemos caché, retornar lista vacía
    if (!_connectivity.hasConnection) {
      return [];
    }
    
    // Si no está en caché, obtener de Firestore con límite para reducir lecturas
    _monitor.logRead('expenses');
    final snapshot = await _db.collection('groups').doc(groupId)
      .collection('expenses')
      .orderBy('date', descending: true)
      .limit(50) // Limitar la cantidad inicial para reducir lecturas
      .get();
      
    final expenses = snapshot.docs
      .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id)).toList();
      
    // Guardar en caché
    await _cache.cacheExpenses(expenses, groupId);
    
    return expenses;
  }

  Stream<List<ExpenseModel>> getExpenses(String groupId) {
    // Crear un controlador para gestionar el stream manualmente
    final controller = StreamController<List<ExpenseModel>>();
    
    // Intentar entregar datos desde caché inmediatamente
    final cachedExpenses = _cache.getExpensesFromCache(groupId);
    if (cachedExpenses != null) {
      _monitor.logCacheHit();
      _monitor.logRead('expenses');
      controller.add(cachedExpenses);
    }
    
    // Suscribirse a cambios remotos
    final subscription = _db.collection('groups').doc(groupId)
      .collection('expenses')
      .orderBy('date', descending: true)
      .snapshots()
      .listen((snapshot) {
        if (!snapshot.metadata.isFromCache) {
          _monitor.logRead('expenses');
        }
        final expenses = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id)).toList();
        // Actualizar caché
        _cache.cacheExpenses(expenses, groupId);
        // Entregar al stream
        controller.add(expenses);
      },
      onError: (e) => controller.addError(e),
    );
    
    // Limpiar cuando se cierra el stream
    controller.onCancel = () => subscription.cancel();
    
    return controller.stream;
  }

  // Método para obtener gastos con paginación
  Future<List<ExpenseModel>> getExpensesPaginated(
    String groupId,
    int limit,
    DocumentSnapshot? lastDocument
  ) async {
    Query query = _db
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .limit(limit);
    
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    
    final snapshot = await query.get();
    _monitor.logRead('expenses');
    return snapshot.docs
        .map((doc) => ExpenseModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  // Nuevo método para obtener un DocumentSnapshot por su path
  Future<DocumentSnapshot?> getDocumentSnapshot(String documentPath) async {
    try {
      final doc = await _db.doc(documentPath).get();
      // Asumiendo que el parent.id es el nombre de la colección para el monitor
      // Puede que necesites ajustar esto si la estructura de path es más compleja
      // o si tienes una forma estándar de determinar la colección desde el path.
      if (doc.reference.parent.parent != null) { // e.g. groups/{groupId}/expenses/{expenseId}
         _monitor.logRead(doc.reference.parent.id); 
      } else { // e.g. users/{userId}
         _monitor.logRead(doc.reference.parent.path); // o alguna otra lógica
      }
      return doc.exists ? doc : null;
    } catch (e) {
      print("Error al obtener DocumentSnapshot para $documentPath: $e");
      return null;
    }
  }

  // Método para obtener el total de gastos (para saber cuántas páginas hay)
  Future<int> getExpensesCount(String groupId) async {
    final snapshot = await _db
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .count()
        .get();
    _monitor.logRead('expenses');
    return snapshot.count ?? 0;
  }

  // Elimina un participante de todos los gastos del grupo y ajusta los montos
  Future<void> removeParticipantFromExpenses(String groupId, String userId) async {
    final expensesSnap = await _db.collection('groups').doc(groupId).collection('expenses').get();
    _monitor.logRead('expenses');
    for (final doc in expensesSnap.docs) {
      final expense = ExpenseModel.fromMap(doc.data(), doc.id);
      if (!expense.participantIds.contains(userId)) continue;
      // Quitar participante
      final newParticipantIds = List<String>.from(expense.participantIds)..remove(userId);
      List<Map<String, dynamic>>? newCustomSplits;
      if (expense.customSplits != null) {
        newCustomSplits = expense.customSplits!.where((split) => split['userId'] != userId).toList();
      }
      // Recalcular montos si es división igualitaria
      double newAmount = expense.amount;
      if (expense.customSplits == null && newParticipantIds.isNotEmpty && expense.participantIds.isNotEmpty) { // Evitar división por cero
        newAmount = expense.amount * newParticipantIds.length / expense.participantIds.length;
      } else if (newParticipantIds.isEmpty) {
        // Considerar qué hacer si no quedan participantes en el gasto.
        // Podría ser eliminar el gasto o marcarlo como inválido.
        // Por ahora, se podría dejar el monto como está o ponerlo a 0 si se elimina el gasto.
        // Si se mantiene el gasto, pero sin participantes, el monto podría no tener sentido.
        // Aquí asumimos que el gasto se mantiene y el monto no cambia si no hay recalculo.
      }

      await _db.collection('groups').doc(groupId).collection('expenses').doc(expense.id).update({
        'participantIds': newParticipantIds,
        'customSplits': newCustomSplits,
        'amount': newAmount, // Asegúrate que newAmount se calcula correctamente
      });
      _monitor.logWrite();
    }
    // Invalidar caché de gastos del grupo después de modificar los gastos
    await _cache.removeData('group_expenses_$groupId');
    print("Cache invalidated for group_expenses: $groupId after removing participant from expenses.");
  }

  Future<GroupModel> removeParticipantFromGroup(String groupId, String userIdToRemove, String currentUserId) async {
    final groupRef = _db.collection('groups').doc(groupId);

    // Primero, remover al participante de todos los gastos y redistribuir si es necesario.
    // Esta llamada ya invalida 'group_expenses_groupId'
    await removeParticipantFromExpenses(groupId, userIdToRemove);

    // Luego, actualizar el documento del grupo para remover al participante de participantIds y roles.
    // Es importante obtener el documento del grupo *antes* de la actualización para poder filtrar el array de roles.
    final groupDoc = await groupRef.get();
    if (!groupDoc.exists) {
      throw Exception("Group not found: $groupId");
    }
    final groupData = groupDoc.data();
    if (groupData == null) {
      throw Exception("Group data is null for: $groupId");
    }

    final String adminId = groupData['adminId'] as String? ?? '';
    if (userIdToRemove == adminId) {
      // Adicionalmente, verificar si es el único participante.
      // Aunque la lógica principal es no remover al admin, si es el único,
      // el grupo debería ser eliminado en lugar de dejar un admin solitario que no se puede ir.
      // Sin embargo, la acción de "eliminar grupo" es separada. Por ahora, solo prevenimos remover al admin.
      final List<dynamic> participantIds = groupData['participantIds'] ?? [];
      if (participantIds.length == 1 && participantIds.contains(adminId)) {
        // Podrías lanzar un error más específico o manejarlo de forma diferente.
        // Por ejemplo, "El administrador es el único miembro y no puede ser eliminado. Elimine el grupo en su lugar."
        // Pero por consistencia con el objetivo de no remover al admin, este error es suficiente.
        throw Exception("The group administrator cannot be removed, especially if they are the only participant. Consider deleting the group instead.");
      }
      throw Exception("The group administrator cannot be removed.");
    }

    final List<dynamic> currentRoles = groupData['roles'] ?? [];
    final updatedRoles = currentRoles.where((role) {
      if (role is Map<String, dynamic>) {
        return role['uid'] != userIdToRemove;
      }
      return true; // Mantener roles si no tienen el formato esperado (aunque esto no debería ocurrir)
    }).toList();

    await groupRef.update({
      'participantIds': FieldValue.arrayRemove([userIdToRemove]),
      'roles': updatedRoles,
    });
    _monitor.logWrite();

    // Invalidar caché para este grupo específico
    await _cache.removeData('group_$groupId');
    print("Cache invalidated for group: $groupId after removing participant.");

    // Invalidar la lista de grupos en caché para el usuario que fue removido
    await _cache.removeData('user_groups_$userIdToRemove');
    print("Cache invalidated for user_groups list for user: $userIdToRemove");
    
    // Invalidar la lista de grupos en caché para el usuario actual (quien realizó la acción),
    // por si la información del grupo (como la lista de participantes) se muestra en su dashboard.
    await _cache.removeData('user_groups_$currentUserId');
    print("Cache invalidated for user_groups list for current user: $currentUserId");


    // Devolver el grupo actualizado
    return await getGroupOnce(groupId);
  }

  // Liquidaciones
  Future<void> addSettlement(SettlementModel settlement) async {
    await _db.collection('groups').doc(settlement.groupId)
      .collection('settlements').doc(settlement.id).set(settlement.toMap());
    _monitor.logWrite();
    // Invalidar caché de liquidaciones
    await _cache.removeData('group_settlements_${settlement.groupId}');
  }

  // Método para obtener liquidaciones una sola vez (sin stream)
  Future<List<SettlementModel>> getSettlementsOnce(String groupId) async {
    // Verificar caché primero
    final cachedSettlements = _cache.getSettlementsFromCache(groupId);
    if (cachedSettlements != null) {
      _monitor.logCacheHit();
      _monitor.logRead('settlements');
      return cachedSettlements;
    }
    _monitor.logCacheMiss();
    // Si no está en caché, obtener de Firestore
    _monitor.logRead('settlements');
    final snapshot = await _db.collection('groups').doc(groupId)
      .collection('settlements')
      .orderBy('date', descending: true)
      .get();
      
    final settlements = snapshot.docs
      .map((doc) => SettlementModel.fromMap(doc.data(), doc.id)).toList();
      
    // Guardar en caché
    await _cache.cacheSettlements(settlements, groupId);
    
    return settlements;
  }

  Stream<List<SettlementModel>> getSettlements(String groupId) {
    // Crear un controlador para gestionar el stream manualmente
    final controller = StreamController<List<SettlementModel>>();
    
    // Intentar entregar datos desde caché inmediatamente
    final cachedSettlements = _cache.getSettlementsFromCache(groupId);
    if (cachedSettlements != null) {
      _monitor.logCacheHit();
      _monitor.logRead('settlements');
      controller.add(cachedSettlements);
    }
    
    // Suscribirse a cambios remotos
    final subscription = _db.collection('groups').doc(groupId)
      .collection('settlements')
      .orderBy('date', descending: true)
      .snapshots()
      .listen((snapshot) {
        if (!snapshot.metadata.isFromCache) {
          _monitor.logRead('settlements');
        }
        final settlements = snapshot.docs
          .map((doc) => SettlementModel.fromMap(doc.data(), doc.id)).toList();
        // Actualizar caché
        _cache.cacheSettlements(settlements, groupId);
        // Entregar al stream
        controller.add(settlements);
      },
      onError: (e) => controller.addError(e),
    );
    
    // Limpiar cuando se cierra el stream
    controller.onCancel = () => subscription.cancel();
    
    return controller.stream;
  }

  // Limpia todos los gastos y liquidaciones de un grupo (antes de eliminarlo)
  Future<void> cleanGroupExpensesAndSettlements(String groupId) async {
    final expensesSnap = await _db.collection('groups').doc(groupId).collection('expenses').get();
    _monitor.logRead('expenses');
    for (final doc in expensesSnap.docs) {
      await doc.reference.delete();
      _monitor.logWrite();
    }
    final settlementsSnap = await _db.collection('groups').doc(groupId).collection('settlements').get();
    _monitor.logRead('settlements');
    for (final doc in settlementsSnap.docs) {
      await doc.reference.delete();
      _monitor.logWrite();
    }
    
    // Limpiar caché relacionada
    await _cache.removeData('group_expenses_$groupId');
    await _cache.removeData('group_settlements_$groupId');
  }
  
  // Método para obtener múltiples usuarios de una vez
  Future<List<UserModel>> fetchUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    
    // Comprobar primero en la caché
    final cachedUsers = _cache.getUsersFromCache(userIds);
    if (cachedUsers != null && cachedUsers.length == userIds.length) {
      _monitor.logCacheHit();
      _monitor.logRead('users');
      return cachedUsers;
    }
    
    // Obtener solo los IDs que faltan en caché
    List<String> missingIds;
    if (cachedUsers != null) {
      final cachedIds = cachedUsers.map((user) => user.id).toSet();
      missingIds = userIds.where((id) => !cachedIds.contains(id)).toList();
    } else {
      missingIds = userIds;
    }
    
    // Si no hay IDs faltantes, devolver los usuarios en caché
    if (missingIds.isEmpty && cachedUsers != null) {
      _monitor.logCacheHit();
      _monitor.logRead('users');
      return cachedUsers;
    }
    
    _monitor.logCacheMiss();
    
    // Firestore tiene un límite de 30 IDs por consulta whereIn
    List<UserModel> allUsers = cachedUsers ?? [];
    List<List<String>> chunks = [];
    
    for (var i = 0; i < missingIds.length; i += 10) {
      chunks.add(missingIds.sublist(
          i, i + 10 > missingIds.length ? missingIds.length : i + 10));
    }

    for (final chunk in chunks) {
      if (chunk.isEmpty) continue;
      final usersSnap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      _monitor.logRead('users');
      final fetchedUsers = usersSnap.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
          
      allUsers.addAll(fetchedUsers);
      
      // Actualizar caché con usuarios nuevos
      await _cache.cacheUsers(fetchedUsers);
    }

    return allUsers;
  }

  // OPERACIONES EN LOTE (BATCH)
  
  /// Actualiza varios documentos en una sola operación atómica
  Future<void> batchUpdate({
    required List<Map<String, dynamic>> updates,
  }) async {
    if (updates.isEmpty) return;
    
    final batch = _db.batch();
    
    for (final update in updates) {
      final docRef = _db.doc(update['path'] as String);
      batch.update(docRef, update['data'] as Map<String, dynamic>);
    }
    
    await batch.commit();
    _monitor.logWrite();
  }
  
  /// Crea varios documentos en una sola operación atómica
  Future<void> batchCreate({
    required List<Map<String, dynamic>> creates,
  }) async {
    if (creates.isEmpty) return;
    
    final batch = _db.batch();
    
    for (final create in creates) {
      final docRef = _db.doc(create['path'] as String);
      batch.set(docRef, create['data'] as Map<String, dynamic>);
    }
    
    await batch.commit();
    _monitor.logWrite();
  }
  
  /// Elimina varios documentos en una sola operación atómica
  Future<void> batchDelete({
    required List<String> paths,
  }) async {
    if (paths.isEmpty) return;
    
    final batch = _db.batch();
    
    for (final path in paths) {
      final docRef = _db.doc(path);
      batch.delete(docRef);
    }
    
    await batch.commit();
    _monitor.logWrite();
  }
}
