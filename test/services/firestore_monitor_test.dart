import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitup_application/services/firestore_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('logs operations and generates report', () async {
    final monitor = FirestoreMonitor();

    monitor.logRead('groups');
    monitor.logWrite();
    monitor.logCacheHit();
    monitor.logCacheMiss();

    expect(monitor.readCount, 1);
    expect(monitor.writeCount, 1);
    expect(monitor.cacheHitCount, 1);
    expect(monitor.cacheMissCount, 1);
    expect(monitor.readsByCollection['groups'], 1);

    final report = monitor.generateReport();
    expect(report, contains('Lecturas totales: 1'));
    expect(report, contains('Escrituras totales: 1'));
  });
}
