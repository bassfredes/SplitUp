import 'package:flutter_test/flutter_test.dart';
import 'package:splitup_application/models/group_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('GroupModel', () {
    final DateTime testDate = DateTime(2024, 5, 27, 10, 30, 0);
    final Timestamp testTimestamp = Timestamp.fromDate(testDate);
    final int testDateMillis = testDate.millisecondsSinceEpoch;

    final baseLastExpenseMap = {
      'id': 'exp123',
      'description': 'Last dinner',
      'amount': 50.0,
      'date': testTimestamp, // Firestore representation
      'paidBy': 'user1'
    };

    final baseLastExpenseModel = {
      'id': 'exp123',
      'description': 'Last dinner',
      'amount': 50.0,
      'date': testDate, // Model representation (DateTime)
      'paidBy': 'user1'
    };

    final baseGroupMap = {
      'name': 'Test Group',
      'description': 'A group for testing',
      'participantIds': ['user1', 'user2', 'admin'],
      'adminId': 'admin',
      'roles': [
        {'uid': 'admin', 'role': 'admin'},
        {'uid': 'user1', 'role': 'member'},
        {'uid': 'user2', 'role': 'member'}
      ],
      'currency': 'USD',
      'photoUrl': 'http://example.com/photo.png',
      'participantBalances': [
        {
          'userId': 'user1',
          'balances': {'USD': 10.5, 'EUR': -5.0}
        },
        {
          'userId': 'user2',
          'balances': {'USD': -20.0, 'CLP': 10000.0}
        }
      ],
      'totalExpenses': 150.75,
      'expensesCount': 5,
      'lastExpense': baseLastExpenseMap,
    };

    GroupModel createBaseGroup({
      String id = 'group1',
      String name = 'Test Group',
      String? description = 'A group for testing',
      List<String> participantIds = const ['user1', 'user2', 'admin'],
      String adminId = 'admin',
      List<Map<String, String>> roles = const [
        {'uid': 'admin', 'role': 'admin'},
        {'uid': 'user1', 'role': 'member'},
        {'uid': 'user2', 'role': 'member'}
      ],
      String currency = 'USD',
      String? photoUrl = 'http://example.com/photo.png',
      List<Map<String, dynamic>> participantBalances = const [
        {
          'userId': 'user1',
          'balances': {'USD': 10.5, 'EUR': -5.0}
        },
        {
          'userId': 'user2',
          'balances': {'USD': -20.0, 'CLP': 10000.0}
        }
      ],
      double totalExpenses = 150.75,
      int expensesCount = 5,
      // Modificación: Permitir que lastExpense sea explícitamente null si se pasa como tal.
      // El valor predeterminado solo se aplica si el parámetro no se proporciona en absoluto.
      // Para lograr esto, necesitamos un valor centinela o manejarlo en la lógica de llamada.
      // Por simplicidad aquí, si se pasa `null`, se usará `null`.
      // Si no se pasa el parámetro `lastExpense` en la llamada a `createBaseGroup`,
      // entonces se usará `baseLastExpenseModel`.
      // Esto requiere que el llamador decida. Para los tests que necesitan `null`,
      // pasarán `lastExpense: null`.
      Map<String, dynamic>? lastExpense,
      bool useDefaultLastExpense = true, // Nuevo parámetro para controlar el comportamiento por defecto
      DateTime? createdAt, // Nuevo campo
      DateTime? updatedAt, // Nuevo campo
    }) {
      Map<String, dynamic>? finalLastExpense;
      if (useDefaultLastExpense) {
        finalLastExpense = lastExpense ?? Map<String, dynamic>.from(baseLastExpenseModel);
      } else {
        finalLastExpense = lastExpense; // Permite que lastExpense sea null si se pasa explícitamente
      }

      return GroupModel(
        id: id,
        name: name,
        description: description,
        participantIds: participantIds,
        adminId: adminId,
        roles: roles,
        currency: currency,
        photoUrl: photoUrl,
        participantBalances: participantBalances,
        totalExpenses: totalExpenses,
        expensesCount: expensesCount,
        lastExpense: finalLastExpense,
        createdAt: createdAt, // Pasar el valor al constructor de GroupModel
        updatedAt: updatedAt, // Pasar el valor al constructor de GroupModel
      );
    }

    test('constructor creates an instance with all fields', () {
      final group = createBaseGroup();
      expect(group.id, 'group1');
      expect(group.name, 'Test Group');
      expect(group.description, 'A group for testing');
      expect(group.participantIds, ['user1', 'user2', 'admin']);
      expect(group.adminId, 'admin');
      expect(group.roles, [
        {'uid': 'admin', 'role': 'admin'},
        {'uid': 'user1', 'role': 'member'},
        {'uid': 'user2', 'role': 'member'}
      ]);
      expect(group.currency, 'USD');
      expect(group.photoUrl, 'http://example.com/photo.png');
      expect(group.participantBalances, [
        {
          'userId': 'user1',
          'balances': {'USD': 10.5, 'EUR': -5.0}
        },
        {
          'userId': 'user2',
          'balances': {'USD': -20.0, 'CLP': 10000.0}
        }
      ]);
      expect(group.totalExpenses, 150.75);
      expect(group.expensesCount, 5);
      expect(group.lastExpense, baseLastExpenseModel);
      expect(group.createdAt, isA<DateTime>());
      expect(group.updatedAt, isA<DateTime>());
    });

    group('fromMap', () {
      test('creates an instance from a map with all fields', () {
        final groupMapWithTimestamps = Map<String, dynamic>.from(baseGroupMap);
        groupMapWithTimestamps['createdAt'] = Timestamp.now();
        groupMapWithTimestamps['updatedAt'] = Timestamp.now();

        final group = GroupModel.fromMap(groupMapWithTimestamps, 'group1');
        expect(group.id, 'group1');
        expect(group.name, 'Test Group');
        expect(group.description, 'A group for testing');
        expect(group.participantIds, ['user1', 'user2', 'admin']);
        expect(group.adminId, 'admin');
        expect(group.roles, [
          {'uid': 'admin', 'role': 'admin'},
          {'uid': 'user1', 'role': 'member'},
          {'uid': 'user2', 'role': 'member'}
        ]);
        expect(group.currency, 'USD');
        expect(group.photoUrl, 'http://example.com/photo.png');
        expect(group.participantBalances, [
          {
            'userId': 'user1',
            'balances': {'USD': 10.5, 'EUR': -5.0}
          },
          {
            'userId': 'user2',
            'balances': {'USD': -20.0, 'CLP': 10000.0}
          }
        ]);
        expect(group.totalExpenses, 150.75);
        expect(group.expensesCount, 5);
        
        final expectedLastExpenseModel = Map<String, dynamic>.from(baseLastExpenseModel);
        // fromMap converts date in lastExpense to DateTime for the model object
        expectedLastExpenseModel['date'] = testDate; 
        expect(group.lastExpense, expectedLastExpenseModel);
        expect(group.createdAt, isA<DateTime>()); 
        expect(group.updatedAt, isA<DateTime>()); 
      });

      test('handles missing optional fields with defaults', () {
        final minimalMap = {
          'name': 'Minimal Group',
          'participantIds': ['user3'],
          'adminId': 'user3',
          'roles': [{'uid': 'user3', 'role': 'admin'}],
          // No optional fields, incluyendo participantBalances, totalExpenses, expensesCount, lastExpense
        };
        final group = GroupModel.fromMap(minimalMap, 'group2');
        expect(group.id, 'group2');
        expect(group.name, 'Minimal Group');
        expect(group.description, isNull);
        expect(group.participantIds, ['user3']);
        expect(group.adminId, 'user3');
        expect(group.roles, [{'uid': 'user3', 'role': 'admin'}]);
        expect(group.currency, 'CLP'); // Default
        expect(group.photoUrl, isNull);
        expect(group.participantBalances, isEmpty); // Default
        expect(group.totalExpenses, 0.0); // Default
        expect(group.expensesCount, 0); // Default
        expect(group.lastExpense, isNull); // Default
        expect(group.createdAt, isA<DateTime>()); 
        expect(group.updatedAt, isA<DateTime>());
      });

      test('handles participantBalances with invalid items or empty balances', () {
        final mapWithInvalidBalances = {
          'name': 'GroupWithInvalidBalances',
          'participantIds': ['user1'],
          'adminId': 'user1',
          'roles': [{'uid': 'user1', 'role': 'admin'}],
          'participantBalances': [
            {'userId': 'user1', 'balances': {'USD': 10.0}}, // Valid
            {'userId': null, 'balances': {'USD': 5.0}},    // Invalid userId
            {'userId': 'user2', 'balances': null},          // Invalid balances map
            {'userId': 'user3', 'balances': {}},             // Empty balances map (filtered out)
            {'userId': 'user4', 'balances': {'USD': 'not_a_number'}}, // Invalid balance value (currency filtered)
            {'userId': 'user5', 'balances': {'EUR': 20.0, 'BAD': 'data'}}, // Partially valid
          ]
        };
        final group = GroupModel.fromMap(mapWithInvalidBalances, 'group3');
        expect(group.participantBalances.length, 2);
        expect(group.participantBalances[0]['userId'], 'user1');
        expect(group.participantBalances[0]['balances'], {'USD': 10.0});
        expect(group.participantBalances[1]['userId'], 'user5');
        expect(group.participantBalances[1]['balances'], {'EUR': 20.0});
      });

      test('handles null or empty lists for participantIds and roles', () {
        final mapWithNullLists = {
          'name': 'GroupWithNullLists',
          'adminId': 'admin',
          'participantIds': null,
          'roles': null,
        };
        var group = GroupModel.fromMap(mapWithNullLists, 'group4');
        expect(group.participantIds, isEmpty);
        expect(group.roles, isEmpty);

        final mapWithEmptyLists = {
          'name': 'GroupWithEmptyLists',
          'adminId': 'admin',
          'participantIds': [],
          'roles': [],
        };
        group = GroupModel.fromMap(mapWithEmptyLists, 'group5');
        expect(group.participantIds, isEmpty);
        expect(group.roles, isEmpty);
      });

      test('fromMap handles all nullable fields being null', () {
        final mapWithNullOptionals = {
          'name': 'Test Group',
          'participantIds': ['user1'],
          'adminId': 'admin1',
          'roles': [{'uid': 'admin1', 'role': 'admin'}],
          // Nullable fields
          'description': null,
          'photoUrl': null,
          'participantBalances': null, // Will default to empty list
          'totalExpenses': null, // Will default to 0.0
          'expensesCount': null, // Will default to 0
          'lastExpense': null,
          'createdAt': null, 
          'updatedAt': null,
        };
        final group = GroupModel.fromMap(mapWithNullOptionals, 'group_null_opt');
        expect(group.description, isNull);
        expect(group.photoUrl, isNull);
        expect(group.participantBalances, isEmpty);
        expect(group.totalExpenses, 0.0);
        expect(group.expensesCount, 0);
        expect(group.lastExpense, isNull);
        expect(group.createdAt, isA<DateTime>()); 
        expect(group.updatedAt, isA<DateTime>()); 
      });

      test('fromMap handles lastExpense with date as int (cache format)', () {
        final lastExpenseCache = {
          'id': 'expCache',
          'description': 'Cached Expense',
          'amount': 75.0,
          'date': testDateMillis, // Date as int
          'paidBy': 'user2'
        };
        final groupMapWithCachedLastExpense = Map<String, dynamic>.from(baseGroupMap);
        groupMapWithCachedLastExpense['lastExpense'] = lastExpenseCache;

        final group = GroupModel.fromMap(groupMapWithCachedLastExpense, 'group_cache_le');

        final expectedLastExpenseModel = Map<String, dynamic>.from(lastExpenseCache);
        // fromMap converts int date in lastExpense to DateTime for the model object
        expectedLastExpenseModel['date'] = testDate;
        expect(group.lastExpense, expectedLastExpenseModel);
        expect(group.createdAt, isA<DateTime>());
        expect(group.updatedAt, isA<DateTime>());
      });

      test('fromMap parses createdAt and updatedAt when given as int', () {
        final mapWithIntDates = Map<String, dynamic>.from(baseGroupMap);
        mapWithIntDates['createdAt'] = testDateMillis;
        mapWithIntDates['updatedAt'] = testDateMillis;
        final group = GroupModel.fromMap(mapWithIntDates, 'group_int_dates');
        expect(group.createdAt.millisecondsSinceEpoch, testDateMillis);
        expect(group.updatedAt.millisecondsSinceEpoch, testDateMillis);
      });

      test('fromMap parses createdAt and updatedAt when given as ISO strings', () {
        final isoString = testDate.toIso8601String();
        final mapWithStringDates = Map<String, dynamic>.from(baseGroupMap);
        mapWithStringDates['createdAt'] = isoString;
        mapWithStringDates['updatedAt'] = isoString;
        final group = GroupModel.fromMap(mapWithStringDates, 'group_string_dates');
        expect(group.createdAt, DateTime.parse(isoString));
        expect(group.updatedAt, DateTime.parse(isoString));
      });
    });

    group('toMap', () {
      test('converts an instance to a map with all fields (for Firestore)', () {
        final group = createBaseGroup();
        final map = group.toMap(); // forCache = false (default)

        expect(map['name'], 'Test Group');
        expect(map['description'], 'A group for testing');
        expect(map['participantIds'], ['user1', 'user2', 'admin']);
        expect(map['adminId'], 'admin');
        expect(map['roles'], [
          {'uid': 'admin', 'role': 'admin'},
          {'uid': 'user1', 'role': 'member'},
          {'uid': 'user2', 'role': 'member'}
        ]);
        expect(map['currency'], 'USD');
        expect(map['photoUrl'], 'http://example.com/photo.png');
        expect(map['participantBalances'], [
          {
            'userId': 'user1',
            'balances': {'USD': 10.5, 'EUR': -5.0}
          },
          {
            'userId': 'user2',
            'balances': {'USD': -20.0, 'CLP': 10000.0}
          }
        ]);
        expect(map['totalExpenses'], 150.75);
        expect(map['expensesCount'], 5);
        
        // lastExpense in the model has DateTime, toMap for Firestore should convert it to Timestamp
        final expectedLastExpenseToMap = Map<String, dynamic>.from(baseLastExpenseModel);
        expectedLastExpenseToMap['date'] = testTimestamp; 
        expect(map['lastExpense'], expectedLastExpenseToMap);
        expect(map['createdAt'], isA<Timestamp>()); 
        expect(map['updatedAt'], isA<Timestamp>()); 
      });

      test('converts an instance to a map for cache (lastExpense date as int)', () {
        final group = createBaseGroup(); // lastExpense.date is DateTime
        final map = group.toMap(forCache: true);

        final lastExpenseFromMap = map['lastExpense'] as Map<String, dynamic>; 
        expect(lastExpenseFromMap['date'], testDateMillis); // Should be int for cache
        expect(map['createdAt'], isA<int>()); 
        expect(map['updatedAt'], isA<int>()); 
      });

      test('toMap forCache specifically with DateTime input for date', () {
        final dateTimeSpecificLastExpense = {
          'id': 'expDT_cache',
          'description': 'DateTime to Cache Test',
          'amount': 10.0,
          'date': DateTime(2025, 1, 1, 12, 0, 0), // Explicit DateTime
          'paidBy': 'userDT'
        };
        final group = createBaseGroup(lastExpense: dateTimeSpecificLastExpense, useDefaultLastExpense: false);
        final map = group.toMap(forCache: true);
        // Aseguramos que date no es null y es DateTime antes de acceder a millisecondsSinceEpoch
        final dateValue = dateTimeSpecificLastExpense['date'];
        expect(dateValue, isA<DateTime>());
        expect(map['lastExpense']!['date'], (dateValue as DateTime).millisecondsSinceEpoch);
        expect(map['createdAt'], group.createdAt.millisecondsSinceEpoch);
        expect(map['updatedAt'], group.updatedAt.millisecondsSinceEpoch);
      });

      test('toMap forFirestore specifically with DateTime input for date', () {
        final dateTimeSpecificLastExpense = {
          'id': 'expDT_firestore',
          'description': 'DateTime to Firestore Test',
          'amount': 20.0,
          'date': DateTime(2025, 2, 2, 15, 0, 0), // Explicit DateTime
          'paidBy': 'userDT'
        };
        final group = createBaseGroup(lastExpense: dateTimeSpecificLastExpense, useDefaultLastExpense: false);
        final map = group.toMap(forCache: false); // for Firestore
        expect(map['lastExpense']!['date'], isA<Timestamp>());
        // Aseguramos que date no es null y es DateTime antes de la comparación
        final dateValue = dateTimeSpecificLastExpense['date'];
        expect(dateValue, isA<DateTime>());
        expect((map['lastExpense']!['date'] as Timestamp).toDate(), dateValue as DateTime);
        expect(map['createdAt'], isA<Timestamp>());
        expect((map['createdAt'] as Timestamp).toDate(), group.createdAt);
        expect(map['updatedAt'], isA<Timestamp>());
        expect((map['updatedAt'] as Timestamp).toDate(), group.updatedAt);
      });

      test('toMap handles null optional fields correctly', () {
        final group = createBaseGroup(
          description: null,
          photoUrl: null,
          lastExpense: null, // Explicitly pass null here
          useDefaultLastExpense: false, // Asegura que el null se use
          // participantBalances defaults to empty, not null in constructor
        );
        final map = group.toMap();

        expect(map.containsKey('description'), isTrue); // Firestore keeps nulls
        expect(map['description'], isNull);
        expect(map.containsKey('photoUrl'), isTrue);
        expect(map['photoUrl'], isNull);
        expect(map.containsKey('lastExpense'), isTrue);
        expect(map['lastExpense'], isNull); // Now expects null
        expect(map['createdAt'], isNotNull); 
        expect(map['updatedAt'], isNotNull); 
      });

      test('toMap for cache handles null lastExpense', () {
        final group = createBaseGroup(lastExpense: null, useDefaultLastExpense: false); // Asegura que el null se use
        final map = group.toMap(forCache: true);
        expect(map['lastExpense'], isNull); // Now expects null
        expect(map['createdAt'], group.createdAt.millisecondsSinceEpoch);
        expect(map['updatedAt'], group.updatedAt.millisecondsSinceEpoch);
      });

      test('toMap for cache handles lastExpense with int date already (no change)', () {
        final lastExpenseWithIntDate = {
          'id': 'expInt',
          'description': 'Int Date Expense',
          'amount': 99.0,
          'date': testDateMillis, // Already int
          'paidBy': 'user1'
        };
        final group = createBaseGroup(lastExpense: lastExpenseWithIntDate);
        final map = group.toMap(forCache: true);
        expect(map['lastExpense']['date'], testDateMillis);
        expect(map['createdAt'], group.createdAt.millisecondsSinceEpoch);
        expect(map['updatedAt'], group.updatedAt.millisecondsSinceEpoch);
      });

      test('toMap for Firestore handles lastExpense with Timestamp date already (no change)', () {
         final lastExpenseWithTimestampDate = {
          'id': 'expTS',
          'description': 'Timestamp Date Expense',
          'amount': 88.0,
          'date': testTimestamp, // Already Timestamp
          'paidBy': 'user3'
        };
        // The model constructor expects DateTime for lastExpense.date
        // So, to test this scenario, we would need to manually construct a GroupModel
        // where its lastExpense map *already* has a Timestamp. 
        // The current createBaseGroup converts it to DateTime.
        // However, the toMap logic for !forCache directly uses group.lastExpense.
        // If group.lastExpense somehow contained a Timestamp, it would pass it through.
        // Let\'s simulate that by creating a map that would be the result of such a model state.

        final groupWithTimestampInLastExpense = GroupModel(
          id: 'g1', name: 'N', participantIds: [], adminId: 'a', roles: [],
          lastExpense: lastExpenseWithTimestampDate,
          createdAt: DateTime.now(), // Añadir createdAt
          updatedAt: DateTime.now(), // Añadir updatedAt
        );
        final map = groupWithTimestampInLastExpense.toMap(forCache: false);
        expect(map['lastExpense']['date'], testTimestamp);
        expect(map['createdAt'], isA<Timestamp>());
        expect(map['updatedAt'], isA<Timestamp>());
      });

      test('toMap for cache converts Timestamp date to milliseconds', () {
        final group = GroupModel(
          id: 'gCache',
          name: 'n',
          participantIds: [],
          adminId: 'a',
          roles: [],
          lastExpense: {
            'id': 'e1',
            'description': 'ts',
            'amount': 1.0,
            'date': testTimestamp,
          },
          createdAt: testDate,
          updatedAt: testDate,
        );
        final map = group.toMap(forCache: true);
        expect(map['lastExpense']['date'], testDateMillis);
      });

      test('toMap for Firestore converts int date to Timestamp', () {
        final group = GroupModel(
          id: 'gFs',
          name: 'n',
          participantIds: [],
          adminId: 'a',
          roles: [],
          lastExpense: {
            'id': 'e1',
            'description': 'int',
            'amount': 1.0,
            'date': testDateMillis,
          },
          createdAt: testDate,
          updatedAt: testDate,
        );
        final map = group.toMap(forCache: false);
        expect(map['lastExpense']['date'], isA<Timestamp>());
        expect((map['lastExpense']['date'] as Timestamp).millisecondsSinceEpoch, testDateMillis);
      });

    });

    // No copyWith method in GroupModel, so no tests for it.
  });
}
