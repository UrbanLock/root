import Cell from '../models/Cell.js';
import { NotFoundError, ValidationError } from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';

/**
 * PUT /api/v1/cells/:id
 * Aggiorna cella
 */
export async function updateCell(req, res, next) {
  try {
    const { id } = req.params;
    const updateData = req.body;

    logger.info(`Aggiornamento cella ${id}:`, { updateData });

    // Campi che possono essere aggiornati
    const allowedFields = [
      'categoria',
      'richiede_foto',
      'stato',
      'costo',
      'grandezza',
      'tipo',
      'peso',
      'fotoUrl',
      'operatoreCreatoreId',
    ];

    // Filtra solo i campi consentiti
    const filteredUpdate = {};
    for (const field of allowedFields) {
      if (updateData[field] !== undefined) {
        filteredUpdate[field] = updateData[field];
      }
    }

    logger.info(`Campi filtrati per aggiornamento:`, { filteredUpdate });

    // Verifica che ci sia almeno un campo da aggiornare
    if (Object.keys(filteredUpdate).length === 0) {
      throw new ValidationError('Nessun campo valido da aggiornare');
    }

    // Trova e aggiorna la cella
    const cell = await Cell.findOneAndUpdate(
      { cellaId: id },
      { $set: filteredUpdate },
      { new: true, runValidators: true }
    );

    if (!cell) {
      throw new NotFoundError(`Cella con ID ${id} non trovata`);
    }

    logger.info(`Cella ${id} aggiornata con successo: ${Object.keys(filteredUpdate).join(', ')}`);

    // Estrai numero cella da cellaId (es. "CEL-001-1" -> "Cella 1")
    const cellNumberMatch = cell.cellaId.match(/CEL-[\w-]+-(\d+)/);
    const cellNumber = cellNumberMatch ? `Cella ${parseInt(cellNumberMatch[1], 10)}` : cell.cellaId;

    // Mapping tipo backend -> frontend
    const tipoMapping = {
      'deposito': 'deposit',
      'prestito': 'borrow',
      'ordini': 'pickup',
    };

    // Mapping grandezza backend -> frontend
    const grandezzaMapping = {
      'piccola': 'small',
      'media': 'medium',
      'grande': 'large',
      'extra_large': 'extraLarge',
    };

    // Formatta cella per frontend
    const cellFormattata = {
      id: cell.cellaId,
      cellNumber,
      type: tipoMapping[cell.tipo] || 'deposit',
      size: grandezzaMapping[cell.grandezza] || 'medium',
      isAvailable: cell.stato === 'libera', // Disponibile solo se 'libera'
      stato: cell.stato, // Aggiungi lo stato per il frontend
      pricePerHour: cell.costo || 0,
      pricePerDay: (cell.costo || 0) * 10, // Stima
      grandezza: cell.grandezza,
      richiede_foto: cell.richiede_foto,
      categoria: cell.categoria || null,
      peso: cell.peso,
    };

    res.json({
      success: true,
      data: {
        cell: cellFormattata,
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  updateCell,
};

