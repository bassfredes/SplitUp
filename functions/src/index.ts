import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {onDocumentWritten} from "firebase-functions/v2/firestore";

admin.initializeApp();
interface Expense {
  amount: number;
  currency: string;
  payers: { userId: string; amount: number }[];
  participantIds: string[];
  splitType: string; // 'equal', 'custom', 'percent', 'shares'
  customSplits?: { userId: string; amount: number }[];
}

/**
 * Calculates the balances of each participant per currency in a group.
 * @param {Array<Expense>} expenses - List of group expenses
 * @param {Array<string>} participantIds - IDs of the participants
 * @return {Object} Object with balances per user and currency
 */
function calculateGroupBalances(
  expenses: Expense[],
  participantIds: string[]
): { [userId: string]: { [currency: string]: number } } {
  const userBalances: { [userId: string]: { [currency: string]: number } } = {};

  // Initialize balances for all participants
  for (const userId of participantIds) {
    userBalances[userId] = {};
  }

  // Group expenses by currency
  const expensesByCurrency: { [currency: string]: Expense[] } = {};
  for (const expense of expenses) {
    if (!expensesByCurrency[expense.currency]) {
      expensesByCurrency[expense.currency] = [];
    }
    expensesByCurrency[expense.currency].push(expense);
  }

  // Calculate balances for each currency
  for (const currency in expensesByCurrency) {
    if (!Object.prototype.hasOwnProperty.call(expensesByCurrency, currency)) {
      continue;
    }
    const currencyExpenses = expensesByCurrency[currency];
    const balancesInCurrency: { [userId: string]: number } = {};

    // Initialize balances for this currency
    for (const userId of participantIds) {
      balancesInCurrency[userId] = 0;
    }

    for (const expense of currencyExpenses) {
      const validParticipants = expense.participantIds.filter((id) =>
        participantIds.includes(id)
      );
      if (validParticipants.length === 0) continue;

      // Add what each participant paid
      for (const payer of expense.payers) {
        if (participantIds.includes(payer.userId)) {
          balancesInCurrency[payer.userId] =
            (balancesInCurrency[payer.userId] || 0) + payer.amount;
        }
      }

      // Subtract what each participant owes based on split type
      let totalShares = 0;
      switch (expense.splitType) {
      case "equal": {
        const share = expense.amount / validParticipants.length;
        for (const userId of validParticipants) {
          balancesInCurrency[userId] =
              (balancesInCurrency[userId] || 0) - share;
        }
        break;
      }
      case "shares": {
        totalShares = validParticipants.reduce(
          (sum, id) =>
            sum +
              (expense.customSplits?.find((s) => s.userId === id)?.amount || 1),
          0
        );
        if (totalShares > 0) {
          for (const userId of validParticipants) {
            const userShareCount =
                expense.customSplits?.find((s) => s.userId === userId)
                  ?.amount || 1;
            const shareAmount =
                (expense.amount * userShareCount) / totalShares;
            balancesInCurrency[userId] =
                (balancesInCurrency[userId] || 0) - shareAmount;
          }
        }
        break;
      }
      case "percent":
      case "custom":
      default: {
        // For 'percent' and 'custom', assume customSplits
        // contains the final amounts
        // (or percentages that must be converted to amounts here if necessary)
        // This logic may need adjustment depending on your exact implementation
        if (expense.customSplits) {
          let totalSplitAmount = 0;
          if (expense.splitType === "percent") {
            totalSplitAmount = 100; // or validate that they sum to 100
          } else {
            // custom
            totalSplitAmount = expense.amount;
            // or validate that they sum to the total
          }

          for (const split of expense.customSplits) {
            if (validParticipants.includes(split.userId)) {
              let amountToSubtract = split.amount;
              if (expense.splitType === "percent" && totalSplitAmount > 0) {
                // Ensure the percentage calculation is correct
                amountToSubtract = (expense.amount * split.amount) / 100;
              }
              // Validate that the sum of custom
              // splits matches the total if 'custom'
              balancesInCurrency[split.userId] =
                  (balancesInCurrency[split.userId] || 0) - amountToSubtract;
            }
          }
        } else {
          // Fallback to equal split if there are no
          // customSplits but the type requires it
          const share = expense.amount / validParticipants.length;
          for (const userId of validParticipants) {
            balancesInCurrency[userId] =
                (balancesInCurrency[userId] || 0) - share;
          }
        }
        break;
      }
      }
    }

    // Assign calculated balances for this currency to the final structure
    for (const userId of participantIds) {
      // Round to 2 decimals to avoid floating point precision issues
      const finalBalance = parseFloat(balancesInCurrency[userId].toFixed(2));
      if (finalBalance !== 0) {
        // Optionally: do not store zero balances
        userBalances[userId][currency] = finalBalance;
      } else {
        // Ensure the currency is removed if the balance is zero
        delete userBalances[userId][currency];
      }
    }
    // Remove users with no balances in any currency
    Object.keys(userBalances).forEach((userId) => {
      if (Object.keys(userBalances[userId]).length === 0) {
        delete userBalances[userId];
      }
    });
  }

  return userBalances;
}

export const onExpenseWrite = onDocumentWritten(
  "groups/{groupId}/expenses/{expenseId}",
  async (event) => {
    const groupId = event.params.groupId;
    const db = admin.firestore();
    // Instead of recalculating here, mark the group as pending
    await db.collection("pendingBalanceRecalc").doc(groupId).set({
      groupId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Do not recalculate balances here
    return;
  }
);

// Scheduled function every minute to process pending groups
export const processPendingBalanceRecalcs = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {
    const db = admin.firestore();
    const pendingSnap = await db.collection("pendingBalanceRecalc").get();
    for (const doc of pendingSnap.docs) {
      const groupId = doc.id;
      const groupRef = db.collection("groups").doc(groupId);
      functions.logger.info(`Processing balance recalculation for group: ${groupId}`);
      try {
        // 1. Read all current expenses of the group
        const expensesSnapshot = await groupRef.collection("expenses").get();
        const expensesData = expensesSnapshot.docs.map(
          (doc) => doc.data() as Expense
        );
        // 2. Read the group document to get participants
        const groupDoc = await groupRef.get();
        if (!groupDoc.exists) {
          functions.logger.warn(`Group ${groupId} not found.`);
          await doc.ref.delete();
          continue;
        }
        const groupData = groupDoc.data();
        const participantIds = (groupData?.participantIds as string[]) || [];
        if (participantIds.length === 0) {
          functions.logger.info(
            `Group ${groupId} has no participants. Cleaning balances.`
          );
          await groupRef.update({ participantBalances: {} });
          await doc.ref.delete();
          continue;
        }
        // 3. Calculate balances
        const calculatedBalances = calculateGroupBalances(
          expensesData,
          participantIds
        );
        // 4. Transform to app-compatible format
        const participantBalancesArray = Object.entries(calculatedBalances).map(
          ([userId, balances]) => ({ userId, balances })
        );
        // 5. Update the group document
        await groupRef.update({ participantBalances: participantBalancesArray });
        // 6. Remove the pending mark
        await doc.ref.delete();
        functions.logger.info(
          `Balances updated for group: ${groupId}`
        );
      } catch (error) {
        functions.logger.error(
          `Error recalculating balances for group ${groupId}:`,
          error
        );
        // Do not remove the mark, it will be retried in the next cycle
      }
    }
    return null;
  });
