import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitup_application/models/group_model.dart';
import 'package:splitup_application/services/cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixedNow = DateTime(2024, 1, 1, 12);
  late CacheService cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = CacheService();
    await cache.init();
  });

  test('setData respects expiration and bypassExpiration flag', () async {
    await withClock(Clock.fixed(fixedNow), () async {
      await cache.setData('short', 'value', expiration: const Duration(seconds: 1));
    });

    final beforeExpire = withClock(
      Clock.fixed(fixedNow.add(const Duration(milliseconds: 500))),
      () => cache.getData('short'),
    );
    expect(beforeExpire, 'value');

    final expired = withClock(
      Clock.fixed(fixedNow.add(const Duration(seconds: 2))),
      () => cache.getData('short'),
    );
    expect(expired, isNull);

    await withClock(Clock.fixed(fixedNow), () async {
      await cache.setData('bypass', 'keep', expiration: const Duration(seconds: 1));
    });

    final bypassed = withClock(
      Clock.fixed(fixedNow.add(const Duration(seconds: 2))),
      () => cache.getData('bypass', bypassExpiration: true),
    );
    expect(bypassed, 'keep');
  });

  test('cacheGroups round-trips and expires correctly', () async {
    final groupBase = DateTime(2024, 1, 2, 9);
    final group = GroupModel(
      id: 'g1',
      name: 'Group',
      participantIds: const ['u1'],
      adminId: 'u1',
      roles: const [{'uid': 'u1', 'role': 'admin'}],
      currency: 'USD',
      lastExpense: {
        'id': 'exp1',
        'description': 'Coffee',
        'amount': 5.0,
        'date': groupBase,
        'paidBy': 'u1',
      },
      createdAt: groupBase,
      updatedAt: groupBase,
    );

    await withClock(Clock.fixed(groupBase), () async {
      await cache.cacheGroups([group], 'u1');
    });

    final cached = withClock(
      Clock.fixed(groupBase),
      () => cache.getGroupsFromCache('u1'),
    );
    expect(cached, isNotNull);
    expect(cached!.first.lastExpense?['date'], isA<DateTime>());
    expect(cached.first.createdAt, isA<DateTime>());

    final expired = withClock(
      Clock.fixed(groupBase.add(CacheService.defaultExpiration + const Duration(seconds: 1))),
      () => cache.getGroupsFromCache('u1'),
    );
    expect(expired, isNull);
  });

  test('removeKeysWithPattern clears matching entries', () async {
    await cache.setData('pattern_one', 1);
    await cache.setData('pattern_two', 2);
    await cache.setData('other', 3);

    await cache.removeKeysWithPattern('pattern_');

    expect(cache.getData('pattern_one'), isNull);
    expect(cache.getData('pattern_two'), isNull);
    expect(cache.getData('other'), 3);
  });
}
