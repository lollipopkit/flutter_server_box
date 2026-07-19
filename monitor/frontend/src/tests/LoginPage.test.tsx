import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { AxiosError } from 'axios';
import '@testing-library/jest-dom/vitest';
import LoginPage from '../pages/LoginPage';
import { apiService } from '../services/api';

// Mock the API service (partial mock: pure helpers like apiErrorMessage stay real)
vi.mock('../services/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../services/api')>()),
  apiService: { login: vi.fn() },
}));
const mockedApiService = vi.mocked(apiService);

// Mock the hooks
vi.mock('../hooks', () => ({
  useAuth: () => ({ login: vi.fn() }),
  useStatus: vi.fn(),
  useMetrics: vi.fn(),
}));

describe('LoginPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders login form', () => {
    render(
      <BrowserRouter>
        <LoginPage />
      </BrowserRouter>
    );

    expect(screen.getByText('ServerBox Monitor')).toBeInTheDocument();
    expect(screen.getByLabelText('Username')).toBeInTheDocument();
    expect(screen.getByLabelText('Password')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /sign in/i })).toBeInTheDocument();
  });

  it('handles successful login', async () => {
    mockedApiService.login.mockResolvedValue({ token: 'test-token' });
    
    render(
      <BrowserRouter>
        <LoginPage />
      </BrowserRouter>
    );

    fireEvent.change(screen.getByLabelText('Username'), {
      target: { value: 'admin' },
    });
    fireEvent.change(screen.getByLabelText('Password'), {
      target: { value: 'password' },
    });
    fireEvent.click(screen.getByRole('button', { name: /sign in/i }));

    await waitFor(() => {
      expect(mockedApiService.login).toHaveBeenCalledWith({
        username: 'admin',
        password: 'password',
      });
    });
  });

  it('displays error on failed login', async () => {
    mockedApiService.login.mockRejectedValue(
      new AxiosError('Unauthorized', AxiosError.ERR_BAD_REQUEST, undefined, undefined, {
        data: { error: 'Invalid credentials' },
        status: 401,
        statusText: 'Unauthorized',
        headers: {},
        config: {} as never,
      }),
    );

    render(
      <BrowserRouter>
        <LoginPage />
      </BrowserRouter>
    );

    fireEvent.change(screen.getByLabelText('Username'), {
      target: { value: 'wrong' },
    });
    fireEvent.change(screen.getByLabelText('Password'), {
      target: { value: 'wrong' },
    });
    fireEvent.click(screen.getByRole('button', { name: /sign in/i }));

    await waitFor(() => {
      expect(screen.getByText('Invalid credentials')).toBeInTheDocument();
    });
  });
});