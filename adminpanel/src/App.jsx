import { useState } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { clearAuth, getSavedUser, getToken } from './api';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import ReportsPage from './pages/ReportsPage';
import UsersPage from './pages/UsersPage';
import CustomersPage from './pages/CustomersPage';
import OrdersPage from './pages/OrdersPage';

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
        <Route path="/users" element={<UsersPage />} />
        <Route path="/customers" element={<CustomersPage />} />
        <Route path="/orders" element={<OrdersPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Layout>
  );
}
