import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

admin.initializeApp();
const db = admin.firestore();

// --- INICIO: Lógica adaptada de DebtCalculatorService ---
// Debes incluir o importar tu lógica real aquí.
// Esta es una versión simplificada como ejemplo.
interface Expense {
  amount: number;
  currency: string;
  payers: { userId: string; amount: number }[];
  participantIds: string[];
  splitType: string; // 'equal', 'custom', 'percent', 'shares'
  customSplits?: { userId: string; amount: number }[];
}

function calculateGroupBalances(
  expenses: Expense[],
  participantIds: string[]
): { [userId: string]: { [currency: string]: number } } {
  const userBalances: { [userId: string]: { [currency: string]: number } } = {};

  // Inicializar balances para todos los participantes
  for (const userId of participantIds) {
    userBalances[userId] = {};
  }

  // Agrupar gastos por moneda
  const expensesByCurrency: { [currency: string]: Expense[] } = {};
  for (const expense of expenses) {
    if (!expensesByCurrency[expense.currency]) {
      expensesByCurrency[expense.currency] = [];
    }
    expensesByCurrency[expense.currency].push(expense);
  }

  // Calcular balances por cada moneda
  for (const currency in expensesByCurrency) {
    const currencyExpenses = expensesByCurrency[currency];
    const balancesInCurrency: { [userId: string]: number } = {};

    // Inicializar balances para esta moneda
    for (const userId of participantIds) {
      balancesInCurrency[userId] = 0;
    }

    for (const expense of currencyExpenses) {
      const validParticipants = expense.participantIds.filter((id) =>
        participantIds.includes(id)
      );
      if (validParticipants.length === 0) continue;

      // Sumar lo que cada uno pagó
      for (const payer of expense.payers) {
        if (participantIds.includes(payer.userId)) {
          balancesInCurrency[payer.userId] =
            (balancesInCurrency[payer.userId] || 0) + payer.amount;
        }
      }

      // Restar lo que cada uno debe según el tipo de división
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
        case "custom": // Asume que customSplits tiene montos directos o porcentajes
        default: {
          // Para 'percent' y 'custom', asumimos que customSplits contiene los montos finales
          // (o porcentajes que deben convertirse a montos aquí si es necesario)
          // Esta lógica puede necesitar ajuste según tu implementación exacta
          if (expense.customSplits) {
            let totalSplitAmount = 0;
            if (expense.splitType === "percent") {
              totalSplitAmount = 100; // o validar que sumen 100
            } else {
              // custom
              totalSplitAmount = expense.amount; // o validar que sumen el total
            }

            for (const split of expense.customSplits) {
              if (validParticipants.includes(split.userId)) {
                let amountToSubtract = split.amount;
                if (expense.splitType === "percent" && totalSplitAmount > 0) {
                  // Asegúrate que el cálculo de porcentaje sea correcto
                  amountToSubtract = (expense.amount * split.amount) / 100;
                }
                // Validar que la suma de custom splits coincida con el total si es 'custom'
                balancesInCurrency[split.userId] =
                  (balancesInCurrency[split.userId] || 0) - amountToSubtract;
              }
            }
          } else {
            // Fallback a división igual si no hay customSplits pero el tipo lo requiere
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

    // Asignar balances calculados para esta moneda a la estructura final
    for (const userId of participantIds) {
      // Redondear a 2 decimales para evitar problemas de precisión flotante
      const finalBalance = parseFloat(balancesInCurrency[userId].toFixed(2));
      if (finalBalance !== 0) {
        // Opcional: no guardar balances cero
        userBalances[userId][currency] = finalBalance;
      } else {
        // Asegurarse de eliminar la moneda si el balance es cero
        delete userBalances[userId][currency];
      }
    }
    // Limpiar usuarios sin balances en ninguna moneda
    Object.keys(userBalances).forEach((userId) => {
      if (Object.keys(userBalances[userId]).length === 0) {
        delete userBalances[userId];
      }
    });
  }

  return userBalances;
}
// --- FIN: Lógica adaptada de DebtCalculatorService ---

export const onExpenseWrite = onDocumentWritten(
  "groups/{groupId}/expenses/{expenseId}",
  async (event) => {
    const groupId = event.params.groupId;
    const db = admin.firestore();
    const groupRef = db.collection("groups").doc(groupId);

    functions.logger.info(`Recalculating balances for group: ${groupId}`);

    try {
      // 1. Leer todos los gastos actuales del grupo
      const expensesSnapshot = await groupRef.collection("expenses").get();
      const expensesData = expensesSnapshot.docs.map(
        (doc) => doc.data() as Expense
      );

      // 2. Leer el documento del grupo para obtener participantes
      const groupDoc = await groupRef.get();
      if (!groupDoc.exists) {
        functions.logger.warn(`Group ${groupId} not found.`);
        return;
      }
      const groupData = groupDoc.data();
      const participantIds = (groupData?.participantIds as string[]) || [];

      if (participantIds.length === 0) {
        functions.logger.info(
          `Group ${groupId} has no participants. Clearing balances.`
        );
        // Si no hay participantes, limpiar los balances
        await groupRef.update({ participantBalances: {} });
        return;
      }

      // 3. Calcular los balances
      const calculatedBalances = calculateGroupBalances(
        expensesData,
        participantIds
      );

      // 4. Actualizar el documento del grupo
      await groupRef.update({ participantBalances: calculatedBalances });

      functions.logger.info(
        `Successfully updated balances for group: ${groupId}`
      );
    } catch (error) {
      functions.logger.error(
        `Error recalculating balances for group ${groupId}:`,
        error
      );
      return;
    }
  }
);
