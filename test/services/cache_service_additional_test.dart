import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitup_application/services/cache_service.dart';
import 'package:splitup_application/models/group_model.dart';
import 'package:splitup_application/models/expense_model.dart';
import 'package:splitup_application/models/settlement_model.dart';
import 'package:splitup_application/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('exercise additional CacheService paths', () async {
    final service = CacheService();
    await service.init();

    final group = GroupModel(
      id: 'g',
      name: 'n',
      participantIds: ['u'],
      adminId: 'u',
      currency: 'USD',
      roles: [ {'uid': 'u', 'role': 'admin'} ],
    );
    await service.cacheGroups([group], 'u');
    final groups = service.getGroupsFromCache('u');
    expect(groups, isNotNull);
    expect(groups!.first.id, 'g');

    final expense = ExpenseModel(
      id: 'e',
      groupId: 'g',
      description: 'd',
      amount: 1,
      date: DateTime.now(),
      participantIds: ['u'],
      payers: [ {'userId': 'u', 'amount': 1.0} ],
      createdBy: 'u',
      splitType: 'equal',
    );
    await service.cacheExpenses([expense], 'g');
    final expenses = service.getExpensesFromCache('g');
    expect(expenses, isNotNull);
    expect(expenses!.first.id, 'e');

    final settlement = SettlementModel(
      id: 's',
      groupId: 'g',
      amount: 2,
      date: DateTime.now(),
      fromUserId: 'u',
      toUserId: 'u',
      createdBy: 'u',
      status: 'pending',
    );
    await service.cacheSettlements([settlement], 'g');
    expect(() => service.getSettlementsFromCache('g'), throwsA(isA<TypeError>()));

    final user = UserModel(id: 'u', name: 'user', email: 'u@example.com');
    await service.cacheUsers([user]);
    expect(service.getUserFromCache('u')!.id, 'u');
    expect(service.getUsersFromCache(['u'])!.first.id, 'u');

    await service.removeKeysWithPattern('group_');
    await service.clearAll();
    expect(service.getGroupsFromCache('u'), isNull);
  });
}
