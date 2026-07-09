// Tax-engine tests. These same cases are mirrored in the Dart port to prove
// client and server compute byte-identical totals.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeLine, computeBill, roundToRupee } from '../src/utils/money.js';

test('roundToRupee rounds to nearest 100 paise', () => {
  assert.equal(roundToRupee(12345), 12300);
  assert.equal(roundToRupee(12350), 12400); // half up
  assert.equal(roundToRupee(12399), 12400);
  assert.equal(roundToRupee(0), 0);
});

test('computeLine intra-state splits tax into equal CGST/SGST', () => {
  // ₹275.00 x 2 @ 5% = taxable 55000, tax 2750 -> cgst 1375, sgst 1375
  const l = computeLine({ unitPrice: 27500, qty: 2, gstRate: 5 });
  assert.equal(l.taxable, 55000);
  assert.equal(l.tax, 2750);
  assert.equal(l.cgst, 1375);
  assert.equal(l.sgst, 1375);
  assert.equal(l.igst, 0);
  assert.equal(l.lineTotal, 57750);
});

test('computeLine odd tax splits remainder to SGST', () => {
  // taxable 100, 5% -> tax 5 -> cgst 2, sgst 3
  const l = computeLine({ unitPrice: 100, qty: 1, gstRate: 5 });
  assert.equal(l.tax, 5);
  assert.equal(l.cgst, 2);
  assert.equal(l.sgst, 3);
});

test('computeLine inter-state uses IGST only', () => {
  const l = computeLine({ unitPrice: 10000, qty: 1, gstRate: 18, interState: true });
  assert.equal(l.igst, 1800);
  assert.equal(l.cgst, 0);
  assert.equal(l.sgst, 0);
});

test('line discount reduces taxable before tax', () => {
  const l = computeLine({ unitPrice: 10000, qty: 1, lineDiscount: 2000, gstRate: 18 });
  assert.equal(l.taxable, 8000);
  assert.equal(l.tax, 1440);
});

test('computeBill totals + round-off', () => {
  const bill = computeBill(
    [
      { unitPrice: 27500, qty: 2, gstRate: 5 }, // taxable 55000, tax 2750
      { unitPrice: 4000, qty: 1, gstRate: 28 }, // taxable 4000, tax 1120
    ],
    { billDiscount: 0 },
  );
  assert.equal(bill.subTotal, 59000);
  assert.equal(bill.totalTax, 3870);
  // preRound = 62870 -> round to 62900, roundOff +30
  assert.equal(bill.grandTotal, 62900);
  assert.equal(bill.roundOff, 30);
});

test('computeBill applies bill discount capped at subtotal', () => {
  const bill = computeBill([{ unitPrice: 10000, qty: 1, gstRate: 0 }], { billDiscount: 99999 });
  assert.equal(bill.billDiscount, 10000);
  assert.equal(bill.grandTotal, 0);
});

test('rejects invalid GST slab', () => {
  assert.throws(() => computeLine({ unitPrice: 100, qty: 1, gstRate: 7 }));
});
