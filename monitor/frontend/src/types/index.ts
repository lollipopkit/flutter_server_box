export interface SystemMetrics {
  timestamp: string;
  server_name: string;
  cpu_usage: number;
  // Wire-compatible with monitor's CpuCoreTime { used, total } (busy/total
  // ticks); array index is the core number (no id/label on the wire)
  cpu_cores?: { used: number; total: number }[];
  memory: MemoryMetrics;
  swap: SwapMetrics;
  disk: DiskMetrics;
  network: NetworkMetrics;
  temperature?: number;
  sys?: string;
  cpu_brand?: string;
  // Detail lists are absent on older agents; treat as optional
  gpus?: GpuMetrics[];
  disk_details?: DiskDetail[];
  ifaces?: IfaceMetrics[];
  // Already formatted by the collection script, e.g. "up 3 days, 2:14"
  uptime?: string;
  conn?: ConnMetrics;
  // Cumulative sector counters since boot (not a rate) — see diskio_rate
  // for a live speed derived from this
  diskio?: DiskIoMetrics[];
  // Bytes/sec since the previous poll; empty on the agent's first cycle or
  // for a device with no prior sample yet
  diskio_rate?: DiskIoRate[];
  batteries?: BatteryMetrics[];
  sensors?: SensorMetrics[];
  disk_smart?: DiskSmartMetrics[];
}

export type FieldSupport = 'supported' | 'not_implemented' | 'hardware_dependent'

/// Platform-only support level per ServerStatus field — depends on OS, not
/// on any sample. See sbm_parser::capabilities for the three-state meaning:
/// 'not_implemented' = this platform never collects it (hide unconditionally),
/// 'hardware_dependent' = collected when present, empty just means no such
/// hardware, 'supported' = always populated when the command succeeds.
export interface Capabilities {
  cpu: FieldSupport
  cpu_brand: FieldSupport
  mem: FieldSupport
  swap: FieldSupport
  disks: FieldSupport
  net: FieldSupport
  temps: FieldSupport
  conn: FieldSupport
  uptime: FieldSupport
  sys: FieldSupport
  host: FieldSupport
  diskio: FieldSupport
  batteries: FieldSupport
  sensors: FieldSupport
  nvidia: FieldSupport
  amd: FieldSupport
  disk_smart: FieldSupport
}

export interface ConnMetrics {
  max_conn: number;
  fail: number;
}

export interface DiskIoMetrics {
  dev: string;
  sectors_read: number;
  sectors_write: number;
}

export interface DiskIoRate {
  dev: string;
  read_bytes_per_sec: number;
  write_bytes_per_sec: number;
}

export interface BatteryMetrics {
  percent: number | null;
  status: 'charging' | 'discharging' | 'full' | 'unknown';
  name: string | null;
  cycle: number | null;
  tech: string | null;
}

export interface SensorMetrics {
  device: string;
  adapter: string;
  details: [string, string][];
}

export interface DiskSmartMetrics {
  device: string;
  healthy: boolean | null;
  temperature: number | null;
  model: string | null;
  serial: string | null;
  power_on_hours: number | null;
  power_cycle_count: number | null;
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