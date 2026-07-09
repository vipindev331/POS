import { getDb } from '../../../db/index.js';
import { InventoryRepository } from '../repositories/inventory.repository.js';
import { now, badRequest, forbidden } from '../../../utils/http.js';
import { audit } from '../../../utils/audit.js';

export const InventoryService = {
  // Manual stock adjustment (stock-in, stock-out, correction).
  adjust({ productId, change, reason = 'adjustment', note = null }, user, ip) {
    if (!Number.isInteger(change) || change === 0) throw badRequest('change must be a non-zero integer');
    const projected = InventoryRepository.currentStock(productId) + change;
    if (projected < 0 && user.role !== 'manager') {
      throw forbidden('Adjustment would make stock negative — manager approval required');
    }
    const ts = now();
    const tx = getDb().transaction(() => {
      const balance = InventoryRepository.applyMovement({ productId, change, reason, note, ts });
      audit({ userId: user.id, action: 'stock_adjust', entity: 'product', entityId: productId, detail: { change, reason }, ip });
      return balance;
    });
    return { productId, stock: tx() };
  },
  ledger: (productId) => InventoryRepository.ledger(productId),
};
