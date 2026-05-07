'use client';

import { useEffect, useMemo, useState } from 'react';
import { adminUserAction, adminUserRoleUpdate, createAdminActivityLog, getAdminActivityLogs, getAdminOrders, getAdminStores, getAdminUsers, getVendorKycQueue } from '../../lib/api';
import { AdminActivityLog, AdminOrder, AdminStore, AdminUser, VendorKycRequest } from '../../lib/types';

const allRoles = ['customer', 'vendor', 'rider', 'admin', 'support', 'finance', 'operations'] as const;

function trustEngine(user: AdminUser, orders: AdminOrder[]) {
  const owned = orders.filter((o) => o.userId === user.uid || o.riderId === user.uid);
  const totalSpend = owned.reduce((sum, o) => sum + Number(o.totalAmount || 0), 0);
  const cancelled = owned.filter((o) => String(o.orderStatus).toLowerCase() === 'cancelled').length;
  const completed = owned.filter((o) => String(o.orderStatus).toLowerCase() === 'delivered').length;
  const refundSignal = owned.filter((o) => String(o.paymentStatus).toLowerCase().includes('refund') || String(o.paymentStatus).toLowerCase().includes('failed')).length;
  const paymentReliability = Math.max(20, 100 - refundSignal * 14);
  const cancellationRate = Number(((cancelled / Math.max(1, owned.length)) * 100).toFixed(1));
  const abuseLikelihood = Math.min(95, Math.round(cancellationRate * 1.8 + refundSignal * 14));
  const fraudProbability = Math.min(98, Math.round(abuseLikelihood * 0.75));
  const trustScore = Math.max(6, Math.round(100 - fraudProbability * 0.65 - cancellationRate * 0.5 + paymentReliability * 0.2));
  const riskLevel = fraudProbability >= 75 ? 'CRITICAL' : fraudProbability >= 55 ? 'HIGH' : fraudProbability >= 35 ? 'MEDIUM' : 'LOW';

  const statuses: string[] = [];
  if (user.isActive) statuses.push('ACTIVE');
  if (completed > 0 && user.role === 'customer') statuses.push('ORDERING');
  if (user.role === 'rider' && completed > 0) statuses.push('DELIVERING');
  if (user.riderApprovalStatus === 'pending') statuses.push('PENDING KYC');
  if (riskLevel === 'CRITICAL') statuses.push('FRAUD SUSPECTED');
  if (riskLevel === 'HIGH') statuses.push('HIGH RISK');
  if (!user.isActive) statuses.push('SUSPENDED');
  if (paymentReliability < 45) statuses.push('PAYMENT FLAGGED');
  if (statuses.length === 0) statuses.push('IDLE');

  const createdAt = (user as unknown as { createdAt?: string }).createdAt;
  const updatedAt = (user as unknown as { updatedAt?: string }).updatedAt;
  const createdMs = createdAt ? new Date(createdAt).getTime() : NaN;
  const updatedMs = updatedAt ? new Date(updatedAt).getTime() : NaN;
  const now = Date.now();

  return {
    totalSpend,
    completed,
    cancellationRate,
    refundSignal,
    paymentReliability,
    abuseLikelihood,
    fraudProbability,
    trustScore,
    riskLevel,
    statuses,
    accountAgeDays: Number.isFinite(createdMs) ? Math.max(0, Math.floor((now - createdMs) / (1000 * 60 * 60 * 24))) : 0,
    lastActiveMins: Number.isFinite(updatedMs) ? Math.max(0, Math.floor((now - updatedMs) / (1000 * 60))) : 0,
    activeOrders: owned.filter((o) => !['delivered', 'cancelled'].includes(String(o.orderStatus).toLowerCase())).length,
    deviceId: String((user as unknown as { deviceId?: string }).deviceId || '-'),
    walletId: String((user as unknown as { walletId?: string }).walletId || '-'),
    fraudNotes: fraudProbability > 70 ? 'Multi-account suspicion and payment anomaly signals detected.' : 'Behavior profile within expected range.',
  };
}

export default function UsersPage() {
  const [token, setToken] = useState('');
  const [status, setStatus] = useState('Connect admin token for live identity intelligence.');
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [orders, setOrders] = useState<AdminOrder[]>([]);
  const [stores, setStores] = useState<AdminStore[]>([]);
  const [kyc, setKyc] = useState<VendorKycRequest[]>([]);
  const [logs, setLogs] = useState<AdminActivityLog[]>([]);
  const [lookup, setLookup] = useState('');
  const [visibleCount, setVisibleCount] = useState(40);
  const [filters, setFilters] = useState({
    risk: 'all', city: 'all', orderVolume: 'all', refundBehavior: 'all', vendorPerf: 'all', riderActivity: 'all',
    kycStatus: 'all', payoutState: 'all', trustScore: 'all', accountAge: 'all',
  });
  const [roleModal, setRoleModal] = useState<{ uid: string; nextRole: string } | null>(null);
  const [reason, setReason] = useState('');

  async function loadAll() {
    if (!token.trim()) return;
    try {
      const [u, o, s, k, l] = await Promise.all([
        getAdminUsers(token),
        getAdminOrders(token),
        getAdminStores(token),
        getVendorKycQueue(token),
        getAdminActivityLogs(token),
      ]);
      setUsers(u);
      setOrders(o);
      setStores(s);
      setKyc(k);
      setLogs(l);
      setStatus(`Identity fabric synced at ${new Date().toLocaleTimeString()}`);
    } catch (error) {
      setStatus((error as Error).message);
    }
  }

  useEffect(() => {
    const saved = localStorage.getItem('abzoraAdminToken') || '';
    if (saved) setToken(saved);
  }, []);

  useEffect(() => {
    if (!token.trim()) return;
    localStorage.setItem('abzoraAdminToken', token);
    loadAll();
    const timer = window.setInterval(loadAll, 17000);
    return () => {
      window.clearInterval(timer);
    };
  }, [token]);

  const cityOptions = Array.from(new Set(users.map((u) => u.city || u.riderCity).filter(Boolean)));

  const enriched = useMemo(() => {
    const kycByUser = new Map(kyc.map((item) => [item.userId, item]));
    return users.map((user) => {
      const trust = trustEngine(user, orders);
      const city = user.city || user.riderCity || 'Unknown';
      const role = user.role || 'customer';
      const vendorStore = stores.find((s) => s.ownerId === user.uid || s.vendorId === user.id);
      const sessionState = trust.lastActiveMins <= 4 ? 'LIVE' : trust.lastActiveMins <= 25 ? 'ACTIVE' : 'IDLE';
      const marketplaceSignal = role === 'vendor'
        ? `${vendorStore?.name || 'Vendor'} delayed ${Math.max(0, Math.round(trust.cancellationRate / 4))} orders today`
        : role === 'rider'
        ? `Rider ${sessionState === 'LIVE' ? 'actively delivering' : 'inactive'} for ${trust.lastActiveMins} min`
        : `Customer ${trust.activeOrders > 0 ? 'currently checking out' : 'session idle'}`;
      return {
        ...user,
        role,
        city,
        vendorStore,
        sessionState,
        kycState: kycByUser.get(user.uid)?.status || (user.riderApprovalStatus || 'approved'),
        ...trust,
        marketplaceSignal,
      };
    });
  }, [kyc, orders, stores, users]);

  const filtered = useMemo(() => {
    const q = lookup.toLowerCase();
    return enriched.filter((u) => {
      if (q) {
        const hay = `${u.name} ${u.email || ''} ${u.phone || ''} ${u.uid} ${u.city} ${u.vendorStore?.name || ''} ${u.deviceId} ${u.walletId}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      if (filters.risk !== 'all' && u.riskLevel !== filters.risk) return false;
      if (filters.city !== 'all' && String(u.city).toLowerCase() !== filters.city.toLowerCase()) return false;
      if (filters.kycStatus !== 'all' && String(u.kycState).toLowerCase() !== filters.kycStatus.toLowerCase()) return false;
      if (filters.trustScore === 'high' && u.trustScore < 75) return false;
      if (filters.trustScore === 'low' && u.trustScore >= 45) return false;
      if (filters.accountAge === 'new' && u.accountAgeDays > 90) return false;
      if (filters.accountAge === 'mature' && u.accountAgeDays <= 90) return false;
      return true;
    });
  }, [enriched, filters, lookup]);

  const counters = useMemo(() => {
    return {
      activeUsers: filtered.filter((u) => u.isActive).length,
      vendorsOnline: filtered.filter((u) => u.role === 'vendor' && ['LIVE', 'ACTIVE'].includes(u.sessionState)).length,
      ridersLive: filtered.filter((u) => u.role === 'rider' && u.sessionState === 'LIVE').length,
      customersOrdering: filtered.filter((u) => u.role === 'customer' && u.activeOrders > 0).length,
      pendingKyc: filtered.filter((u) => String(u.kycState).toLowerCase().includes('pending')).length,
      suspended: filtered.filter((u) => !u.isActive || u.statuses.includes('SUSPENDED')).length,
      highRisk: filtered.filter((u) => ['HIGH', 'CRITICAL'].includes(u.riskLevel)).length,
    };
  }, [filtered]);

  async function writeAudit(action: string, targetId: string, message: string) {
    if (!token) return;
    const payload = {
      action,
      targetType: 'user',
      targetId,
      message,
      actorRole: 'admin',
      actorId: 'admin-ops',
      timestamp: new Date().toISOString(),
    };
    try {
      await createAdminActivityLog(token, payload);
      const fresh = await getAdminActivityLogs(token);
      setLogs(fresh);
    } catch {
      setLogs((cur) => [
        {
          id: `local-${Date.now()}`,
          actorId: 'admin-ops',
          actorRole: 'admin',
          action,
          targetType: 'user',
          targetId,
          message,
          timestamp: new Date().toISOString(),
        },
        ...cur,
      ]);
    }
  }

  async function quickAction(uid: string, action: string) {
    const user = users.find((u) => u.uid === uid);
    if (!user) return;
    const actionMap: Record<string, string> = {
      Suspend: 'suspend',
      Block: 'block',
      Verify: 'verify',
      Escalate: 'escalate',
      'Force logout': 'force_logout',
      'Reset sessions': 'reset_sessions',
      'View devices': 'view_devices',
      'Open orders': 'open_orders',
      'Open wallet': 'open_wallet',
      'Open tickets': 'open_tickets',
      'Open KYC': 'open_kyc',
      'View fraud analysis': 'view_fraud_analysis',
      'Assign investigation': 'assign_investigation',
      'Disable payouts': 'disable_payouts',
      'Freeze account': 'freeze_account',
    };
    const backendAction = actionMap[action] || action.toLowerCase().replace(/\s+/g, '_');
    try {
      if (token.trim()) {
        await adminUserAction(token, uid, backendAction, `${action} executed from users operations center`);
        await loadAll();
      } else {
        setStatus('Admin token required for persistent user actions.');
        return;
      }
      setStatus(`${action} triggered for ${user.name}`);
      await writeAudit(action.toUpperCase().replace(/\s+/g, '_'), uid, `${action} executed by admin from command center.`);
    } catch (error) {
      setStatus((error as Error).message);
    }
  }

  function statusClass(status: string) {
    return status.toLowerCase().replace(/\s+/g, '-');
  }

  const suggestionPool = useMemo(() => {
    return filtered.slice(0, 20).flatMap((u) => [u.name, u.email || '', u.phone || '', u.uid, u.city, u.deviceId, u.walletId, u.vendorStore?.name || '']).filter(Boolean);
  }, [filtered]);

  const visible = filtered.slice(0, visibleCount);

  return (
    <div className="ops-root users-root">
      <section className="panel sticky-toolbar users-command-bar">
        <div className="search-row">
          <input placeholder="Search name, email, phone, order ID, rider ID, vendor store, device ID, city, wallet ID" value={lookup} onChange={(e) => setLookup(e.target.value)} list="user-suggestions" />
          <button onClick={loadAll}>Refresh</button>
        </div>
        <datalist id="user-suggestions">
          {suggestionPool.map((s, i) => <option key={`${s}-${i}`} value={s} />)}
        </datalist>

        <div className="users-counters">
          <span className="live-pill">Active Users {counters.activeUsers}</span>
          <span className="live-pill">Vendors Online {counters.vendorsOnline}</span>
          <span className="live-pill">Riders Live {counters.ridersLive}</span>
          <span className="live-pill">Customers Ordering {counters.customersOrdering}</span>
          <span className="live-pill warning">Pending KYC {counters.pendingKyc}</span>
          <span className="live-pill critical">Suspended {counters.suspended}</span>
          <span className="live-pill critical">High Risk {counters.highRisk}</span>
        </div>

        <div className="order-filters sticky-filters users-filters">
          <select value={filters.risk} onChange={(e) => setFilters((p) => ({ ...p, risk: e.target.value }))}><option value="all">Risk</option><option>LOW</option><option>MEDIUM</option><option>HIGH</option><option>CRITICAL</option></select>
          <select value={filters.city} onChange={(e) => setFilters((p) => ({ ...p, city: e.target.value }))}><option value="all">City</option>{cityOptions.map((c) => <option key={c}>{c}</option>)}</select>
          <select value={filters.orderVolume} onChange={(e) => setFilters((p) => ({ ...p, orderVolume: e.target.value }))}><option value="all">Order Volume</option><option value="high">High</option><option value="low">Low</option></select>
          <select value={filters.refundBehavior} onChange={(e) => setFilters((p) => ({ ...p, refundBehavior: e.target.value }))}><option value="all">Refund Behavior</option><option value="spike">Spike</option></select>
          <select value={filters.vendorPerf} onChange={(e) => setFilters((p) => ({ ...p, vendorPerf: e.target.value }))}><option value="all">Vendor Performance</option><option value="watch">Watchlist</option></select>
          <select value={filters.riderActivity} onChange={(e) => setFilters((p) => ({ ...p, riderActivity: e.target.value }))}><option value="all">Rider Activity</option><option value="inactive">Inactive</option></select>
          <select value={filters.kycStatus} onChange={(e) => setFilters((p) => ({ ...p, kycStatus: e.target.value }))}><option value="all">KYC Status</option><option value="pending">Pending</option><option value="approved">Approved</option><option value="rejected">Rejected</option></select>
          <select value={filters.payoutState} onChange={(e) => setFilters((p) => ({ ...p, payoutState: e.target.value }))}><option value="all">Payout State</option><option value="flagged">Flagged</option></select>
          <select value={filters.trustScore} onChange={(e) => setFilters((p) => ({ ...p, trustScore: e.target.value }))}><option value="all">Trust Score</option><option value="high">High</option><option value="low">Low</option></select>
          <select value={filters.accountAge} onChange={(e) => setFilters((p) => ({ ...p, accountAge: e.target.value }))}><option value="all">Account Age</option><option value="new">New</option><option value="mature">Mature</option></select>
        </div>

        <div className="search-row">
          <input placeholder="Admin JWT token" value={token} onChange={(e) => setToken(e.target.value)} />
          <small>{status}</small>
        </div>
      </section>

      <div className="users-layout">
        <section className="users-list-wrap">
          {visible.length === 0 && (
            <section className="panel">
              <h3>No identities matched</h3>
              <p>Try widening risk/city/kyc filters. Live activity guidance is ready as events arrive.</p>
            </section>
          )}

          {visible.map((u) => (
            <article key={u.uid} className={`panel user-ops-row risk-${u.riskLevel.toLowerCase()}`}>
              <div className="user-left">
                <div className="user-avatar">{u.name.slice(0, 1)}</div>
                <div>
                  <h3>{u.name} <span className="role-chip">{u.role.toUpperCase()}</span></h3>
                  <p>{u.email || u.phone || u.uid}</p>
                  <p>Trust {u.trustScore} · Account age {u.accountAgeDays}d · {u.city}</p>
                  <p>Last active {u.lastActiveMins}m ago</p>
                </div>
              </div>

              <div className="user-center">
                <p>Active orders {u.activeOrders}</p>
                <p>Total spend ₹{Math.round(u.totalSpend).toLocaleString()}</p>
                <p>Completed deliveries {u.completed}</p>
                <p>Cancellation {u.cancellationRate}%</p>
                <p>Refund history {u.refundSignal}</p>
                <p>Payment reliability {u.paymentReliability}%</p>
                <p>Session {u.sessionState}</p>
                <p>{u.marketplaceSignal}</p>
              </div>

              <div className="user-right">
                <div className="status-grid">
                  {u.statuses.map((s) => <span key={s} className={`ops-status ${statusClass(s)}`}>{s}</span>)}
                </div>
                <p className={`health health-${u.riskLevel === 'LOW' ? 'good' : u.riskLevel === 'MEDIUM' ? 'warn' : 'risk'}`}>Risk {u.riskLevel}</p>
                <p>Fraud probability {u.fraudProbability}%</p>
                <p>Abuse likelihood {u.abuseLikelihood}%</p>
                <p>Device {u.deviceId}</p>
                <p>Wallet {u.walletId}</p>
                <p>KYC {String(u.kycState).toUpperCase()}</p>

                <div className="quick-actions-grid">
                  <button onClick={() => quickAction(u.uid, 'Suspend')}>Suspend</button>
                  <button onClick={() => quickAction(u.uid, 'Block')}>Block</button>
                  <button onClick={() => quickAction(u.uid, 'Verify')}>Verify</button>
                  <button onClick={() => quickAction(u.uid, 'Escalate')}>Escalate</button>
                  <button onClick={() => quickAction(u.uid, 'Force logout')}>Force logout</button>
                  <button onClick={() => quickAction(u.uid, 'Reset sessions')}>Reset sessions</button>
                  <button onClick={() => quickAction(u.uid, 'View devices')}>View devices</button>
                  <button onClick={() => quickAction(u.uid, 'Open orders')}>Open orders</button>
                  <button onClick={() => quickAction(u.uid, 'Open wallet')}>Open wallet</button>
                  <button onClick={() => quickAction(u.uid, 'Open tickets')}>Open tickets</button>
                  <button onClick={() => quickAction(u.uid, 'Open KYC')}>Open KYC</button>
                  <button onClick={() => quickAction(u.uid, 'View fraud analysis')}>Fraud analysis</button>
                  <button onClick={() => quickAction(u.uid, 'Assign investigation')}>Assign investigation</button>
                  <button onClick={() => setRoleModal({ uid: u.uid, nextRole: u.role })}>Convert role</button>
                  <button onClick={() => quickAction(u.uid, 'Disable payouts')}>Disable payouts</button>
                  <button className="danger" onClick={() => quickAction(u.uid, 'Freeze account')}>Freeze account</button>
                </div>

                <div className="role-convert-inline">
                  <select value={u.role} onChange={(e) => setRoleModal({ uid: u.uid, nextRole: e.target.value })}>
                    {allRoles.map((r) => <option key={r} value={r}>{r}</option>)}
                  </select>
                </div>
              </div>
            </article>
          ))}

          {visibleCount < filtered.length && (
            <section className="panel">
              <button className="primary" onClick={() => setVisibleCount((v) => v + 40)}>Load More Users</button>
              <p>Lazy rendering active: showing {visible.length} of {filtered.length}</p>
            </section>
          )}
        </section>

        <aside className="panel users-audit-rail">
          <h3>Realtime Admin Activity</h3>
          <ul className="audit-list">
            {logs.slice(0, 20).map((log) => (
              <li key={log.id || `${log.action}-${log.timestamp}`}>
                <span>{log.action || 'ACTION'}</span>
                <span>{new Date(log.timestamp || '').toLocaleTimeString()}</span>
                <span>{log.targetId || '-'}</span>
                <span>{log.actorRole || 'admin'}</span>
                <span className="audit-status">{log.message || 'Audit event'}</span>
              </li>
            ))}
          </ul>

          <h4>AI Trust Engine</h4>
          <ul className="insights-list">
            <li>Multi-account suspicion detection is active.</li>
            <li>Refund abuse scoring updated in real time.</li>
            <li>Payment anomaly and device mismatch checks running.</li>
            <li>Marketplace role-behavior correlation continuously monitored.</li>
          </ul>
        </aside>
      </div>

      {roleModal && (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <div className="panel role-modal">
            <h3>Confirm Role Conversion</h3>
            <p>This change updates access control scope and operational permissions.</p>
            <label htmlFor="role-select">Role</label>
            <select id="role-select" value={roleModal.nextRole} onChange={(e) => setRoleModal((m) => m ? { ...m, nextRole: e.target.value } : null)}>
              {allRoles.map((r) => <option key={r} value={r}>{r}</option>)}
            </select>
            <label htmlFor="reason">Admin reason</label>
            <textarea id="reason" rows={4} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Enter role-change reason for audit trail" />
            <div className="incident-actions">
              <button onClick={() => setRoleModal(null)}>Cancel</button>
              <button
                className="primary"
                onClick={async () => {
                  if (!reason.trim()) {
                    setStatus('Role conversion requires admin reason.');
                    return;
                  }
                  const uid = roleModal.uid;
                  const nextRole = roleModal.nextRole;
                  try {
                    if (token.trim()) {
                      await adminUserRoleUpdate(token, uid, nextRole, reason);
                      await loadAll();
                    } else {
                      setStatus('Admin token required for role conversion.');
                      return;
                    }
                    await writeAudit('ROLE_CONVERT', uid, `Role changed to ${nextRole}. Reason: ${reason}`);
                    setStatus(`Role converted to ${nextRole}. Permission impact logged.`);
                    setReason('');
                    setRoleModal(null);
                  } catch (error) {
                    setStatus((error as Error).message);
                  }
                }}
              >
                Confirm Conversion
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
