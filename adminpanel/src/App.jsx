import { useState } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { clearAuth, getSavedUser, getToken } from './api';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import ReportsPage from './pages/ReportsPage';
import CategoriesPage from './pages/CategoriesPage';
import CatalogPage from './pages/CatalogPage';
import UsersPage from './pages/UsersPage';
import CustomersPage from './pages/CustomersPage';
import OrdersPage from './pages/OrdersPage';
import NotificationsPage from './pages/NotificationsPage';

export default function App() {
  const [user, setUser] = useState(() => (getToken() ? getSavedUser() : null));

  function handleLogout() {
    clearAuth();
    setUser(null);
  }

  if (!user) {
    return <LoginPage onLogin={setUser} />;
  }

  return (
    <Layout user={user} onLogout={handleLogout}>
      <Routes>
        <Route path="/" element={<ReportsPage />} />
        <Route path="/categories" element={<CategoriesPage />} />
        <Route path="/catalog" element={<CatalogPage />} />
        <Route path="/users" element={<UsersPage />} />
        <Route path="/customers" element={<CustomersPage />} />
        <Route path="/orders" element={<OrdersPage />} />
        <Route path="/notifications" element={<NotificationsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Layout>
  );
}
