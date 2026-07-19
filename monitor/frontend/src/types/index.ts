export interface SystemMetrics {
  timestamp: string;
  server_name: string;
  cpu_usage: number;
  cpu_cores: unknown[];
  memory: MemoryMetrics;
  swap: SwapMetrics;
  disk: DiskMetrics;
  network: NetworkMetrics;
  temperature?: number;
  gpus: GpuMetrics[];
  disk_details: DiskDetail[];
  ifaces: IfaceMetrics[];
}

export interface GpuMetrics {
  name: string;
  usage_percent: number;
  temperature: number;
  power: string;
  memory_used: number;
  memory_total: number;
  memory_unit: string;
}

export interface DiskDetail {
  path: string;
  mount: string;
  fs_type?: string;
  used: number;
  total: number;
  usage_percent: number;
}

export interface IfaceMetrics {
  name: string;
  rx_bytes: number;
  tx_bytes: number;
}

export interface MemoryMetrics {
  total: number;
  used: number;
  free: number;
  usage_percent: number;
}

export interface SwapMetrics {
  total: number;
  used: number;
  usage_percent: number;
}

export interface DiskMetrics {
  total: number;
  used: number;
  free: number;
  usage_percent: number;
}

export interface NetworkMetrics {
  rx_bytes: number;
  tx_bytes: number;
}

export interface StatusResponse {
  name: string;
  cpu: string;
  memory: string;
  disk: string;
  network: string;
  temperature?: string;
  timestamp: string;
}

export interface HistoryPoint {
  timestamp: string;
  cpu: number;
  memory: number;
  disk: number;
  net_rx_speed: number;
  net_tx_speed: number;
  temperature?: number;
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  token: string;
}

export interface User {
  username: string;
  token: string;
}

export interface ApiError {
  error: string;
}