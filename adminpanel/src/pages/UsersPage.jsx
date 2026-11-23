import { useEffect, useState } from 'react';
import { apiRequest } from '../api';

const EMPTY_FORM = {
  name: '',
  email: '',
  phone: '',
  password: '',
  role: 'sales',
};

export default function UsersPage() {
  const [users, setUsers] = useState([]);
  const [roleFilter, setRoleFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [saving, setSaving] = useState(false);

  async function loadUsers() {
    setLoading(true);
    setError('');
    try {
      const qs = new URLSearchParams();
      if (roleFilter !== 'all') qs.set('role', roleFilter);
      if (search.trim()) qs.set('search', search.trim());
      const data = await apiRequest(`/users?${qs.toString()}`);
      setUsers(data.users || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadUsers();
  }, [roleFilter]);

  function openCreate() {
    setEditingUser(null);
    setForm(EMPTY_FORM);
    setShowModal(true);
  }

  function openEdit(u) {
    setEditingUser(u);
    setForm({
      name: u.name,
      email: u.email,
      phone: u.phone || '',
      password: '',
      role: u.role,
    });
    setShowModal(true);
  }

  async function handleSave(e) {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      if (editingUser) {
        const payload = {
          name: form.name,
          phone: form.phone,
          role: form.role,
        };
        if (form.password.trim()) payload.password = form.password.trim();
        await apiRequest(`/users/${editingUser.id}`, {
          method: 'PUT',
          body: JSON.stringify(payload),
        });
      } else {
        await apiRequest('/users', {
          method: 'POST',
          body: JSON.stringify(form),
        });
      }
      setShowModal(false);
      loadUsers();
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive(u) {
    try {
      await apiRequest(`/users/${u.id}`, {
        method: 'PUT',
        body: JSON.stringify({ is_active: !u.is_active }),
      });
      loadUsers();
    } catch (err) {
      setError(err.message);
    }
  }

  async function deleteUser(u) {
    if (!window.confirm(`Delete login access for ${u.name}?`)) return;
    try {
      await apiRequest(`/users/${u.id}`, { method: 'DELETE' });
      loadUsers();
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h2>Staff & Role Access Management</h2>
          <p>Create and manage login credentials for Admin, Owner, Sales Team, and Production Team</p>
        </div>
        <button className="btn btn-primary" onClick={openCreate}>+ Create Staff Access</button>
      </div>

      {error && <div className="alert-error">{error}</div>}

      <div className="card">
        <div className="toolbar">
          <input
            className="input"
            style={{ minWidth: 240 }}
            placeholder="Search name, email, phone..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && loadUsers()}
          />
          <select className="select" value={roleFilter} onChange={(e) => setRoleFilter(e.target.value)}>
            <option value="all">All Roles</option>
            <option value="admin">Admin</option>
            <option value="owner">Owner</option>
            <option value="sales">Sales Team</option>
            <option value="production">Production Team</option>
          </select>
          <button className="btn btn-outline" onClick={loadUsers}>Search</button>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Email (Login ID)</th>
                <th>Phone</th>
                <th>Role</th>
                <th>Status</th>
                <th>Created</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={7}>Loading staff accounts...</td></tr>
              ) : users.length === 0 ? (
                <tr><td colSpan={7}>No staff accounts found.</td></tr>
              ) : (
                users.map((u) => (
                  <tr key={u.id}>
                    <td style={{ fontWeight: 600 }}>{u.name}</td>
                    <td>{u.email}</td>
                    <td>{u.phone || '—'}</td>
                    <td><span className={`badge badge-${u.role}`}>{u.role}</span></td>
                    <td>
                      <span className={`badge ${u.is_active ? 'badge-active' : 'badge-inactive'}`}>
                        {u.is_active ? 'Active' : 'Disabled'}
                      </span>
                    </td>
                    <td>{String(u.created_at || '').slice(0, 10)}</td>
                    <td style={{ display: 'flex', gap: 6 }}>
                      <button className="btn btn-outline btn-sm" onClick={() => openEdit(u)}>Edit</button>
                      <button className="btn btn-outline btn-sm" onClick={() => toggleActive(u)}>
                        {u.is_active ? 'Disable' : 'Enable'}
                      </button>
                      <button className="btn btn-danger btn-sm" onClick={() => deleteUser(u)}>Delete</button>
                    </td>
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
              <h3>{editingUser ? 'Edit Staff Access' : 'Create Staff Login Access'}</h3>
              <button className="btn btn-outline btn-sm" onClick={() => setShowModal(false)}>Close</button>
            </div>
            <form onSubmit={handleSave} className="form-grid">
              <div className="form-field">
                <label>Full Name *</label>
                <input
                  className="input"
                  required
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  placeholder="e.g. Suresh Sales"
                />
              </div>
              <div className="form-field">
                <label>Role *</label>
                <select
                  className="select"
                  value={form.role}
                  onChange={(e) => setForm({ ...form, role: e.target.value })}
                >
                  <option value="admin">Admin (Admin Panel)</option>
                  <option value="owner">Owner (Staff App + Admin)</option>
                  <option value="sales">Sales Person (Staff App)</option>
                  <option value="production">Production Team (Workshop Only)</option>
                </select>
              </div>
              <div className="form-field">
                <label>Email (Login ID) *</label>
                <input
                  className="input"
                  type="email"
                  required
                  disabled={Boolean(editingUser)}
                  value={form.email}
                  onChange={(e) => setForm({ ...form, email: e.target.value })}
                  placeholder="Enter staff email"
                />
              </div>
              <div className="form-field">
                <label>Phone Number</label>
                <input
                  className="input"
                  value={form.phone}
                  onChange={(e) => setForm({ ...form, phone: e.target.value })}
                  placeholder="76039 70435"
                />
              </div>
              <div className="form-field full">
                <label>{editingUser ? 'New Password (leave blank to keep current)' : 'Password *'}</label>
                <input
                  className="input"
                  type="password"
                  required={!editingUser}
                  value={form.password}
                  onChange={(e) => setForm({ ...form, password: e.target.value })}
                  placeholder="Minimum 4 characters"
                />
              </div>
              <div className="form-field full" style={{ flexDirection: 'row', justifyContent: 'flex-end', gap: 10, marginTop: 8 }}>
                <button type="button" className="btn btn-outline" onClick={() => setShowModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary" disabled={saving}>
                  {saving ? 'Saving...' : editingUser ? 'Update Account' : 'Create Account'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
