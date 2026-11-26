const API_ORIGIN = (import.meta.env.VITE_API_ORIGIN || 'https://ttbilling.in/woodcraft/api').replace(/\/+$/, '');
export const API_BASE = API_ORIGIN.endsWith('/api') ? API_ORIGIN : `${API_ORIGIN}/api`;

export function mediaUrl(path) {
  if (!path) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return `${API_ORIGIN}${path.startsWith('/') ? '' : '/'}${path}`;
}

export function getToken() {
  return localStorage.getItem('wd_admin_token');
}

export function getSavedUser() {
  try {
    const raw = localStorage.getItem('wd_admin_user');
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

export function saveAuth(token, user) {
  localStorage.setItem('wd_admin_token', token);
  localStorage.setItem('wd_admin_user', JSON.stringify(user));
}

export function clearAuth() {
  localStorage.removeItem('wd_admin_token');
  localStorage.removeItem('wd_admin_user');
}

export async function apiRequest(endpoint, options = {}) {
  const token = getToken();
  const headers = {
    ...(options.headers || {}),
  };
  if (!(options.body instanceof FormData)) {
    headers['Content-Type'] = 'application/json';
  }
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
    headers['X-Auth-Token'] = token;
  }

  const res = await fetch(`${API_BASE}${endpoint}`, {
    ...options,
    headers,
  });

  const data = await res.json().catch(() => ({}));

  if (res.status === 401) {
    const isLogin = endpoint.includes('/auth/login');
    if (!isLogin) clearAuth();
    throw new Error(data.message || (isLogin ? 'Invalid email or password' : 'Session expired. Please log in again.'));
  }

  if (!res.ok || data.success === false) {
    throw new Error(data.message || `Request failed (${res.status})`);
  }
  return data;
}
