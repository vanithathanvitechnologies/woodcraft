import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiRequest } from '../api';

const EMPTY_FORM = {
  name: '',
  description: '',
  sort_order: '',
  is_active: true,
};

export default function CategoriesPage() {
  const navigate = useNavigate();
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [saving, setSaving] = useState(false);

  async function loadCategories() {
    setLoading(true);
    setError('');
    try {
      const data = await apiRequest('/categories?include_inactive=true');
      setCategories(data.categories || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadCategories();
  }, []);

  function openCreate() {
    setEditing(null);
    setForm({
      ...EMPTY_FORM,
      sort_order: String((categories.length || 0) + 1),
    });
    setError('');
    setShowModal(true);
  }

  function openEdit(cat) {
    setEditing(cat);
    setForm({
      name: cat.name || '',
      description: cat.description || '',
      sort_order: String(cat.sort_order ?? 0),
      is_active: Boolean(Number(cat.is_active)),
    });
    setError('');
    setShowModal(true);
  }

  async function handleSave(e) {
    e.preventDefault();
    if (!form.name.trim()) {
      setError('Category name is required.');
      return;
    }
    setSaving(true);
    setError('');
    setSuccessMsg('');
    try {
      const payload = {
        name: form.name.trim(),
        description: form.description.trim(),
        sort_order: form.sort_order === '' ? undefined : Number(form.sort_order) || 0,
        is_active: form.is_active,
      };
      if (editing) {
        await apiRequest(`/categories/${editing.id}`, {
          method: 'PUT',
          body: JSON.stringify(payload),
        });
        setSuccessMsg(`Updated wooden category "${payload.name}".`);
      } else {
        await apiRequest('/categories', {
          method: 'POST',
          body: JSON.stringify(payload),
        });
        setSuccessMsg(`Created wooden category "${payload.name}".`);
      }
      setShowModal(false);
      await loadCategories();
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive(cat) {
    setError('');
    setSuccessMsg('');
    try {
      const nextActive = !Boolean(Number(cat.is_active));
      await apiRequest(`/categories/${cat.id}`, {
        method: 'PUT',
        body: JSON.stringify({ is_active: nextActive }),
      });
      setSuccessMsg(`"${cat.name}" is now ${nextActive ? 'Active' : 'Inactive'}.`);
      await loadCategories();
    } catch (err) {
      setError(err.message);
    }
  }

  async function handleDelete(cat) {
    if (!window.confirm(`Delete wooden category "${cat.name}"?`)) return;
    setError('');
    setSuccessMsg('');
    try {
      await apiRequest(`/categories/${cat.id}`, { method: 'DELETE' });
      setSuccessMsg(`Deleted wooden category "${cat.name}".`);
      await loadCategories();
    } catch (err) {
      setError(err.message);
    }
  }

  const totalCount = categories.length;
  const activeCount = categories.filter((c) => Boolean(Number(c.is_active))).length;
  const totalDesigns = categories.reduce((sum, c) => sum + Number(c.design_count || 0), 0);

  return (
    <div>
      <div className="page-header">
        <div>
          <h2>Wooden Categories</h2>
          <p>Manage woodwork categories displayed across the Design Catalog and Staff App</p>
        </div>
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
          <button className="btn btn-outline" onClick={() => navigate('/catalog')}>
            View Design Catalog
          </button>
          <button className="btn btn-primary" onClick={openCreate}>
            + Add Wooden Category
          </button>
        </div>
      </div>

      {error && <div className="alert-error">{error}</div>}
      {successMsg && <div className="alert-success">{successMsg}</div>}

      <div className="kpi-grid">
        <div className="kpi-card">
          <div className="label">Total Categories</div>
          <div className="value">{totalCount}</div>
          <div className="sub">Configured wooden woodwork groups</div>
        </div>
        <div className="kpi-card">
          <div className="label">Active in Staff App</div>
          <div className="value">{activeCount}</div>
          <div className="sub">Visible in Catalog & AI Combiner</div>
        </div>
        <div className="kpi-card">
          <div className="label">Active Catalog Designs</div>
          <div className="value">{totalDesigns}</div>
          <div className="sub">Linked across all wooden categories</div>
        </div>
      </div>

      <div className="card">
        <div className="toolbar" style={{ justifyContent: 'space-between' }}>
          <div style={{ fontSize: 13.5, color: 'var(--muted)' }}>
            Categories appear in the Staff App in ascending <strong>Sort Order</strong>.
          </div>
          <button className="btn btn-outline btn-sm" onClick={loadCategories}>
            Refresh
          </button>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th style={{ width: 80 }}>Order</th>
                <th>Category Name</th>
                <th>Description</th>
                <th style={{ width: 150 }}>Catalog Designs</th>
                <th style={{ width: 110 }}>Status</th>
                <th style={{ width: 250 }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6}>Loading wooden categories...</td>
                </tr>
              ) : categories.length === 0 ? (
                <tr>
                  <td colSpan={6}>No wooden categories found. Click "+ Add Wooden Category" to create one.</td>
                </tr>
              ) : (
                categories.map((cat) => {
                  const isActive = Boolean(Number(cat.is_active));
                  return (
                    <tr key={cat.id}>
                      <td style={{ fontWeight: 700, color: 'var(--wood-primary)' }}>#{cat.sort_order}</td>
                      <td style={{ fontWeight: 700 }}>{cat.name}</td>
                      <td style={{ color: 'var(--muted)' }}>{cat.description || '—'}</td>
                      <td>
                        <button
                          className="btn btn-outline btn-sm"
                          onClick={() => navigate(`/catalog?category=${encodeURIComponent(cat.name)}`)}
                          title="Open designs in this category"
                        >
                          {cat.design_count || 0} active
                        </button>
                      </td>
                      <td>
                        <span className={`badge ${isActive ? 'badge-active' : 'badge-inactive'}`}>
                          {isActive ? 'Active' : 'Hidden'}
                        </span>
                      </td>
                      <td>
                        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                          <button className="btn btn-outline btn-sm" onClick={() => openEdit(cat)}>
                            Edit
                          </button>
                          <button className="btn btn-outline btn-sm" onClick={() => toggleActive(cat)}>
                            {isActive ? 'Hide' : 'Activate'}
                          </button>
                          <button
                            className="btn btn-danger btn-sm"
                            onClick={() => handleDelete(cat)}
                            disabled={Number(cat.design_count || 0) > 0}
                            title={
                              Number(cat.design_count || 0) > 0
                                ? 'Archive or reassign active designs before deleting'
                                : 'Delete category'
                            }
                            style={Number(cat.design_count || 0) > 0 ? { opacity: 0.5, cursor: 'not-allowed' } : undefined}
                          >
                            Delete
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {showModal && (
        <div className="modal-backdrop" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>{editing ? 'Edit Wooden Category' : 'Add Wooden Category'}</h3>
              <button className="btn btn-outline btn-sm" onClick={() => setShowModal(false)}>
                Close
              </button>
            </div>
            <form onSubmit={handleSave} className="form-grid">
              <div className="form-field">
                <label>Category Name *</label>
                <input
                  className="input"
                  required
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  placeholder="e.g. Door, Pooja Door, Wood Frames, Hard Wood"
                />
              </div>
              <div className="form-field">
                <label>Sort Order</label>
                <input
                  className="input"
                  type="number"
                  min={0}
                  value={form.sort_order}
                  onChange={(e) => setForm({ ...form, sort_order: e.target.value })}
                  placeholder="1"
                />
              </div>
              <div className="form-field full">
                <label>Description</label>
                <textarea
                  className="textarea"
                  rows={3}
                  value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                  placeholder="Short description of woodwork designs in this category..."
                />
              </div>
              <div className="form-field full">
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', color: 'var(--text)' }}>
                  <input
                    type="checkbox"
                    checked={form.is_active}
                    onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
                  />
                  Show this category in Staff App & Design Catalog
                </label>
                {editing && (
                  <span style={{ fontSize: 12, color: 'var(--muted)' }}>
                    Note: Renaming this category automatically updates all linked catalog designs and orders.
                  </span>
                )}
              </div>
              <div
                className="form-field full"
                style={{ flexDirection: 'row', justifyContent: 'flex-end', gap: 10, marginTop: 8 }}
              >
                <button type="button" className="btn btn-outline" onClick={() => setShowModal(false)}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary" disabled={saving}>
                  {saving ? 'Saving...' : editing ? 'Update Category' : 'Create Category'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
