import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Monitor, AlertCircle } from 'lucide-react';
import { apiService } from '../services/api';
import { useAuth } from '../hooks';
import LoadingSpinner from '../components/LoadingSpinner';

const LoginPage: React.FC = () => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const response = await apiService.login({ username, password });
      login(response.token, username);
      navigate('/');
    } catch (err: any) {
      setError(err.response?.data?.error || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="max-w-md w-full space-y-8 p-8">
        <div className="text-center">
          <div className="flex justify-center">
            <Monitor className="w-12 h-12 text-primary-600" />
          </div>
          <h2 className="mt-6 text-3xl font-bold text-gray-900">
            ServerBox Monitor
          </h2>
          <p className="mt-2 text-sm text-gray-600">
            Sign in to access your server monitoring dashboard
          </p>
        </div>

        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          {error && (
            <div className="bg-danger-50 border border-danger-200 rounded-md p-4">
              <div className="flex">
                <AlertCircle className="w-5 h-5 text-danger-400" />
                <div className="ml-3">
                  <p className="text-sm text-danger-700">{error}</p>
                </div>
              </div>
            </div>
          )}

          <div className="space-y-4">
            <div>
              <label htmlFor="username" className="block text-sm font-medium text-gray-700">
                Username
              </label>
              <input
                id="username"
                name="username"
                type="text"
                required
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                className="input mt-1"
                placeholder="Enter your username"
              />
            </div>
            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700">
                Password
              </label>
              <input
                id="password"
                name="password"
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="input mt-1"
                placeholder="Enter your password"
              />
            </div>
          </div>

          <div>
            <button
              type="submit"
              disabled={loading}
              className="btn-primary w-full flex items-center justify-center"
            >
              {loading ? (
                <>
                  <LoadingSpinner size="sm" className="mr-2" />
                  Signing in...
                </>
              ) : (
                'Sign in'
              )}
            </button>
          </div>

          <div className="text-center text-sm text-gray-600">
            Default credentials: admin / admin123
          </div>
        </form>
      </div>
    </div>
  );
};

export default LoginPage;