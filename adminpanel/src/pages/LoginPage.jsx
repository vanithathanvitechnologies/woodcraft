import { useState } from 'react';
import { apiRequest, saveAuth } from '../api';

export default function LoginPage({ onLogin }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const data = await apiRequest('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      });
      if (!['admin', 'owner'].includes(data.user.role)) {
        throw new Error('Admin Panel access is restricted to Admin and Owner accounts.');
      }
      saveAuth(data.token, data.user);
      onLogin(data.user);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-wrapper">
      <div className="login-card" style={{ padding: 0, overflow: 'hidden', maxWidth: 440 }}>
        {/* TOP HERO IMAGE */}
        <div style={{ position: 'relative', height: 175, overflow: 'hidden', background: '#3b210e' }}>
          <img
            src={`${import.meta.env.BASE_URL}login_hero.jpg`}
            alt="WoodCraft Door"
            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
          />
          <div
            style={{
              position: 'absolute',
              inset: 0,
              background: 'linear-gradient(180deg, rgba(0,0,0,0.1) 0%, rgba(59,33,14,0.72) 100%)',
              display: 'flex',
              alignItems: 'flex-end',
              padding: '16px 24px',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <img
                src={`${import.meta.env.BASE_URL}logo.png`}
                alt="Logo"
                className="brand-logo brand-logo-lg"
              />
              <div>
                <h1 style={{ fontSize: 21, color: '#fff', lineHeight: 1.15 }}>WoodCraft</h1>
                <p style={{ fontSize: 12, color: '#f3dec0' }}>Admin Panel & Role Management</p>
              </div>
            </div>
          </div>
        </div>

        <div style={{ padding: 26 }}>
          {error && <div className="alert-error">{error}</div>}

          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div className="form-field">
              <label>Admin / Owner Email</label>
              <input
                className="input"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Enter your email"
                required
              />
            </div>

            <div className="form-field">
              <label>Password</label>
              <input
                className="input"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Enter password"
                required
              />
            </div>

            <button className="btn btn-primary" type="submit" disabled={loading} style={{ padding: '12px 16px', marginTop: 4 }}>
              {loading ? 'Signing in...' : 'Login to WoodCraft Admin'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
