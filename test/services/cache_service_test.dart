import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitup_application/services/cache_service.dart';
import 'package:splitup_application/models/group_model.dart';
import 'package:splitup_application/models/expense_model.dart';
import 'package:splitup_application/models/user_model.dart';
import 'package:splitup_application/models/settlement_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_async/fake_async.dart';
import 'package:clock/clock.dart';

// Helper class to test non-primitive caching
class _Unsupported {
  final String value;
  _Unsupported(this.value);
}

void main() {
  late CacheService cacheService;
  const String testUserId = 'testUser123';
  const String otherUserId = 'otherUser456';
  final DateTime fixedNow = DateTime(2023, 1, 1, 12, 0, 0);


  GroupModel createTestGroup(String id, {
    DateTime? createdAt,
    DateTime? updatedAt,
    // Parámetros de GroupModel actualizados:
    String? photoUrl,
    double totalExpenses = 0.0,
    int expensesCount = 0,
    Map<String, dynamic>? lastExpense,
  }) {
    return GroupModel(
      id: id,
      name: 'Test Group $id',
      description: 'Description for $id',
      participantIds: [testUserId, otherUserId],
      adminId: testUserId,
      currency: 'USD',
      roles: [{ 'uid': testUserId, 'role': 'admin'}, { 'uid': otherUserId, 'role': 'member'}],
      photoUrl: photoUrl ?? 'http://example.com/image.png',
      createdAt: createdAt ?? fixedNow,
      updatedAt: updatedAt ?? fixedNow,
      totalExpenses: totalExpenses,
      expensesCount: expensesCount,
      lastExpense: lastExpense,
      participantBalances: [
        {'userId': testUserId, 'balances': {'USD': 50.0}},
        {'userId': otherUserId, 'balances': {'USD': -50.0}},
      ],
    );
  }

  ExpenseModel createTestExpense(String id, String groupId, {
    DateTime? date,
    List<String>? attachments,
    List<Map<String, dynamic>>? customSplits,
    bool isRecurring = false,
    String? recurringRule,
    bool isLocked = false,
  }) {
    return ExpenseModel(
      id: id,
      groupId: groupId,
      description: 'Test Expense $id',
      amount: 20.0,
      date: date ?? fixedNow,
      participantIds: [testUserId, otherUserId],
      payers: [{ 'userId': testUserId, 'amount': 20.0}],
      createdBy: testUserId,
      category: 'Food',
      splitType: 'equal',
      currency: 'USD',
      attachments: attachments,
      customSplits: customSplits,
      isRecurring: isRecurring,
      recurringRule: recurringRule,
      isLocked: isLocked,
    );
  }
  
  UserModel createTestUser(String id, {String? photoUrl}) {
    return UserModel(
      id: id,
      name: 'Test User $id',
      email: '$id@example.com',
      photoUrl: photoUrl ?? 'http://example.com/$id.png',
    );
  }

  SettlementModel createTestSettlement(String id, String groupId, {
    double amount = 50.0, 
    DateTime? date, 
    String fromUserId = testUserId, 
    String toUserId = otherUserId,
    String createdBy = testUserId,
    String status = 'pending',
    String? note,
  }) {
    return SettlementModel(
      id: id,
      groupId: groupId,
      amount: amount,
      date: date ?? fixedNow,
      fromUserId: fromUserId,
      toUserId: toUserId,
      status: status,
      createdBy: createdBy,
      note: note,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cacheService = CacheService();
    // No await cacheService.init() here, let tests that need it call it or rely on lazy init.
  });

  tearDown(() async {
    await cacheService.clearAll();
  });

  group('CacheService Core Functionality', () {
    test('init should initialize SharedPreferences and set _initialized to true', () async {
      // Ensure it starts uninitialized
      expect(cacheService.isInitialized, isFalse);
      await cacheService.init();
      expect(cacheService.isInitialized, isTrue);
    });

    test('setData and getData should store and retrieve simple data', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'testKey';
          const value = 'testValue';
          await cacheService.setData(key, value, expiration: const Duration(minutes: 5));
          // async.elapse(Duration.zero); // Not needed if SharedPreferences.setMockInitialValues is efficient
          final data = cacheService.getData(key);
          expect(data, equals(value));
        });
      });
    });

    test('getData should return null for non-existent key', () async {
      await cacheService.init();
      final data = cacheService.getData('nonExistentKey');
      expect(data, isNull);
    });

    test('getData should return null for expired data', () {
      fakeAsync((async) {
         withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'expiredKey';
          const value = 'expiredValue';
          const expirationTime = Duration(minutes: 5);
          await cacheService.setData(key, value, expiration: expirationTime);
          
          // Elapse time to just before expiration
          async.elapse(expirationTime - const Duration(seconds: 1));
          expect(cacheService.getData(key), equals(value));

          // Elapse time to just after expiration
          async.elapse(const Duration(seconds: 2)); // Total elapsed: expirationTime + 1 second
          expect(cacheService.getData(key), isNull);
        });
      });
    });

    test('getData with bypassExpiration should return expired data', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'expiredBypassKey';
          const value = 'expiredBypassValue';
          const expirationTime = Duration(minutes: 5);
          await cacheService.setData(key, value, expiration: expirationTime);
          async.elapse(expirationTime + const Duration(seconds: 1));
          final data = cacheService.getData(key, bypassExpiration: true);
          expect(data, equals(value));
        });
      });
    });
    
    test('setData should handle Map data and _convertTimestamps for Timestamps', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'mapWithTimestampKey';
          final timestamp = Timestamp.fromDate(fixedNow);
          final value = {
            'name': 'Test Map',
            'time': timestamp,
            'nested': {'deepTime': timestamp}
          };
          final expectedValue = {
            'name': 'Test Map',
            'time': timestamp.millisecondsSinceEpoch,
            'nested': {'deepTime': timestamp.millisecondsSinceEpoch}
          };
          await cacheService.setData(key, value, expiration: const Duration(minutes: 5));
          final data = cacheService.getData(key);
          expect(data, equals(expectedValue));
        });
      });
    });

    test('setData should handle List<Map> data with Timestamps', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'listMapWithTimestampKey';
          final timestamp = Timestamp.fromDate(fixedNow);
          final value = [
            {'id': 1, 'time': timestamp},
            {'id': 2, 'time': timestamp, 'nested': {'deepTime': timestamp}}
          ];
          final expectedValue = [
            {'id': 1, 'time': timestamp.millisecondsSinceEpoch},
            {'id': 2, 'time': timestamp.millisecondsSinceEpoch, 'nested': {'deepTime': timestamp.millisecondsSinceEpoch}}
          ];
          await cacheService.setData(key, value, expiration: const Duration(minutes: 5));
          final data = cacheService.getData(key);
          expect(data, equals(expectedValue));
        });
      });
    });

    test('hasValidData should return true for valid data', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'validDataKey';
          await cacheService.setData(key, 'some data', expiration: const Duration(minutes: 5));
          expect(cacheService.hasValidData(key), isTrue);
        });
      });
    });

    test('hasValidData should return false for expired data', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'expiredDataKeyForHasValid';
          const expirationTime = Duration(minutes: 5);
          await cacheService.setData(key, 'some data', expiration: expirationTime);
          async.elapse(expirationTime + const Duration(seconds: 1));
          expect(cacheService.hasValidData(key), isFalse);
        });
      });
    });

    test('hasValidData should return false for non-existent key', () async {
      await cacheService.init();
      expect(cacheService.hasValidData('nonExistentForHasValid'), isFalse);
    });

    test('hasValidData with bypassOverride should return true for expired data', () {
       fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'expiredDataKeyForHasValidBypass';
          const expirationTime = Duration(minutes: 5);
          await cacheService.setData(key, 'some data', expiration: expirationTime);
          async.elapse(expirationTime + const Duration(seconds: 1));
          expect(cacheService.hasValidData(key, bypassOverride: true), isTrue);
        });
      });
    });

    test('removeData should remove data from cache', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'removeKey';
          await cacheService.setData(key, 'data to remove');
          expect(cacheService.getData(key), isNotNull);
          await cacheService.removeData(key);
          expect(cacheService.getData(key), isNull);
        });
      });
    });

    test('removeKeysWithPattern should remove matching keys', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          await cacheService.setData('pattern_abc_1', 'data1');
          await cacheService.setData('pattern_xyz_2', 'data2');
          await cacheService.setData('no_pattern_3', 'data3');
          await cacheService.removeKeysWithPattern('pattern_');
          expect(cacheService.getData('pattern_abc_1'), isNull);
          expect(cacheService.getData('pattern_xyz_2'), isNull);
          expect(cacheService.getData('no_pattern_3'), isNotNull);
        });
      });
    });

    test('clearAll should remove all data from cache', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          await cacheService.setData('key1', 'data1');
          await cacheService.setData('key2', 'data2');
          await cacheService.clearAll();
          expect(cacheService.getData('key1'), isNull);
          expect(cacheService.getData('key2'), isNull);
        });
      });
    });
  });

  group('CacheService Model Specific Functionality', () {
    test('cacheGroups and getGroupsFromCache should work correctly', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          final group1 = createTestGroup('group1');
          final group2 = createTestGroup('group2', createdAt: fixedNow.subtract(const Duration(days: 1)));
          final groups = [group1, group2];
          await cacheService.cacheGroups(groups, testUserId);
          final cachedGroups = cacheService.getGroupsFromCache(testUserId);
          expect(cachedGroups, isNotNull);
          expect(cachedGroups!.length, 2);
          expect(cachedGroups.first.id, group1.id);
          expect(cachedGroups.first.name, group1.name);
          expect(cachedGroups.first.createdAt.millisecondsSinceEpoch, group1.createdAt.millisecondsSinceEpoch);
          expect(cachedGroups.last.id, group2.id);
          expect(cachedGroups.last.updatedAt.millisecondsSinceEpoch, group2.updatedAt.millisecondsSinceEpoch);
          
          async.elapse(CacheService.defaultExpiration + const Duration(seconds: 1));
          expect(cacheService.getGroupsFromCache(testUserId), isNull);
        });
      });
    });
    
    test('getGroupsFromCache should return null if no data', () async {
        await cacheService.init();
        expect(cacheService.getGroupsFromCache('unknownUser'), isNull);
    });

    test('cacheExpenses and getExpensesFromCache should work correctly', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const groupId = 'testGroupForExpenses';
          final expense1 = createTestExpense('expense1', groupId);
          final expense2 = createTestExpense('expense2', groupId, date: fixedNow.subtract(Duration(hours:1)));
          final expenses = [expense1, expense2];
          await cacheService.cacheExpenses(expenses, groupId);
          final cachedExpenses = cacheService.getExpensesFromCache(groupId);
          expect(cachedExpenses, isNotNull);
          expect(cachedExpenses!.length, 2);
          expect(cachedExpenses.first.id, expense1.id);
          expect(cachedExpenses.first.amount, expense1.amount);
          expect(cachedExpenses.first.date.millisecondsSinceEpoch, expense1.date.millisecondsSinceEpoch);
          expect(cachedExpenses.last.date.millisecondsSinceEpoch, expense2.date.millisecondsSinceEpoch);
          
          // Default expiration for expenses is 20 minutes
          async.elapse(const Duration(minutes: 19, seconds: 59)); 
          expect(cacheService.getExpensesFromCache(groupId), isNotNull, reason: "Cache should still be valid before 20 mins");
          
          async.elapse(const Duration(seconds: 2)); // Total 20 mins and 1 sec
          expect(cacheService.getExpensesFromCache(groupId), isNull, reason: "Cache should be invalid after 20 mins");
        });
      });
    });

    test('getExpensesFromCache should return empty list if cached data is empty list', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const groupId = 'groupWithEmptyExpenses';
          await cacheService.cacheExpenses([], groupId);
          final cachedExpenses = cacheService.getExpensesFromCache(groupId);
          expect(cachedExpenses, isNotNull);
          expect(cachedExpenses, isEmpty);
        });
      });
    });

    test('getExpensesFromCache should return null if no data', () async {
        await cacheService.init();
        expect(cacheService.getExpensesFromCache('unknownGroup'), isNull);
    });

    test('cacheSettlements and getSettlementsFromCache should work correctly', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const groupId = 'testGroupForSettlements';
          final settlement1 = createTestSettlement('s1', groupId, date: fixedNow.subtract(const Duration(days: 1)));
          final settlement2 = createTestSettlement('s2', groupId);
          final settlements = [settlement1, settlement2];
          await cacheService.cacheSettlements(settlements, groupId);
          final cachedSettlements = cacheService.getSettlementsFromCache(groupId);
          expect(cachedSettlements, isNotNull);
          expect(cachedSettlements!.length, 2);
          expect(cachedSettlements.first.id, settlement1.id);
          expect(cachedSettlements.first.amount, settlement1.amount);
          expect(cachedSettlements.first.date.millisecondsSinceEpoch, settlement1.date.millisecondsSinceEpoch);
          expect(cachedSettlements.last.id, settlement2.id);
          
          async.elapse(CacheService.defaultExpiration + const Duration(seconds: 1));
          expect(cacheService.getSettlementsFromCache(groupId), isNull);
        });
      });
    });

    test('getSettlementsFromCache should return null if no data', () async {
      await cacheService.init();
      expect(cacheService.getSettlementsFromCache('unknownGroupForSettlements'), isNull);
    });

    test('cacheUsers and getUserFromCache should work correctly', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          final user1 = createTestUser('user1');
          final user2 = createTestUser('user2');
          await cacheService.cacheUsers([user1, user2]);
          final cachedUser1 = cacheService.getUserFromCache('user1');
          expect(cachedUser1, isNotNull);
          expect(cachedUser1!.id, user1.id);
          expect(cachedUser1.email, user1.email);
          final cachedUser2 = cacheService.getUserFromCache('user2');
          expect(cachedUser2, isNotNull);
          expect(cachedUser2!.name, user2.name);
          final cachedUserNonExistent = cacheService.getUserFromCache('nonExistent');
          expect(cachedUserNonExistent, isNull);
        });
      });
    });

    test('getUsersFromCache should retrieve multiple users', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          final user1 = createTestUser('userA');
          final user2 = createTestUser('userB');
          final user3 = createTestUser('userC');
          await cacheService.cacheUsers([user1, user2, user3]);
          final cachedUsers = cacheService.getUsersFromCache(['userA', 'userC', 'userD']);
          expect(cachedUsers, isNotNull);
          expect(cachedUsers!.length, 2);
          expect(cachedUsers.any((u) => u.id == 'userA'), isTrue);
          expect(cachedUsers.any((u) => u.id == 'userC'), isTrue);
          expect(cachedUsers.any((u) => u.id == 'userD'), isFalse);
        });
      });
    });
    
    test('getUsersFromCache should return null if no users found for given ids', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          final user1 = createTestUser('userOnlyOne');
          await cacheService.cacheUsers([user1]);
          final cachedUsers = cacheService.getUsersFromCache(['userNonExist1', 'userNonExist2']);
          expect(cachedUsers, isNull);
        });
      });
    });
    
    test('getUsersFromCache should return null if cache is empty for users_data', () async {
      await cacheService.init();
      final cachedUsers = cacheService.getUsersFromCache(['user1']);
      expect(cachedUsers, isNull);
    });

    test('setData should correctly convert nested Timestamps in complex objects', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'complexObjectWithTimestamps';
          final ts = Timestamp.fromDate(fixedNow);
          final complexData = {
            'level1_string': 'hello',
            'level1_timestamp': ts,
            'level1_list': [1, ts, {'nested_list_ts': ts}],
            'level1_map': {'map_ts': ts, 'map_string': 'world', 'map_list_ts': [ts, 2, ts]}
          };
          final expectedConvertedData = {
            'level1_string': 'hello',
            'level1_timestamp': ts.millisecondsSinceEpoch,
            'level1_list': [1, ts.millisecondsSinceEpoch, {'nested_list_ts': ts.millisecondsSinceEpoch}],
            'level1_map': {'map_ts': ts.millisecondsSinceEpoch, 'map_string': 'world', 'map_list_ts': [ts.millisecondsSinceEpoch, 2, ts.millisecondsSinceEpoch]}
          };
          await cacheService.setData(key, complexData);
          final retrievedData = cacheService.getData(key);
          expect(retrievedData, equals(expectedConvertedData));
        });
      });
    });
    
    test('setData with GroupModel should use toMap(forCache: true)', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'groupModelCacheTest';
          final group = createTestGroup('groupCache', createdAt: fixedNow, updatedAt: fixedNow.add(const Duration(hours:1)));
          await cacheService.setData(key, group);
          final prefs = await SharedPreferences.getInstance();
          final rawDataString = prefs.getString(key);
          expect(rawDataString, isNotNull);
          final decodedPayload = jsonDecode(rawDataString!);
          final cachedGroupData = decodedPayload['data'] as Map<String, dynamic>;
          expect(cachedGroupData['createdAt'], group.createdAt.millisecondsSinceEpoch);
          expect(cachedGroupData['updatedAt'], group.updatedAt.millisecondsSinceEpoch);
          final retrievedGroupData = cacheService.getData(key) as Map<String, dynamic>;
          expect(retrievedGroupData['createdAt'], group.createdAt.millisecondsSinceEpoch);
          expect(retrievedGroupData['updatedAt'], group.updatedAt.millisecondsSinceEpoch);
        });
      });
    });

    test('setData with List<GroupModel> should use toMap(forCache: true) for each element', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'listGroupModelCacheTest';
          final group1 = createTestGroup('lg1', createdAt: fixedNow);
          final group2 = createTestGroup('lg2', createdAt: fixedNow.add(const Duration(days:1)));
          final groups = [group1, group2];
          await cacheService.setData(key, groups);
          final prefs = await SharedPreferences.getInstance();
          final rawDataString = prefs.getString(key);
          expect(rawDataString, isNotNull);
          final decodedPayload = jsonDecode(rawDataString!);
          final cachedListData = decodedPayload['data'] as List<dynamic>;
          expect(cachedListData.length, 2);
          final group1Data = cachedListData[0] as Map<String, dynamic>;
          final group2Data = cachedListData[1] as Map<String, dynamic>;
          expect(group1Data['createdAt'], group1.createdAt.millisecondsSinceEpoch);
          expect(group2Data['createdAt'], group2.createdAt.millisecondsSinceEpoch);
          final retrievedListData = cacheService.getData(key) as List<dynamic>;
          final retrievedGroup1Data = retrievedListData[0] as Map<String, dynamic>;
          expect(retrievedGroup1Data['createdAt'], group1.createdAt.millisecondsSinceEpoch);
        });
      });
    });

     test('setData with ExpenseModel should use toMap(forCache: true)', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'expenseModelCacheTest';
          final expense = createTestExpense('expCache', 'g1', date: fixedNow );
          await cacheService.setData(key, expense);
          final prefs = await SharedPreferences.getInstance();
          final rawDataString = prefs.getString(key);
          expect(rawDataString, isNotNull);
          final decodedPayload = jsonDecode(rawDataString!);
          final cachedExpenseData = decodedPayload['data'] as Map<String, dynamic>;
          expect(cachedExpenseData['date'], expense.date.millisecondsSinceEpoch);
          final retrievedExpenseData = cacheService.getData(key) as Map<String, dynamic>;
          expect(retrievedExpenseData['date'], expense.date.millisecondsSinceEpoch);
        });
      });
    });

    test('setData with List<ExpenseModel> should use toMap(forCache: true) for each element', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'listExpenseModelCacheTest';
          final expense1 = createTestExpense('le1', 'g1', date: fixedNow);
          final expense2 = createTestExpense('le2', 'g1', date: fixedNow.add(Duration(minutes:10)));
          final expenses = [expense1, expense2];
          await cacheService.setData(key, expenses);
          final prefs = await SharedPreferences.getInstance();
          final rawDataString = prefs.getString(key);
          expect(rawDataString, isNotNull);
          final decodedPayload = jsonDecode(rawDataString!);
          final cachedListData = decodedPayload['data'] as List<dynamic>;
          expect(cachedListData.length, 2);
          final expense1Data = cachedListData[0] as Map<String, dynamic>;
          final expense2Data = cachedListData[1] as Map<String, dynamic>;
          expect(expense1Data['date'], expense1.date.millisecondsSinceEpoch);
          expect(expense2Data['date'], expense2.date.millisecondsSinceEpoch);
          final retrievedListData = cacheService.getData(key) as List<dynamic>;
          final retrievedExpense1Data = retrievedListData[0] as Map<String, dynamic>;
          expect(retrievedExpense1Data['date'], expense1.date.millisecondsSinceEpoch);
        });
      });
    });

    test('setData handles non-primitive objects gracefully', () {
      fakeAsync((async) {
        withClock(Clock.fixed(fixedNow), () async {
          await cacheService.init();
          const key = 'unsupported';
          final obj = _Unsupported('v');
          await cacheService.setData(key, obj);
          expect(cacheService.getData(key), same(obj));
        });
      });
    });
  });
}
