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
  date?: string | number; // Puede ser string, number o Timestamp
}

export const onExpenseWrite = onDocumentWritten(
  "groups/{groupId}/expenses/{expenseId}",
  async (event) => {
    const db = admin.firestore();
    const groupId = event.params.groupId;
    const expenseId = event.params.expenseId;
    const groupRef = db.collection("groups").doc(groupId);

    // Simple lock: check if update in progress
    const groupDoc = await groupRef.get();
    if (groupDoc.exists && groupDoc.get("balanceUpdateInProgress")) {
      functions.logger.warn(
        `Balance update already in progress for group ${groupId}, skipping.`
      );
      return;
    }
    // Set lock
    await groupRef.update({balanceUpdateInProgress: true});

    try {
      const before = event.data?.before?.data();
      const after = event.data?.after?.data();
      const groupData = (await groupRef.get()).data();
      const participantIds = (groupData?.participantIds as string[]) || [];
      let participantBalances = groupData?.participantBalances || [];
      let lastExpense = groupData?.lastExpense || null;
      let totalExpenses = groupData?.totalExpenses || 0;
      let expensesCount = groupData?.expensesCount || 0;

      /**
       * Actualiza el balance de un usuario en una moneda específica.
       * @param {Array<{userId: string, balances: Record<string, number>}>} balancesArr
       *   Arreglo de balances por usuario
       * @param {string} userId ID del usuario
       * @param {string} currency Moneda
       * @param {number} diff Diferencia a sumar/restar
       */
      const updateBalances = (
        balancesArr: Array<{
          userId: string;
          balances: Record<string, number>;
        }>,
        userId: string,
        currency: string,
        diff: number
      ) => {
        let found = balancesArr.find((b) => b.userId === userId);
        if (!found) {
          found = {userId, balances: {}};
          balancesArr.push(found);
        }
        found.balances[currency] = (found.balances[currency] || 0) + diff;
        // Limpiar balances en cero
        if (Math.abs(found.balances[currency]) < 0.01) {
          delete found.balances[currency];
        }
      };

      // 1. Handle deleted expense
      if (before && !after) {
        // Remove from balances
        const expense = before as Expense;
        // Revert balances
        for (const payer of expense.payers) {
          if (participantIds.includes(payer.userId)) {
            updateBalances(
              participantBalances,
              payer.userId,
              expense.currency,
              -payer.amount
            );
          }
        }
        // Revert splits
        const validParticipants = expense.participantIds.filter((id) =>
          participantIds.includes(id)
        );
        let totalShares = 0;
        switch (expense.splitType) {
        case "equal": {
          const share = expense.amount / validParticipants.length;
          for (const userId of validParticipants) {
            updateBalances(
              participantBalances,
              userId,
              expense.currency,
              share
            );
          }
          break;
        }
        case "shares": {
          totalShares = validParticipants.reduce(
            (sum, id) =>
              sum +
                (expense.customSplits?.find((s) => s.userId === id)?.amount ||
                  1),
            0
          );
          if (totalShares > 0) {
            for (const userId of validParticipants) {
              const userShareCount =
                  expense.customSplits?.find((s) => s.userId === userId)
                    ?.amount || 1;
              const shareAmount =
                  (expense.amount * userShareCount) / totalShares;
              updateBalances(
                participantBalances,
                userId,
                expense.currency,
                shareAmount
              );
            }
          }
          break;
        }
        case "percent":
        case "custom":
        default: {
          if (expense.customSplits) {
            for (const split of expense.customSplits) {
              if (validParticipants.includes(split.userId)) {
                let amountToAdd = split.amount;
                if (expense.splitType === "percent") {
                  amountToAdd = (expense.amount * split.amount) / 100;
                }
                updateBalances(
                  participantBalances,
                  split.userId,
                  expense.currency,
                  amountToAdd
                );
              }
            }
          } else {
            const share = expense.amount / validParticipants.length;
            for (const userId of validParticipants) {
              updateBalances(
                participantBalances,
                userId,
                expense.currency,
                share
              );
            }
          }
          break;
        }
        }
        // Update counters
        expensesCount = Math.max(0, expensesCount - 1);
        totalExpenses = Math.max(0, totalExpenses - expense.amount);
        // Update lastExpense si corresponde
        if (lastExpense && lastExpense.id === expenseId) {
          // Buscar el nuevo último gasto
          const lastSnap = await groupRef
            .collection("expenses")
            .orderBy("date", "desc")
            .limit(1)
            .get();
          lastExpense = lastSnap.empty ?
            null :
            {...lastSnap.docs[0].data(), id: lastSnap.docs[0].id};
        }
      }

      // 2. Handle created expense
      if (!before && after) {
        const expense = after as Expense;
        // Sumar balances
        for (const payer of expense.payers) {
          if (participantIds.includes(payer.userId)) {
            updateBalances(
              participantBalances,
              payer.userId,
              expense.currency,
              payer.amount
            );
          }
        }
        // Restar splits
        const validParticipants = expense.participantIds.filter((id) =>
          participantIds.includes(id)
        );
        let totalShares = 0;
        switch (expense.splitType) {
        case "equal": {
          const share = expense.amount / validParticipants.length;
          for (const userId of validParticipants) {
            updateBalances(
              participantBalances,
              userId,
              expense.currency,
              -share
            );
          }
          break;
        }
        case "shares": {
          totalShares = validParticipants.reduce(
            (sum, id) =>
              sum +
                (expense.customSplits?.find((s) => s.userId === id)?.amount ||
                  1),
            0
          );
          if (totalShares > 0) {
            for (const userId of validParticipants) {
              const userShareCount =
                  expense.customSplits?.find((s) => s.userId === userId)
                    ?.amount || 1;
              const shareAmount =
                  (expense.amount * userShareCount) / totalShares;
              updateBalances(
                participantBalances,
                userId,
                expense.currency,
                -shareAmount
              );
            }
          }
          break;
        }
        case "percent":
        case "custom":
        default: {
          if (expense.customSplits) {
            for (const split of expense.customSplits) {
              if (validParticipants.includes(split.userId)) {
                let amountToSubtract = split.amount;
                if (expense.splitType === "percent") {
                  amountToSubtract = (expense.amount * split.amount) / 100;
                }
                updateBalances(
                  participantBalances,
                  split.userId,
                  expense.currency,
                  -amountToSubtract
                );
              }
            }
          } else {
            const share = expense.amount / validParticipants.length;
            for (const userId of validParticipants) {
              updateBalances(
                participantBalances,
                userId,
                expense.currency,
                -share
              );
            }
          }
          break;
        }
        }
        // Update counters
        expensesCount += 1;
        totalExpenses += expense.amount;
        // Update lastExpense si corresponde
        if (
          !lastExpense ||
          (expense.date && expense.date >= (lastExpense.date || ""))
        ) {
          lastExpense = {...expense, id: expenseId};
        }
      }

      // 3. Handle updated expense
      if (before && after) {
        // Revertir el gasto anterior
        const beforeExpense = before as Expense;
        for (const payer of beforeExpense.payers) {
          if (participantIds.includes(payer.userId)) {
            updateBalances(
              participantBalances,
              payer.userId,
              beforeExpense.currency,
              -payer.amount
            );
          }
        }
        const validParticipantsBefore = beforeExpense.participantIds.filter((id) =>
          participantIds.includes(id)
        );
        let totalSharesBefore = 0;
        switch (beforeExpense.splitType) {
        case "equal": {
          const share = beforeExpense.amount / validParticipantsBefore.length;
          for (const userId of validParticipantsBefore) {
            updateBalances(
              participantBalances,
              userId,
              beforeExpense.currency,
              share
            );
          }
          break;
        }
        case "shares": {
          totalSharesBefore = validParticipantsBefore.reduce(
            (sum, id) =>
              sum +
                  (beforeExpense.customSplits?.find((s) => s.userId === id)?.amount ||
                    1),
            0
          );
          if (totalSharesBefore > 0) {
            for (const userId of validParticipantsBefore) {
              const userShareCount =
                    beforeExpense.customSplits?.find((s) => s.userId === userId)
                      ?.amount || 1;
              const shareAmount =
                    (beforeExpense.amount * userShareCount) / totalSharesBefore;
              updateBalances(
                participantBalances,
                userId,
                beforeExpense.currency,
                shareAmount
              );
            }
          }
          break;
        }
        case "percent":
        case "custom":
        default: {
          if (beforeExpense.customSplits) {
            for (const split of beforeExpense.customSplits) {
              if (validParticipantsBefore.includes(split.userId)) {
                let amountToAdd = split.amount;
                if (beforeExpense.splitType === "percent") {
                  amountToAdd = (beforeExpense.amount * split.amount) / 100;
                }
                updateBalances(
                  participantBalances,
                  split.userId,
                  beforeExpense.currency,
                  amountToAdd
                );
              }
            }
          } else {
            const share = beforeExpense.amount / validParticipantsBefore.length;
            for (const userId of validParticipantsBefore) {
              updateBalances(
                participantBalances,
                userId,
                beforeExpense.currency,
                share
              );
            }
          }
          break;
        }
        }
        expensesCount = Math.max(0, expensesCount - 1);
        totalExpenses = Math.max(0, totalExpenses - beforeExpense.amount);

        // Aplicar el nuevo gasto
        const afterExpense = after as Expense;
        for (const payer of afterExpense.payers) {
          if (participantIds.includes(payer.userId)) {
            updateBalances(
              participantBalances,
              payer.userId,
              afterExpense.currency,
              payer.amount
            );
          }
        }
        const validParticipantsAfter = afterExpense.participantIds.filter((id) =>
          participantIds.includes(id)
        );
        let totalSharesAfter = 0;
        switch (afterExpense.splitType) {
        case "equal": {
          const share = afterExpense.amount / validParticipantsAfter.length;
          for (const userId of validParticipantsAfter) {
            updateBalances(
              participantBalances,
              userId,
              afterExpense.currency,
              -share
            );
          }
          break;
        }
        case "shares": {
          totalSharesAfter = validParticipantsAfter.reduce(
            (sum, id) =>
              sum +
                  (afterExpense.customSplits?.find((s) => s.userId === id)?.amount ||
                    1),
            0
          );
          if (totalSharesAfter > 0) {
            for (const userId of validParticipantsAfter) {
              const userShareCount =
                    afterExpense.customSplits?.find((s) => s.userId === userId)
                      ?.amount || 1;
              const shareAmount =
                    (afterExpense.amount * userShareCount) / totalSharesAfter;
              updateBalances(
                participantBalances,
                userId,
                afterExpense.currency,
                -shareAmount
              );
            }
          }
          break;
        }
        case "percent":
        case "custom":
        default: {
          if (afterExpense.customSplits) {
            for (const split of afterExpense.customSplits) {
              if (validParticipantsAfter.includes(split.userId)) {
                let amountToSubtract = split.amount;
                if (afterExpense.splitType === "percent") {
                  amountToSubtract = (afterExpense.amount * split.amount) / 100;
                }
                updateBalances(
                  participantBalances,
                  split.userId,
                  afterExpense.currency,
                  -amountToSubtract
                );
              }
            }
          } else {
            const share = afterExpense.amount / validParticipantsAfter.length;
            for (const userId of validParticipantsAfter) {
              updateBalances(
                participantBalances,
                userId,
                afterExpense.currency,
                -share
              );
            }
          }
          break;
        }
        }
        expensesCount += 1;
        totalExpenses += afterExpense.amount;
        // Update lastExpense si corresponde
        if (
          !lastExpense ||
          (afterExpense.date && afterExpense.date >= (lastExpense.date || ""))
        ) {
          lastExpense = {...afterExpense, id: expenseId};
        }
      }

      // Limpiar balances vacíos
      participantBalances = participantBalances.filter(
        (b: { userId: string; balances: Record<string, number> }) =>
          Object.keys(b.balances).length > 0
      );

      // Guardar cambios
      await groupRef.update({
        participantBalances,
        lastExpense,
        totalExpenses,
        expensesCount,
        balanceUpdateInProgress: false,
      });
    } catch (error) {
      functions.logger.error(
        `Error updating balances for group ${groupId}:`,
        error
      );
      // Unlock on error
      await groupRef.update({balanceUpdateInProgress: false});
    }
    return;
  }
);
