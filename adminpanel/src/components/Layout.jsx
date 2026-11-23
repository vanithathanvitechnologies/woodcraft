import { NavLink } from 'react-router-dom';

export default function Layout({ user, onLogout, children }) {
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
          <NavLink to="/customers" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
            <span>👥</span> Customers
          </NavLink>
          <NavLink to="/orders" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
            <span>🚪</span> Orders & Tracking
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
