import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { apiRequest, mediaUrl } from '../api';

const WOOD_SPECIES = [
  'Burma Teak',
  'Ghana Teak',
  'Nilambur Teak',
  'Indian Rosewood',
  'Mahogany',
  'Sal Wood',
  'Vengai Wood',
];

const FALLBACK_CATEGORIES = ['Door', 'Wood Frames', 'Hard Wood'];

const EMPTY_FORM = {
  title: '',
  category: 'Door',
  wood_species: 'Burma Teak',
  carving_style: '',
  tags: '',
  description: '',
  is_trending: false,
};

export default function CatalogPage() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const initialCategory = searchParams.get('category') || 'All';

  const [designs, setDesigns] = useState([]);
  const [categories, setCategories] = useState([]);
  const [categoryFilter, setCategoryFilter] = useState(initialCategory);
  const [woodFilter, setWoodFilter] = useState('All');
  const [search, setSearch] = useState('');
  const [includeArchived, setIncludeArchived] = useState(false);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  // Upload / Edit modal state
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [selectedFile, setSelectedFile] = useState(null);
  const [previewUrl, setPreviewUrl] = useState('');
  const [saving, setSaving] = useState(false);
  const fileInputRef = useRef(null);

  // Quick-add category inline inside upload modal
  const [showQuickCat, setShowQuickCat] = useState(false);
  const [quickCatName, setQuickCatName] = useState('');
  const [addingQuickCat, setAddingQuickCat] = useState(false);

  // Full-size lightbox image
  const [lightbox, setLightbox] = useState(null);

  const categoryNames = useMemo(() => {
    const names = categories
      .filter((c) => Boolean(Number(c.is_active)))
      .map((c) => String(c.name || '').trim())
      .filter(Boolean);
    return names.length ? names : FALLBACK_CATEGORIES;
  }, [categories]);

  const allCategoryNames = useMemo(() => {
    const set = new Set(categories.map((c) => String(c.name || '').trim()).filter(Boolean));
    for (const d of designs) {
      const c = String(d.category || '').trim();
      if (c) set.add(c);
    }
    if (!set.size) {
      FALLBACK_CATEGORIES.forEach((c) => set.add(c));
    }
    return Array.from(set);
  }, [categories, designs]);

  async function loadCategories() {
    try {
      const data = await apiRequest('/categories?include_inactive=true');
      setCategories(data.categories || []);
    } catch {
      // Fallback gracefully if categories API isn't deployed yet
      setCategories(FALLBACK_CATEGORIES.map((name, idx) => ({ id: idx + 1, name, is_active: 1 })));
    }
  }

  async function loadCatalog() {
    setLoading(true);
    setError('');
    try {
      const qs = new URLSearchParams();
      if (includeArchived) qs.set('include_archived', 'true');
      if (categoryFilter && categoryFilter !== 'All') qs.set('category', categoryFilter);
      if (woodFilter && woodFilter !== 'All') qs.set('wood_species', woodFilter);
      if (search.trim()) qs.set('search', search.trim());
      const data = await apiRequest(`/catalog?${qs.toString()}`);
      setDesigns(data.designs || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadCategories();
  }, []);

  useEffect(() => {
    loadCatalog();
  }, [categoryFilter, woodFilter, includeArchived]);

  useEffect(() => {
    return () => {
      if (previewUrl && previewUrl.startsWith('blob:')) {
        URL.revokeObjectURL(previewUrl);
      }
    };
  }, [previewUrl]);

  function handleCategoryFilterChange(val) {
    setCategoryFilter(val);
    if (val === 'All') {
      searchParams.delete('category');
    } else {
      searchParams.set('category', val);
    }
    setSearchParams(searchParams, { replace: true });
  }

  function clearPreview() {
    if (previewUrl && previewUrl.startsWith('blob:')) {
      URL.revokeObjectURL(previewUrl);
    }
    setSelectedFile(null);
    setPreviewUrl('');
    if (fileInputRef.current) fileInputRef.current.value = '';
  }

  function openUpload() {
    clearPreview();
    setEditing(null);
    setShowQuickCat(false);
    setQuickCatName('');
    const defaultCat =
      categoryFilter !== 'All' && categoryNames.includes(categoryFilter)
        ? categoryFilter
        : categoryNames[0] || 'Door';
    setForm({
      ...EMPTY_FORM,
      category: defaultCat,
    });
    setError('');
    setShowModal(true);
  }

  function openEdit(d) {
    clearPreview();
    setEditing(d);
    setShowQuickCat(false);
    setQuickCatName('');
    setForm({
      title: d.title || '',
      category: d.category || categoryNames[0] || 'Door',
      wood_species: d.wood_species || WOOD_SPECIES[0],
      carving_style: d.carving_style || '',
      tags: d.tags || '',
      description: d.description || '',
      is_trending: Boolean(Number(d.is_trending)),
    });
    setPreviewUrl(d.image_url ? mediaUrl(d.image_url) : '');
    setError('');
    setShowModal(true);
  }

  function handleFileChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (previewUrl && previewUrl.startsWith('blob:')) {
      URL.revokeObjectURL(previewUrl);
    }
    setSelectedFile(file);
    setPreviewUrl(URL.createObjectURL(file));
  }

  async function handleQuickAddCategory() {
    const trimmed = quickCatName.trim();
    if (!trimmed) return;
    setAddingQuickCat(true);
    setError('');
    try {
      await apiRequest('/categories', {
        method: 'POST',
        body: JSON.stringify({ name: trimmed, is_active: true }),
      });
      await loadCategories();
      setForm((prev) => ({ ...prev, category: trimmed }));
      setQuickCatName('');
      setShowQuickCat(false);
    } catch (err) {
      setError(err.message);
    } finally {
      setAddingQuickCat(false);
    }
  }

  async function handleSave(e) {
    e.preventDefault();
    if (!form.title.trim()) {
      setError('Design title is required.');
      return;
    }
    if (!editing && !selectedFile) {
      setError('Please select a catalog design photo to upload.');
      return;
    }

    setSaving(true);
    setError('');
    setSuccessMsg('');
    try {
      if (selectedFile || !editing) {
        const fd = new FormData();
        if (selectedFile) {
          fd.append('images', selectedFile, selectedFile.name);
        }
        fd.append('title', form.title.trim());
        fd.append('category', form.category);
        fd.append('wood_species', form.wood_species);
        fd.append('carving_style', form.carving_style.trim());
        fd.append('tags', form.tags.trim());
        fd.append('description', form.description.trim());
        fd.append('is_trending', form.is_trending ? '1' : '0');

        if (editing) {
          await apiRequest(`/catalog/${editing.id}`, {
            method: 'POST',
            body: fd,
          });
          setSuccessMsg(`Updated design "${form.title.trim()}".`);
        } else {
          await apiRequest('/catalog', {
            method: 'POST',
            body: fd,
          });
          setSuccessMsg(`Uploaded new design "${form.title.trim()}" to ${form.category}.`);
        }
      } else {
        await apiRequest(`/catalog/${editing.id}`, {
          method: 'PUT',
          body: JSON.stringify({
            title: form.title.trim(),
            category: form.category,
            wood_species: form.wood_species,
            carving_style: form.carving_style.trim(),
            tags: form.tags.trim(),
            description: form.description.trim(),
            is_trending: form.is_trending,
          }),
        });
        setSuccessMsg(`Updated design "${form.title.trim()}".`);
      }

      setShowModal(false);
      clearPreview();
      await loadCatalog();
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  }

  async function toggleTrending(d) {
    setError('');
    try {
      await apiRequest(`/catalog/${d.id}`, {
        method: 'PUT',
        body: JSON.stringify({ is_trending: !Boolean(Number(d.is_trending)) }),
      });
      await loadCatalog();
    } catch (err) {
      setError(err.message);
    }
  }

  async function toggleArchive(d) {
    const isArchived = Boolean(Number(d.is_archived));
    const verb = isArchived ? 'restore' : 'archive';
    if (!window.confirm(`${isArchived ? 'Restore' : 'Archive'} "${d.title}"?`)) return;
    setError('');
    setSuccessMsg('');
    try {
      if (isArchived) {
        await apiRequest(`/catalog/${d.id}`, {
          method: 'PUT',
          body: JSON.stringify({ is_archived: false }),
        });
        setSuccessMsg(`Restored "${d.title}" to active catalog.`);
      } else {
        await apiRequest(`/catalog/${d.id}`, { method: 'DELETE' });
        setSuccessMsg(`Archived "${d.title}".`);
      }
      await loadCatalog();
    } catch (err) {
      setError(err.message || `Failed to ${verb} design`);
    }
  }

  async function permanentDelete(d) {
    if (!window.confirm(`Permanently delete "${d.title}"? This cannot be undone.`)) return;
    setError('');
    setSuccessMsg('');
    try {
      await apiRequest(`/catalog/${d.id}?permanent=true`, { method: 'DELETE' });
      setSuccessMsg(`Permanently deleted "${d.title}".`);
      await loadCatalog();
    } catch (err) {
      setError(err.message);
    }
  }

  const formCategoryOptions = useMemo(() => {
    const opts = [...categoryNames];
    if (form.category && !opts.includes(form.category)) {
      opts.unshift(form.category);
    }
    return opts;
  }, [categoryNames, form.category]);

  return (
    <div>
      <div className="page-header">
        <div>
          <h2>Design Catalog</h2>
          <p>Upload, organize, and manage wooden door & woodwork catalog designs shown in the Staff App</p>
        </div>
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
          <button className="btn btn-outline" onClick={() => navigate('/categories')}>
            🪵 Manage Categories
          </button>
          <button className="btn btn-primary" onClick={openUpload}>
            + Upload Design
          </button>
        </div>
      </div>

      {error && <div className="alert-error">{error}</div>}
      {successMsg && <div className="alert-success">{successMsg}</div>}

      <div className="card">
        <div className="toolbar">
          <input
            className="input"
            style={{ minWidth: 240, flex: '1 1 240px' }}
            placeholder="Search title, carving style, wood, tags..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && loadCatalog()}
          />
          <select
            className="select"
            value={categoryFilter}
            onChange={(e) => handleCategoryFilterChange(e.target.value)}
          >
            <option value="All">All Wooden Categories</option>
            {allCategoryNames.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </select>
          <select className="select" value={woodFilter} onChange={(e) => setWoodFilter(e.target.value)}>
            <option value="All">All Wood Species</option>
            {WOOD_SPECIES.map((w) => (
              <option key={w} value={w}>
                {w}
              </option>
            ))}
          </select>
          <label style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 13, cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={includeArchived}
              onChange={(e) => setIncludeArchived(e.target.checked)}
            />
            Show Archived
          </label>
          <button className="btn btn-outline" onClick={loadCatalog}>
            Search
          </button>
        </div>

        {loading ? (
          <div style={{ padding: '36px 0', textAlign: 'center', color: 'var(--muted)' }}>
            Loading catalog designs...
          </div>
        ) : designs.length === 0 ? (
          <div style={{ padding: '44px 16px', textAlign: 'center', color: 'var(--muted)' }}>
            <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--wood-dark)', marginBottom: 6 }}>
              No catalog designs found
            </div>
            <div style={{ fontSize: 13, marginBottom: 16 }}>
              Upload a design photo and assign it to any Wooden Category so your Sales Team sees it immediately.
            </div>
            <button className="btn btn-primary" onClick={openUpload}>
              + Upload First Design
            </button>
          </div>
        ) : (
          <div className="catalog-grid">
            {designs.map((d) => {
              const isTrending = Boolean(Number(d.is_trending));
              const isArchived = Boolean(Number(d.is_archived));
              const imgUrl = mediaUrl(d.image_url);
              return (
                <div
                  key={d.id}
                  className="catalog-card"
                  style={isArchived ? { opacity: 0.72, borderStyle: 'dashed' } : undefined}
                >
                  <div
                    className="catalog-card-media"
                    title="Click to view full size"
                    onClick={() =>
                      setLightbox({
                        url: imgUrl,
                        title: d.title,
                        subtitle: `${d.wood_species} • ${d.category}${d.carving_style ? ` • ${d.carving_style}` : ''}`,
                      })
                    }
                  >
                    <img src={imgUrl} alt={d.title} loading="lazy" />
                    <div className="catalog-card-badges">
                      {isTrending && <span className="badge badge-trending">TRENDING</span>}
                      {isArchived && <span className="badge badge-inactive">ARCHIVED</span>}
                    </div>
                  </div>

                  <div className="catalog-card-body">
                    <div className="catalog-card-title" title={d.title}>
                      {d.title}
                    </div>
                    <div className="catalog-card-meta">
                      <span className="badge badge-stage">{d.category}</span>
                      <span>{d.wood_species}</span>
                    </div>
                    {d.carving_style && (
                      <div className="catalog-card-sub" title={d.carving_style}>
                        {d.carving_style}
                      </div>
                    )}

                    <div className="catalog-card-actions">
                      <button className="btn btn-outline btn-sm" onClick={() => openEdit(d)}>
                        Edit
                      </button>
                      <button className="btn btn-outline btn-sm" onClick={() => toggleTrending(d)}>
                        {isTrending ? 'Unstar' : 'Trending'}
                      </button>
                      <button
                        className={`btn btn-sm ${isArchived ? 'btn-outline' : 'btn-danger'}`}
                        onClick={() => toggleArchive(d)}
                      >
                        {isArchived ? 'Restore' : 'Archive'}
                      </button>
                      {isArchived && (
                        <button className="btn btn-danger btn-sm" onClick={() => permanentDelete(d)}>
                          Delete
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Upload / Edit Design Modal */}
      {showModal && (
        <div className="modal-backdrop" onClick={() => setShowModal(false)}>
          <div className="modal modal-lg" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>{editing ? 'Edit Catalog Design' : 'Upload New Catalog Design'}</h3>
              <button className="btn btn-outline btn-sm" onClick={() => setShowModal(false)}>
                Close
              </button>
            </div>

            <form onSubmit={handleSave} className="form-grid">
              <div className="form-field full">
                <label>Design Photo {editing ? '(leave unchanged to keep current photo)' : '*'}</label>
                <div className="upload-dropzone" onClick={() => fileInputRef.current?.click()}>
                  {previewUrl ? (
                    <img src={previewUrl} alt="Design Preview" className="upload-preview-img" />
                  ) : (
                    <div className="upload-placeholder">
                      <div style={{ fontSize: 28, marginBottom: 6 }}>🖼️</div>
                      <div style={{ fontWeight: 700, color: 'var(--wood-dark)' }}>
                        Click to choose door / woodwork image
                      </div>
                      <div style={{ fontSize: 12, color: 'var(--muted)' }}>
                        Supports JPG, PNG, WebP (uncropped studio preview)
                      </div>
                    </div>
                  )}
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept="image/*"
                    onChange={handleFileChange}
                    style={{ display: 'none' }}
                  />
                </div>
                {selectedFile && (
                  <div style={{ fontSize: 12, color: 'var(--success)', fontWeight: 600 }}>
                    Selected file: {selectedFile.name}
                  </div>
                )}
              </div>

              <div className="form-field full">
                <label>Design Title *</label>
                <input
                  className="input"
                  required
                  value={form.title}
                  onChange={(e) => setForm({ ...form, title: e.target.value })}
                  placeholder="e.g. Royal Carved Burma Teak Main Entrance Door"
                />
              </div>

              <div className="form-field">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <label>Wooden Category *</label>
                  <button
                    type="button"
                    className="btn-link"
                    onClick={() => setShowQuickCat((v) => !v)}
                  >
                    {showQuickCat ? 'Cancel' : '+ New Category'}
                  </button>
                </div>
                <select
                  className="select"
                  value={form.category}
                  onChange={(e) => setForm({ ...form, category: e.target.value })}
                >
                  {formCategoryOptions.map((c) => (
                    <option key={c} value={c}>
                      {c}
                    </option>
                  ))}
                </select>
                {showQuickCat && (
                  <div style={{ display: 'flex', gap: 6, marginTop: 6 }}>
                    <input
                      className="input"
                      style={{ flex: 1, padding: '6px 10px', fontSize: 13 }}
                      placeholder="New category name..."
                      value={quickCatName}
                      onChange={(e) => setQuickCatName(e.target.value)}
                    />
                    <button
                      type="button"
                      className="btn btn-primary btn-sm"
                      disabled={addingQuickCat || !quickCatName.trim()}
                      onClick={handleQuickAddCategory}
                    >
                      {addingQuickCat ? '...' : 'Add'}
                    </button>
                  </div>
                )}
              </div>

              <div className="form-field">
                <label>Wood Species *</label>
                <select
                  className="select"
                  value={form.wood_species}
                  onChange={(e) => setForm({ ...form, wood_species: e.target.value })}
                >
                  {WOOD_SPECIES.map((w) => (
                    <option key={w} value={w}>
                      {w}
                    </option>
                  ))}
                </select>
              </div>

              <div className="form-field">
                <label>Carving Style</label>
                <input
                  className="input"
                  value={form.carving_style}
                  onChange={(e) => setForm({ ...form, carving_style: e.target.value })}
                  placeholder="e.g. Chettinad Lotus, Temple Bells, Raja Nilai"
                />
              </div>

              <div className="form-field full">
                <label>Search Tags (comma separated)</label>
                <input
                  className="input"
                  value={form.tags}
                  onChange={(e) => setForm({ ...form, tags: e.target.value })}
                  placeholder="e.g. pooja door, teak, double leaf, brass bells"
                />
              </div>

              <div className="form-field full">
                <label>Description</label>
                <textarea
                  className="textarea"
                  rows={2}
                  value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                  placeholder="Optional details about craftsmanship, dimensions, or polish..."
                />
              </div>

              <div className="form-field full">
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', color: 'var(--text)' }}>
                  <input
                    type="checkbox"
                    checked={form.is_trending}
                    onChange={(e) => setForm({ ...form, is_trending: e.target.checked })}
                  />
                  Highlight as Trending (shows gold TRENDING badge and appears at top)
                </label>
              </div>

              <div
                className="form-field full"
                style={{ flexDirection: 'row', justifyContent: 'flex-end', gap: 10, marginTop: 8 }}
              >
                <button type="button" className="btn btn-outline" onClick={() => setShowModal(false)}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary" disabled={saving}>
                  {saving ? 'Uploading...' : editing ? 'Save Changes' : 'Upload Design'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Full-Size Image Lightbox */}
      {lightbox && (
        <div
          className="modal-backdrop"
          style={{ background: 'rgba(15, 10, 6, 0.85)', zIndex: 1200 }}
          onClick={() => setLightbox(null)}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: 16,
              maxWidth: '90vw',
              maxHeight: '92vh',
              width: 720,
              overflow: 'hidden',
              display: 'flex',
              flexDirection: 'column',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="modal-header" style={{ padding: '14px 20px', marginBottom: 0 }}>
              <div>
                <h3 style={{ fontSize: 16 }}>{lightbox.title}</h3>
                <div style={{ fontSize: 12.5, color: 'var(--muted)' }}>
                  {lightbox.subtitle}
                </div>
              </div>
              <button className="btn btn-outline btn-sm" onClick={() => setLightbox(null)}>
                Close
              </button>
            </div>
            <div
              style={{
                background: '#faf7f2',
                padding: 20,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                overflow: 'auto',
                flex: 1,
              }}
            >
              <img
                src={lightbox.url}
                alt={lightbox.title}
                style={{ maxWidth: '100%', maxHeight: '72vh', objectFit: 'contain', borderRadius: 8 }}
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
