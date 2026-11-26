import { useEffect, useState } from 'react';
import { apiRequest } from '../api';

export default function CustomersPage() {
  const [customers, setCustomers] = useState([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({ name: '', mobile: '', delivery_address: '' });
  const [saving, setSaving] = useState(false);

  async function loadCustomers() {
    setLoading(true);
    setError('');
    try {
      const qs = search.trim() ? `?search=${encodeURIComponent(search.trim())}` : '';
      const data = await apiRequest(`/customers${qs}`);
      setCustomers(data.customers || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadCustomers();
  }, []);

  async function handleAddCustomer(e) {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      await apiRequest('/customers', {
        method: 'POST',
        body: JSON.stringify(form),
      });
      setShowModal(false);
      setForm({ name: '', mobile: '', delivery_address: '' });
      loadCustomers();
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h2>Customers Directory</h2>
          <p>Customers registered by Sales Team — mobile numbers automatically enable Customer App OTP login</p>
        </div>
        <button className="btn btn-primary" onClick={() => setShowModal(true)}>+ Add Customer</button>
      </div>

      {error && <div className="alert-error">{error}</div>}

      <div className="card">
        <div className="toolbar">
          <input
            className="input"
            style={{ minWidth: 260 }}
            placeholder="Search customer name, mobile, address..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && loadCustomers()}
          />
          <button className="btn btn-outline" onClick={loadCustomers}>Search</button>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Customer Name</th>
                <th>Mobile (OTP Login)</th>
                <th>Delivery Address</th>
                <th>Orders</th>
                <th>Registered</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={5}>Loading customers...</td></tr>
              ) : customers.length === 0 ? (
                <tr><td colSpan={5}>No customers found.</td></tr>
              ) : (
                customers.map((c) => (
                  <tr key={c.id}>
                    <td style={{ fontWeight: 600 }}>{c.name}</td>
                    <td><span className="badge badge-sales">{c.mobile}</span></td>
                    <td style={{ maxWidth: 260 }}>{c.delivery_address || '—'}</td>
                    <td style={{ fontWeight: 700 }}>{c.order_count || 0}</td>
                    <td>{String(c.created_at || '').slice(0, 10)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {showModal && (
        <div className="modal-backdrop" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Add Customer</h3>
              <button className="btn btn-outline btn-sm" onClick={() => setShowModal(false)}>Close</button>
            </div>
            <form onSubmit={handleAddCustomer} className="form-grid">
              <div className="form-field">
                <label>Customer Name *</label>
                <input
                  className="input"
                  required
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                />
              </div>
              <div className="form-field">
                <label>Mobile Number (10 digits) *</label>
                <input
                  className="input"
                  required
                  value={form.mobile}
                  onChange={(e) => setForm({ ...form, mobile: e.target.value })}
                  placeholder="76039 70435"
                />
              </div>
              <div className="form-field full">
                <label>Delivery Address</label>
                <textarea
                  className="textarea"
                  rows={3}
                  value={form.delivery_address}
                  onChange={(e) => setForm({ ...form, delivery_address: e.target.value })}
                />
              </div>
              <div className="form-field full" style={{ flexDirection: 'row', justifyContent: 'flex-end', gap: 10 }}>
                <button type="button" className="btn btn-outline" onClick={() => setShowModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary" disabled={saving}>
                  {saving ? 'Saving...' : 'Save Customer'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
