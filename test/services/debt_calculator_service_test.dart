import 'package:flutter_test/flutter_test.dart';
import 'package:splitup_application/models/expense_model.dart';
import 'package:splitup_application/models/group_model.dart';
import 'package:splitup_application/services/debt_calculator_service.dart';

void main() {
  late DebtCalculatorService debtCalculatorService;

  setUp(() {
    debtCalculatorService = DebtCalculatorService();
  });

  group('DebtCalculatorService', () {
    group('calculateBalances', () {
      final group = GroupModel(
        id: 'group1',
        name: 'Test Group',
        participantIds: ['user1', 'user2', 'user3'],
        adminId: 'user1',
        roles: [{'uid': 'user1', 'role': 'admin'}],
      );

      test('No expenses, balances should be zero for all participants', () {
        final expenses = <ExpenseModel>[];
        final balances = debtCalculatorService.calculateBalances(expenses, group);

        expect(balances['user1'], 0.0);
        expect(balances['user2'], 0.0);
        expect(balances['user3'], 0.0);
      });

      test('Single expense, equally split among all participants', () {
        final expenses = [
          ExpenseModel(
            id: 'expense1',
            groupId: 'group1',
            description: 'Lunch',
            amount: 30.0,
            date: DateTime.now(),
            participantIds: ['user1', 'user2', 'user3'],
            payers: [{'userId': 'user1', 'amount': 30.0}],
            createdBy: 'user1',
            splitType: 'equal',
          ),
        ];
        final balances = debtCalculatorService.calculateBalances(expenses, group);

        expect(balances['user1'], closeTo(20.0, 0.01)); // Paid 30, share 10 -> 30 - 10 = 20
        expect(balances['user2'], closeTo(-10.0, 0.01)); // Paid 0, share 10 -> 0 - 10 = -10
        expect(balances['user3'], closeTo(-10.0, 0.01)); // Paid 0, share 10 -> 0 - 10 = -10
      });

      test('Multiple expenses, equally split', () {
        final expenses = [
          ExpenseModel(
            id: 'expense1',
            groupId: 'group1',
            description: 'Lunch',
            amount: 30.0,
            date: DateTime.now(),
            participantIds: ['user1', 'user2', 'user3'],
            payers: [{'userId': 'user1', 'amount': 30.0}],
            createdBy: 'user1',
            splitType: 'equal',
          ),
          ExpenseModel(
            id: 'expense2',
            groupId: 'group1',
            description: 'Groceries',
            amount: 60.0,
            date: DateTime.now(),
            participantIds: ['user1', 'user2', 'user3'],
            payers: [{'userId': 'user2', 'amount': 60.0}],
            createdBy: 'user2',
            splitType: 'equal',
          ),
        ];
        final balances = debtCalculatorService.calculateBalances(expenses, group);

        // Expense 1: user1 +20, user2 -10, user3 -10
        // Expense 2: user1 -20, user2 +40, user3 -20
        // Total:     user1  0, user2 +30, user3 -30
        expect(balances['user1'], closeTo(0.0, 0.01));
        expect(balances['user2'], closeTo(30.0, 0.01));
        expect(balances['user3'], closeTo(-30.0, 0.01));
      });

      test('Single expense with custom fixed splits', () {
        final expenses = [
          ExpenseModel(
            id: 'expense3',
            groupId: 'group1',
            description: 'Tickets',
            amount: 50.0, // Total amount, sum of custom splits
            date: DateTime.now(),
            participantIds: ['user1', 'user2', 'user3'], // All involved
            payers: [{'userId': 'user1', 'amount': 50.0}],
            createdBy: 'user1',
            splitType: 'fixed', // Assuming 'fixed' means customSplits are absolute amounts owed
            customSplits: [
              {'userId': 'user1', 'amount': 10.0},
              {'userId': 'user2', 'amount': 20.0},
              {'userId': 'user3', 'amount': 20.0},
            ],
          ),
        ];
        final balances = debtCalculatorService.calculateBalances(expenses, group);
        // user1 paid 50, owes 10 -> +40
        // user2 paid 0, owes 20 -> -20
        // user3 paid 0, owes 20 -> -20
        expect(balances['user1'], closeTo(40.0, 0.01));
        expect(balances['user2'], closeTo(-20.0, 0.01));
        expect(balances['user3'], closeTo(-20.0, 0.01));
      });

      test('Expense where one user paid, but multiple users participated (equal split)', () {
        final expenses = [
          ExpenseModel(
            id: 'expense4',
            groupId: 'group1',
            description: 'Dinner',
            amount: 90.0,
            date: DateTime.now(),
            participantIds: ['user1', 'user2', 'user3'],
            payers: [{'userId': 'user1', 'amount': 90.0}],
            createdBy: 'user1',
            splitType: 'equal',
          ),
        ];
        final balances = debtCalculatorService.calculateBalances(expenses, group);
        // user1 paid 90, share 30 -> +60
        // user2 paid 0, share 30 -> -30
        // user3 paid 0, share 30 -> -30
        expect(balances['user1'], closeTo(60.0, 0.01));
        expect(balances['user2'], closeTo(-30.0, 0.01));
        expect(balances['user3'], closeTo(-30.0, 0.01));
      });

      test('Expense where multiple users paid different amounts, equal split', () {
        final expenses = [
          ExpenseModel(
            id: 'expense5',
            groupId: 'group1',
            description: 'Event',
            amount: 120.0, // Total amount
            date: DateTime.now(),
            participantIds: ['user1', 'user2', 'user3'], // Share is 40 each
            payers: [
              {'userId': 'user1', 'amount': 60.0},
              {'userId': 'user2', 'amount': 60.0},
            ],
            createdBy: 'user1',
            splitType: 'equal',
          ),
        ];
        final balances = debtCalculatorService.calculateBalances(expenses, group);
        // user1 paid 60, share 40 -> +20
        // user2 paid 60, share 40 -> +20
        // user3 paid 0, share 40 -> -40
        expect(balances['user1'], closeTo(20.0, 0.01));
        expect(balances['user2'], closeTo(20.0, 0.01));
        expect(balances['user3'], closeTo(-40.0, 0.01));
      });

      test('Edge case - expense amount is zero', () {
        final expenses = [
          ExpenseModel(
            id: 'expense6',
            groupId: 'group1',
            description: 'Freebie',
            amount: 0.0,
            date: DateTime.now(),
            participantIds: ['user1', 'user2', 'user3'],
            payers: [{'userId': 'user1', 'amount': 0.0}],
            createdBy: 'user1',
            splitType: 'equal',
          ),
        ];
        final balances = debtCalculatorService.calculateBalances(expenses, group);
        expect(balances['user1'], closeTo(0.0, 0.01));
        expect(balances['user2'], closeTo(0.0, 0.01));
        expect(balances['user3'], closeTo(0.0, 0.01));
      });

       test('Expense with custom splits not summing to total (should still use custom splits for shares)', () {
        // This tests if custom splits are taken as the definitive shares, regardless of expense.amount
        // The current implementation of calculateBalances uses expense.amount for equal split,
        // but for customSplits, it directly subtracts the split['amount'].
        // The sum of customSplits might not equal expense.amount. The model doesn't enforce this.
        // Let's assume customSplit amounts are what each person *owes* for that expense.
        final expenses = [
          ExpenseModel(
            id: 'expense7',
            groupId: 'group1',
            description: 'Miscalculated Event',
            amount: 100.0, // This amount is used if splitType is 'equal'
            date: DateTime.now(),
            participantIds: ['user1', 'user2', 'user3'],
            payers: [{'userId': 'user1', 'amount': 100.0}], // User1 paid 100
            createdBy: 'user1',
            splitType: 'fixed', // Indicates customSplits should be used
            customSplits: [
              {'userId': 'user1', 'amount': 20.0}, // User1's share is 20
              {'userId': 'user2', 'amount': 30.0}, // User2's share is 30
              {'userId': 'user3', 'amount': 40.0}, // User3's share is 40
            ], // Total shares = 90. User1 paid 100.
          ),
        ];
        // Balances:
        // User1: paid 100, share 20 => +80
        // User2: paid 0,   share 30 => -30
        // User3: paid 0,   share 40 => -40
        final balances = debtCalculatorService.calculateBalances(expenses, group);
        expect(balances['user1'], closeTo(80.0, 0.01));
        expect(balances['user2'], closeTo(-30.0, 0.01));
        expect(balances['user3'], closeTo(-40.0, 0.01));
      });

      test('Expense only involves a subset of group members (equal split)', () {
        final expenses = [
          ExpenseModel(
            id: 'expense8',
            groupId: 'group1',
            description: 'Drinks for two',
            amount: 20.0,
            date: DateTime.now(),
            participantIds: ['user1', 'user2'], // Only user1 and user2 participated
            payers: [{'userId': 'user1', 'amount': 20.0}],
            createdBy: 'user1',
            splitType: 'equal',
          ),
        ];
        // Balances:
        // User1: paid 20, share 10 (20/2) => +10
        // User2: paid 0,  share 10 (20/2) => -10
        // User3: not involved, share 0 => 0
        final balances = debtCalculatorService.calculateBalances(expenses, group);
        expect(balances['user1'], closeTo(10.0, 0.01));
        expect(balances['user2'], closeTo(-10.0, 0.01));
        expect(balances['user3'], closeTo(0.0, 0.01)); // User3 was not part of this expense
      });
    });

    group('simplifyDebts', () {
      test('Simple scenario - one debtor, one creditor', () {
        final balances = {'user1': -50.0, 'user2': 50.0};
        final transactions = debtCalculatorService.simplifyDebts(balances);
        expect(transactions.length, 1);
        expect(transactions[0]['from'], 'user1');
        expect(transactions[0]['to'], 'user2');
        expect(transactions[0]['amount'], closeTo(50.0, 0.01));
      });

      test('Multiple debtors, one creditor', () {
        final balances = {'user1': -20.0, 'user2': -30.0, 'user3': 50.0};
        final transactions = debtCalculatorService.simplifyDebts(balances);
        // Expected: user2 pays user3 30, user1 pays user3 20 (order might vary due to sorting)
        expect(transactions.length, 2);
        expect(transactions.any((t) => t['from'] == 'user2' && t['to'] == 'user3' && (t['amount'] as double).isCloseTo(30.0)), isTrue);
        expect(transactions.any((t) => t['from'] == 'user1' && t['to'] == 'user3' && (t['amount'] as double).isCloseTo(20.0)), isTrue);
      });

      test('One debtor, multiple creditors', () {
        final balances = {'user1': -50.0, 'user2': 20.0, 'user3': 30.0};
        final transactions = debtCalculatorService.simplifyDebts(balances);
        // Expected: user1 pays user3 30, user1 pays user2 20 (order might vary)
        expect(transactions.length, 2);
        expect(transactions.any((t) => t['from'] == 'user1' && t['to'] == 'user3' && (t['amount'] as double).isCloseTo(30.0)), isTrue);
        expect(transactions.any((t) => t['from'] == 'user1' && t['to'] == 'user2' && (t['amount'] as double).isCloseTo(20.0)), isTrue);
      });

      test('Complex scenario - multiple debtors and multiple creditors', () {
        final balances = {'userA': -50.0, 'userB': -20.0, 'userC': 30.0, 'userD': 40.0};
        // Debtors: A (50), B (20) -> Sorted: A, B
        // Creditors: D (40), C (30) -> Sorted: D, C
        final transactions = debtCalculatorService.simplifyDebts(balances);
        // A pays D 40. A still owes 10. D is settled.
        // A pays C 10. A is settled. C needs 20.
        // B pays C 20. B is settled. C is settled.
        expect(transactions.length, 3);
        // Check for specific transactions, amounts may vary slightly due to double precision
        final t1 = transactions.firstWhere((t) => t['from'] == 'userA' && t['to'] == 'userD');
        expect(t1['amount'], closeTo(40.0, 0.01));
        
        final t2 = transactions.firstWhere((t) => t['from'] == 'userA' && t['to'] == 'userC');
        expect(t2['amount'], closeTo(10.0, 0.01));

        final t3 = transactions.firstWhere((t) => t['from'] == 'userB' && t['to'] == 'userC');
        expect(t3['amount'], closeTo(20.0, 0.01));
      });

      test('Balances that are already settled (all zeros)', () {
        final balances = {'user1': 0.0, 'user2': 0.0, 'user3': 0.0};
        final transactions = debtCalculatorService.simplifyDebts(balances);
        expect(transactions.length, 0);
      });
      
      test('Balances that are already settled (close to zero within threshold)', () {
        final balances = {'user1': 0.001, 'user2': -0.002, 'user3': 0.001};
        final transactions = debtCalculatorService.simplifyDebts(balances);
        expect(transactions.length, 0);
      });

      test('Only debtors, no creditors (should result in no transactions)', () {
        final balances = {'user1': -50.0, 'user2': -30.0};
        final transactions = debtCalculatorService.simplifyDebts(balances);
        expect(transactions.length, 0);
      });

      test('Only creditors, no debtors (should result in no transactions)', () {
        final balances = {'user1': 50.0, 'user2': 30.0};
        final transactions = debtCalculatorService.simplifyDebts(balances);
        expect(transactions.length, 0);
      });
      
      test('Balances involving amounts around the 0.01 threshold for floating point precision', () {
        // Scenario 1: Debtor owes slightly more than threshold, creditor is owed slightly more
        var balances = {'userA': -0.015, 'userB': 0.015};
        var transactions = debtCalculatorService.simplifyDebts(balances);
        expect(transactions.length, 1, reason: "Scenario 1 failed");
        expect(transactions[0]['from'], 'userA');
        expect(transactions[0]['to'], 'userB');
        expect(transactions[0]['amount'], closeTo(0.015, 0.0001));

        // Scenario 2: Debtor owes slightly less than threshold
        balances = {'userA': -0.005, 'userB': 0.015};
        transactions = debtCalculatorService.simplifyDebts(balances);
        expect(transactions.length, 0, reason: "Scenario 2 failed - debtor too small");

        // Scenario 3: Creditor is owed slightly less than threshold
        balances = {'userA': -0.015, 'userB': 0.005};
        transactions = debtCalculatorService.simplifyDebts(balances);
        expect(transactions.length, 0, reason: "Scenario 3 failed - creditor too small");

        // Scenario 4: Complex case with threshold considerations
        // userA owes 10.015 (debtor), userB is owed 10.005 (creditor too small), userC is owed 0.015 (creditor)
        balances = {'userA': -10.015, 'userB': 10.005, 'userC': 0.010}; 
        // Expected: userA pays userC 0.01. userB is ignored as creditor. userA still owes 10.005 (debtor).
        // The simplifyDebts algorithm might have userA pay userB first if userB is larger and > 0.01
        // Let's make userB large:
        balances = {'userA': -10.015, 'userB': 20.0, 'userC': 0.010}; // userC is valid creditor
        // Debtors: A (10.015)
        // Creditors: B (20.0), C (0.010) -> Sorted B, C
        // A pays B 10.015. B is owed 9.985. C is owed 0.010.
        // transactions: A -> B (10.015)
        transactions = debtCalculatorService.simplifyDebts(balances);
        expect(transactions.length, 1, reason: "Scenario 4 check 1 failed");
        expect(transactions.any((t) => t['from'] == 'userA' && t['to'] == 'userB' && (t['amount'] as double).isCloseTo(10.015)), isTrue);

        // userA owes 0.015 (debtor), userB owes 0.005 (ignored debtor), userC is owed 0.02 (creditor)
        balances = {'userA': -0.015, 'userB': -0.005, 'userC': 0.020};
        // Debtors: A (0.015)
        // Creditors: C (0.020)
        // A pays C 0.015
        transactions = debtCalculatorService.simplifyDebts(balances);
        expect(transactions.length, 1, reason: "Scenario 4 check 2 failed");
        expect(transactions[0]['from'], 'userA');
        expect(transactions[0]['to'], 'userC');
        expect(transactions[0]['amount'], closeTo(0.015, 0.0001));
      });

      test('Multiple debtors and creditors, testing sorting and sequential settlement', () {
        final balances = {
          'userA': -100.0, // Debtor
          'userB': -50.0,  // Debtor
          'userC': 70.0,   // Creditor
          'userD': 80.0,   // Creditor
        };
        // Sorted Debtors: userA (100), userB (50)
        // Sorted Creditors: userD (80), userC (70)

        final transactions = debtCalculatorService.simplifyDebts(balances);
        
        // Expected transactions:
        // 1. userA pays userD 80.0. userA owes 20. userD settled.
        // 2. userA pays userC 20.0. userA settled. userC needs 50.
        // 3. userB pays userC 50.0. userB settled. userC settled.

        expect(transactions.length, 3);

        expect(transactions.any((t) => t['from'] == 'userA' && t['to'] == 'userD' && (t['amount'] as double).isCloseTo(80.0)), isTrue);
        expect(transactions.any((t) => t['from'] == 'userA' && t['to'] == 'userC' && (t['amount'] as double).isCloseTo(20.0)), isTrue);
        expect(transactions.any((t) => t['from'] == 'userB' && t['to'] == 'userC' && (t['amount'] as double).isCloseTo(50.0)), isTrue);
      });
    });
  });
}

// Helper for comparing doubles with a tolerance, if not using closeTo
extension DoubleIsCloseTo on double {
  bool isCloseTo(double other, [double tolerance = 0.01]) {
    return (this - other).abs() < tolerance;
  }
}

```
