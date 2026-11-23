import { useEffect, useState } from 'react';
import { API_BASE, apiRequest, formatINR, getToken } from '../api';

export default function ReportsPage() {
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  async function loadReport() {
    setLoading(true);
    setError('');
    try {
      const data = await apiRequest('/reports/summary');
      setReport(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadReport();
  }, []);

  async function downloadCsv() {
    try {
      const res = await fetch(`${API_BASE}/reports/export/csv`, {
        headers: {
          Authorization: `Bearer ${getToken()}`,
          'X-Auth-Token': getToken() || '',
        },
      });
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'woodcraft-orders-report.csv';
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      setError('Failed to export CSV report');
    }
  }

  if (loading) return <div className="card">Loading WoodCraft dashboard...</div>;
  if (error) return <div className="alert-error">{error}</div>;
  if (!report) return null;

  const { kpis, by_stage, by_wood, by_category, by_salesperson } = report;
  const maxStageCount = Math.max(1, ...(by_stage || []).map((x) => Number(x.count)));
  const maxWoodRev = Math.max(1, ...(by_wood || []).map((x) => Number(x.revenue)));

  const statCards = [
    { label: 'Total Customers', value: kpis.total_customers || 0, sub: `${kpis.active_staff || 0} active staff`, icon: '👥', bg: '#e8f1fd', color: '#2563eb' },
    { label: 'Total Orders', value: kpis.total_orders || 0, sub: formatINR(kpis.total_revenue), icon: '🛒', bg: '#ede9fe', color: '#6d28d9' },
    { label: 'In Production', value: kpis.active_orders || 0, sub: `${kpis.delayed_orders || 0} delayed • ${kpis.blocked_orders || 0} blockers`, icon: '⚙️', bg: '#fef3c7', color: '#d97706' },
    { label: 'Delivered / Ready', value: kpis.completed_orders || 0, sub: `Bal: ${formatINR(kpis.total_balance)}`, icon: '✅', bg: '#dcfce7', color: '#16a34a' },
  ];

  return (
    <div>
      <div className="page-header">
        <div>
          <h2>WoodCraft Dashboard & Reports</h2>
          <p>Real-time orders, revenue collections, workshop stage bottlenecks, and sales performance</p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button className="btn btn-outline" onClick={loadReport}>Refresh</button>
          <button className="btn btn-primary" onClick={downloadCsv}>Export CSV Report</button>
        </div>
      </div>

      {/* KPI Summary Cards */}
      <div className="kpi-grid">
        {statCards.map((c) => (
          <div className="kpi-card" key={c.label} style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            <div
              style={{
                width: 50,
                height: 50,
                borderRadius: 14,
                background: c.bg,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: 22,
                flexShrink: 0,
              }}
            >
              {c.icon}
            </div>
            <div>
              <div className="label">{c.label}</div>
              <div className="value" style={{ fontSize: 24, marginTop: 2, color: c.color }}>{c.value}</div>
              <div className="sub">{c.sub}</div>
            </div>
          </div>
        ))}
      </div>

      {/* Revenue Strip */}
      <div className="kpi-grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
        <div className="kpi-card">
          <div className="label">Total Order Revenue</div>
          <div className="value">{formatINR(kpis.total_revenue)}</div>
        </div>
        <div className="kpi-card">
          <div className="label">Advance Collected</div>
          <div className="value" style={{ color: '#1f7a4c' }}>{formatINR(kpis.total_advance)}</div>
        </div>
        <div className="kpi-card">
          <div className="label">Pending Balance</div>
          <div className="value" style={{ color: '#b83227' }}>{formatINR(kpis.total_balance)}</div>
        </div>
      </div>

      <div className="two-col">
        <div className="card">
          <h3 style={{ marginBottom: 16, color: '#3b210e' }}>Orders by Production Stage</h3>
          {(by_stage || []).length === 0 ? (
            <p style={{ color: '#6f6256' }}>No stage data yet.</p>
          ) : (
            by_stage.map((s) => (
              <div className="bar-row" key={s.stage_number}>
                <div className="bar-label">{s.stage_number}. {s.stage_name}</div>
                <div className="bar-track">
                  <div className="bar-fill" style={{ width: `${(Number(s.count) / maxStageCount) * 100}%` }} />
                </div>
                <div className="bar-val">{s.count} jobs</div>
              </div>
            ))
          )}
        </div>

        <div className="card">
          <h3 style={{ marginBottom: 16, color: '#3b210e' }}>Revenue by Wood Species</h3>
          {(by_wood || []).length === 0 ? (
            <p style={{ color: '#6f6256' }}>No wood species data yet.</p>
          ) : (
            by_wood.map((w) => (
              <div className="bar-row" key={w.wood_species}>
                <div className="bar-label">{w.wood_species}</div>
                <div className="bar-track">
                  <div className="bar-fill" style={{ width: `${(Number(w.revenue) / maxWoodRev) * 100}%` }} />
                </div>
                <div className="bar-val">{formatINR(w.revenue)}</div>
              </div>
            ))
          )}
        </div>

        <div className="card">
          <h3 style={{ marginBottom: 14, color: '#3b210e' }}>Woodwork Categories</h3>
          <table>
            <thead>
              <tr><th>Category</th><th>Orders</th><th>Revenue</th></tr>
            </thead>
            <tbody>
              {(by_category || []).map((c) => (
                <tr key={c.woodwork_category}>
                  <td style={{ fontWeight: 600 }}>{c.woodwork_category}</td>
                  <td>{c.order_count}</td>
                  <td style={{ fontWeight: 700 }}>{formatINR(c.revenue)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="card">
          <h3 style={{ marginBottom: 14, color: '#3b210e' }}>Sales Team Performance</h3>
          <table>
            <thead>
              <tr><th>Sales Person</th><th>Orders</th><th>Total Value</th></tr>
            </thead>
            <tbody>
              {(by_salesperson || []).map((sp) => (
                <tr key={sp.sales_name}>
                  <td style={{ fontWeight: 600 }}>{sp.sales_name}</td>
                  <td>{sp.order_count}</td>
                  <td style={{ fontWeight: 700 }}>{formatINR(sp.revenue)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
