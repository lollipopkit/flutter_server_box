import { useState, useEffect } from 'react';
import { apiService } from '../services/api';
import { StatusResponse, SystemMetrics } from '../types';

export const useAuth = () => {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  const [username, setUsername] = useState<string | null>(null);
  const [loading, setLoading] = useState<boolean>(true);

  useEffect(() => {
    const token = localStorage.getItem('token');
    const storedUsername = localStorage.getItem('username');
    
    if (token && storedUsername) {
      setIsAuthenticated(true);
      setUsername(storedUsername);
    }
    setLoading(false);
  }, []);

  const login = (token: string, username: string) => {
    localStorage.setItem('token', token);
    localStorage.setItem('username', username);
    setIsAuthenticated(true);
    setUsername(username);
  };

  const logout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('username');
    setIsAuthenticated(false);
    setUsername(null);
  };

  return { isAuthenticated, username, loading, login, logout };
};

export const useStatus = (refreshInterval: number = 5000) => {
  const [status, setStatus] = useState<StatusResponse | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchStatus = async () => {
      try {
        const data = await apiService.getStatus();
        setStatus(data);
        setError(null);
      } catch (err: any) {
        setError(err.response?.data?.error || 'Failed to fetch status');
      } finally {
        setLoading(false);
      }
    };

    fetchStatus();
    const interval = setInterval(fetchStatus, refreshInterval);

    return () => clearInterval(interval);
  }, [refreshInterval]);

  return { status, loading, error };
};

export const useMetrics = (refreshInterval: number = 5000) => {
  const [metrics, setMetrics] = useState<SystemMetrics | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchMetrics = async () => {
      try {
        const data = await apiService.getMetrics();
        setMetrics(data);
        setError(null);
      } catch (err: any) {
        setError(err.response?.data?.error || 'Failed to fetch metrics');
      } finally {
        setLoading(false);
      }
    };

    fetchMetrics();
    const interval = setInterval(fetchMetrics, refreshInterval);

    return () => clearInterval(interval);
  }, [refreshInterval]);

  return { metrics, loading, error };
};