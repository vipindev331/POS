import { getDb } from '../../../db/index.js';
import { TransactionsRepository as Repo } from '../repositories/transactions.repository.js';
import { ProductsRepository } from '../../products/repositories/products.repository.js';
import { CustomersRepository } from '../../customers/repositories/customers.repository.js';
import { InventoryRepository } from '../../inventory/repositories/inventory.repository.js';
import { computeBill } from '../../../utils/money.js';
import { newId, now, badRequest, notFound, forbidden, conflict } from '../../../utils/http.js';
import { audit } from '../../../utils/audit.js';
import env from '../../../config/env.js';

// Assemble a full bill DTO from its rows.
export function billDto(billRow) {
  return {
    id: billRow.id,
    invoiceNo: billRow.invoice_no,
    branchId: billRow.branch_id,
    customerId: billRow.customer_id,
    cashierId: billRow.cashier_id,
    status: billRow.status,
    subTotal: billRow.sub_total,
    itemDiscount: billRow.item_discount,
    billDiscount: billRow.bill_discount,
    cgst: billRow.cgst,
    sgst: billRow.sgst,
    igst: billRow.igst,
    totalTax: billRow.total_tax,
    roundOff: billRow.round_off,
    grandTotal: billRow.grand_total,
    paid: billRow.paid,
    interState: !!billRow.inter_state,
    note: billRow.note,
    createdAt: billRow.created_at,
    items: Repo.items(billRow.id).map((i) => ({
      id: i.id, productId: i.product_id, name: i.name, hsn: i.hsn, qty: i.qty,
      unitPrice: i.unit_price, lineDiscount: i.line_discount, gstRate: i.gst_rate,
      taxable: i.taxable, cgst: i.cgst, sgst: i.sgst, igst: i.igst, lineTotal: i.line_total,
    })),
    payments: Repo.payments(billRow.id).map((p) => ({
      id: p.id, method: p.method, amount: p.amount, reference: p.reference,
    })),
  };
}

export const TransactionsService = {
  /**
   * Idempotent checkout. Replaying the same idempotencyKey (or a duplicate
   * bill id) returns the already-stored bill without touching stock again.
   */
  checkout(payload, user) {
    const {
      billId, idempotencyKey, customerId = null, items, billDiscount = 0,
      payments = [], interState = false, allowNegativeStock = false, note = null,
      status = 'completed',
    } = payload;

    // 1. Idempotent replay guards.
    const byKey = Repo.findByIdempotencyKey(idempotencyKey);
    if (byKey) return { bill: billDto(byKey), replayed: true };
    if (billId) {
      const existing = Repo.findBillRow(billId);
      if (existing) return { bill: billDto(existing), replayed: true };
    }

    if (!Array.isArray(items) || items.length === 0) throw badRequest('items cannot be empty');

    // 2. Resolve products, snapshot name/hsn, build tax-engine inputs.
    const engineItems = items.map((it) => {
      const p = it.productId ? ProductsRepository.findById(it.productId) : null;
      if (it.productId && !p) throw notFound(`Product ${it.productId} not found`);
      return {
        productId: it.productId ?? null,
        name: it.name ?? p?.name ?? 'Item',
        hsn: it.hsn ?? p?.hsn ?? null,
        unitPrice: it.unitPrice ?? p?.selling_price ?? 0,
        qty: it.qty,
        lineDiscount: it.lineDiscount ?? 0,
        gstRate: it.gstRate ?? p?.gst_rate ?? 0,
      };
    });

    // 3. Deterministic math (identical to the Flutter client).
    const computed = computeBill(engineItems, { billDiscount, interState });

    // 4. Stock guard (unless manager explicitly overrides).
    for (const it of engineItems) {
      if (!it.productId) continue;
      const available = InventoryRepository.currentStock(it.productId);
      if (available < it.qty) {
        if (!(allowNegativeStock && user.role === 'manager')) {
          throw conflict(`Insufficient stock for "${it.name}" (have ${available}, need ${it.qty})`, {
            productId: it.productId, available, requested: it.qty,
          });
        }
      }
    }

    const paid = payments.reduce((s, p) => s + p.amount, 0);
    const usesCredit = payments.some((p) => p.method === 'credit') || paid < computed.grandTotal;
    if (usesCredit && !customerId) {
      throw badRequest('Credit / partial payment requires a customer');
    }

    const ts = now();
    const finalBillId = billId ?? newId();

    // 5. Single atomic transaction.
    const run = getDb().transaction(() => {
      const invoiceNo = status === 'held' ? null : Repo.allocateInvoiceNo(env.branchId);

      Repo.insertBill({
        id: finalBillId,
        invoice_no: invoiceNo,
        branch_id: env.branchId,
        customer_id: customerId,
        cashier_id: user.id,
        status,
        sub_total: computed.subTotal,
        item_discount: computed.itemDiscount,
        bill_discount: computed.billDiscount,
        cgst: computed.cgst,
        sgst: computed.sgst,
        igst: computed.igst,
        total_tax: computed.totalTax,
        round_off: computed.roundOff,
        grand_total: computed.grandTotal,
        paid,
        inter_state: interState ? 1 : 0,
        idempotency_key: idempotencyKey ?? null,
        note,
        created_at: ts,
        updated_at: ts,
      });

      computed.lines.forEach((line, i) => {
        const src = engineItems[i];
        Repo.insertItem({
          id: newId(),
          bill_id: finalBillId,
          product_id: src.productId,
          name: src.name,
          hsn: src.hsn,
          qty: src.qty,
          unit_price: src.unitPrice,
          line_discount: src.lineDiscount,
          gst_rate: src.gstRate,
          taxable: line.taxable,
          cgst: line.cgst,
          sgst: line.sgst,
          igst: line.igst,
          line_total: line.lineTotal,
        });
        // Held bills don't move stock until resumed & completed.
        if (status === 'completed' && src.productId) {
          InventoryRepository.applyMovement({
            productId: src.productId,
            change: -src.qty,
            reason: 'sale',
            refType: 'bill',
            refId: finalBillId,
            ts,
          });
        }
      });

      for (const p of payments) {
        Repo.insertPayment({
          id: newId(), bill_id: finalBillId, method: p.method,
          amount: p.amount, reference: p.reference ?? null, created_at: ts,
        });
      }

      // Credit → increase customer balance (they owe us) + ledger entry.
      if (status === 'completed' && customerId) {
        const due = computed.grandTotal - paid;
        if (due > 0) {
          const cust = CustomersRepository.adjustBalance(customerId, due, ts);
          Repo.insertLedger({
            id: newId(), party_type: 'customer', party_id: customerId,
            ref_type: 'bill', ref_id: finalBillId, debit: due, credit: 0,
            balance_after: cust.balance, note: `Credit on ${invoiceNo}`, created_at: ts,
          });
        }
        // Loyalty: 1 point per ₹100 of grand total.
        CustomersRepository.addLoyalty(customerId, Math.floor(computed.grandTotal / 10000), ts);
      }

      audit({
        userId: user.id, action: status === 'held' ? 'hold_bill' : 'checkout',
        entity: 'bill', entityId: finalBillId,
        detail: { invoiceNo, grandTotal: computed.grandTotal, items: engineItems.length },
      });
    });
    run();

    return { bill: billDto(Repo.findBillRow(finalBillId)), replayed: false };
  },

  get(id) {
    const row = Repo.findBillRow(id);
    if (!row) throw notFound('Bill not found');
    return billDto(row);
  },

  list(opts) {
    return Repo.list(opts).map(billDto);
  },

  /** Full or partial return: restocks items and reverses credit. */
  returnBill({ billId, reason = null }, user) {
    const original = Repo.findBillRow(billId);
    if (!original) throw notFound('Bill not found');
    if (original.status === 'returned') throw conflict('Bill already returned');
    if (original.status !== 'completed') throw badRequest('Only completed bills can be returned');

    const ts = now();
    const run = getDb().transaction(() => {
      for (const it of Repo.items(billId)) {
        if (it.product_id) {
          InventoryRepository.applyMovement({
            productId: it.product_id, change: it.qty, reason: 'return',
            refType: 'bill_return', refId: billId, ts,
          });
        }
      }
      if (original.customer_id) {
        const due = original.grand_total - original.paid;
        if (due > 0) {
          const cust = CustomersRepository.adjustBalance(original.customer_id, -due, ts);
          Repo.insertLedger({
            id: newId(), party_type: 'customer', party_id: original.customer_id,
            ref_type: 'bill_return', ref_id: billId, debit: 0, credit: due,
            balance_after: cust.balance, note: `Return of ${original.invoice_no}`, created_at: ts,
          });
        }
      }
      Repo.updateStatus(billId, 'returned', ts);
      audit({ userId: user.id, action: 'return_bill', entity: 'bill', entityId: billId, detail: { reason } });
    });
    run();
    return billDto(Repo.findBillRow(billId));
  },
};
