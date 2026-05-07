'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  cancelOrder,
  forceDispatch,
  getOpsAlerts,
  getOpsLive,
  getOpsLogs,
  getOpsMetrics,
  reassignOrder,
  retryPayment,
  runAlertAction,
  runOpsDetection,
  runOpsSimulation,
} from '../lib/api';
import { OpsAlert, OpsLiveData, OpsLogEntry, OpsMetricSnapshot } from '../lib/types';

const operationsToolbar = ['Run Detection', 'Refresh', 'Simulation', 'AI Assist'] as const;

function toneFromSeverity(severity: string) {
  const value = String(severity || '').toUpperCase();
  if (value === 'CRITICAL') return 'critical';
  if (value === 'HIGH') return 'warning';
  return 'normal';
}

function formatTime(input?: string) {
  if (!input) return '-';
  const date = new Date(input);
  if (Number.isNaN(date.getTime())) return '-';
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

export default function HomePage() {
  const [token, setToken] = useState('');
  const [status, setStatus] = useState('Connect your admin token to enable live ops data.');
  const [alerts, setAlerts] = useState<OpsAlert[]>([]);
  const [live, setLive] = useState<OpsLiveData | null>(null);
  const [logs, setLogs] = useState<OpsLogEntry[]>([]);
  const [metrics, setMetrics] = useState<OpsMetricSnapshot[]>([]);
  const [loading, setLoading] = useState(false);

  const loadOps = useCallback(async () => {
    if (!token.trim()) return;
    setLoading(true);
    try {
      const [alertData, liveData, logData, metricData] = await Promise.all([
        getOpsAlerts(token),
        getOpsLive(token),
        getOpsLogs(token),
        getOpsMetrics(token),
      ]);
      setAlerts(alertData);
      setLive(liveData);
      setLogs(logData);
      setMetrics(metricData);
      setStatus(`Live feed updated at ${new Date().toLocaleTimeString()}`);
    } catch (error) {
      setStatus((error as Error).message);
    } finally {
      setLoading(false);
    }
  }, [token]);

  useEffect(() => {
    const saved = localStorage.getItem('abzoraAdminToken') || '';
    if (saved) {
      setToken(saved);
    }
  }, []);

  useEffect(() => {
    if (!token.trim()) return;
    localStorage.setItem('abzoraAdminToken', token);
    loadOps();
    const timer = window.setInterval(loadOps, 25000);
    return () => window.clearInterval(timer);
  }, [token, loadOps]);

  const alertCounts = useMemo(() => {
    const counter = { critical: 0, high: 0, medium: 0, low: 0 };
    for (const item of alerts) {
      const level = String(item.severity || '').toLowerCase();
      if (level === 'critical') counter.critical += 1;
      else if (level === 'high') counter.high += 1;
      else if (level === 'medium') counter.medium += 1;
      else counter.low += 1;
    }
    return counter;
  }, [alerts]);

  const liveOrders = live?.liveOrders || [];
  const riders = live?.riders || [];
  const vendors = live?.vendors || [];
  const dispatch = live?.dispatch || [];

  const delayedOrders = alerts.filter((a) => /delay|dispatch/i.test(a.type + a.message)).length;
  const pendingKyc = alerts.filter((a) => /kyc/i.test(a.type + a.message)).length;
  const failedPayments = alerts.filter((a) => /payment|refund/i.test(a.type + a.message)).length;

  const heroKpis = [
    { label: 'Active Orders', value: `${liveOrders.length}`, trend: 'Live', tone: 'normal', icon: '◎' },
    { label: 'Revenue Today', value: 'Live', trend: `${vendors.length} vendors`, tone: 'normal', icon: '◍' },
    { label: 'Pending KYC', value: `${pendingKyc}`, trend: 'Ops tracked', tone: pendingKyc > 0 ? 'warning' : 'normal', icon: '◌' },
    { label: 'Active Riders', value: `${riders.length}`, trend: 'Online fleet', tone: 'normal', icon: '◈' },
    { label: 'Delayed Orders', value: `${delayedOrders}`, trend: 'Incident linked', tone: delayedOrders > 0 ? 'critical' : 'normal', icon: '◒' },
    { label: 'High Demand Zones', value: `${Math.max(1, Math.ceil((dispatch.length || 1) / 15))}`, trend: 'Dynamic', tone: 'warning', icon: '◐' },
  ];

  const criticalKpis = [
    { label: 'Critical Alerts', value: `${alertCounts.critical}`, trend: 'priority', tone: 'critical' },
    { label: 'High Alerts', value: `${alertCounts.high}`, trend: 'attention', tone: 'warning' },
    { label: 'Live Orders', value: `${liveOrders.length}`, trend: 'active', tone: 'normal' },
    { label: 'Delayed Dispatches', value: `${delayedOrders}`, trend: 'track', tone: delayedOrders > 0 ? 'critical' : 'normal' },
    { label: 'Failed Payments', value: `${failedPayments}`, trend: 'monitor', tone: failedPayments > 0 ? 'warning' : 'normal' },
    { label: 'Active Riders', value: `${riders.length}`, trend: 'coverage', tone: 'normal' },
  ];

  const activityFeed = logs.slice(0, 8).map((entry) => ({
    text: `${entry.action || 'Ops action'} ${entry.entityId ? `(${entry.entityId.slice(-8)})` : ''}`,
    time: formatTime(entry.createdAt),
    icon: entry.status === 'FAILED' ? '!' : entry.status === 'RESOLVED' ? '✓' : '↺',
  }));

  const orders = liveOrders.slice(0, 8).map((order) => {
    const id = String(order._id || order.id || '').trim();
    const statusRaw = String(order.deliveryStatus || order.orderStatus || 'Processing');
    const status = /cancel/i.test(statusRaw)
      ? 'Cancelled'
      : /deliver/i.test(statusRaw)
      ? 'Delivered'
      : /delay|failed/i.test(statusRaw)
      ? 'Delayed'
      : 'Processing';
    return {
      id: id || '-',
      vendor: String(order.storeId || '-'),
      amount: `₹${Number(order.totalAmount || 0).toLocaleString()}`,
      status,
      eta: String(order.estimatedDeliveryTime || order.eta || 'Live'),
    };
  });

  async function handleToolbarAction(action: (typeof operationsToolbar)[number]) {
    if (!token.trim()) {
      setStatus('Add admin token first.');
      return;
    }
    try {
      if (action === 'Run Detection') {
        await runOpsDetection(token);
        setStatus('Detection completed. Refreshing live state...');
      } else if (action === 'Refresh') {
        setStatus('Refreshing live data...');
      } else if (action === 'Simulation') {
        await runOpsSimulation(token);
        setStatus('Simulation finished.');
      } else {
        setStatus('AI Assist is connected to live insights panel.');
      }
      await loadOps();
    } catch (error) {
      setStatus((error as Error).message);
    }
  }

  async function handleIncidentAction(kind: 'run' | 'reassign' | 'retry' | 'dispatch' | 'cancel', alert: OpsAlert) {
    if (!token.trim()) return;
    const orderId = String(alert.orderId || '').trim();
    try {
      if (kind === 'run') await runAlertAction(token, alert.alertId);
      if (kind === 'reassign' && orderId) await reassignOrder(token, orderId);
      if (kind === 'retry' && orderId) await retryPayment(token, orderId);
      if (kind === 'dispatch' && orderId) await forceDispatch(token, orderId);
      if (kind === 'cancel' && orderId) await cancelOrder(token, orderId);
      setStatus('Action executed successfully.');
      await loadOps();
    } catch (error) {
      setStatus((error as Error).message);
    }
  }

  const sparkValues = metrics.map((item, index) => {
    const a = Number(item.delayPercent || 0);
    const b = Number(item.paymentRetryFailures || 0) * 8;
    const c = Number(item.vendorResponseFailures || 0) * 8;
    const mixed = Math.max(20, Math.min(92, a + b + c));
    return { key: `${index}-${item.timestamp || 't'}`, height: `${mixed}%` };
  });

  return (
    <div className="ops-root">
      <header className="ops-toolbar panel sticky-toolbar">
        <div className="ops-live"><span className="live-dot" /> LIVE</div>
        <div className="toolbar-actions">
          {operationsToolbar.map((action) => (
            <button key={action} className="action-btn" type="button" onClick={() => handleToolbarAction(action)}>
              {action}
            </button>
          ))}
        </div>
      </header>

      <section className="panel search-panel">
        <label htmlFor="ops-token">Admin Token</label>
        <input
          id="ops-token"
          placeholder="Paste admin JWT to connect live ops"
          value={token}
          onChange={(event) => setToken(event.target.value)}
        />
        <small>{loading ? 'Syncing live data...' : status}</small>
      </section>

      <section className="critical-alert-bar">
        <span className="alert-chip critical">{alertCounts.critical} critical incidents</span>
        <span className="alert-chip warning">{alertCounts.high} high-priority incidents</span>
        <span className="alert-chip neutral">{liveOrders.length} live orders monitored</span>
      </section>

      <section className="panel search-panel">
        <label htmlFor="global-search">Global Search</label>
        <input id="global-search" list="ops-search" placeholder="Search users, vendors, orders, riders" />
        <datalist id="ops-search">
          {orders.slice(0, 6).map((item) => (
            <option key={item.id} value={item.id} />
          ))}
        </datalist>
      </section>

      <section className="kpi-grid hero-grid">
        {heroKpis.map((kpi) => (
          <article key={kpi.label} className={`panel kpi-card ${kpi.tone}`}>
            <div className="kpi-top"><span>{kpi.label}</span><span className="kpi-icon">{kpi.icon}</span></div>
            <p className="kpi-value">{kpi.value}</p>
            <p className="kpi-trend">{kpi.trend}</p>
          </article>
        ))}
      </section>

      <section className="kpi-grid critical-grid">
        {criticalKpis.map((kpi) => (
          <article key={kpi.label} className={`panel kpi-card ${kpi.tone}`}>
            <span>{kpi.label}</span>
            <p className="kpi-value">{kpi.value}</p>
            <p className="kpi-trend">{kpi.trend}</p>
          </article>
        ))}
      </section>

      <div className="ops-layout">
        <section className="panel queue-panel">
          <div className="section-head"><h2>Priority Alert Queue</h2></div>
          {alerts.length === 0 && <p className="premium-empty">No alerts right now. Platform running smoothly.</p>}
          {alerts.map((incident) => (
            <article key={incident.id} className={`incident-card ${toneFromSeverity(incident.severity)}`}>
              <details open>
                <summary><span>{incident.type}</span><span className="severity">Severity {Math.round(incident.score || 0)}</span></summary>
                <p>{incident.message || 'Operational incident requires review.'}</p>
                <div className="incident-meta">
                  <span>Order: {incident.orderId || '-'}</span>
                  <span>Time: {formatTime(incident.createdAt)}</span>
                  <span>Status: {incident.status}</span>
                  <span>Retries: {incident.retryCount || 0}</span>
                </div>
                <div className="incident-actions">
                  <button className="primary" type="button" onClick={() => handleIncidentAction('run', incident)}>Run Action</button>
                  <button type="button" onClick={() => handleIncidentAction('reassign', incident)}>Reassign</button>
                  <button type="button" onClick={() => handleIncidentAction('retry', incident)}>Retry Payment</button>
                  <button type="button" onClick={() => handleIncidentAction('dispatch', incident)}>Force Dispatch</button>
                  <button className="danger" type="button" onClick={() => handleIncidentAction('cancel', incident)}>Cancel Order</button>
                </div>
              </details>
            </article>
          ))}
        </section>

        <aside className="right-rail">
          <section className="panel">
            <h3>Live Dispatch Snapshot</h3>
            <div className="chip-row">
              <span className="state-chip critical">Critical {alertCounts.critical}</span>
              <span className="state-chip warning">High {alertCounts.high}</span>
              <span className="state-chip medium">Medium {alertCounts.medium}</span>
              <span className="state-chip low">Low {alertCounts.low}</span>
            </div>
            <p className="premium-empty">Dispatch queue operating normally.</p>
          </section>

          <section className="panel">
            <h3>Delay Trend Analytics</h3>
            {sparkValues.length > 0 ? (
              <div className="sparkline" aria-hidden>
                {sparkValues.map((item) => (
                  <span key={item.key} style={{ height: item.height }} />
                ))}
              </div>
            ) : (
              <p className="premium-empty">No delay metrics yet.</p>
            )}
          </section>

          <section className="panel">
            <h3>AI Operational Insights</h3>
            <ul className="insights-list">
              <li>{alertCounts.critical > 0 ? 'Critical incident load rising. Trigger auto-action on top queue items.' : 'No critical incidents detected in current cycle.'}</li>
              <li>{riders.length < Math.max(20, liveOrders.length / 5) ? 'Rider shortage risk detected in active zones.' : 'Rider coverage currently stable for live volume.'}</li>
              <li>{failedPayments > 0 ? 'Payment anomaly detected. Retry success probability may be low.' : 'Payment flow stable. No major retry spikes.'}</li>
            </ul>
            <div className="insight-actions">
              <button className="primary" type="button" onClick={() => handleToolbarAction('Run Detection')}>Auto Resolve</button>
              <button type="button">Escalate</button>
              <button type="button">Open Incident</button>
              <button type="button">Review</button>
            </div>
          </section>
        </aside>
      </div>

      <div className="ops-layout lower-grid">
        <section className="panel">
          <h3>Live Activity Feed</h3>
          <ul className="activity-list">
            {activityFeed.length === 0 && <li><span className="activity-icon">✓</span><span>Platform running smoothly</span><time>Now</time></li>}
            {activityFeed.map((item) => (
              <li key={`${item.text}-${item.time}`}>
                <span className="activity-icon">{item.icon}</span>
                <span>{item.text}</span>
                <time>{item.time}</time>
              </li>
            ))}
          </ul>
        </section>

        <section className="panel">
          <h3>Recent Orders</h3>
          <table className="table">
            <thead><tr><th>Order ID</th><th>Vendor</th><th>Amount</th><th>Status</th><th>ETA</th></tr></thead>
            <tbody>
              {orders.length === 0 && (
                <tr><td colSpan={5}>No live orders right now.</td></tr>
              )}
              {orders.map((order) => (
                <tr key={order.id}>
                  <td>{order.id}</td>
                  <td>{order.vendor}</td>
                  <td>{order.amount}</td>
                  <td><span className={`status-chip ${order.status.toLowerCase()}`}>{order.status}</span></td>
                  <td>{order.eta}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </div>

      <section className="panel">
        <div className="section-head"><h3>Ops Audit Log</h3><span className="live-scroll">Live auto-scroll</span></div>
        <ul className="audit-list">
          {logs.length === 0 && <li><span>No ops actions logged yet.</span><span>-</span><span>-</span><span>-</span><span className="audit-status">Idle</span></li>}
          {logs.slice(0, 10).map((entry) => (
            <li key={entry._id || `${entry.action}-${entry.createdAt}`}>
              <span>{entry.action || 'Ops action'}</span>
              <span>{formatTime(entry.createdAt)}</span>
              <span>{entry.entityId || '-'}</span>
              <span>Attempts {Number(entry.details?.attempts || 1)}</span>
              <span className="audit-status">{entry.status || 'Started'}</span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
