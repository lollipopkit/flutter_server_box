import React from 'react';
import { 
  Monitor, 
  LogOut, 
  Cpu, 
  HardDrive, 
  MemoryStick, 
  Thermometer,
  Network,
  AlertCircle,
  RefreshCw
} from 'lucide-react';
import { useAuth, useStatus, useMetrics } from '../hooks';
import LoadingSpinner from '../components/LoadingSpinner';

const DashboardPage: React.FC = () => {
  const { username, logout } = useAuth();
  const { status, loading: statusLoading, error: statusError } = useStatus(5000);
  const { metrics, loading: metricsLoading, error: metricsError } = useMetrics(5000);

  const handleLogout = () => {
    logout();
  };

  const getStatusBadge = (value: string, type: 'cpu' | 'memory' | 'disk') => {
    const percentage = parseFloat(value);
    
    if (isNaN(percentage)) return 'status-success';
    
    const thresholds = {
      cpu: { warning: 70, danger: 85 },
      memory: { warning: 80, danger: 90 },
      disk: { warning: 85, danger: 95 },
    };
    
    const threshold = thresholds[type];
    
    if (percentage >= threshold.danger) return 'status-danger';
    if (percentage >= threshold.warning) return 'status-warning';
    return 'status-success';
  };

  if (statusLoading && metricsLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-4">
            <div className="flex items-center">
              <Monitor className="w-8 h-8 text-primary-600 mr-3" />
              <div>
                <h1 className="text-xl font-semibold text-gray-900">
                  ServerBox Monitor
                </h1>
                <p className="text-sm text-gray-500">
                  {status?.name || 'Unknown Server'}
                </p>
              </div>
            </div>
            
            <div className="flex items-center space-x-4">
              <div className="text-sm text-gray-600">
                Welcome, <span className="font-medium">{username}</span>
              </div>
              <button
                onClick={handleLogout}
                className="btn btn-secondary flex items-center"
              >
                <LogOut className="w-4 h-4 mr-2" />
                Logout
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {(statusError || metricsError) && (
          <div className="mb-6 bg-danger-50 border border-danger-200 rounded-md p-4">
            <div className="flex">
              <AlertCircle className="w-5 h-5 text-danger-400" />
              <div className="ml-3">
                <p className="text-sm text-danger-700">
                  {statusError || metricsError}
                </p>
              </div>
            </div>
          </div>
        )}

        {/* Status Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          {/* CPU Card */}
          <div className="card">
            <div className="flex items-center justify-between">
              <div className="flex items-center">
                <Cpu className="w-8 h-8 text-blue-500 mr-3" />
                <div>
                  <p className="text-sm font-medium text-gray-600">CPU Usage</p>
                  <p className="text-2xl font-bold text-gray-900">
                    {status?.cpu || '--'}
                  </p>
                </div>
              </div>
              <span className={getStatusBadge(status?.cpu || '0', 'cpu')}>
                {status?.cpu ? 'Active' : 'N/A'}
              </span>
            </div>
          </div>

          {/* Memory Card */}
          <div className="card">
            <div className="flex items-center justify-between">
              <div className="flex items-center">
                <MemoryStick className="w-8 h-8 text-green-500 mr-3" />
                <div>
                  <p className="text-sm font-medium text-gray-600">Memory</p>
                  <p className="text-lg font-bold text-gray-900">
                    {status?.memory || '--'}
                  </p>
                </div>
              </div>
              <span className={getStatusBadge(status?.memory || '0', 'memory')}>
                {status?.memory ? 'Active' : 'N/A'}
              </span>
            </div>
          </div>

          {/* Disk Card */}
          <div className="card">
            <div className="flex items-center justify-between">
              <div className="flex items-center">
                <HardDrive className="w-8 h-8 text-yellow-500 mr-3" />
                <div>
                  <p className="text-sm font-medium text-gray-600">Disk Usage</p>
                  <p className="text-lg font-bold text-gray-900">
                    {status?.disk || '--'}
                  </p>
                </div>
              </div>
              <span className={getStatusBadge(status?.disk || '0', 'disk')}>
                {status?.disk ? 'Active' : 'N/A'}
              </span>
            </div>
          </div>

          {/* Network Card */}
          <div className="card">
            <div className="flex items-center justify-between">
              <div className="flex items-center">
                <Network className="w-8 h-8 text-purple-500 mr-3" />
                <div>
                  <p className="text-sm font-medium text-gray-600">Network</p>
                  <p className="text-sm font-bold text-gray-900">
                    {status?.network || '--'}
                  </p>
                </div>
              </div>
              <span className="status-success">Active</span>
            </div>
          </div>
        </div>

        {/* Detailed Metrics */}
        {metrics && (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* System Information */}
            <div className="card">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">
                System Information
              </h3>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-sm text-gray-600">Server Name:</span>
                  <span className="text-sm font-medium">{metrics.server_name}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-gray-600">Last Updated:</span>
                  <span className="text-sm font-medium">
                    {new Date(metrics.timestamp).toLocaleString()}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-gray-600">CPU Usage:</span>
                  <span className="text-sm font-medium">{metrics.cpu_usage.toFixed(1)}%</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-gray-600">Memory Usage:</span>
                  <span className="text-sm font-medium">
                    {metrics.memory.usage_percent.toFixed(1)}%
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-gray-600">Disk Usage:</span>
                  <span className="text-sm font-medium">
                    {metrics.disk.usage_percent.toFixed(1)}%
                  </span>
                </div>
                {metrics.temperature && (
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Temperature:</span>
                    <span className="text-sm font-medium flex items-center">
                      <Thermometer className="w-4 h-4 mr-1" />
                      {metrics.temperature.toFixed(1)}°C
                    </span>
                  </div>
                )}
              </div>
            </div>

            {/* Quick Actions */}
            <div className="card">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">
                Quick Actions
              </h3>
              <div className="space-y-3">
                <button 
                  onClick={() => window.location.reload()}
                  className="btn-primary w-full flex items-center justify-center"
                >
                  <RefreshCw className="w-4 h-4 mr-2" />
                  Refresh Data
                </button>
                <div className="text-xs text-gray-500 text-center mt-4">
                  Data refreshes automatically every 5 seconds
                </div>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
};

export default DashboardPage;