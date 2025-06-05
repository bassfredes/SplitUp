import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:splitup_application/models/group_model.dart';
import 'package:splitup_application/models/expense_model.dart';
import 'package:splitup_application/models/settlement_model.dart';
import 'package:splitup_application/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitup_application/services/cache_service.dart';
import 'package:splitup_application/services/connectivity_service.dart';
import 'package:splitup_application/services/firestore_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'firestore_service_test.mocks.dart';

@GenerateMocks([CacheService, ConnectivityService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late FakeFirebaseFirestore mockFirestore;
  late FirestoreService firestoreService;
  late MockCacheService mockCacheService;
  late MockConnectivityService mockConnectivityService;

  setUp(() {
    mockFirestore = FakeFirebaseFirestore();
    mockCacheService = MockCacheService();
    mockConnectivityService = MockConnectivityService();
    firestoreService = FirestoreService(
      firestore: mockFirestore,
      cacheService: mockCacheService,
      connectivityService: mockConnectivityService,
    );

    when(mockConnectivityService.hasConnection).thenReturn(true);
    when(mockConnectivityService.connectionStream).thenAnswer((_) => Stream.value(true));

    // Configuración de mocks para CacheService
    when(mockCacheService.removeData(any)).thenAnswer((_) async => Future.value(null));
    when(mockCacheService.removeKeysWithPattern(any)).thenAnswer((_) async => Future.value(null));
    when(mockCacheService.setData(any, any, expiration: anyNamed('expiration'))).thenAnswer((_) async => Future.value(null));
    when(mockCacheService.cacheGroups(any, any)).thenAnswer((_) async => Future.value(null));
    when(mockCacheService.cacheExpenses(any, any)).thenAnswer((_) async => Future.value(null));
    when(mockCacheService.cacheSettlements(any, any)).thenAnswer((_) async => Future.value(null));
    when(mockCacheService.cacheUsers(any)).thenAnswer((_) async => Future.value(null));
    when(mockCacheService.init()).thenAnswer((_) async => Future.value(null));
    when(mockCacheService.clearAll()).thenAnswer((_) async => Future.value(null));

    when(mockCacheService.getData(any, bypassExpiration: anyNamed('bypassExpiration'))).thenReturn(null);
    when(mockCacheService.getGroupsFromCache(any)).thenReturn(null);
    when(mockCacheService.getExpensesFromCache(any)).thenReturn(null);
    when(mockCacheService.getSettlementsFromCache(any)).thenReturn(null);
    when(mockCacheService.getUsersFromCache(any)).thenReturn(null);
    when(mockCacheService.getUserFromCache(any)).thenReturn(null);
    
    when(mockCacheService.hasValidData(any, bypassOverride: anyNamed('bypassOverride'))).thenReturn(false);
  });

  group('removeParticipantFromGroup', () {
    final groupId = 'testGroupId';
    final adminId = 'adminUserId';
    final participantToRemoveId = 'participantToRemoveId';
    final otherParticipantId = 'otherParticipantId';

    setUp(() async {
      await mockFirestore.collection('groups').doc(groupId).set(GroupModel(
        id: groupId,
        name: 'Test Group',
        participantIds: [adminId, participantToRemoveId, otherParticipantId],
        adminId: adminId,
        currency: 'USD',
        roles: [
          {'uid': adminId, 'role': 'admin'},
          {'uid': participantToRemoveId, 'role': 'member'},
          {'uid': otherParticipantId, 'role': 'member'},
        ],
      ).toMap());
    });

    test('should remove participant successfully by admin', () async {
      final initialGroupDoc = await mockFirestore.collection('groups').doc(groupId).get();
      expect(initialGroupDoc.data()?['participantIds'], contains(participantToRemoveId));

      final updatedGroup = await firestoreService.removeParticipantFromGroup(
        groupId,
        participantToRemoveId,
        adminId,
      );

      expect(updatedGroup.participantIds, isNot(contains(participantToRemoveId)));
      expect(updatedGroup.roles.where((roleMap) => roleMap['uid'] == participantToRemoveId).isEmpty, isTrue);
      // ACTUALIZADO: Verificar la invalidación de caché correcta
      verify(mockCacheService.removeData('group_$groupId')).called(1);
      verify(mockCacheService.removeData('group_expenses_$groupId')).called(1); // Asumiendo que removeParticipantFromExpenses invalida esto

      final groupDoc = await mockFirestore.collection('groups').doc(groupId).get();
      expect(groupDoc.data()?['participantIds'], isNot(contains(participantToRemoveId)));
      final rolesFromDb = groupDoc.data()?['roles'] as List<dynamic>;
      expect(rolesFromDb.where((roleMap) => (roleMap as Map)['uid'] == participantToRemoveId).isEmpty, isTrue);
    });

    test('should throw exception if non-admin tries to remove participant', () async {
      expect(
        () => firestoreService.removeParticipantFromGroup(
          groupId,
          participantToRemoveId,
          otherParticipantId, // Non-admin
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Only the group administrator can remove participants.'))),
      );
    });

    test('removeParticipantFromGroup should throw exception if trying to remove non-existent participant', () async {
      // Ensure the group is set up for this specific test case
      await mockFirestore.collection('groups').doc('testGroupId').set({
        'id': 'testGroupId',
        'name': 'Test Group',
        'adminId': 'adminUserId',
        'participantIds': ['adminUserId', 'otherUser'],
        'currency': 'USD',
        'roles': [
          {'uid': 'adminUserId', 'role': 'admin'},
          {'uid': 'otherUser', 'role': 'member'}
        ]
      });

      expect(
        () async => await firestoreService.removeParticipantFromGroup('testGroupId', 'nonExistentUserId', 'adminUserId'),
        throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            // Using equals for an exact match of the exception message string
            equals("Exception: Participant with ID 'nonExistentUserId' not found in group 'testGroupId'.")
        ))
      );
    });

    test('removeParticipantFromGroup should throw exception if admin tries to remove themselves', () async {
      expect(
        () => firestoreService.removeParticipantFromGroup(
          groupId,
          adminId, // Admin removing themselves
          adminId,
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('The group administrator cannot be removed.'))),
      );
    });

     test('should remove participant from expenses when removed from group', () async {
      final expenseId = 'testExpenseId';
      await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(expenseId).set(ExpenseModel(
        id: expenseId,
        groupId: groupId,
        description: 'Test Expense',
        amount: 100.0,
        payers: [{'userId': adminId, 'amount': 100.0}],
        participantIds: [adminId, participantToRemoveId],
        date: DateTime.now(),
        category: 'Test',
        createdBy: adminId,
        splitType: 'custom',
        customSplits: [
            {'userId': participantToRemoveId, 'amount': 50.0},
            {'userId': adminId, 'amount': 50.0}
        ],
      ).toMap());
      
      when(mockCacheService.getData('expenses_$groupId', bypassExpiration: true)).thenReturn(null);


      await firestoreService.removeParticipantFromGroup(
        groupId,
        participantToRemoveId,
        adminId,
      );

      final expenseDoc = await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(expenseId).get();
      final expenseData = ExpenseModel.fromMap(expenseDoc.data()!, expenseDoc.id);
      expect(expenseData.participantIds, isNot(contains(participantToRemoveId)));
      expect(expenseData.customSplits?.where((split) => split['userId'] == participantToRemoveId).isEmpty, isTrue);
      expect(expenseData.amount, 100.0); 
    });


    test('should delete expense if last participant is removed when removing from group', () async {
      final expenseId = 'singleParticipantExpense';
      await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(expenseId).set(ExpenseModel(
        id: expenseId,
        groupId: groupId,
        description: 'Single Participant Expense',
        amount: 50.0,
        payers: [{'userId': participantToRemoveId, 'amount': 50.0}], 
        participantIds: [participantToRemoveId],
        date: DateTime.now(),
        category: 'Test',
        createdBy: adminId,
        splitType: 'custom',
        customSplits: [{'userId': participantToRemoveId, 'amount': 50.0}],
      ).toMap());

      var expenseDoc = await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(expenseId).get();
      expect(expenseDoc.exists, isTrue);

      when(mockCacheService.getData('expenses_$groupId', bypassExpiration: true)).thenReturn(null);


      await firestoreService.removeParticipantFromGroup(
        groupId,
        participantToRemoveId,
        adminId,
      );

      expenseDoc = await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(expenseId).get();
      expect(expenseDoc.exists, isFalse);
    });
  });

  group('removeParticipantFromExpenses', () {
    final groupId = 'testGroupId';
    final expenseId = 'testExpenseId';
    final participantToRemoveId = 'participant1';
    final otherParticipantId = 'participant2';
    final payerId = 'payerId';

    setUp(() async {
      await mockFirestore.collection('groups').doc(groupId).set(GroupModel(
        id: groupId,
        name: 'Test Group for Expenses',
        participantIds: [participantToRemoveId, otherParticipantId, payerId],
        adminId: payerId,
        currency: 'USD',
        roles: [
          {'uid': payerId, 'role': 'admin'},
          {'uid': participantToRemoveId, 'role': 'member'},
          {'uid': otherParticipantId, 'role': 'member'},
        ],
      ).toMap());
      when(mockCacheService.getData('expenses_$groupId', bypassExpiration: true)).thenReturn(null);
    });

    test('should remove participant from expense and update customSplits', () async {
      await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(expenseId).set(ExpenseModel(
        id: expenseId,
        groupId: groupId,
        description: 'Test Expense',
        amount: 100.0,
        date: DateTime.now(),
        participantIds: [participantToRemoveId, otherParticipantId],
        payers: [{'userId': payerId, 'amount': 100.0}],
        createdBy: payerId,
        splitType: 'custom',
        customSplits: [
          {'userId': participantToRemoveId, 'amount': 50.0},
          {'userId': otherParticipantId, 'amount': 50.0},
        ],
      ).toMap());

      await firestoreService.removeParticipantFromExpenses(groupId, participantToRemoveId);

      final expenseDoc = await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(expenseId).get();
      expect(expenseDoc.exists, isTrue);
      final expenseData = ExpenseModel.fromMap(expenseDoc.data()!, expenseDoc.id);

      expect(expenseData.participantIds, isNot(contains(participantToRemoveId)));
      expect(expenseData.participantIds, contains(otherParticipantId));
      expect(expenseData.customSplits?.any((split) => split['userId'] == participantToRemoveId), isFalse);
      expect(expenseData.customSplits?.any((split) => split['userId'] == otherParticipantId), isTrue);
      expect(expenseData.amount, 100.0); 
      // ACTUALIZADO: Verificar la invalidación de caché correcta
      verify(mockCacheService.removeData('group_expenses_$groupId')).called(1);
    });

    test('should delete expense if last participant is removed', () async {
      await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(expenseId).set(ExpenseModel(
        id: expenseId,
        groupId: groupId,
        description: 'Single Participant Expense',
        amount: 50.0,
        date: DateTime.now(),
        participantIds: [participantToRemoveId],
        payers: [{'userId': payerId, 'amount': 50.0}],
        createdBy: payerId,
        splitType: 'custom',
        customSplits: [{'userId': participantToRemoveId, 'amount': 50.0}],
      ).toMap());

      await firestoreService.removeParticipantFromExpenses(groupId, participantToRemoveId);

      final expenseDoc = await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(expenseId).get();
      expect(expenseDoc.exists, isFalse);
      // ACTUALIZADO: Verificar la invalidación de caché correcta
      verify(mockCacheService.removeData('group_expenses_$groupId')).called(1);
    });

    test('should not modify expense if participant is not involved', () async {
      final initialExpense = ExpenseModel(
        id: expenseId,
        groupId: groupId,
        description: 'Test Expense',
        amount: 100.0,
        date: DateTime.now(),
        participantIds: [otherParticipantId], // participantToRemoveId ('participant1') is NOT here
        payers: [{'userId': payerId, 'amount': 100.0}],
        createdBy: payerId,
        splitType: 'custom',
        customSplits: [{'userId': otherParticipantId, 'amount': 100.0}],
      );
      await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(expenseId).set(initialExpense.toMap());

      await firestoreService.removeParticipantFromExpenses(groupId, participantToRemoveId); // participantToRemoveId is 'participant1'

      final expenseDoc = await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(expenseId).get();
      expect(expenseDoc.exists, isTrue);
      final expenseData = ExpenseModel.fromMap(expenseDoc.data()!, expenseDoc.id);

      expect(expenseData.participantIds, orderedEquals(initialExpense.participantIds));
      // Using predicate to compare lists of maps for customSplits
      expect(expenseData.customSplits, predicate((dynamic actualSplitsDynamic) {
        final actualSplits = actualSplitsDynamic as List<Map<String, dynamic>>?;
        if (actualSplits == null && initialExpense.customSplits == null) return true;
        if (actualSplits == null || initialExpense.customSplits == null) return false;
        if (actualSplits.length != initialExpense.customSplits!.length) return false;
        for (int i = 0; i < actualSplits.length; i++) {
          if (actualSplits[i]['userId'] != initialExpense.customSplits![i]['userId'] ||
              actualSplits[i]['amount'] != initialExpense.customSplits![i]['amount']) {
            return false;
          }
        }
        return true;
      }));
      expect(expenseData.amount, initialExpense.amount);
      
      // The service method always invalidates this cache key upon execution if it proceeds past initial checks.
      verify(mockCacheService.removeData('group_expenses_$groupId')).called(1);
    });

     test('should correctly update customSplits when a participant is removed', () async {
      await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(expenseId).set(ExpenseModel(
        id: expenseId,
        groupId: groupId,
        description: 'Complex Split Expense',
        amount: 150.0,
        date: DateTime.now(),
        participantIds: [participantToRemoveId, otherParticipantId, payerId],
        payers: [{'userId': payerId, 'amount': 150.0}],
        createdBy: payerId,
        splitType: 'custom',
        customSplits: [
          {'userId': participantToRemoveId, 'amount': 50.0},
          {'userId': otherParticipantId, 'amount': 70.0},
          {'userId': payerId, 'amount': 30.0},
        ],
      ).toMap());

      await firestoreService.removeParticipantFromExpenses(groupId, participantToRemoveId);

      final expenseDoc = await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(expenseId).get();
      final expenseData = ExpenseModel.fromMap(expenseDoc.data()!, expenseDoc.id);

      expect(expenseData.participantIds, isNot(contains(participantToRemoveId)));
      expect(expenseData.customSplits?.any((split) => split['userId'] == participantToRemoveId), isFalse);
      expect(expenseData.customSplits?.length, 2);
      final expectedSplits = [
        {'userId': otherParticipantId, 'amount': 70.0},
        {'userId': payerId, 'amount': 30.0},
      ];
      expect(expenseData.customSplits, predicate((splits) => 
        splits != null &&
        expectedSplits.every((expectedSplit) => 
          (splits as List<Map<String,dynamic>>).any((actualSplit) => 
            actualSplit['userId'] == expectedSplit['userId'] && actualSplit['amount'] == expectedSplit['amount']
          )
        ) && (splits as List<Map<String,dynamic>>).length == expectedSplits.length
      ));
      expect(expenseData.amount, 150.0);
    });

    test('removeParticipantFromExpenses should handle multiple expenses correctly, only modifying relevant ones', () async {
      final expense1 = ExpenseModel(id: 'expense1', groupId: 'testGroupId', description: 'Expense 1', amount: 100, payers: [{'userId': 'payerId', 'amount': 100.0}], participantIds: ['participant1', 'participantToRemove'], date: DateTime.now(), createdBy: 'payerId', splitType: 'custom', customSplits: [ { 'userId': 'participant1', 'amount': 50.0 }, { 'userId': 'participantToRemove', 'amount': 50.0 }]);
      final expense2 = ExpenseModel(id: 'expense2', groupId: 'testGroupId', description: 'Expense 2', amount: 200, payers: [{'userId': 'payerId', 'amount': 200.0}], participantIds: ['participant2', 'payerId'], date: DateTime.now(), createdBy: 'payerId', splitType: 'custom', customSplits: [ { 'userId': 'participant2', 'amount': 100.0 }, { 'userId': 'payerId', 'amount': 100.0 }]);
    
      // Populate Firestore directly
      await mockFirestore.collection('groups').doc('testGroupId').collection('expenses').doc('expense1').set(expense1.toMap());
      await mockFirestore.collection('groups').doc('testGroupId').collection('expenses').doc('expense2').set(expense2.toMap());

      await firestoreService.removeParticipantFromExpenses('testGroupId', 'participantToRemove');

      // Verify expense1 was updated by fetching it
      final doc1 = await mockFirestore.collection('groups').doc('testGroupId').collection('expenses').doc('expense1').get();
      expect(doc1.exists, isTrue);
      final updatedExpense1Data = doc1.data()!;
      expect(updatedExpense1Data['participantIds'], equals(['participant1']));
      expect(updatedExpense1Data['customSplits'], equals([{'userId': 'participant1', 'amount': 50.0}]));
    
      // Verify expense2 was NOT updated by fetching it
      final doc2 = await mockFirestore.collection('groups').doc('testGroupId').collection('expenses').doc('expense2').get();
      expect(doc2.exists, isTrue);
      final expense2Data = doc2.data()!;
      expect(expense2Data['participantIds'], equals(['participant2', 'payerId']));
      expect(expense2Data['customSplits'], equals([{'userId': 'participant2', 'amount': 100.0}, {'userId': 'payerId', 'amount': 100.0}]));
    
      verify(mockCacheService.removeData('group_expenses_testGroupId')).called(1);
    });
  });

  group('CRUD Operations', () {
    final groupId = 'testGroupId';
    final adminId = 'adminUserId';

    setUp(() async {
      await mockFirestore.collection('groups').doc(groupId).set(GroupModel(
        id: groupId,
        name: 'Test Group',
        participantIds: [adminId],
        adminId: adminId,
        currency: 'USD',
        roles: [
          {'uid': adminId, 'role': 'admin'},
        ],
      ).toMap());
    });

    test('addExpense should add expense and update cache', () async {
      when(mockConnectivityService.hasConnection).thenReturn(true);
      final expense = ExpenseModel(
        id: 'newExpenseId',
        groupId: groupId,
        description: 'New Expense',
        amount: 100.0,
        date: DateTime.now(),
        participantIds: [adminId],
        payers: [{'userId': adminId, 'amount': 100.0}],
        createdBy: adminId,
        splitType: 'equal',
      );

      await firestoreService.addExpense(expense);

      final expenseDoc = await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc('newExpenseId').get();
      expect(expenseDoc.exists, isTrue);
      final expenseData = ExpenseModel.fromMap(expenseDoc.data()!, expenseDoc.id);
      expect(expenseData.description, expense.description);
      expect(expenseData.amount, expense.amount);
      expect(expenseData.participantIds, expense.participantIds);

      verify(mockCacheService.removeData('group_expenses_${expense.groupId}')).called(1);
    });

    test('updateExpense should update expense and invalidate cache', () async {
      when(mockConnectivityService.hasConnection).thenReturn(true);
      final existingExpenseId = 'existingExpenseId';
      // Ensure the expense exists before updating
      final originalExpense = ExpenseModel(
        id: existingExpenseId,
        groupId: groupId,
        description: 'Original Expense',
        amount: 100.0,
        date: DateTime.now().subtract(Duration(days:1)), // ensure different date from updated
        participantIds: [adminId],
        payers: [{'userId': adminId, 'amount': 100.0}],
        createdBy: adminId,
        splitType: 'equal',
      );
      await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(existingExpenseId).set(originalExpense.toMap());

      final updatedExpense = ExpenseModel(
        id: existingExpenseId, // Use the same ID
        groupId: groupId,
        description: 'Updated Expense',
        amount: 75.0,
        date: DateTime.now(),
        participantIds: [adminId],
        payers: [{'userId': adminId, 'amount': 75.0}],
        createdBy: adminId,
        splitType: 'equal',
      );

      await firestoreService.updateExpense(updatedExpense);

      final expenseDoc = await mockFirestore.collection('groups').doc(groupId).collection('expenses').doc(existingExpenseId).get();
      expect(expenseDoc.exists, isTrue);
      final expenseData = ExpenseModel.fromMap(expenseDoc.data()!, expenseDoc.id);
      expect(expenseData.description, updatedExpense.description);
      expect(expenseData.amount, updatedExpense.amount);

      verify(mockCacheService.removeData('group_expenses_${updatedExpense.groupId}')).called(1);
    });

    test('deleteExpense should remove specific expense and invalidate cache', () async {
      // const groupId = 'testGroupId'; // No es necesario redeclarar, usar el del setUp
      // const expenseId = 'testExpenseId'; // No es necesario redeclarar, usar el del setUp
      // final expense = ExpenseModel(id: expenseId, groupId: groupId, amount: 100, description: 'Test', date: DateTime.now(), paidBy: 'user1', participantIds: ['user1', 'user2']);

      // Mock the behavior of deleteExpense if it's not directly calling Firestore methods
      // that are already part of FakeFirebaseFirestore's capabilities.
      // For this test, we assume firestoreService.deleteExpense will be implemented
      // and will interact with Firestore and CacheService as expected.

      await firestoreService.deleteExpense(groupId, 'expenseToDelete'); // Usar las variables del setUp

      // Verify that the cache invalidation method was called correctly.
      // Assuming deleteExpense invalidates the cache for the specific group's expenses.
      verify(mockCacheService.removeData('group_expenses_$groupId')).called(1);
      
      // Optionally, verify that removeKeysWithPattern was not called if that's the expected behavior
      verifyNever(mockCacheService.removeKeysWithPattern(any));
    });

    test('addSettlement should add a new settlement and invalidate cache', () async {
      when(mockConnectivityService.hasConnection).thenReturn(true);
      final settlement = SettlementModel(
        id: 'newSettlementId',
        groupId: groupId,
        fromUserId: adminId,
        toUserId: 'otherUserId',
        amount: 50.0,
        date: DateTime.now(),
        status: 'pending', // Usar String en lugar de Enum
        createdBy: adminId,
      );

      await firestoreService.addSettlement(settlement);

      final settlementDoc = await mockFirestore.collection('groups').doc(groupId).collection('settlements').doc('newSettlementId').get();
      expect(settlementDoc.exists, isTrue);
      final settlementData = SettlementModel.fromMap(settlementDoc.data()!, settlementDoc.id);
      expect(settlementData.amount, settlement.amount);
      expect(settlementData.status, settlement.status);

      verify(mockCacheService.removeData('group_settlements_${settlement.groupId}')).called(1);
    });
  });

  group('deleteSettlement', () {
    final groupId = 'testGroupId';
    final settlementId = 'settlementToDelete';
    final adminId = 'adminUserId';

    setUp(() async {
      await mockFirestore.collection('groups').doc(groupId).set(GroupModel(
        id: groupId,
        name: 'Test Group',
        participantIds: [adminId, 'user2'],
        adminId: adminId,
        currency: 'USD',
        roles: [
          {'uid': adminId, 'role': 'admin'},
          {'uid': 'user2', 'role': 'member'},
        ],
      ).toMap());

      await mockFirestore.collection('groups').doc(groupId).collection('settlements').doc(settlementId).set(SettlementModel(
        id: settlementId,
        groupId: groupId,
        fromUserId: adminId,
        toUserId: 'user2',
        amount: 25.0,
        date: DateTime.now(),
        status: 'pending', // Usar String en lugar de Enum
        createdBy: adminId,
      ).toMap());
    });

    test('should delete settlement and invalidate cache', () async {
      when(mockConnectivityService.hasConnection).thenReturn(true);

      await firestoreService.deleteSettlement(groupId, settlementId);

      final settlementDoc = await mockFirestore.collection('groups').doc(groupId).collection('settlements').doc(settlementId).get();
      expect(settlementDoc.exists, isFalse);

      verify(mockCacheService.removeData('group_settlements_$groupId')).called(1);
    });
  });

  group('createGroup', () {
    test('should create group and invalidate user group caches', () async {
      final group = GroupModel(
        id: 'newGroupId',
        name: 'New Group',
        participantIds: ['creator'],
        adminId: 'creator',
        currency: 'USD',
        roles: [ {'uid': 'creator', 'role': 'admin'} ],
      );

      await firestoreService.createGroup(group);

      final doc = await mockFirestore.collection('groups').doc('newGroupId').get();
      expect(doc.exists, isTrue);
      verify(mockCacheService.removeKeysWithPattern('user_groups_')).called(1);
    });
  });

  group('updateGroup', () {
    test('should update group and invalidate cache', () async {
      final initialGroupId = 'groupToUpdateId';
      final adminUserId = 'adminForUpdate';

      // Ensure the group exists before updating
      await mockFirestore.collection('groups').doc(initialGroupId).set(GroupModel(
        id: initialGroupId,
        name: 'Initial Group Name',
        adminId: adminUserId,
        participantIds: [adminUserId],
        currency: 'EUR',
        roles: [{'uid': adminUserId, 'role': 'admin'}],
        description: 'Initial description',
      ).toMap());

      final groupToUpdate = GroupModel(
        id: initialGroupId,
        name: 'Updated Group Name',
        adminId: adminUserId, // Admin ID typically doesn't change or is validated
        participantIds: [adminUserId, 'newUserInGroup'],
        description: 'Updated description',
        currency: 'USD',
        roles: [
          {'uid': adminUserId, 'role': 'admin'},
          {'uid': 'newUserInGroup', 'role': 'member'}
        ],
      );

      await firestoreService.updateGroup(groupToUpdate);

      // Verify cache invalidations
      verify(mockCacheService.removeData('group_${groupToUpdate.id}')).called(1);
      verify(mockCacheService.removeKeysWithPattern('user_groups_')).called(1);

      // Verify the update in fakeFirestore
      final updatedDoc = await mockFirestore.collection('groups').doc(initialGroupId).get();
      expect(updatedDoc.exists, isTrue);
      final updatedData = GroupModel.fromMap(updatedDoc.data()!, updatedDoc.id);
      expect(updatedData.name, 'Updated Group Name');
      expect(updatedData.currency, 'USD');
      expect(updatedData.participantIds, contains('newUserInGroup'));
      expect(updatedData.description, 'Updated description');
    });
  });

  group('deleteGroup', () {
    final groupId = 'testGroupId';
    final adminId = 'adminUserId';

    setUp(() async {
      await mockFirestore.collection('groups').doc(groupId).set(GroupModel(
        id: groupId,
        name: 'Test Group',
        participantIds: [adminId],
        adminId: adminId,
        currency: 'USD',
        roles: [
          {'uid': adminId, 'role': 'admin'},
        ],
      ).toMap());
    });

    test('should delete group and invalidate all related caches', () async {
      when(mockConnectivityService.hasConnection).thenReturn(true);

      // Ensure the group exists before attempting deletion
      await mockFirestore.collection('groups').doc(groupId).set(GroupModel(
        id: groupId,
        name: 'Test Group For Deletion',
        participantIds: [adminId],
        adminId: adminId,
        currency: 'USD',
        roles: [{'uid': adminId, 'role': 'admin'}],
      ).toMap());


      await firestoreService.deleteGroup(groupId);

      final groupDoc = await mockFirestore.collection('groups').doc(groupId).get();
      expect(groupDoc.exists, isFalse);

      // Correct verifications based on firestore_service.dart's deleteGroup method
      verify(mockCacheService.removeKeysWithPattern('group_${groupId}_')).called(1);
      verify(mockCacheService.removeData('group_$groupId')).called(1);
      verify(mockCacheService.removeKeysWithPattern('user_groups_')).called(1); 

      // The following lines were removed as cleanGroupExpensesAndSettlements,
      // which is called by deleteGroup, DOES invalidate these cache entries.
      // verifyNever(mockCacheService.removeData('group_expenses_$groupId'));
      // verifyNever(mockCacheService.removeData('group_settlements_$groupId'));
    });
  });

  group('addParticipantToGroup', () {
    final groupId = 'testGroupId';
    final userIdToAdd = 'newUserId';
    final adminId = 'adminUserId';

    setUp(() async {
      await mockFirestore.collection('groups').doc(groupId).set(GroupModel(
        id: groupId,
        name: 'Test Group',
        participantIds: [adminId],
        adminId: adminId,
        currency: 'USD',
        roles: [
          {'uid': adminId, 'role': 'admin'},
        ],
      ).toMap());
    });

    test('should add participant to group and update caches', () async {
      when(mockConnectivityService.hasConnection).thenReturn(true);
      final userToAdd = UserModel(id: userIdToAdd, name: 'New User', email: 'newuser@example.com');

      await firestoreService.addParticipantToGroup(groupId, userToAdd);

      final groupDoc = await mockFirestore.collection('groups').doc(groupId).get();
      expect(groupDoc.exists, isTrue);
      final updatedParticipantIds = List<String>.from(groupDoc.data()?['participantIds']);
      expect(updatedParticipantIds, contains(userIdToAdd));

      // Verificar que se haya llamado a removeData para el grupo y el usuario
      verify(mockCacheService.removeData('group_$groupId')).called(1);
      verify(mockCacheService.removeData('user_groups_${userIdToAdd}')).called(1);
    });
  });

  group('removeParticipantFromGroup', () {
    final groupId = 'testGroupId';
    final participantIdToRemove = 'participantToRemoveId';
    final adminId = 'adminUserId';

    setUp(() async {
      await mockFirestore.collection('groups').doc(groupId).set(GroupModel(
        id: groupId,
        name: 'Test Group',
        participantIds: [adminId, participantIdToRemove],
        adminId: adminId,
        currency: 'USD',
        roles: [
          {'uid': adminId, 'role': 'admin'},
          {'uid': participantIdToRemove, 'role': 'member'},
        ],
      ).toMap());
    });

    test('should remove participant from group and update caches', () async {
      when(mockConnectivityService.hasConnection).thenReturn(true);

      await firestoreService.removeParticipantFromGroup(groupId, participantIdToRemove, adminId);

      final groupDoc = await mockFirestore.collection('groups').doc(groupId).get();
      expect(groupDoc.exists, isTrue);
      final updatedParticipantIds = List<String>.from(groupDoc.data()?['participantIds']);
      expect(updatedParticipantIds, isNot(contains(participantIdToRemove)));

      // Verificar que se haya llamado a removeData para el grupo y las listas de grupos de usuario
      verify(mockCacheService.removeData('group_$groupId')).called(1);
      verify(mockCacheService.removeData('user_groups_${participantIdToRemove}')).called(1);
    });
  });

  group('Retrieval methods', () {
    final groupId = 'retrievalGroup';
    final userId = 'testUser';

    setUp(() async {
      await mockFirestore.collection('groups').doc(groupId).set(GroupModel(
        id: groupId,
        name: 'Test Group',
        participantIds: [userId],
        adminId: userId,
        currency: 'USD',
        roles: [ {'uid': userId, 'role': 'admin'} ],
      ).toMap());
    });

    test('getGroupOnce returns cached group if present', () async {
      when(mockCacheService.getData('group_$groupId'))
          .thenReturn({'name': 'Cached Group'});

      final group = await firestoreService.getGroupOnce(groupId);

      expect(group.name, 'Cached Group');
      verify(mockCacheService.getData('group_$groupId')).called(1);
      verifyNever(mockCacheService.setData(any, any));
    });

    test('getGroupOnce fetches from Firestore and caches when not cached', () async {
      when(mockCacheService.getData(any)).thenReturn(null);

      final group = await firestoreService.getGroupOnce(groupId);

      expect(group.name, 'Test Group');
      verify(mockCacheService.setData('group_$groupId', any)).called(1);
    });

    test('getGroupOnce throws when offline and not cached', () async {
      when(mockCacheService.getData(any)).thenReturn(null);
      when(mockConnectivityService.hasConnection).thenReturn(false);

      expect(() => firestoreService.getGroupOnce(groupId), throwsException);
    });

    test('getUserGroupsOnce returns cached list if present', () async {
      when(mockCacheService.getGroupsFromCache(userId))
          .thenReturn([GroupModel(id: 'cg', name: 'Cached', participantIds: [userId], adminId: userId, roles: [])]);

      final groups = await firestoreService.getUserGroupsOnce(userId);
      expect(groups.length, 1);
      expect(groups.first.name, 'Cached');
    });

    test('getUserGroupsOnce fetches from Firestore and caches when not cached', () async {
      when(mockCacheService.getGroupsFromCache(userId)).thenReturn(null);

      final groups = await firestoreService.getUserGroupsOnce(userId);
      expect(groups.length, 1);
      expect(groups.first.name, 'Test Group');
      verify(mockCacheService.cacheGroups(any, userId)).called(1);
    });
  });

  group('Additional methods', () {
    final groupId = 'extraGroup';
    final userId = 'extraUser';

    setUp(() async {
      await mockFirestore.collection('groups').doc(groupId).set(GroupModel(
        id: groupId,
        name: 'Extra Group',
        participantIds: [userId],
        adminId: userId,
        currency: 'USD',
        roles: [ {'uid': userId, 'role': 'admin'} ],
      ).toMap());

      await mockFirestore.collection('users').doc(userId).set(UserModel(
        id: userId,
        name: 'User',
        email: 'user@example.com',
      ).toMap());
    });

    test('getExpensesOnce fetches from Firestore and caches when not cached', () async {
      final expense = ExpenseModel(
        id: 'e1',
        groupId: groupId,
        description: 'e',
        amount: 1.0,
        date: DateTime.now(),
        participantIds: [userId],
        payers: [ {'userId': userId, 'amount': 1.0} ],
        createdBy: userId,
        splitType: 'equal',
      );
      await mockFirestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .doc(expense.id)
          .set(expense.toMap());

      when(mockCacheService.getExpensesFromCache(groupId)).thenReturn(null);

      final expenses = await firestoreService.getExpensesOnce(groupId);

      expect(expenses.length, 1);
      expect(expenses.first.id, expense.id);
      verify(mockCacheService.cacheExpenses(any, groupId)).called(1);
    });

    test('getExpensesOnce returns cached expenses if present', () async {
      when(mockCacheService.getExpensesFromCache(groupId))
          .thenReturn([ExpenseModel(
        id: 'cached',
        groupId: groupId,
        description: 'c',
        amount: 2.0,
        date: DateTime.now(),
        participantIds: [userId],
        payers: [ {'userId': userId, 'amount': 2.0} ],
        createdBy: userId,
        splitType: 'equal',
      )]);

      final expenses = await firestoreService.getExpensesOnce(groupId);
      expect(expenses.length, 1);
      expect(expenses.first.id, 'cached');
      verifyNever(mockCacheService.cacheExpenses(any, any));
    });

    test('getDocumentSnapshot retrieves document', () async {
      final doc = await firestoreService.getDocumentSnapshot('groups/$groupId');
      expect(doc, isNotNull);
      expect(doc?.id, groupId);
    });

    test('getExpensesCount returns correct count', () async {
      await mockFirestore.collection('groups').doc(groupId).collection('expenses')
          .add({'description': 't', 'amount': 1, 'date': DateTime.now()});
      await mockFirestore.collection('groups').doc(groupId).collection('expenses')
          .add({'description': 't2', 'amount': 2, 'date': DateTime.now()});

      final count = await firestoreService.getExpensesCount(groupId);
      expect(count, 2);
    });

    test('cleanGroupExpensesAndSettlements removes all docs', () async {
      await mockFirestore.collection('groups').doc(groupId).collection('expenses')
          .add({'description': 'e', 'amount': 1, 'date': DateTime.now()});
      await mockFirestore.collection('groups').doc(groupId).collection('settlements')
          .add({'amount': 5, 'date': DateTime.now(), 'fromUserId': userId, 'toUserId': userId, 'createdBy': userId, 'status': 'pending'});

      await firestoreService.cleanGroupExpensesAndSettlements(groupId);

      final expSnap = await mockFirestore.collection('groups').doc(groupId).collection('expenses').get();
      final setSnap = await mockFirestore.collection('groups').doc(groupId).collection('settlements').get();
      expect(expSnap.docs, isEmpty);
      expect(setSnap.docs, isEmpty);
      verify(mockCacheService.removeData('group_expenses_$groupId')).called(1);
      verify(mockCacheService.removeData('group_settlements_$groupId')).called(1);
    });

    test('fetchUsersByIds merges cached and remote users', () async {
      when(mockCacheService.getUsersFromCache([userId, 'u2']))
          .thenReturn([UserModel(id: userId, name: 'User', email: 'user@example.com')]);
      await mockFirestore.collection('users').doc('u2').set(UserModel(id: 'u2', name: 'Other', email: 'o@example.com').toMap());

      final users = await firestoreService.fetchUsersByIds([userId, 'u2']);
      expect(users.length, 2);
      verify(mockCacheService.cacheUsers(any)).called(1);
    });

    test('batch operations update, create and delete documents', () async {
      await mockFirestore.collection('groups').doc('b1').set({'name': 'old'});

      await firestoreService.batchUpdate(updates: [
        {'path': 'groups/b1', 'data': {'name': 'new'}},
      ]);

      final updated = await mockFirestore.collection('groups').doc('b1').get();
      expect(updated.data()?['name'], 'new');

      await firestoreService.batchCreate(creates: [
        {'path': 'groups/b2', 'data': {'name': 'created'}},
      ]);

      final created = await mockFirestore.collection('groups').doc('b2').get();
      expect(created.exists, isTrue);

      await firestoreService.batchDelete(paths: ['groups/b2']);
      final deleted = await mockFirestore.collection('groups').doc('b2').get();
      expect(deleted.exists, isFalse);
    });

    test('getExpensesPaginated returns paged results', () async {
      final e1 = ExpenseModel(
        id: 'p1',
        groupId: groupId,
        description: 'e1',
        amount: 1,
        date: DateTime(2022,1,1),
        participantIds: [userId],
        payers: [ {'userId': userId, 'amount': 1.0} ],
        createdBy: userId,
        splitType: 'equal',
      );
      final e2 = ExpenseModel(
        id: 'p2',
        groupId: groupId,
        description: 'e2',
        amount: 2,
        date: DateTime(2022,2,1),
        participantIds: [userId],
        payers: [ {'userId': userId, 'amount': 2.0} ],
        createdBy: userId,
        splitType: 'equal',
      );
      final e3 = ExpenseModel(
        id: 'p3',
        groupId: groupId,
        description: 'e3',
        amount: 3,
        date: DateTime(2022,3,1),
        participantIds: [userId],
        payers: [ {'userId': userId, 'amount': 3.0} ],
        createdBy: userId,
        splitType: 'equal',
      );
      await mockFirestore.collection('groups').doc(groupId).collection('expenses')
          .doc(e1.id).set(e1.toMap());
      await mockFirestore.collection('groups').doc(groupId).collection('expenses')
          .doc(e2.id).set(e2.toMap());
      await mockFirestore.collection('groups').doc(groupId).collection('expenses')
          .doc(e3.id).set(e3.toMap());

      final first = await firestoreService.getExpensesPaginated(groupId, 2, null);
      expect(first.length, 2);
    });

    test('getSettlementsOnce fetches and caches settlements', () async {
      when(mockCacheService.getSettlementsFromCache(groupId)).thenReturn(null);
      await mockFirestore.collection('groups').doc(groupId).collection('settlements')
          .add({
            'amount': 5,
            'date': Timestamp.now(),
            'fromUserId': userId,
            'toUserId': userId,
            'status': 'pending',
            'createdBy': userId,
          });

      final settlements = await firestoreService.getSettlementsOnce(groupId);
      expect(settlements.length, 1);
      verify(mockCacheService.cacheSettlements(any, groupId)).called(1);
    });
  });

}
