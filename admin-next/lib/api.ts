import {
  AdminActivityLog,
  AdminOrder,
  AdminStore,
  AdminUser,
  FleetAlert,
  FleetZoneMetric,
  GarmentTemplate,
  OpsAlert,
  OpsLiveData,
  OpsLogEntry,
  OpsMetricSnapshot,
  ProductLinkDraft,
  VendorKycRequest,
} from './types';

const API_BASE =
  process.env.NEXT_PUBLIC_BACKEND_URL?.replace(/\/+$/, '') ||
  'http://localhost:5000';

async function json<T>(input: RequestInfo | URL, init?: RequestInit): Promise<T> {
  const response = await fetch(input, init);
  const payload = (await response.json()) as {
    success?: boolean;
    message?: string;
    data?: T;
  };
  if (!response.ok || payload.success === false) {
    throw new Error(payload.message || 'Request failed');
  }
  return (payload.data ?? payload) as T;
}

function authHeaders(token: string): HeadersInit {
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };
}

export async function listTemplates(): Promise<GarmentTemplate[]> {
  return json<GarmentTemplate[]>(`${API_BASE}/ar/templates`, {
    cache: 'no-store',
  });
}

export async function upsertTemplate(
  token: string,
  template: Partial<GarmentTemplate>,
): Promise<GarmentTemplate> {
  return json<GarmentTemplate>(`${API_BASE}/ar/templates/upsert`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify(template),
  });
}

export async function saveProductLink(
  token: string,
  draft: ProductLinkDraft,
): Promise<unknown> {
  return json(`${API_BASE}/products/${draft.productId}`, {
    method: 'PUT',
    headers: authHeaders(token),
    body: JSON.stringify({
      garmentConfig: {
        templateId: draft.templateId,
        fabricTextureUrl: draft.fabricTextureUrl,
        normalMapUrl: draft.normalMapUrl,
        fitPreset: draft.fitPreset,
        colorHex: draft.colorHex,
        lodPreference: draft.lodPreference,
        designOptions: draft.designOptions,
      },
    }),
  });
}

export async function getOpsAlerts(token: string): Promise<OpsAlert[]> {
  return json<OpsAlert[]>(`${API_BASE}/ops/alerts?limit=60`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function getOpsLive(token: string): Promise<OpsLiveData> {
  return json<OpsLiveData>(`${API_BASE}/ops/live`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function getOpsLogs(token: string): Promise<OpsLogEntry[]> {
  return json<OpsLogEntry[]>(`${API_BASE}/ops/logs?limit=80`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function getOpsMetrics(token: string): Promise<OpsMetricSnapshot[]> {
  return json<OpsMetricSnapshot[]>(`${API_BASE}/ops/metrics?type=hourly&limit=8`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function runOpsDetection(token: string): Promise<void> {
  await json(`${API_BASE}/ops/detect`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({}),
  });
}

export async function runOpsSimulation(token: string): Promise<unknown> {
  return json(`${API_BASE}/ops/simulate`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({ N: 300, M: 60 }),
  });
}

export async function runAlertAction(token: string, alertId: string): Promise<unknown> {
  return json(`${API_BASE}/ops/alerts/${alertId}/action`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({}),
  });
}

export async function reassignOrder(token: string, orderId: string): Promise<unknown> {
  return json(`${API_BASE}/ops/orders/${orderId}/reassign`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({}),
  });
}

export async function retryPayment(token: string, orderId: string): Promise<unknown> {
  return json(`${API_BASE}/ops/payments/${orderId}/retry`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({}),
  });
}

export async function forceDispatch(token: string, orderId: string): Promise<unknown> {
  return json(`${API_BASE}/ops/dispatch/${orderId}/force`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({}),
  });
}

export async function cancelOrder(token: string, orderId: string): Promise<unknown> {
  return json(`${API_BASE}/ops/orders/${orderId}/cancel`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({ reason: 'Cancelled by ops command center' }),
  });
}

export async function getAdminOrders(token: string): Promise<AdminOrder[]> {
  return json<AdminOrder[]>(`${API_BASE}/admin/orders`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function getAdminStores(token: string): Promise<AdminStore[]> {
  return json<AdminStore[]>(`${API_BASE}/admin/stores`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function getAdminUsers(token: string): Promise<AdminUser[]> {
  return json<AdminUser[]>(`${API_BASE}/admin/users`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function verifyAdminSession(token: string): Promise<Record<string, unknown>> {
  return json<Record<string, unknown>>(`${API_BASE}/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function adminUserAction(token: string, userId: string, action: string, reason = ''): Promise<AdminUser> {
  return json<AdminUser>(`${API_BASE}/admin/users/${userId}/action`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({ action, reason }),
  });
}

export async function adminUserRoleUpdate(token: string, userId: string, role: string, reason: string): Promise<AdminUser> {
  return json<AdminUser>(`${API_BASE}/admin/users/${userId}/role`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({ role, reason }),
  });
}

export async function getAdminProducts(token: string): Promise<Array<Record<string, unknown>>> {
  return json<Array<Record<string, unknown>>>(`${API_BASE}/admin/products`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function adminProductAction(
  token: string,
  productId: string,
  action: string,
  payload: Record<string, unknown> = {},
): Promise<Record<string, unknown>> {
  return json<Record<string, unknown>>(`${API_BASE}/admin/products/${productId}/action`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({ action, ...payload }),
  });
}

export async function getVendorKycQueue(token: string): Promise<VendorKycRequest[]> {
  return json<VendorKycRequest[]>(`${API_BASE}/admin/kyc/vendors`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function processVendorPayout(token: string, storeId: string): Promise<unknown> {
  return json(`${API_BASE}/admin/payouts/process`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({ storeId, periodLabel: 'Manual payout from vendor intelligence panel' }),
  });
}

export async function getFleetZones(token: string): Promise<FleetZoneMetric[]> {
  return json<FleetZoneMetric[]>(`${API_BASE}/fleet/zones`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function getFleetAlerts(token: string): Promise<FleetAlert[]> {
  return json<FleetAlert[]>(`${API_BASE}/fleet/alerts`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function getFleetDashboard(token: string): Promise<Record<string, unknown>> {
  return json<Record<string, unknown>>(`${API_BASE}/fleet/live-dashboard`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function simulateFleet(token: string): Promise<Record<string, unknown>> {
  return json<Record<string, unknown>>(`${API_BASE}/fleet/simulate`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({ demand: 'high', weather: 'rain', riderOutagePercent: 12 }),
  });
}

export async function bulkFleetAction(token: string, action: string, riderIds: string[]): Promise<Record<string, unknown>> {
  return json<Record<string, unknown>>(`${API_BASE}/fleet/bulk-actions`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify({ action, riderIds }),
  });
}

export async function getAdminActivityLogs(token: string): Promise<AdminActivityLog[]> {
  return json<AdminActivityLog[]>(`${API_BASE}/admin/activity-logs`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function createAdminActivityLog(token: string, payload: Partial<AdminActivityLog>): Promise<AdminActivityLog> {
  return json<AdminActivityLog>(`${API_BASE}/admin/activity-logs`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify(payload),
  });
}

export async function getAdminDashboard(token: string): Promise<Record<string, unknown>> {
  return json<Record<string, unknown>>(`${API_BASE}/admin/dashboard`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function getAdminPricing(token: string): Promise<Record<string, unknown>> {
  return json<Record<string, unknown>>(`${API_BASE}/admin/pricing`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function simulateAdminPricing(token: string, payload: Record<string, unknown>): Promise<Record<string, unknown>> {
  return json<Record<string, unknown>>(`${API_BASE}/admin/pricing/simulate`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify(payload),
  });
}

export async function getAdminDisputes(token: string): Promise<Array<Record<string, unknown>>> {
  return json<Array<Record<string, unknown>>>(`${API_BASE}/admin/disputes`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function getAdminNotifications(token: string): Promise<Array<Record<string, unknown>>> {
  return json<Array<Record<string, unknown>>>(`${API_BASE}/admin/notifications`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function createAdminNotification(token: string, payload: Record<string, unknown>): Promise<Record<string, unknown>> {
  return json<Record<string, unknown>>(`${API_BASE}/admin/notifications`, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify(payload),
  });
}

export async function getAdminHomeVisuals(token: string): Promise<Record<string, unknown>> {
  return json<Record<string, unknown>>(`${API_BASE}/admin/home-visuals`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
}

export async function saveAdminHomeVisuals(token: string, payload: Record<string, unknown>): Promise<Record<string, unknown>> {
  return json<Record<string, unknown>>(`${API_BASE}/admin/home-visuals`, {
    method: 'PUT',
    headers: authHeaders(token),
    body: JSON.stringify(payload),
  });
}

export async function getCategoryTree(): Promise<Array<Record<string, unknown>>> {
  return json<Array<Record<string, unknown>>>(`${API_BASE}/api/categories`, {
    cache: 'no-store',
  });
}

export async function updateCategoryNode(
  token: string,
  categoryId: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  return json<Record<string, unknown>>(`${API_BASE}/api/categories/${categoryId}`, {
    method: 'PUT',
    headers: authHeaders(token),
    body: JSON.stringify(payload),
  });
}
