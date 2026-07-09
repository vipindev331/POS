import { SuppliersRepository } from '../repositories/suppliers.repository.js';
import { newId, now, notFound } from '../../../utils/http.js';

export const toDto = (r) =>
  r && { id: r.id, name: r.name, phone: r.phone, email: r.email, gstin: r.gstin,
    balance: r.balance, createdAt: r.created_at, updatedAt: r.updated_at };

const toRow = (i, e = {}) => ({
  id: i.id ?? e.id ?? newId(),
  name: i.name ?? e.name,
  phone: i.phone ?? e.phone ?? null,
  email: i.email ?? e.email ?? null,
  gstin: i.gstin ?? e.gstin ?? null,
  balance: e.balance ?? 0,
  created_at: e.created_at ?? now(),
  updated_at: now(),
  deleted_at: e.deleted_at ?? null,
});

export const SuppliersService = {
  list: () => SuppliersRepository.list().map(toDto),
  get(id) {
    const s = SuppliersRepository.findById(id);
    if (!s) throw notFound('Supplier not found');
    return toDto(s);
  },
  create: (i) => toDto(SuppliersRepository.insert(toRow(i))),
  update(id, i) {
    const e = SuppliersRepository.findById(id);
    if (!e) throw notFound('Supplier not found');
    return toDto(SuppliersRepository.update(id, toRow(i, e)));
  },
  remove(id) {
    if (!SuppliersRepository.findById(id)) throw notFound('Supplier not found');
    SuppliersRepository.softDelete(id, now());
  },
  ledger: (id) => SuppliersRepository.ledger(id),
};
