import { useEffect, useState } from 'react';
import { apiRequest, formatINR, mediaUrl } from '../api';

const STAGES = [
  'Pending / New Job',
  'Timber Cutting',
  'Frame Fabrication',
  'Carving / CNC Work',
  'Door Assembly',
  'Sanding & Polishing',
  'Quality Check',
  'Completed / Ready for Delivery',
];

export default function OrdersPage() {
  const [orders, setOrders] = useState([]);
  const [search, setSearch] = useState('');
  const [stage, setStage] = useState('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedOrder, setSelectedOrder] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [lightboxImage, setLightboxImage] = useState(null);

  async function loadOrders() {
    setLoading(true);
    setError('');
    try {
      const qs = new URLSearchParams();
      if (search.trim()) qs.set('search', search.trim());
      if (stage !== 'all') qs.set('stage', stage);
      const data = await apiRequest(`/orders?${qs.toString()}`);
      setOrders(data.orders || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadOrders();
  }, [stage]);

  async function openOrderDetail(id) {
    setDetailLoading(true);
    try {
      const data = await apiRequest(`/orders/${id}`);
      setSelectedOrder(data.order);
    } catch (err) {
      setError(err.message);
    } finally {
      setDetailLoading(false);
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h2>Orders & Live Production List</h2>
          <p>All confirmed custom door & woodwork orders with live workshop status, billing, and delivery tracking</p>
        </div>
        <button className="btn btn-outline" onClick={loadOrders}>Refresh Orders</button>
      </div>

      {error && <div className="alert-error">{error}</div>}

      <div className="card">
        <div className="toolbar">
          <input
            className="input"
            style={{ minWidth: 260 }}
            placeholder="Search Job ID, customer, mobile, wood..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && loadOrders()}
          />
          <select className="select" value={stage} onChange={(e) => setStage(e.target.value)}>
            <option value="all">All Production Stages</option>
            {STAGES.map((s, idx) => (
              <option key={s} value={idx + 1}>{idx + 1}. {s}</option>
            ))}
          </select>
          <button className="btn btn-outline" onClick={loadOrders}>Filter</button>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Design</th>
                <th>Job ID</th>
                <th>Customer</th>
                <th>Woodwork Specs</th>
                <th>Billing (Total / Bal)</th>
                <th>Delivery Date</th>
                <th>Live Stage</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={8}>Loading orders...</td></tr>
              ) : orders.length === 0 ? (
                <tr><td colSpan={8}>No orders found.</td></tr>
              ) : (
                orders.map((o) => (
                  <tr key={o.id}>
                    <td>
                      {o.ai_output_image_url ? (
                        <img
                          className="thumb"
                          src={mediaUrl(o.ai_output_image_url)}
                          alt={o.job_id}
                          style={{ cursor: 'zoom-in' }}
                          title="Click to view full size"
                          onClick={() =>
                            setLightboxImage({
                              url: mediaUrl(o.ai_output_image_url),
                              title: `${o.job_id} • ${o.woodwork_category}`,
                            })
                          }
                        />
                      ) : (
                        <div className="thumb" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10 }}>N/A</div>
                      )}
                    </td>
                    <td>
                      <div style={{ fontWeight: 700, color: '#3b210e' }}>{o.job_id}</div>
                      <div style={{ fontSize: 11, color: '#6f6256' }}>{o.priority} Priority</div>
                    </td>
                    <td>
                      <div style={{ fontWeight: 600 }}>{o.customer_name}</div>
                      <div style={{ fontSize: 12, color: '#6f6256' }}>{o.customer_mobile}</div>
                    </td>
                    <td>
                      <div style={{ fontWeight: 600 }}>{o.woodwork_category}</div>
                      <div style={{ fontSize: 12, color: '#6f6256' }}>
                        {o.wood_species} • {o.width_inches}&quot;×{o.height_inches}&quot; • {o.leaf_type}
                      </div>
                    </td>
                    <td>
                      <div style={{ fontWeight: 700 }}>{formatINR(o.total_cost)}</div>
                      <div style={{ fontSize: 12, color: Number(o.balance_amount) > 0 ? '#b83227' : '#1f7a4c' }}>
                        Bal: {formatINR(o.balance_amount)}
                      </div>
                    </td>
                    <td>
                      <div style={{ fontWeight: 600 }}>{o.expected_delivery_date}</div>
                      {o.is_delayed && <span className="badge badge-danger">Delayed</span>}
                      {Boolean(o.has_blocker) && <span className="badge badge-warning" style={{ marginLeft: 4 }}>Blocker</span>}
                    </td>
                    <td>
                      <span className="badge badge-stage">
                        {o.current_stage}/8 {o.current_stage_name}
                      </span>
                    </td>
                    <td>
                      <button className="btn btn-outline btn-sm" onClick={() => openOrderDetail(o.id)}>
                        Inspect
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {(selectedOrder || detailLoading) && (
        <div className="modal-backdrop" onClick={() => setSelectedOrder(null)}>
          <div className="modal modal-lg" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>{selectedOrder ? `Order ${selectedOrder.job_id}` : 'Loading order...'}</h3>
              <button className="btn btn-outline btn-sm" onClick={() => setSelectedOrder(null)}>Close</button>
            </div>
            {selectedOrder && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
                <div style={{ display: 'flex', gap: 20, flexWrap: 'wrap' }}>
                  {selectedOrder.ai_output_image_url && (
                    <img
                      src={mediaUrl(selectedOrder.ai_output_image_url)}
                      alt={selectedOrder.job_id}
                      title="Click to view full size"
                      onClick={() =>
                        setLightboxImage({
                          url: mediaUrl(selectedOrder.ai_output_image_url),
                          title: `${selectedOrder.job_id} • ${selectedOrder.woodwork_category}`,
                        })
                      }
                      style={{
                        width: 190,
                        height: 260,
                        objectFit: 'contain',
                        background: '#ffffff',
                        padding: 6,
                        borderRadius: 10,
                        border: '1px solid #e6dfd5',
                        cursor: 'zoom-in',
                      }}
                    />
                  )}
                  <div style={{ flex: 1, minWidth: 260, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, fontSize: 13.5 }}>
                    <div><strong>Customer:</strong> {selectedOrder.customer_name}</div>
                    <div><strong>Mobile:</strong> {selectedOrder.customer_mobile}</div>
                    <div style={{ gridColumn: '1 / -1' }}><strong>Address:</strong> {selectedOrder.customer_address || '—'}</div>
                    <div><strong>Category:</strong> {selectedOrder.woodwork_category}</div>
                    <div><strong>Wood:</strong> {selectedOrder.wood_species}</div>
                    <div><strong>Size:</strong> {selectedOrder.width_inches}&quot; × {selectedOrder.height_inches}&quot;</div>
                    <div><strong>Frame / Thick:</strong> {selectedOrder.frame_section} / {selectedOrder.door_thickness}</div>
                    <div><strong>Leaf / Qty:</strong> {selectedOrder.leaf_type} (Qty {selectedOrder.quantity})</div>
                    <div><strong>Polish:</strong> {selectedOrder.polish_shade}</div>
                    <div><strong>Total:</strong> {formatINR(selectedOrder.total_cost)}</div>
                    <div><strong>Advance / Bal:</strong> {formatINR(selectedOrder.advance_amount)} / {formatINR(selectedOrder.balance_amount)}</div>
                  </div>
                </div>

                {Boolean(selectedOrder.has_blocker) && (
                  <div className="alert-error">
                    <strong>Workshop Hold / Blocker:</strong> {selectedOrder.blocker_note}
                  </div>
                )}

                <div>
                  <h4 style={{ marginBottom: 10, color: '#3b210e' }}>Live Production Timeline</h4>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                    {(selectedOrder.stage_history || []).map((h) => (
                      <div
                        key={h.id}
                        style={{
                          padding: '9px 12px',
                          background: h.is_blocker ? '#fdecec' : '#f8f5f0',
                          borderRadius: 8,
                          display: 'flex',
                          justifyContent: 'space-between',
                          fontSize: 13,
                        }}
                      >
                        <div>
                          <strong>Stage {h.stage_number}: {h.stage_name}</strong>
                          <div style={{ color: '#6f6256' }}>{h.notes} {h.updated_by_name ? `— by ${h.updated_by_name}` : ''}</div>
                        </div>
                        <div style={{ color: '#6f6256', fontSize: 12 }}>{String(h.created_at || '').slice(0, 16)}</div>
                      </div>
                    ))}
                  </div>
                </div>

                {(selectedOrder.progress_photos || []).length > 0 && (
                  <div>
                    <h4 style={{ marginBottom: 10, color: '#3b210e' }}>Workshop Progress Photos</h4>
                    <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
                      {selectedOrder.progress_photos.map((p) => (
                        <div key={p.id} style={{ width: 130 }}>
                          <img
                            src={mediaUrl(p.photo_url)}
                            alt={p.caption}
                            style={{ width: 130, height: 110, objectFit: 'cover', borderRadius: 8, border: '1px solid #ddd' }}
                          />
                          <div style={{ fontSize: 11, color: '#6f6256', marginTop: 4 }}>{p.stage_name}</div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      )}

      {lightboxImage && (
        <div
          className="modal-backdrop"
          style={{ zIndex: 1100, background: 'rgba(0, 0, 0, 0.85)' }}
          onClick={() => setLightboxImage(null)}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              background: '#ffffff',
              borderRadius: 16,
              padding: 16,
              maxWidth: '92vw',
              maxHeight: '92vh',
              display: 'flex',
              flexDirection: 'column',
              gap: 10,
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
              <strong style={{ color: '#3b210e' }}>{lightboxImage.title}</strong>
              <button className="btn btn-outline btn-sm" onClick={() => setLightboxImage(null)}>
                Close
              </button>
            </div>
            <img
              src={lightboxImage.url}
              alt={lightboxImage.title}
              style={{
                maxWidth: '86vw',
                maxHeight: '80vh',
                objectFit: 'contain',
                display: 'block',
                margin: '0 auto',
              }}
            />
          </div>
        </div>
      )}
    </div>
  );
}
