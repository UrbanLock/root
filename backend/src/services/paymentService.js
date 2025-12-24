import { randomUUID } from 'crypto';
import logger from '../utils/logger.js';

/**
 * Servizio pagamenti MOCK
 * NOTA IMPORTANTE: Nessuna transazione bancaria reale, nessun dato sensibile
 * Solo mock per sviluppo/test
 */

let paymentIdCounter = 0;

/**
 * Genera paymentId sequenziale (formato PAY-001)
 */
function generatePaymentId() {
  paymentIdCounter++;
  return `PAY-${paymentIdCounter.toString().padStart(3, '0')}`;
}

/**
 * Processa pagamento mock
 * @param {number} amount - Importo da pagare
 * @param {string} paymentMethod - Metodo pagamento ("mock_card"|"mock_wallet"|"mock_bank")
 * @param {string} depositId - ID deposito (noleggioId)
 * @returns {Promise<Object>} Risultato pagamento mock
 */
export async function processMockPayment(amount, paymentMethod = 'mock_card', depositId) {
  // Simula delay processamento (500ms)
  await new Promise((resolve) => setTimeout(resolve, 500));

  const paymentId = generatePaymentId();
  const transactionId = randomUUID();

  logger.info(`Pagamento mock processato: ${paymentId} per deposito ${depositId}, amount: ${amount}€`);

  // Mock: sempre success
  return {
    paymentId,
    transactionId,
    amount,
    paymentMethod,
    status: 'success',
    timestamp: Date.now(),
  };
}

/**
 * Valida importo pagamento
 * @param {number} amount - Importo da validare
 * @param {number} expectedAmount - Importo atteso
 * @returns {{valid: boolean, error?: string}}
 */
export function validatePaymentAmount(amount, expectedAmount) {
  if (typeof amount !== 'number' || isNaN(amount)) {
    return { valid: false, error: 'Amount deve essere un numero valido' };
  }

  if (amount <= 0) {
    return { valid: false, error: 'Amount deve essere maggiore di 0' };
  }

  // Permette pagamento parziale futuro (per ora accetta qualsiasi amount >= expectedAmount)
  if (amount < expectedAmount) {
    return {
      valid: false,
      error: `Amount (${amount}€) deve essere almeno ${expectedAmount}€`,
    };
  }

  return { valid: true };
}

/**
 * Calcola importo pagamento da noleggio
 * @param {Object} noleggio - Oggetto Noleggio
 * @returns {number} Importo da pagare
 */
export function calculatePaymentAmount(noleggio) {
  if (!noleggio) {
    return 0;
  }

  // Se noleggio terminato, usa costo finale
  if (noleggio.stato === 'terminato' && noleggio.costo) {
    return noleggio.costo;
  }

  // Se noleggio attivo, calcola costo basato su durata attuale
  if (noleggio.stato === 'attivo' && noleggio.costo) {
    // Per ora usa costo già calcolato
    // In futuro si può calcolare basandosi su durata effettiva
    return noleggio.costo;
  }

  return 0;
}

export default {
  processMockPayment,
  validatePaymentAmount,
  calculatePaymentAmount,
};



