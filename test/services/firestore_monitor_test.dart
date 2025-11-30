import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitup_application/services/firestore_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirestoreMonitor monitor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    monitor = FirestoreMonitor();
    await monitor.waitForLoad();
    await monitor.resetForTesting();
  });

  test('logRead tracks counts and collections', () async {
    monitor.logRead('groups');
    monitor.logRead('groups');
    monitor.logRead('users');

    await Future.delayed(Duration.zero);

    expect(monitor.readCount, 3);
    expect(monitor.readsByCollection['groups'], 2);
    expect(monitor.readsByCollection['users'], 1);
  });

  test('write and cache stats are persisted and reported', () async {
    monitor.logRead('groups');
    monitor.logWrite();
    monitor.logCacheHit();
    monitor.logCacheMiss();

    await Future.delayed(Duration.zero);

    expect(monitor.writeCount, 1);
    expect(monitor.cacheHitCount, 1);
    expect(monitor.cacheMissCount, 1);
    expect(monitor.cacheHitRate, greaterThan(0));

    final report = monitor.generateReport();
    expect(report, contains('Lecturas totales: 1'));
    expect(report, contains('Escrituras totales: 1'));
    expect(report, contains('Tasa de aciertos de caché'));
  });
}
