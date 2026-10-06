import { render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import ProtectedRoute from '@/components/ProtectedRoute';
import { AuthProvider } from '@/lib/AuthContext';

const renderAt = (auth) =>
  render(
    <AuthProvider value={auth}>
      <MemoryRouter initialEntries={['/']}>
        <Routes>
          <Route path="/login" element={<p>login page</p>} />
          <Route element={<ProtectedRoute />}>
            <Route path="/" element={<p>secret</p>} />
          </Route>
        </Routes>
      </MemoryRouter>
    </AuthProvider>,
  );

describe('ProtectedRoute', () => {
  it('fails closed when auth is unconfigured', () => {
    renderAt(undefined);
    expect(screen.getByText('login page')).toBeInTheDocument();
  });
  it('renders for authenticated users', () => {
    renderAt({ status: 'authenticated', user: { id: 'u' } });
    expect(screen.getByText('secret')).toBeInTheDocument();
  });
});
