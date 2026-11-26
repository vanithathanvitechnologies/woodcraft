import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiRequest } from '../api';

const TYPE_META = {
  pre_delivery_2d: { label: '2-Day Pre-Delivery Alert', badgeClass: 'badge-warning', icon: '⏰' },
  delivery_reached: { label: 'Delivery Reached (Incomplete)', badgeClass: 'badge-danger', icon: '🚨' },
  order_assigned: { label: 'Production Assigned', badgeClass: 'badge-stage', icon: '🛠️' },
};

export default function NotificationsPage() {
  const navigate = useNavigate();
  const [notifications, setNotifications] = useState([]);
  const [watchOrders, setWatchOrders] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busyId, setBusyId] = useState(null);

  async function loadNotifications() {
    setLoading(true);
    setError('');
    try {
      const data = await apiRequest('/notifications');
      setNotifications(data.notifications || []);
      setWatchOrders(data.scheduled_watch_orders || []);
      setUnreadCount(Number(data.unread_count || 0));
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadNotifications();
  }, []);

  async function markAllRead() {
    try {
      await apiRequest('/notifications/read-all', { method: 'POST', body: '{}' });
      await loadNotifications();
    } catch (err) {
      setError(err.message);
    }
  }

  async function markOneRead(id) {
    setBusyId(id);
    try {
      await apiRequest(`/notifications/${id}/read`, { method: 'PATCH', body: '{}' });
      setNotifications((prev) => prev.map((n) => (n.id === id ? { ...n, is_read: 1 } : n)));
      setUnreadCount((c) => Math.max(0, c - 1));
    } catch (err) {
      setError(err.message);
    } finally {
      setBusyId(null);
    }
  }

  const reachedCount = watchOrders.filter((o) => Number(o.days_left) <= 0).length;
  const dueSoonCount = watchOrders.filter((o) => {
    const d = Number(o.days_left);
    return d > 0 && d <= 2;
  }).length;

  return (
    <div>
      <div className="page-header">
        <div>
          <h2>Delivery Alerts & Notifications</h2>
          <p>
            Automatic 2-day pre-delivery alerts and overdue reminders for incomplete orders (Owner & Production Team)
          </p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button className="btn btn-outline" onClick={loadNotifications}>Refresh</button>
          {unreadCount > 0 && (
            <button className="btn btn-primary" onClick={markAllRead}>Mark All Read ({unreadCount})</button>
          )}
        </div>
      </div>

      {error && <div className="alert-error">{error}</div>}

      <div className="kpi-grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))' }}>
        <div className="kpi-card">
          <div className="label">Unread Notifications</div>
          <div className="value" style={{ color: '#6b3e1d' }}>{unreadCount}</div>
        </div>
        <div className="kpi-card">
          <div className="label">Delivery Reached (Incomplete)</div>
          <div className="value" style={{ color: '#b83227' }}>{reachedCount}</div>
        </div>
        <div className="kpi-card">
          <div className="label">Due Within 2 Days</div>
          <div className="value" style={{ color: '#c87a12' }}>{dueSoonCount}</div>
        </div>
      </div>

      <div className="two-col" style={{ marginTop: 18 }}>
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
            <h3 style={{ color: '#3b210e' }}>Recent Alerts</h3>
            <span style={{ fontSize: 12.5, color: '#6f6256' }}>{notifications.length} total</span>
          </div>
          {loading ? (
            <p>Loading notifications...</p>
          ) : notifications.length === 0 ? (
            <p style={{ color: '#6f6256' }}>No notifications yet. Orders due within 2 days appear here automatically.</p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {notifications.map((n) => {
                const meta = TYPE_META[n.type] || { label: n.type, badgeClass: 'badge-stage', icon: '🔔' };
                const unread = !Number(n.is_read);
                return (
                  <div
                    key={n.id}
                    style={{
                      padding: '12px 14px',
                      borderRadius: 12,
                      border: `1px solid ${unread ? '#c99a2e' : '#e6dfd5'}`,
                      background: unread ? '#fffaf0' : '#ffffff',
                      display: 'flex',
                      flexDirection: 'column',
                      gap: 6,
                    }}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <span>{meta.icon}</span>
                        <span className={`badge ${meta.badgeClass}`}>{meta.label}</span>
                        {unread && <span className="badge badge-danger">NEW</span>}
                      </div>
                      <span style={{ fontSize: 11.5, color: '#6f6256' }}>{String(n.created_at || '').slice(0, 16)}</span>
                    </div>
                    <div style={{ fontWeight: 700, color: '#261b12' }}>{n.title}</div>
                    <div style={{ fontSize: 13, color: '#5b4e43' }}>{n.message}</div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 4 }}>
                      <button
                        className="btn btn-outline btn-sm"
                        onClick={() => navigate(`/orders?search=${encodeURIComponent(n.job_id || '')}`)}
                      >
                        Open {n.job_id}
                      </button>
                      {unread && (
                        <button
                          className="btn btn-outline btn-sm"
                          disabled={busyId === n.id}
                          onClick={() => markOneRead(n.id)}
                        >
                          {busyId === n.id ? 'Saving...' : 'Mark Read'}
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        <div className="card">
          <h3 style={{ marginBottom: 14, color: '#3b210e' }}>2-Day Delivery Watchlist & Incomplete Orders</h3>
          {loading ? (
            <p>Loading pending orders...</p>
          ) : watchOrders.length === 0 ? (
            <p style={{ color: '#6f6256' }}>All dispatched orders are completed!</p>
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Job ID</th>
                    <th>Woodwork / Place</th>
                    <th>Stage</th>
                    <th>Delivery Date</th>
                  </tr>
                </thead>
                <tbody>
                  {watchOrders.map((o) => {
                    const daysLeft = Number(o.days_left);
                    const reached = daysLeft <= 0;
                    const dueSoon = daysLeft > 0 && daysLeft <= 2;
                    return (
                      <tr key={o.id}>
                        <td>
                          <div style={{ fontWeight: 700, color: '#3b210e' }}>{o.job_id}</div>
                          {o.customer_name && <div style={{ fontSize: 12, color: '#6f6256' }}>{o.customer_name}</div>}
                        </td>
                        <td>
                          <div>{o.woodwork_category} • {o.wood_species}</div>
                          {o.production_place && (
                            <div style={{ fontSize: 12, color: '#6b3e1d' }}>Place: {o.production_place}</div>
                          )}
                        </td>
                        <td>
                          <span className="badge badge-stage">{o.current_stage}/8 {o.current_stage_name}</span>
                        </td>
                        <td>
                          <div style={{ fontWeight: 600 }}>{o.expected_delivery_date}</div>
                          {reached ? (
                            <span className="badge badge-danger">
                              {daysLeft === 0 ? 'Reached Today' : `Overdue ${Math.abs(daysLeft)}d`}
                            </span>
                          ) : dueSoon ? (
                            <span className="badge badge-warning">Due in {daysLeft}d</span>
                          ) : (
                            <span style={{ fontSize: 11.5, color: '#6f6256' }}>{daysLeft} days left</span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
