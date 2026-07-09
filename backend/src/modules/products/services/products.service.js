import { ProductsRepository } from '../repositories/products.repository.js';
import { newId, now, notFound } from '../../../utils/http.js';

// Map API camelCase <-> DB snake_case for a product row.
function toRow(input, existing = {}) {
  return {
    id: input.id ?? existing.id ?? newId(),
    sku: input.sku ?? existing.sku ?? null,
    barcode: input.barcode ?? existing.barcode ?? null,
    name: input.name ?? existing.name,
    category_id: input.categoryId ?? existing.category_id ?? null,
    brand_id: input.brandId ?? existing.brand_id ?? null,
    unit_id: input.unitId ?? existing.unit_id ?? null,
    hsn: input.hsn ?? existing.hsn ?? null,
    gst_rate: input.gstRate ?? existing.gst_rate ?? 0,
    purchase_price: input.purchasePrice ?? existing.purchase_price ?? 0,
    selling_price: input.sellingPrice ?? existing.selling_price ?? 0,
    mrp: input.mrp ?? existing.mrp ?? 0,
    stock: input.openingStock ?? existing.stock ?? 0,
    reorder_level: input.reorderLevel ?? existing.reorder_level ?? 0,
    batch_no: input.batchNo ?? existing.batch_no ?? null,
    expiry_at: input.expiryAt ?? existing.expiry_at ?? null,
    image_url: input.imageUrl ?? existing.image_url ?? null,
    active: (input.active ?? existing.active ?? 1) ? 1 : 0,
    created_at: existing.created_at ?? now(),
    updated_at: now(),
    deleted_at: existing.deleted_at ?? null,
  };
}

export function toDto(r) {
  if (!r) return r;
  return {
    id: r.id, sku: r.sku, barcode: r.barcode, name: r.name,
    categoryId: r.category_id, brandId: r.brand_id, unitId: r.unit_id,
    hsn: r.hsn, gstRate: r.gst_rate, purchasePrice: r.purchase_price,
    sellingPrice: r.selling_price, mrp: r.mrp, stock: r.stock,
    reorderLevel: r.reorder_level, batchNo: r.batch_no, expiryAt: r.expiry_at,
    imageUrl: r.image_url, active: !!r.active,
    createdAt: r.created_at, updatedAt: r.updated_at,
  };
}

export const ProductsService = {
  list(opts) {
    return ProductsRepository.list(opts).map(toDto);
  },
  get(id) {
    const p = ProductsRepository.findById(id);
    if (!p) throw notFound('Product not found');
    return toDto(p);
  },
  byBarcode(barcode) {
    const p = ProductsRepository.findByBarcode(barcode);
    if (!p) throw notFound('No product for barcode');
    return toDto(p);
  },
  search(term) {
    return ProductsRepository.search(term).map(toDto);
  },
  create(input) {
    return toDto(ProductsRepository.insert(toRow(input)));
  },
  update(id, input) {
    const existing = ProductsRepository.findById(id);
    if (!existing) throw notFound('Product not found');
    return toDto(ProductsRepository.update(id, toRow(input, existing)));
  },
  remove(id) {
    const existing = ProductsRepository.findById(id);
    if (!existing) throw notFound('Product not found');
    ProductsRepository.softDelete(id, now());
  },
};
