import { CustomersRepository } from '../repositories/customers.repository.js';
import { newId, now, notFound } from '../../../utils/http.js';

export function toDto(r) {
  if (!r) return r;
  return {
    id: r.id, name: r.name, phone: r.phone, email: r.email, group: r.group_name,
    loyaltyPoints: r.loyalty_points, creditLimit: r.credit_limit, balance: r.balance,
    gstin: r.gstin, stateCode: r.state_code, createdAt: r.created_at, updatedAt: r.updated_at,
  };
}

function toRow(input, existing = {}) {
  return {
    id: input.id ?? existing.id ?? newId(),
    name: input.name ?? existing.name,
    phone: input.phone ?? existing.phone ?? null,
    email: input.email ?? existing.email ?? null,
    group_name: input.group ?? existing.group_name ?? 'walk-in',
    loyalty_points: existing.loyalty_points ?? 0,
    credit_limit: input.creditLimit ?? existing.credit_limit ?? 0,
    balance: existing.balance ?? 0,
    gstin: input.gstin ?? existing.gstin ?? null,
    state_code: input.stateCode ?? existing.state_code ?? null,
    created_at: existing.created_at ?? now(),
    updated_at: now(),
    deleted_at: existing.deleted_at ?? null,
  };
}

export const CustomersService = {
  list: (o) => CustomersRepository.list(o).map(toDto),
  search: (t) => CustomersRepository.search(t).map(toDto),
  get(id) {
    const c = CustomersRepository.findById(id);
    if (!c) throw notFound('Customer not found');
    return toDto(c);
  },
  create: (input) => toDto(CustomersRepository.insert(toRow(input))),
  update(id, input) {
    const e = CustomersRepository.findById(id);
    if (!e) throw notFound('Customer not found');
    return toDto(CustomersRepository.update(id, toRow(input, e)));
  },
  remove(id) {
    if (!CustomersRepository.findById(id)) throw notFound('Customer not found');
    CustomersRepository.softDelete(id, now());
  },
  ledger: (id) => CustomersRepository.ledger(id),
  history: (id) => CustomersRepository.bills(id),
};
