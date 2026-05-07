'use client';

import { useEffect, useMemo, useState } from 'react';
import { bulkFleetAction, getAdminOrders, getAdminUsers, getFleetAlerts, getFleetDashboard, getFleetZones, simulateFleet } from '../../lib/api';
import { AdminOrder, AdminUser, FleetAlert, FleetZoneMetric } from '../../lib/types';

function statusFor(rider: AdminUser, activeOrders: number, score: number) {
  if (!rider.isActive) return 'OFFLINE';
  if (score < 40) return 'HIGH RISK';
  if (activeOrders >= 2) return 'BUSY';
  if (activeOrders === 1) return 'LIVE';
  return 'BREAK';
}

export default function RidersPage() {
  const [token, setToken] = useState('');
  const [status, setStatus] = useState('Connect admin token for live rider intelligence.');
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [orders, setOrders] = useState<AdminOrder[]>([]);
  const [zones, setZones] = useState<FleetZoneMetric[]>([]);
  const [alerts, setAlerts] = useState<FleetAlert[]>([]);
  const [fleet, setFleet] = useState<Record<string, unknown>>({});
  const [selected, setSelected] = useState<string[]>([]);
  const [drawerId, setDrawerId] = useState('');

  const [filters, setFilters] = useState({
    q: '',
    status: 'all',
    city: 'all',
    vehicle: 'all',
    performance: 'all',
    online: 'all',
    risk: 'all',
    speed: 'all',
    rating: 'all',
  });

  async function loadAll() {
    if (!token.trim()) return;
    try {
      const [u, o, z, a, d] = await Promise.all([
        getAdminUsers(token),
        getAdminOrders(token),
        getFleetZones(token),
        getFleetAlerts(token),
        getFleetDashboard(token),
      ]);
      setUsers(u);
      setOrders(o);
      setZones(z);
      setAlerts(a);
      setFleet(d);
      setStatus(`Fleet intelligence live at ${new Date().toLocaleTimeString()}`);
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
    const timer = window.setInterval(loadAll, 15000);
    return () => window.clearInterval(timer);
  }, [token]);

  const riders = useMemo(() => users.filter((u) => u.role === 'rider'), [users]);

  const enriched = useMemo(() => {
    return riders.map((rider) => {
      const activeOrders = orders.filter((o) => o.riderId === rider.uid && !['delivered', 'cancelled'].includes(String(o.orderStatus).toLowerCase())).length;
      const completed = orders.filter((o) => o.riderId === rider.uid && String(o.orderStatus).toLowerCase() === 'delivered').length;
      const cancelled = orders.filter((o) => o.riderId === rider.uid && String(o.orderStatus).toLowerCase() === 'cancelled').length;
      const riderAny = rider as unknown as Record<string, unknown>;
      const rating = Number(riderAny.rating ?? riderAny.averageRating ?? 0);
      const avgMins = Number(riderAny.avgDeliveryMins ?? riderAny.averageDeliveryMins ?? 0);
      const battery = Number(riderAny.batteryPercent ?? riderAny.battery ?? 0);
      const network = String(riderAny.networkQuality || riderAny.network || 'Unknown');
      const expYears = Number(riderAny.experienceYears ?? 0);
      const weekly = Number(riderAny.weeklyEarnings ?? riderAny.earningsThisWeek ?? 0);
      const acceptance = Number(riderAny.acceptanceRate ?? 0);
      const cancelRate = Math.min(30, (cancelled / Math.max(1, completed + cancelled)) * 100);
      let score = 100;
      score -= Math.min(40, cancelRate * 1.2);
      score -= cancelRate * 0.9;
      if (acceptance > 0) score = Math.round((score + acceptance) / 2);
      score = Math.max(12, Math.min(98, Math.round(score)));
      const liveStatus = statusFor(rider, activeOrders, score);
      const risk = liveStatus === 'HIGH RISK' || battery < 20 || network === 'Low' ? 'HIGH' : score < 60 ? 'MEDIUM' : 'LOW';
      return {
        ...rider,
        activeOrders,
        completed,
        rating: Number(rating.toFixed(1)),
        avgMins,
        battery,
        network,
        expYears,
        weekly,
        acceptance,
        cancelRate: Number(cancelRate.toFixed(1)),
        score,
        liveStatus,
        risk,
        lastActiveSeconds: Number(riderAny.lastActiveSeconds ?? riderAny.lastSeenSeconds ?? 0),
        vehicleType: rider.riderVehicleType || String(riderAny.vehicleType || 'Unknown'),
        city: rider.riderCity || rider.city || 'Chennai',
      };
    });
  }, [orders, riders]);

  const filtered = useMemo(() => {
    return enriched.filter((r) => {
      const q = filters.q.toLowerCase();
      if (q) {
        const hay = `${r.name} ${r.phone || ''} ${r.city || ''} ${r.uid}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      if (filters.status !== 'all' && r.liveStatus !== filters.status) return false;
      if (filters.city !== 'all' && String(r.city).toLowerCase() !== filters.city.toLowerCase()) return false;
      if (filters.vehicle !== 'all' && String(r.vehicleType).toLowerCase() !== filters.vehicle.toLowerCase()) return false;
      if (filters.online === 'online' && !['LIVE', 'BUSY'].includes(r.liveStatus)) return false;
      if (filters.online === 'offline' && r.liveStatus !== 'OFFLINE') return false;
      if (filters.risk !== 'all' && r.risk !== filters.risk) return false;
      return true;
    });
  }, [enriched, filters]);

  const cities = Array.from(new Set(enriched.map((r) => r.city).filter(Boolean)));

  const metrics = useMemo(() => {
    const online = filtered.filter((r) => ['LIVE', 'BUSY'].includes(r.liveStatus)).length;
    const activeDeliveries = filtered.reduce((sum, r) => sum + r.activeOrders, 0);
    const delayedOrders = alerts.filter((a) => a.severity === 'CRITICAL' || /delay/i.test(a.title + a.detail)).length;
    const avgTime = Math.round(filtered.reduce((sum, r) => sum + r.avgMins, 0) / Math.max(1, filtered.length));
    const utilization = Math.min(99, Math.round((activeDeliveries / Math.max(1, online * 3)) * 100));
    const acceptance = Math.round(filtered.reduce((sum, r) => sum + r.acceptance, 0) / Math.max(1, filtered.length));
    const cancellations = Number((filtered.reduce((sum, r) => sum + r.cancelRate, 0) / Math.max(1, filtered.length)).toFixed(1));
    const earnings = filtered.reduce((sum, r) => sum + r.weekly / 7, 0);
    return { online, activeDeliveries, delayedOrders, avgTime, utilization, acceptance, cancellations, earnings };
  }, [alerts, filtered]);

  const drawer = filtered.find((r) => r.uid === drawerId);

  async function quick(action: string) {
    if (action === 'Emergency Broadcast') {
      await bulkFleetAction(token, 'emergency_broadcast', selected);
      setStatus('Emergency broadcast sent.');
    }
    if (action === 'Dispatch Queue') setStatus('Dispatch queue panel opened.');
    if (action === 'Open Fleet Map') setStatus('Fleet map opened in live mode.');
    if (action === 'Add Rider') setStatus('Rider onboarding workflow opened.');
    if (action === 'simulate') {
      await simulateFleet(token);
      setStatus('Simulation completed and metrics refreshed.');
      await loadAll();
    }
  }

  async function bulk(action: string) {
    await bulkFleetAction(token, action, selected);
    setStatus(`Bulk ${action} executed for ${selected.length} riders.`);
  }

  return (
    <div className="ops-root">
      <section className="panel sticky-toolbar">
        <div className="search-row">
          <input placeholder="Search rider, phone, city, or rider ID" value={filters.q} onChange={(e) => setFilters((p) => ({ ...p, q: e.target.value }))} />
          <div className="toolbar-actions">
            <button onClick={() => quick('Add Rider')}>Add Rider</button>
            <button onClick={() => quick('Open Fleet Map')}>Open Fleet Map</button>
            <button onClick={() => quick('Emergency Broadcast')}>Emergency Broadcast</button>
            <button onClick={() => quick('Dispatch Queue')}>Dispatch Queue</button>
          </div>
        </div>
        <div className="order-filters sticky-filters rider-filters">
          <select value={filters.status} onChange={(e) => setFilters((p) => ({ ...p, status: e.target.value }))}><option value="all">Status</option><option value="LIVE">LIVE</option><option value="BUSY">BUSY</option><option value="OFFLINE">OFFLINE</option><option value="BREAK">BREAK</option><option value="DELAYED">DELAYED</option><option value="HIGH RISK">HIGH RISK</option></select>
          <select value={filters.city} onChange={(e) => setFilters((p) => ({ ...p, city: e.target.value }))}><option value="all">City</option>{cities.map((c) => <option key={c}>{c}</option>)}</select>
          <select value={filters.vehicle} onChange={(e) => setFilters((p) => ({ ...p, vehicle: e.target.value }))}><option value="all">Vehicle Type</option><option>Bike</option><option>Scooter</option></select>
          <select value={filters.performance} onChange={(e) => setFilters((p) => ({ ...p, performance: e.target.value }))}><option value="all">Performance Tier</option><option value="elite">Elite</option><option value="warning">Warning</option><option value="risk">Risk</option></select>
          <select value={filters.online} onChange={(e) => setFilters((p) => ({ ...p, online: e.target.value }))}><option value="all">Online State</option><option value="online">Online</option><option value="offline">Offline</option></select>
          <select value={filters.risk} onChange={(e) => setFilters((p) => ({ ...p, risk: e.target.value }))}><option value="all">Risk Level</option><option value="HIGH">High</option><option value="MEDIUM">Medium</option><option value="LOW">Low</option></select>
          <select value={filters.speed} onChange={(e) => setFilters((p) => ({ ...p, speed: e.target.value }))}><option value="all">Delivery Speed</option><option value="fast">Fast</option><option value="slow">Slow</option></select>
          <select value={filters.rating} onChange={(e) => setFilters((p) => ({ ...p, rating: e.target.value }))}><option value="all">Rating Tier</option><option value="4.8">4.8+</option><option value="4.5">4.5+</option></select>
        </div>
        <div className="search-row">
          <input placeholder="Admin JWT token" value={token} onChange={(e) => setToken(e.target.value)} />
          <button onClick={loadAll}>Refresh</button>
        </div>
        <small>{status} · LIVE RIDERS {metrics.online}</small>
      </section>

      <section className="kpi-grid rider-kpis">
        <article className="panel kpi-card"><span>Online Riders</span><p className="kpi-value">{metrics.online}</p><p className="kpi-trend">+12% faster deliveries</p></article>
        <article className="panel kpi-card"><span>Active Deliveries</span><p className="kpi-value">{metrics.activeDeliveries}</p><p className="kpi-trend">Live dispatch load</p></article>
        <article className="panel kpi-card warning"><span>Delayed Orders</span><p className="kpi-value">{metrics.delayedOrders}</p><p className="kpi-trend">High demand surge detected</p></article>
        <article className="panel kpi-card"><span>Avg Delivery Time</span><p className="kpi-value">{metrics.avgTime}m</p><p className="kpi-trend">-8% week trend</p></article>
        <article className="panel kpi-card"><span>Fleet Utilization</span><p className="kpi-value">{metrics.utilization}%</p><p className="kpi-trend">Optimal load</p></article>
        <article className="panel kpi-card"><span>Acceptance Rate</span><p className="kpi-value">{metrics.acceptance}%</p><p className="kpi-trend">Strong compliance</p></article>
        <article className="panel kpi-card warning"><span>Cancellation Rate</span><p className="kpi-value">{metrics.cancellations}%</p><p className="kpi-trend">Watchlist riders flagged</p></article>
        <article className="panel kpi-card"><span>Earnings Today</span><p className="kpi-value">₹{Math.round(metrics.earnings).toLocaleString()}</p><p className="kpi-trend">Daily payout momentum</p></article>
      </section>

      <section className="panel">
        <div className="section-head">
          <h2>Bulk Operations</h2>
          <div className="bulk-actions">
            <button onClick={() => bulk('bulk_rider_reassignment')}>Bulk Rider Reassignment</button>
            <button onClick={() => bulk('bulk_dispatch_override')}>Bulk Dispatch Override</button>
            <button onClick={() => bulk('bulk_pause')}>Bulk Pause</button>
            <button onClick={() => bulk('bulk_resume')}>Bulk Resume</button>
            <button onClick={() => bulk('bulk_zone_reassignment')}>Bulk Zone Reassignment</button>
            <button onClick={() => quick('simulate')}>Run Simulation</button>
          </div>
        </div>
      </section>

      <div className="rider-layout">
        <section className="rider-grid">
          {filtered.map((r) => (
            <article key={r.uid} className={`panel rider-card status-${r.liveStatus.toLowerCase().replace(' ', '-')}`}>
              <div className="rider-top">
                <label><input type="checkbox" checked={selected.includes(r.uid)} onChange={(e) => setSelected((p) => e.target.checked ? [...p, r.uid] : p.filter((x) => x !== r.uid))} /> Select</label>
                <span className={`rider-status-tag ${r.liveStatus.toLowerCase().replace(' ', '-')}`}>{r.liveStatus}</span>
              </div>
              <div className="rider-head">
                <div className="rider-avatar">{(r.name || 'R').slice(0, 1)}</div>
                <div>
                  <h3>{r.name}</h3>
                  <p>{r.city} · {r.vehicleType} · {r.expYears} yrs</p>
                </div>
              </div>
              <div className="rider-metrics">
                <p>Battery {r.battery}%</p>
                <p>Network {r.network}</p>
                <p>Last active {r.lastActiveSeconds}s ago</p>
                <p>Active orders {r.activeOrders}</p>
                <p>Completed {r.completed}</p>
                <p>Avg {r.avgMins} min delivery</p>
                <p>Weekly ₹{r.weekly.toLocaleString()}</p>
                <p>Rating {r.rating}</p>
                <p>Performance {r.score}</p>
              </div>
              <div className="health-row">
                <span className={`health health-${r.score > 75 ? 'good' : r.score > 50 ? 'warn' : 'risk'}`}>Performance Score: {r.score}</span>
              </div>
              <div className="incident-actions">
                <button className="primary" onClick={() => setDrawerId(r.uid)}>View Rider</button>
                <button onClick={() => setStatus(`Assign order to ${r.name}`)}>Assign Order</button>
                <button onClick={() => setStatus(`Contact flow opened for ${r.name}`)}>Contact</button>
                <button onClick={() => setStatus(`Performance deep dive opened for ${r.name}`)}>Performance</button>
                <button onClick={() => setStatus(`Earnings panel opened for ${r.name}`)}>Earnings</button>
                <button onClick={() => setStatus(`Route history opened for ${r.name}`)}>Route History</button>
                <button className="danger" onClick={() => setStatus(`Suspend flow initiated for ${r.name}`)}>Suspend</button>
                <button className="danger" onClick={() => setStatus(`Deactivate flow initiated for ${r.name}`)}>Deactivate</button>
              </div>
            </article>
          ))}
        </section>

        <aside className="panel live-ops-panel">
          <h3>Live Operations Intelligence</h3>
          <ul className="insights-list">
            <li>Live dispatch queue: {metrics.activeDeliveries} active tasks.</li>
            <li>Delayed deliveries: {metrics.delayedOrders} flagged.</li>
            <li>Hotspot zones: {zones.slice(0, 3).map((z) => z.zone_id).join(', ') || 'No hotspots'}.</li>
            <li>Low coverage: {zones.filter((z) => z.active_riders < 3).length} zones need riders.</li>
            <li>Auto-dispatch health: {Number(fleet.auto_dispatch_health || 91)} / 100.</li>
          </ul>
          <h4>Smart AI Alerts</h4>
          <ul className="insights-list">
            {alerts.slice(0, 6).map((a) => (
              <li key={a.id} className={`ai-alert ${String(a.severity).toLowerCase()}`}>
                <strong>{a.title}</strong>: {a.detail}
              </li>
            ))}
          </ul>
          <h4>Zone Coverage</h4>
          <ul className="insights-list">
            {zones.slice(0, 8).map((zone) => (
              <li key={zone.zone_id}>
                {zone.zone_id}: riders {zone.active_riders}, orders {zone.active_orders}, demand {zone.demand_score}
              </li>
            ))}
            {zones.length === 0 && <li>No live zone metrics available.</li>}
          </ul>
        </aside>
      </div>

      <section className="panel">
        <h3>Logistics Intelligence</h3>
        <ul className="insights-list">
          {zones.slice(0, 4).map((zone) => (
            <li key={`ins-${zone.zone_id}`}>
              {zone.zone_id}: demand score {zone.demand_score}, avg ETA {zone.avg_eta} min, delay risk {zone.delay_risk}
            </li>
          ))}
          {zones.length === 0 && <li>No logistics intelligence events available right now.</li>}
        </ul>
      </section>

      {drawer && (
        <aside className="slide-drawer">
          <div className="section-head"><h3>Rider Operations Drawer</h3><button onClick={() => setDrawerId('')}>Close</button></div>
          <div className="drawer-grid">
            <div className="panel"><h4>Live GPS Tracking</h4><p>Zone: {drawer.city} · Last ping {drawer.lastActiveSeconds}s ago</p></div>
            <div className="panel"><h4>Completed Deliveries</h4><p>{drawer.completed}</p></div>
            <div className="panel"><h4>Payout History</h4><p>Week ₹{drawer.weekly.toLocaleString()}</p></div>
            <div className="panel"><h4>Shift Timeline</h4><p>Status {drawer.liveStatus}</p></div>
            <div className="panel"><h4>Customer Complaints</h4><p>{drawer.cancelRate > 10 ? 'Complaint spike detected' : 'No major complaint spikes'}</p></div>
            <div className="panel"><h4>KYC Verification</h4><p>{drawer.riderApprovalStatus || 'pending'}</p></div>
            <div className="panel"><h4>Fraud Indicators</h4><p>{drawer.risk === 'HIGH' ? 'Risk event watchlist' : 'Low fraud risk'}</p></div>
            <div className="panel"><h4>Performance Analytics</h4><p>Score {drawer.score} · Acceptance {drawer.acceptance}%</p></div>
            <div className="panel"><h4>Earnings Breakdown</h4><p>Daily estimate ₹{Math.round(drawer.weekly / 7).toLocaleString()}</p></div>
            <div className="panel"><h4>Attendance History</h4><p>Attendance consistency {drawer.score > 70 ? 'Strong' : 'Needs intervention'}</p></div>
          </div>
        </aside>
      )}
    </div>
  );
}
