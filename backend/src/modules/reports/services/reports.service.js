import { getDb } from '../../../db/index.js';

const startOfToday = () => { const d = new Date(); d.setHours(0, 0, 0, 0); return d.getTime(); };
const startOfMonth = () => { const d = new Date(); d.setDate(1); d.setHours(0, 0, 0, 0); return d.getTime(); };

export const ReportsService = {
  // Manager dashboard summary.
  dashboard() {
    const db = getDb();
    const salesBetween = (from, to = Date.now()) =>
      db.prepare(
        `SELECT COALESCE(SUM(grand_total),0) total, COUNT(*) count
         FROM bills WHERE status='completed' AND deleted_at IS NULL AND created_at BETWEEN ? AND ?`,
      ).get(from, to);

    const today = salesBetween(startOfToday());
    const month = salesBetween(startOfMonth());

    const profit = db.prepare(
      `SELECT COALESCE(SUM((bi.unit_price - p.purchase_price) * bi.qty),0) profit
       FROM bill_items bi
       JOIN bills b ON b.id = bi.bill_id
       LEFT JOIN products p ON p.id = bi.product_id
       WHERE b.status='completed' AND b.deleted_at IS NULL AND b.created_at >= ?`,
    ).get(startOfMonth());

    const lowStock = db.prepare(
      `SELECT COUNT(*) c FROM products WHERE deleted_at IS NULL AND stock <= reorder_level AND stock > 0`,
    ).get();
    const outOfStock = db.prepare(
      `SELECT COUNT(*) c FROM products WHERE deleted_at IS NULL AND stock <= 0`,
    ).get();

    const recentBills = db.prepare(
      `SELECT id, invoice_no, grand_total, created_at FROM bills
       WHERE status='completed' AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 10`,
    ).all();

    const topProducts = db.prepare(
      `SELECT bi.product_id, bi.name, SUM(bi.qty) qty, SUM(bi.line_total) revenue
       FROM bill_items bi JOIN bills b ON b.id = bi.bill_id
       WHERE b.status='completed' AND b.deleted_at IS NULL AND b.created_at >= ?
       GROUP BY bi.product_id ORDER BY qty DESC LIMIT 10`,
    ).all(startOfMonth());

    return {
      todaySales: today.total, todayCount: today.count,
      monthSales: month.total, monthCount: month.count,
      monthProfit: profit.profit,
      lowStock: lowStock.c, outOfStock: outOfStock.c,
      recentBills, topProducts,
    };
  },

  // Sales grouped by day for a date range.
  salesByDay({ from, to }) {
    return getDb().prepare(
      `SELECT date(created_at/1000,'unixepoch','localtime') day,
              COUNT(*) bills, COALESCE(SUM(grand_total),0) total,
              COALESCE(SUM(total_tax),0) tax
       FROM bills WHERE status='completed' AND deleted_at IS NULL AND created_at BETWEEN ? AND ?
       GROUP BY day ORDER BY day`,
    ).all(from, to);
  },

  // GST summary by slab for a date range.
  gstReport({ from, to }) {
    return getDb().prepare(
      `SELECT bi.gst_rate rate,
              COALESCE(SUM(bi.taxable),0) taxable,
              COALESCE(SUM(bi.cgst),0) cgst,
              COALESCE(SUM(bi.sgst),0) sgst,
              COALESCE(SUM(bi.igst),0) igst
       FROM bill_items bi JOIN bills b ON b.id = bi.bill_id
       WHERE b.status='completed' AND b.deleted_at IS NULL AND b.created_at BETWEEN ? AND ?
       GROUP BY bi.gst_rate ORDER BY bi.gst_rate`,
    ).all(from, to);
  },

  // Profit report (manager only).
  profitReport({ from, to }) {
    return getDb().prepare(
      `SELECT bi.product_id, bi.name,
              SUM(bi.qty) qty,
              SUM(bi.taxable) revenue,
              SUM(p.purchase_price * bi.qty) cost,
              SUM(bi.taxable - p.purchase_price * bi.qty) profit
       FROM bill_items bi
       JOIN bills b ON b.id = bi.bill_id
       LEFT JOIN products p ON p.id = bi.product_id
       WHERE b.status='completed' AND b.deleted_at IS NULL AND b.created_at BETWEEN ? AND ?
       GROUP BY bi.product_id ORDER BY profit DESC`,
    ).all(from, to);
  },

  inventoryReport() {
    return getDb().prepare(
      `SELECT id, name, sku, barcode, stock, reorder_level, purchase_price, selling_price
       FROM products WHERE deleted_at IS NULL ORDER BY name`,
    ).all();
  },

  // Sold products aggregated over a date range (available to all staff — no cost/
  // profit exposed). One row per product with total qty, revenue, and bill count.
  soldProducts({ from, to }) {
    return getDb().prepare(
      `SELECT bi.product_id, bi.name, p.sku,
              SUM(bi.qty) qty,
              COALESCE(SUM(bi.line_total),0) revenue,
              COUNT(DISTINCT bi.bill_id) bills,
              MAX(b.created_at) lastSoldAt
       FROM bill_items bi
       JOIN bills b ON b.id = bi.bill_id
       LEFT JOIN products p ON p.id = bi.product_id
       WHERE b.status='completed' AND b.deleted_at IS NULL AND b.created_at BETWEEN ? AND ?
       GROUP BY bi.product_id ORDER BY qty DESC`,
    ).all(from, to);
  },

  // Individual sale lines for one product in a date range (drill-down view).
  // Includes bill-level context: customer, cashier, bill total and the payment
  // method(s) used (a bill may be split across methods).
  soldProductDetail({ productId, from, to }) {
    return getDb().prepare(
      `SELECT b.id billId, b.invoice_no, b.created_at,
              bi.qty, bi.unit_price, bi.line_total, bi.gst_rate,
              b.grand_total,
              c.name customer_name, c.phone customer_phone,
              u.full_name cashier_name,
              (SELECT GROUP_CONCAT(DISTINCT p.method) FROM payments p WHERE p.bill_id = b.id) payment_methods
       FROM bill_items bi
       JOIN bills b ON b.id = bi.bill_id
       LEFT JOIN customers c ON c.id = b.customer_id
       LEFT JOIN users u ON u.id = b.cashier_id
       WHERE bi.product_id = ? AND b.status='completed' AND b.deleted_at IS NULL
             AND b.created_at BETWEEN ? AND ?
       ORDER BY b.created_at DESC`,
    ).all(productId, from, to);
  },
};
