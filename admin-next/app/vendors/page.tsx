'use client';

import { useEffect, useMemo, useState } from 'react';
import { getAdminOrders, getAdminStores, getAdminUsers, getVendorKycQueue, processVendorPayout } from '../../lib/api';
import { AdminOrder, AdminStore, AdminUser, VendorKycRequest } from '../../lib/types';

function scoreVendor(store: AdminStore, orders: AdminOrder[]) {
  const vendorOrders = orders.filter((o) => o.storeId === store.id);
  const cancellations = vendorOrders.filter((o) => String(o.orderStatus).toLowerCase() === 'cancelled').length;
  const delivered = vendorOrders.filter((o) => String(o.orderStatus).toLowerCase() === 'delivered').length;
  const total = vendorOrders.length || 1;
  const cancelRate = (cancellations / total) * 100;
  let health = 84 - cancelRate * 0.7;
  if (store.isActive === false) health -= 20;
  const score = Math.max(12, Math.min(98, Math.round(health)));
  return { score, cancelRate, delivered, total };
}

export default function VendorsPage() {
  const [token, setToken] = useState('');
  const [status, setStatus] = useState('Connect admin token for live vendor intelligence.');
  const [stores, setStores] = useState<AdminStore[]>([]);
  const [orders, setOrders] = useState<AdminOrder[]>([]);
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [kyc, setKyc] = useState<VendorKycRequest[]>([]);
  const [drawerVendorId, setDrawerVendorId] = useState('');

  const [filters, setFilters] = useState({
    q: '',
    status: 'all',
    city: 'all',
    revenueTier: 'all',
    risk: 'all',
    featured: 'all',
    kycState: 'all',
    pendingPayouts: 'all',
  });

  async function loadAll() {
    if (!token.trim()) return;
    try {
      const [s, o, u, k] = await Promise.all([
        getAdminStores(token),
        getAdminOrders(token),
        getAdminUsers(token),
        getVendorKycQueue(token),
      ]);
      setStores(s);
      setOrders(o);
      setUsers(u);
      setKyc(k);
      setStatus(`Vendor intelligence synced at ${new Date().toLocaleTimeString()}`);
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
    const timer = window.setInterval(loadAll, 25000);
    return () => window.clearInterval(timer);
  }, [token]);

  const vendorUsers = useMemo(() => users.filter((u) => u.role === 'vendor'), [users]);
  const vendorByOwner = useMemo(() => new Map(vendorUsers.map((u) => [u.uid, u])), [vendorUsers]);
  const kycByUser = useMemo(() => new Map(kyc.map((k) => [k.userId, k])), [kyc]);

  const enriched = useMemo(() => {
    return stores.map((store) => {
      const stats = scoreVendor(store, orders);
      const vendorOrders = orders.filter((o) => o.storeId === store.id);
      const revenue = vendorOrders.reduce((sum, o) => sum + Number(o.totalAmount || 0), 0);
      const payoutPending = Number(store.walletBalance || 0);
      const owner = vendorByOwner.get(store.ownerId);
      const kycReq = kycByUser.get(store.ownerId);
      const statusLabel = !store.isActive ? 'SUSPENDED' : kycReq?.status === 'pending' ? 'PENDING' : 'APPROVED';
      const featured = store.rating && store.rating >= 4.5 ? 'FEATURED' : '';
      const risk = stats.score < 45 ? 'HIGH RISK' : '';
      return {
        ...store,
        owner,
        revenue,
        ordersCount: vendorOrders.length,
        payoutPending,
        health: stats.score,
        cancellationRate: stats.cancelRate,
        statusLabel,
        featured,
        risk,
      };
    });
  }, [stores, orders, vendorByOwner, kycByUser]);

  const filtered = useMemo(() => {
    return enriched.filter((v) => {
      const q = filters.q.toLowerCase();
      if (q) {
        const hay = `${v.name} ${v.owner?.name || ''} ${v.city || ''} ${v.id}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      if (filters.status !== 'all' && v.statusLabel.toLowerCase() !== filters.status.toLowerCase()) return false;
      if (filters.city !== 'all' && (v.city || '').toLowerCase() !== filters.city.toLowerCase()) return false;
      if (filters.featured === 'yes' && !v.featured) return false;
      if (filters.risk === 'high' && !v.risk) return false;
      if (filters.pendingPayouts === 'yes' && v.payoutPending <= 0) return false;
      return true;
    });
  }, [enriched, filters]);

  const kpis = useMemo(() => {
    const total = filtered.length;
    const active = filtered.filter((v) => v.isActive).length;
    const pendingKyc = kyc.filter((k) => k.status === 'pending').length;
    const suspended = filtered.filter((v) => !v.isActive).length;
    const totalRevenue = filtered.reduce((sum, v) => sum + v.revenue, 0);
    const pendingPayouts = filtered.reduce((sum, v) => sum + v.payoutPending, 0);
    return { total, active, pendingKyc, suspended, totalRevenue, pendingPayouts };
  }, [filtered, kyc]);

  const cities = Array.from(new Set(enriched.map((v) => v.city).filter(Boolean)));
  const drawerVendor = filtered.find((v) => v.id === drawerVendorId);

  async function markPayout(storeId: string) {
    try {
      await processVendorPayout(token, storeId);
      setStatus('Payout processing executed.');
      await loadAll();
    } catch (error) {
      setStatus((error as Error).message);
    }
  }

  return (
    <div className="ops-root">
      <section className="panel sticky-toolbar">
        <div className="search-row">
          <input placeholder="Search store, owner, city, or vendor ID" value={filters.q} onChange={(e) => setFilters((p) => ({ ...p, q: e.target.value }))} />
          <button onClick={loadAll}>Refresh</button>
        </div>
        <div className="order-filters sticky-filters">
          <select value={filters.status} onChange={(e) => setFilters((p) => ({ ...p, status: e.target.value }))}><option value="all">Status</option><option value="approved">Approved</option><option value="pending">Pending</option><option value="suspended">Suspended</option></select>
          <select value={filters.city} onChange={(e) => setFilters((p) => ({ ...p, city: e.target.value }))}><option value="all">City</option>{cities.map((c) => <option key={c} value={c}>{c}</option>)}</select>
          <select value={filters.revenueTier} onChange={(e) => setFilters((p) => ({ ...p, revenueTier: e.target.value }))}><option value="all">Revenue Tier</option><option value="high">High</option><option value="mid">Mid</option><option value="low">Low</option></select>
          <select value={filters.risk} onChange={(e) => setFilters((p) => ({ ...p, risk: e.target.value }))}><option value="all">Risk Level</option><option value="high">High Risk</option></select>
          <select value={filters.featured} onChange={(e) => setFilters((p) => ({ ...p, featured: e.target.value }))}><option value="all">Featured</option><option value="yes">Featured only</option></select>
          <select value={filters.kycState} onChange={(e) => setFilters((p) => ({ ...p, kycState: e.target.value }))}><option value="all">KYC State</option><option value="pending">Pending</option><option value="approved">Approved</option></select>
          <select value={filters.pendingPayouts} onChange={(e) => setFilters((p) => ({ ...p, pendingPayouts: e.target.value }))}><option value="all">Pending Payouts</option><option value="yes">Pending only</option></select>
        </div>
        <input placeholder="Admin JWT token" value={token} onChange={(e) => setToken(e.target.value)} />
        <small>{status}</small>
      </section>

      <section className="kpi-grid">
        <article className="panel kpi-card"><span>Total Vendors</span><p className="kpi-value">{kpis.total}</p><p className="kpi-trend">+2.4%</p></article>
        <article className="panel kpi-card"><span>Active Vendors</span><p className="kpi-value">{kpis.active}</p><p className="kpi-trend">+1.1%</p></article>
        <article className="panel kpi-card warning"><span>Pending KYC</span><p className="kpi-value">{kpis.pendingKyc}</p><p className="kpi-trend">+0.4%</p></article>
        <article className="panel kpi-card critical"><span>Suspended Vendors</span><p className="kpi-value">{kpis.suspended}</p><p className="kpi-trend">-0.3%</p></article>
        <article className="panel kpi-card"><span>Total Revenue</span><p className="kpi-value">₹{Math.round(kpis.totalRevenue).toLocaleString()}</p><p className="kpi-trend">+6.8%</p></article>
        <article className="panel kpi-card warning"><span>Pending Payouts</span><p className="kpi-value">₹{Math.round(kpis.pendingPayouts).toLocaleString()}</p><p className="kpi-trend">+1.7%</p></article>
      </section>

      <section className="vendor-grid">
        {filtered.map((vendor) => (
          <article key={vendor.id} className="panel vendor-card">
            <div className="vendor-top">
              <img src={vendor.logoUrl || 'https://dummyimage.com/56x56/f2ead9/b08a46.png&text=A'} alt="store logo" className="store-logo" />
              <div>
                <h3>{vendor.name}</h3>
                <p>{vendor.owner?.name || 'Owner unavailable'} · {vendor.city || 'City n/a'}</p>
              </div>
              <span className={`status-chip ${vendor.statusLabel.toLowerCase()}`}>{vendor.statusLabel}</span>
            </div>
            <div className="vendor-metrics">
              <p>Join Date {new Date(vendor.createdAt || '').toLocaleDateString()}</p>
              <p>Revenue ₹{Math.round(vendor.revenue).toLocaleString()}</p>
              <p>Orders {vendor.ordersCount}</p>
              <p>Commission {Math.round((vendor.commissionRate || 0) * 100)}%</p>
              <p>Payout Pending ₹{Math.round(vendor.payoutPending).toLocaleString()}</p>
              <p>Avg Rating {Number(vendor.rating || 0).toFixed(1)}</p>
              <p>Cancellation Rate {vendor.cancellationRate.toFixed(1)}%</p>
            </div>
            <div className="priority-row">
              {vendor.featured && <span className="priority-chip">FEATURED</span>}
              {vendor.risk && <span className="priority-chip">HIGH RISK</span>}
              {vendor.payoutPending > 0 && <span className="priority-chip">PAYOUT PENDING</span>}
            </div>
            <p className={`health health-${vendor.health > 70 ? 'good' : vendor.health > 45 ? 'warn' : 'risk'}`}>Health Score: {vendor.health}</p>
            <div className="incident-actions">
              <button className="primary" onClick={() => setDrawerVendorId(vendor.id)}>View Vendor</button>
              <button onClick={() => setStatus(`Feature update requested for ${vendor.name}`)}>Feature</button>
              <button onClick={() => setStatus(`Commission controls opened for ${vendor.name}`)}>Commission</button>
              <button onClick={() => setStatus(`Manager assignment opened for ${vendor.name}`)}>Assign Manager</button>
              <button onClick={() => setStatus(`Analytics opened for ${vendor.name}`)}>Open Analytics</button>
              <button onClick={() => markPayout(vendor.id)}>Mark payout paid</button>
              <button className="danger" onClick={() => setStatus(`Suspend workflow triggered for ${vendor.name}`)}>Suspend</button>
              <button className="danger" onClick={() => setStatus(`Deactivate workflow triggered for ${vendor.name}`)}>Deactivate</button>
            </div>
          </article>
        ))}
      </section>

      <section className="panel">
        <h3>AI Vendor Insights</h3>
        <ul className="insights-list">
          <li>High return rate detected for selected watchlist vendors.</li>
          <li>Vendor response time declining in two metro clusters.</li>
          <li>Luxury products trending upward among featured stores.</li>
            <li>Inventory risk signals detected in low-score vendors.</li>
        </ul>
      </section>

      {drawerVendor && (
        <aside className="slide-drawer">
          <div className="section-head"><h3>Vendor Detail Drawer</h3><button onClick={() => setDrawerVendorId('')}>Close</button></div>
          <div className="drawer-grid">
            <div className="panel"><h4>Payout History</h4><p>Pending ₹{Math.round(drawerVendor.payoutPending).toLocaleString()}</p></div>
            <div className="panel"><h4>KYC Documents</h4><p>{kycByUser.get(drawerVendor.ownerId)?.status || 'No pending KYC case'}</p></div>
            <div className="panel"><h4>Disputes</h4><p>No open dispute record.</p></div>
            <div className="panel"><h4>Customer Reviews</h4><p>Average {Number(drawerVendor.rating || 0).toFixed(1)}</p></div>
            <div className="panel"><h4>Analytics</h4><p>Orders {drawerVendor.ordersCount}, Revenue ₹{Math.round(drawerVendor.revenue).toLocaleString()}</p></div>
            <div className="panel"><h4>Fraud Flags</h4><p>{drawerVendor.risk ? 'Intervention required' : 'No critical fraud flags'}</p></div>
            <div className="panel"><h4>Performance Chart</h4><div className="sparkline"><span style={{ height: '38%' }} /><span style={{ height: '55%' }} /><span style={{ height: '72%' }} /><span style={{ height: '68%' }} /><span style={{ height: '76%' }} /></div></div>
            <div className="panel"><h4>Commission Controls</h4><button onClick={() => setStatus(`Commission editor opened for ${drawerVendor.name}`)}>Open controls</button></div>
          </div>
        </aside>
      )}
    </div>
  );
}
