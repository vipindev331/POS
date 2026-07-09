/**
 * MONEY & TAX ENGINE — the single source of truth for all billing math.
 *
 * This module is the canonical spec. `pos_app/lib/core/money/tax_engine.dart`
 * MUST be a byte-equivalent port: the same inputs must yield identical totals
 * on client and server, so an offline-computed bill reconciles exactly.
 *
 * RULES
 *  - All money is INTEGER paise. ₹123.45 -> 12345. No floats ever stored.
 *  - `sellingPrice` is treated as the TAX-EXCLUSIVE unit price (taxable value).
 *    GST is added on top. (Documented choice; keep client + server aligned.)
 *  - Per line:  gross = unitPrice * qty
 *               taxable = gross - lineDiscount
 *               tax = round(taxable * gstRate / 100)
 *               intra-state -> cgst = tax >> 1 (floor), sgst = tax - cgst
 *               inter-state -> igst = tax, cgst = sgst = 0
 *               lineTotal = taxable + tax
 *  - Per bill:  subTotal   = sum(taxable)
 *               totalTax   = sum(tax)
 *               afterBillDisc = subTotal - billDiscount    (floored at 0)
 *               preRound   = afterBillDisc + totalTax
 *               grandTotal = roundToRupee(preRound)
 *               roundOff   = grandTotal - preRound   (can be negative)
 *
 * Rounding: nearest rupee, half away from zero. For the non-negative values
 * involved here this equals JS Math.round and Dart num.round() identically.
 */

export const GST_SLABS = [0, 5, 12, 18, 28];

/** Round a paise amount to the nearest whole rupee (100 paise). */
export function roundToRupee(paise) {
  return Math.round(paise / 100) * 100;
}

/**
 * Compute a single line.
 * @param {{unitPrice:number, qty:number, lineDiscount?:number, gstRate:number, interState?:boolean}} item
 * @returns {{gross:number, taxable:number, tax:number, cgst:number, sgst:number, igst:number, lineTotal:number}}
 */
export function computeLine({ unitPrice, qty, lineDiscount = 0, gstRate, interState = false }) {
  assertInt(unitPrice, 'unitPrice');
  assertInt(qty, 'qty');
  assertInt(lineDiscount, 'lineDiscount');
  if (!GST_SLABS.includes(gstRate)) {
    throw new ValidationError(`gstRate ${gstRate} is not a valid GST slab (${GST_SLABS.join('/')})`);
  }

  const gross = unitPrice * qty;
  const taxable = Math.max(0, gross - lineDiscount);
  const tax = Math.round((taxable * gstRate) / 100);

  let cgst = 0;
  let sgst = 0;
  let igst = 0;
  if (interState) {
    igst = tax;
  } else {
    cgst = Math.floor(tax / 2);
    sgst = tax - cgst;
  }

  return { gross, taxable, tax, cgst, sgst, igst, lineTotal: taxable + tax };
}

/**
 * Compute a full bill.
 * @param {Array} items   line inputs (see computeLine)
 * @param {{billDiscount?:number, interState?:boolean}} opts
 * @returns full breakdown incl. per-line results.
 */
export function computeBill(items, { billDiscount = 0, interState = false } = {}) {
  assertInt(billDiscount, 'billDiscount');

  const lines = items.map((it) => computeLine({ ...it, interState }));

  const subTotal = lines.reduce((s, l) => s + l.taxable, 0);
  const totalTax = lines.reduce((s, l) => s + l.tax, 0);
  const totalCgst = lines.reduce((s, l) => s + l.cgst, 0);
  const totalSgst = lines.reduce((s, l) => s + l.sgst, 0);
  const totalIgst = lines.reduce((s, l) => s + l.igst, 0);

  const cappedBillDiscount = Math.min(billDiscount, subTotal);
  const afterBillDisc = subTotal - cappedBillDiscount;
  const preRound = afterBillDisc + totalTax;
  const grandTotal = roundToRupee(preRound);
  const roundOff = grandTotal - preRound;

  return {
    lines,
    subTotal,
    itemDiscount: lines.reduce((s, l, i) => s + ((items[i].lineDiscount ?? 0)), 0),
    billDiscount: cappedBillDiscount,
    totalTax,
    cgst: totalCgst,
    sgst: totalSgst,
    igst: totalIgst,
    interState,
    roundOff,
    grandTotal,
  };
}

// ── helpers ──
export class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ValidationError';
    this.statusCode = 400;
  }
}

function assertInt(v, name) {
  if (!Number.isInteger(v)) {
    throw new ValidationError(`${name} must be an integer number of paise (got ${v})`);
  }
}
