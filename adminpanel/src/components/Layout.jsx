import { useEffect, useState } from 'react';
import { NavLink } from 'react-router-dom';
import { apiRequest } from '../api';

export default function Layout({ user, onLogout, children }) {
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    let active = true;
    async function loadUnread() {
      try {
        const data = await apiRequest('/notifications');
        if (active) setUnreadCount(Number(data.unread_count || 0));
      } catch {
        // Ignore transient polling failures
      }
    }
    loadUnread();
    const timer = setInterval(loadUnread, 45000);
    return () => {
      active = false;
      clearInterval(timer);
    };
  }, []);

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <img
            src={`${import.meta.env.BASE_URL}logo.png`}
            alt="Logo"
            className="brand-logo"
          />
          <div>
            <h1>WoodCraft</h1>
            <span>Admin Panel</span>
          </div>
        </div>

        <nav className="nav-links">
          <NavLink to="/" end className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
            <span>📊</span> Dashboard & Reports
          </NavLink>
          <NavLink to="/categories" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
            <span>🪵</span> Wooden Categories
          </NavLink>
          <NavLink to="/catalog" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
            <span>🖼️</span> Design Catalog
          </NavLink>
          <NavLink to="/customers" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
            <span>👥</span> Customers
          </NavLink>
          <NavLink to="/orders" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
            <span>🚪</span> Orders & Tracking
          </NavLink>
          <NavLink to="/notifications" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
            <span>🔔</span> Notifications
            {unreadCount > 0 && (
              <span
                style={{
                  marginLeft: 'auto',
                  background: '#b83227',
                  color: '#fff',
                  borderRadius: 999,
                  padding: '2px 8px',
                  fontSize: 11,
                  fontWeight: 800,
                }}
              >
                {unreadCount}
              </span>
            )}
          </NavLink>
          <NavLink to="/users" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
            <span>🔐</span> Staff & Role Access
          </NavLink>
        </nav>

        <div className="sidebar-footer">
          <div className="user-pill">
            <div className="name">{user?.name}</div>
            <div className="role">{user?.role}</div>
          </div>
          <button
            className="btn btn-outline"
            style={{ width: '100%', background: 'rgba(255,255,255,0.08)', color: '#fff', borderColor: 'rgba(255,255,255,0.18)' }}
            onClick={onLogout}
          >
            Sign Out
          </button>
        </div>
      </aside>

      <main className="main-content">{children}</main>
    </div>
  );
}
