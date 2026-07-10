import { CustomersRepository } from '../repositories/customers.repository.js';
import { newId, now, notFound, conflict } from '../../../utils/http.js';

// Reject a customer whose phone or email already belongs to another (non-deleted)
// customer. `selfId` is excluded so editing/idempotent re-sends don't self-collide.
function assertUnique(input, selfId = null) {
  if (input.phone) {
    const e = CustomersRepository.findByPhone(input.phone);
    if (e && e.id !== selfId) throw conflict('A customer with this phone number already exists');
  }
  if (input.email) {
    const e = CustomersRepository.findByEmail(input.email);
    if (e && e.id !== selfId) throw conflict('A customer with this email already exists');
  }
}

export function toDto(r) {
  if (!r) return r;
  return {
    id: r.id, name: r.name, phone: r.phone, email: r.email, group: r.group_name,
    loyaltyPoints: r.loyalty_points, creditLimit: r.credit_limit, balance: r.balance,
    gstin: r.gstin, stateCode: r.state_code,
    createdBy: r.created_by ?? null, updatedBy: r.updated_by ?? null,
    createdAt: r.created_at, updatedAt: r.updated_at,
  };
}

// `user` is the authenticated actor ({ id, username, role }) performing the
// write; it stamps the audit trail. created_by is set once, on first insert.
function toRow(input, existing = {}, user = null) {
  const actor = user?.username ?? null;
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
    created_by: existing.created_by ?? actor ?? input.createdBy ?? null,
    updated_by: actor ?? input.updatedBy ?? existing.updated_by ?? null,
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
  create(input, user = null) {
    assertUnique(input, input.id ?? null);
    return toDto(CustomersRepository.insert(toRow(input, {}, user)));
  },
  update(id, input, user = null) {
    const e = CustomersRepository.findById(id);
    if (!e) throw notFound('Customer not found');
    assertUnique(input, id);
    return toDto(CustomersRepository.update(id, toRow(input, e, user)));
  },
  remove(id) {
    if (!CustomersRepository.findById(id)) throw notFound('Customer not found');
    CustomersRepository.softDelete(id, now());
  },
  ledger: (id) => CustomersRepository.ledger(id),
  history: (id) => CustomersRepository.bills(id),
};
