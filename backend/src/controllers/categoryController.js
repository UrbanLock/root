import CategoriaLocker from '../models/CategoriaLocker.js';
import {
  NotFoundError,
  ValidationError,
  UnauthorizedError,
} from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';

/**
 * GET /api/v1/admin/categories
 * Lista tutte le categorie locker
 * RF20: Lista categorie locker
 */
export async function getAllCategories(req, res, next) {
  try {
    const { attiva } = req.query;

    // Costruisci query
    const query = {};

    // Filtro attiva
    if (attiva !== undefined) {
      const isAttiva = attiva === 'true' || attiva === true;
      query.attiva = isAttiva;
    }

    // Trova categorie
    const categorie = await CategoriaLocker.find(query)
      .sort({ nome: 1 })
      .lean();

    // Formatta risposte
    const items = categorie.map((categoria) => ({
      id: categoria.categoriaId,
      nome: categoria.nome,
      descrizione: categoria.descrizione || null,
      icon: categoria.icona || null,
      color: categoria.colore || null,
      features: categoria.caratteristiche || [],
      active: categoria.attiva,
      createdAt: categoria.dataCreazione,
      updatedAt: categoria.dataModifica,
    }));

    logger.info(`Categorie locker recuperate: ${items.length}`);

    res.json({
      success: true,
      data: {
        items,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/admin/categories
 * Crea nuova categoria locker
 * RF20: Crea categoria locker
 */
export async function createCategory(req, res, next) {
  try {
    const { nome, descrizione, icona, colore, caratteristiche } = req.body;

    // Validazione
    if (!nome) {
      throw new ValidationError('nome è obbligatorio');
    }

    // Verifica nome univoco
    const categoriaEsistente = await CategoriaLocker.findOne({
      nome: nome.trim(),
    });

    if (categoriaEsistente) {
      throw new ValidationError('Categoria con questo nome già esistente');
    }

    // Genera categoriaId
    const categoriaId = await CategoriaLocker.generateCategoriaId();

    // Crea categoria
    const categoria = await CategoriaLocker.create({
      categoriaId,
      nome: nome.trim(),
      descrizione: descrizione || null,
      icona: icona || null,
      colore: colore || null,
      caratteristiche: caratteristiche || [],
      attiva: true,
      dataCreazione: new Date(),
      dataModifica: new Date(),
    });

    logger.info(`Categoria locker creata: ${categoriaId} (${nome})`);

    res.status(201).json({
      success: true,
      data: {
        category: {
          id: categoria.categoriaId,
          nome: categoria.nome,
          descrizione: categoria.descrizione || null,
          icon: categoria.icona || null,
          color: categoria.colore || null,
          features: categoria.caratteristiche || [],
          active: categoria.attiva,
          createdAt: categoria.dataCreazione,
          updatedAt: categoria.dataModifica,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/admin/categories/:id
 * Dettaglio categoria locker
 * RF20: Dettaglio categoria locker
 */
export async function getCategoryById(req, res, next) {
  try {
    const { id } = req.params;

    // Trova categoria
    const categoria = await CategoriaLocker.findOne({ categoriaId: id }).lean();

    if (!categoria) {
      throw new NotFoundError('Categoria non trovata');
    }

    logger.info(`Categoria locker recuperata: ${id}`);

    res.json({
      success: true,
      data: {
        category: {
          id: categoria.categoriaId,
          nome: categoria.nome,
          descrizione: categoria.descrizione || null,
          icon: categoria.icona || null,
          color: categoria.colore || null,
          features: categoria.caratteristiche || [],
          active: categoria.attiva,
          createdAt: categoria.dataCreazione,
          updatedAt: categoria.dataModifica,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * PUT /api/v1/admin/categories/:id
 * Aggiorna categoria locker
 * RF20: Aggiorna categoria locker
 */
export async function updateCategory(req, res, next) {
  try {
    const { id } = req.params;
    const { nome, descrizione, icona, colore, caratteristiche, attiva } =
      req.body;

    // Trova categoria
    const categoria = await CategoriaLocker.findOne({ categoriaId: id });

    if (!categoria) {
      throw new NotFoundError('Categoria non trovata');
    }

    // Aggiorna campi
    if (nome !== undefined) {
      // Verifica nome univoco se cambiato
      if (nome.trim() !== categoria.nome) {
        const categoriaEsistente = await CategoriaLocker.findOne({
          nome: nome.trim(),
          categoriaId: { $ne: id },
        });

        if (categoriaEsistente) {
          throw new ValidationError('Categoria con questo nome già esistente');
        }
      }
      categoria.nome = nome.trim();
    }

    if (descrizione !== undefined) {
      categoria.descrizione = descrizione || null;
    }

    if (icona !== undefined) {
      categoria.icona = icona || null;
    }

    if (colore !== undefined) {
      categoria.colore = colore || null;
    }

    if (caratteristiche !== undefined) {
      categoria.caratteristiche = caratteristiche || [];
    }

    if (attiva !== undefined) {
      categoria.attiva = attiva;
    }

    categoria.dataModifica = new Date();

    await categoria.save();

    logger.info(`Categoria locker aggiornata: ${id}`);

    res.json({
      success: true,
      data: {
        category: {
          id: categoria.categoriaId,
          nome: categoria.nome,
          descrizione: categoria.descrizione || null,
          icon: categoria.icona || null,
          color: categoria.colore || null,
          features: categoria.caratteristiche || [],
          active: categoria.attiva,
          createdAt: categoria.dataCreazione,
          updatedAt: categoria.dataModifica,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * DELETE /api/v1/admin/categories/:id
 * Elimina categoria locker
 * RF20: Elimina categoria locker
 */
export async function deleteCategory(req, res, next) {
  try {
    const { id } = req.params;

    // Trova categoria
    const categoria = await CategoriaLocker.findOne({ categoriaId: id });

    if (!categoria) {
      throw new NotFoundError('Categoria non trovata');
    }

    // Elimina categoria
    await CategoriaLocker.deleteOne({ categoriaId: id });

    logger.info(`Categoria locker eliminata: ${id}`);

    res.json({
      success: true,
      data: {
        message: 'Categoria eliminata con successo',
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  getAllCategories,
  createCategory,
  getCategoryById,
  updateCategory,
  deleteCategory,
};

