import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart'; // Import fake_cloud_firestore
import 'package:splitup_application/models/change_log_model.dart';
import 'package:splitup_application/services/change_log_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Keep this for Timestamp

void main() {
  late ChangeLogService changeLogService;
  late FakeFirebaseFirestore mockFirestore; // Use FakeFirebaseFirestore

  setUp(() {
    mockFirestore = FakeFirebaseFirestore(); // Initialize FakeFirebaseFirestore
    
    // Initialize ChangeLogService with the mock Firestore
    changeLogService = ChangeLogService(mockFirestore);
  });

  group('ChangeLogService', () {
    group('logChange', () {
      test('correctly adds ChangeLogModel data to Firestore', () async {
        final log = ChangeLogModel(
          id: '1', // ID will be auto-generated by Firestore, but good for comparison
          actionType: 'create',
          userId: 'user1',
          entityType: 'expense',
          entityId: 'expense1',
          date: DateTime.now(),
          details: 'Created new expense',
        );
        
        await changeLogService.logChange(log);

        final snapshot = await mockFirestore.collection('change_logs').get();
        expect(snapshot.docs.length, 1);
        final docData = snapshot.docs.first.data();
        expect(docData['actionType'], log.actionType);
        expect(docData['userId'], log.userId);
        expect(docData['entityType'], log.entityType);
        expect(docData['entityId'], log.entityId);
        // Compare Timestamps carefully or convert to DateTime
        expect((docData['date'] as Timestamp).toDate().isAtSameMomentAs(log.date), isTrue);
        expect(docData['details'], log.details);
      });

      test('correctly processes a comment ChangeLogModel', () async {
        final commentLog = ChangeLogModel(
          id: '2',
          actionType: 'add_comment',
          userId: 'user2',
          entityType: 'expense',
          entityId: 'expense2',
          date: DateTime.now(),
          details: 'This is a test comment',
        );

        await changeLogService.logChange(commentLog);
        
        final snapshot = await mockFirestore.collection('change_logs').get();
        expect(snapshot.docs.length, 1);
        final docData = snapshot.docs.first.data();
        expect(docData['actionType'], commentLog.actionType);
        expect(docData['userId'], commentLog.userId);
        expect(docData['details'], commentLog.details);
      });
    });

    group('getLogsByEntity', () {
      final entityType = 'expense';
      final entityId = 'expense123';
      final now = DateTime.now();
      // Order matters for the test, log2 is later than log1
      final date1 = now.subtract(Duration(minutes: 10));
      final date2 = now; 

      final log1 = ChangeLogModel(
        id: 'log1',
        actionType: 'create',
        userId: 'user1',
        entityType: entityType,
        entityId: entityId,
        date: date1,
        details: 'Created entity',
      );
      final log2 = ChangeLogModel(
        id: 'log2',
        actionType: 'add_comment',
        userId: 'user2',
        entityType: entityType,
        entityId: entityId,
        date: date2, 
        details: 'Test comment for entity',
      );

      setUp(() async {
        // Add documents directly to FakeFirebaseFirestore
        await mockFirestore.collection('change_logs').add(log1.toMap());
        await mockFirestore.collection('change_logs').add(log2.toMap());
        // Add an unrelated document to ensure filtering works
        await mockFirestore.collection('change_logs').add(ChangeLogModel(
            id: 'otherLog',
            actionType: 'update',
            userId: 'user3',
            entityType: 'otherEntity',
            entityId: 'otherId',
            date: now,
            details: 'some other details'
        ).toMap());
      });

      test('correctly filters and orders logs by entity', () async {
        final stream = changeLogService.getLogsByEntity(entityType, entityId);

        final logs = await stream.first; // Get the first emitted list

        expect(logs.length, 2);
        // Firestore orders by date descending, so log2 (later) should be first
        expect(logs[0].details, log2.details);
        expect(logs[0].date.isAtSameMomentAs(log2.date), isTrue);

        expect(logs[1].details, log1.details);
        expect(logs[1].date.isAtSameMomentAs(log1.date), isTrue);
      });
    });

    group('getLogsByUser', () {
      final userId = 'userTest123';
      final now = DateTime.now();
      final dateEarlier = now.subtract(Duration(days: 1));
      final dateNow = now;

      final logUser1 = ChangeLogModel(
        id: 'logUser1',
        actionType: 'update',
        userId: userId,
        entityType: 'profile',
        entityId: 'profile1',
        date: dateNow,
        details: 'Updated profile',
      );
      final logUser2 = ChangeLogModel(
        id: 'logUser2',
        actionType: 'delete',
        userId: userId,
        entityType: 'item',
        entityId: 'itemX',
        date: dateEarlier,
        details: 'Deleted item X',
      );

      setUp(() async {
        await mockFirestore.collection('change_logs').add(logUser1.toMap());
        await mockFirestore.collection('change_logs').add(logUser2.toMap());
        // Add an unrelated document
         await mockFirestore.collection('change_logs').add(ChangeLogModel(
            id: 'otherUserLog',
            actionType: 'create',
            userId: 'anotherUser',
            entityType: 'task',
            entityId: 'taskY',
            date: now,
            details: 'Created task Y'
        ).toMap());
      });

      test('correctly filters and orders logs by user', () async {
        final stream = changeLogService.getLogsByUser(userId);
        final logs = await stream.first;

        expect(logs.length, 2);
        // Ordered by date descending
        expect(logs[0].details, logUser1.details);
        expect(logs[0].date.isAtSameMomentAs(logUser1.date), isTrue);

        expect(logs[1].details, logUser2.details);
        expect(logs[1].date.isAtSameMomentAs(logUser2.date), isTrue);
      });
    });
  });
}
