'use client';

import { useEffect, useMemo, useState } from 'react';
import { adminProductAction, getAdminProducts } from '../../lib/api';

type Product = {
  id: string;
  name: string;
  category: string;
  brand: string;
  stock: number;
  conversion: number;
  returns: number;
  velocity: number;
  moderation: number;
  visibility: number;
  vendor: string;
  status: 'Synced' | 'Syncing';
};

const stockBand = (stock: number) => (stock < 20 ? 'low' : stock < 60 ? 'mid' : 'high');

export default function ProductsPage() {
  const [token, setToken] = useState('');
  const [view, setView] = useState<'table' | 'grid'>('grid');
  const [q, setQ] = useState('');
  const [toast, setToast] = useState('');
  const [status, setStatus] = useState('Connect admin token for live products.');
  const [rows, setRows] = useState<Product[]>([]);
  const [selected, setSelected] = useState<string[]>([]);
  const [draftLaunchDate, setDraftLaunchDate] = useState('');
  const [drawer, setDrawer] = useState<Product | null>(null);
  const [filters, setFilters] = useState({
    category: 'all',
    brand: 'all',
    moderation: 'all',
    visibility: 'all',
    stock: 'all',
    conversion: 'all',
    returns: 'all',
    velocity: 'all',
    verified: 'all',
  });

  useEffect(() => {
    const saved = localStorage.getItem('abzoraAdminToken') || '';
    if (saved) setToken(saved);
  }, []);

  function mapProduct(raw: Record<string, unknown>): Product {
    const id = String(raw._id || raw.id || raw.productId || '').trim();
    const stock = Number(raw.stock ?? raw.quantity ?? 0);
    const conversion = Number(raw.conversionRate ?? raw.conversion ?? 0);
    const returns = Number(raw.returnRate ?? raw.returns ?? 0);
    const velocity = Number(raw.salesVelocity ?? raw.velocity ?? 0);
    const moderation = Number(raw.aiModerationScore ?? raw.moderation ?? 72);
    const visibility = Number(raw.visibilityScore ?? raw.visibility ?? 75);
    const vendor = String(raw.vendorBadge || raw.vendorTier || (raw.isPremiumVendor ? 'Premium Verified' : 'Standard'));
    const status: Product['status'] = String(raw.inventorySyncStatus || raw.syncStatus || 'Synced') === 'Syncing' ? 'Syncing' : 'Synced';
    return {
      id: id || 'UNMAPPED',
      name: String(raw.name || raw.title || 'Luxury Product'),
      category: String(raw.category || 'Uncategorized'),
      brand: String(raw.brand || 'ABZORA'),
      stock,
      conversion,
      returns,
      velocity,
      moderation,
      visibility,
      vendor,
      status,
    };
  }

  async function loadProducts(activeToken: string) {
    if (!activeToken.trim()) {
      setRows([]);
      return;
    }
    try {
      const backendRows = await getAdminProducts(activeToken);
      setRows(Array.isArray(backendRows) ? backendRows.map((r) => mapProduct(r)) : []);
      setStatus(`Catalog synced at ${new Date().toLocaleTimeString()}`);
    } catch (error) {
      setRows([]);
      setStatus((error as Error).message);
    }
  }

  useEffect(() => {
    if (!token.trim()) return;
    localStorage.setItem('abzoraAdminToken', token);
    loadProducts(token);
  }, [token]);

  const brands = useMemo(() => Array.from(new Set(rows.map((p) => p.brand))), [rows]);
  const categories = useMemo(() => Array.from(new Set(rows.map((p) => p.category))), [rows]);

  const products = useMemo(() => {
    return rows.filter((p) => {
      const s = `${p.name} ${p.brand} ${p.category} ${p.id}`.toLowerCase();
      if (q && !s.includes(q.toLowerCase())) return false;
      if (filters.category !== 'all' && p.category !== filters.category) return false;
      if (filters.brand !== 'all' && p.brand !== filters.brand) return false;
      if (filters.verified === 'verified' && p.vendor !== 'Premium Verified') return false;
      if (filters.stock !== 'all' && stockBand(p.stock) !== filters.stock) return false;
      if (filters.moderation === 'high' && p.moderation < 80) return false;
      if (filters.visibility === 'high' && p.visibility < 80) return false;
      if (filters.conversion === 'high' && p.conversion < 4.2) return false;
      if (filters.returns === 'high' && p.returns < 2.0) return false;
      if (filters.velocity === 'high' && p.velocity < 55) return false;
      return true;
    });
  }, [filters, q, rows]);

  function action(msg: string) {
    setToast(msg);
    setTimeout(() => setToast(''), 1800);
  }

  async function runProductAction(productId: string, actionKey: string, payload: Record<string, unknown> = {}, successText?: string) {
    try {
      if (token.trim()) {
        await adminProductAction(token, productId, actionKey, payload);
        await loadProducts(token);
      }
      action(successText || `${productId} updated`);
    } catch (error) {
      setStatus((error as Error).message);
    }
  }

  function toggleSelected(id: string) {
    setSelected((cur) => (cur.includes(id) ? cur.filter((x) => x !== id) : [...cur, id]));
  }

  return (
    <div className="ops-root">
      <section className="panel section-toolbar">
        <div className="search-row">
          <input placeholder="Search product, brand, category, ID" value={q} onChange={(e) => setQ(e.target.value)} />
          <input placeholder="Admin JWT token" value={token} onChange={(e) => setToken(e.target.value)} />
          <div className="toolbar-actions">
            <button onClick={() => setView('table')}>Table</button>
            <button onClick={() => setView('grid')}>Grid</button>
            <button onClick={() => action(`Bulk set visibility on ${selected.length} products`)}>Bulk Actions</button>
            <button onClick={() => Promise.all(selected.map((id) => runProductAction(id, 'ai_optimize'))).then(() => action('AI optimization queue started'))}>AI Optimize Listing</button>
          </div>
        </div>
        <small>{status}</small>

        <div className="order-filters sticky-filters users-filters">
          <select value={filters.category} onChange={(e) => setFilters((p) => ({ ...p, category: e.target.value }))}><option value="all">Category</option>{categories.map((c) => <option key={c}>{c}</option>)}</select>
          <select value={filters.brand} onChange={(e) => setFilters((p) => ({ ...p, brand: e.target.value }))}><option value="all">Brand</option>{brands.map((b) => <option key={b}>{b}</option>)}</select>
          <select value={filters.moderation} onChange={(e) => setFilters((p) => ({ ...p, moderation: e.target.value }))}><option value="all">AI Moderation</option><option value="high">High Score</option></select>
          <select value={filters.visibility} onChange={(e) => setFilters((p) => ({ ...p, visibility: e.target.value }))}><option value="all">Visibility</option><option value="high">High</option></select>
          <select value={filters.stock} onChange={(e) => setFilters((p) => ({ ...p, stock: e.target.value }))}><option value="all">Stock Level</option><option value="low">Low</option><option value="mid">Mid</option><option value="high">High</option></select>
          <select value={filters.conversion} onChange={(e) => setFilters((p) => ({ ...p, conversion: e.target.value }))}><option value="all">Conversion Rate</option><option value="high">High</option></select>
          <select value={filters.returns} onChange={(e) => setFilters((p) => ({ ...p, returns: e.target.value }))}><option value="all">Returns %</option><option value="high">High Return</option></select>
          <select value={filters.velocity} onChange={(e) => setFilters((p) => ({ ...p, velocity: e.target.value }))}><option value="all">Sales Velocity</option><option value="high">High</option></select>
          <select value={filters.verified} onChange={(e) => setFilters((p) => ({ ...p, verified: e.target.value }))}><option value="all">Vendor</option><option value="verified">Premium Verified</option></select>
        </div>
      </section>

      <section className="kpi-grid">
        <article className="panel kpi-card"><span>Total Products</span><p className="kpi-value">{products.length}</p><p className="kpi-trend">Live catalog rows</p></article>
        <article className="panel kpi-card warning"><span>Low Stock</span><p className="kpi-value">{products.filter((p) => p.stock < 20).length}</p><p className="kpi-trend">Operational alerts</p></article>
        <article className="panel kpi-card"><span>Avg Moderation</span><p className="kpi-value">{products.length ? Math.round(products.reduce((s, p) => s + p.moderation, 0) / products.length) : 0}</p><p className="kpi-trend">Backend computed</p></article>
        <article className="panel kpi-card"><span>Avg Visibility</span><p className="kpi-value">{products.length ? Math.round(products.reduce((s, p) => s + p.visibility, 0) / products.length) : 0}</p><p className="kpi-trend">Backend computed</p></article>
        <article className="panel kpi-card warning"><span>High Returns</span><p className="kpi-value">{products.filter((p) => p.returns > 2).length}</p><p className="kpi-trend">Risk SKUs</p></article>
        <article className="panel kpi-card"><span>Sync State</span><p className="kpi-value">{products.filter((p) => p.status === 'Synced').length}</p><p className="kpi-trend">Synced rows</p></article>
      </section>

      <section className={`product-workspace ${view}`}>
        {products.length === 0 && (
          <article className="panel empty-premium">
            <h3>Start building the Abzora catalog</h3>
            <p>Activate premium products with AI-assisted merchandising controls.</p>
            <button className="primary">Create Product</button>
          </article>
        )}

        {products.map((p) => (
          <article key={p.id} className="panel product-card-premium">
            <div className="section-head">
              <h3>{p.name}</h3>
              <div className="chip-row">
                <label><input type="checkbox" checked={selected.includes(p.id)} onChange={() => toggleSelected(p.id)} /> Select</label>
                <span className="status-chip processing">{p.status}</span>
              </div>
            </div>
            <p>{p.brand} · {p.category}</p>
            <div className="vendor-preview">Vendor badge: {p.vendor}</div>
            <div className="product-metrics-grid">
              <p>Stock {p.stock}</p>
              <p>Conversion {p.conversion.toFixed(1)}%</p>
              <p>Returns {p.returns.toFixed(1)}%</p>
              <p>Velocity {p.velocity.toFixed(0)}/wk</p>
              <p>Moderation {p.moderation}</p>
              <p>Visibility {p.visibility}</p>
            </div>
            <div className="incident-actions">
              <button className="primary" onClick={() => setDrawer(p)}>Quick Edit</button>
              <button onClick={() => runProductAction(p.id, 'duplicate', {}, `${p.id} duplicated`)}>Duplicate</button>
              <button onClick={() => runProductAction(p.id, 'ai_optimize', {}, `${p.id} AI optimized`)}>AI Optimize</button>
              <button onClick={() => runProductAction(p.id, 'pin_featured', {}, `${p.id} pinned as featured`)}>Pin Featured</button>
              <button onClick={() => runProductAction(p.id, 'toggle_visibility', {}, `${p.id} visibility toggled`)}>Hide/Show</button>
            </div>
          </article>
        ))}
      </section>

      {drawer && (
        <aside className="slide-drawer">
          <div className="section-head"><h3>Quick Edit Drawer</h3><button onClick={() => setDrawer(null)}>Close</button></div>
          <div className="drawer-grid">
            <div className="panel"><h4>{drawer.name}</h4><p>{drawer.id}</p></div>
            <div className="panel"><label>Schedule Launch</label><input type="datetime-local" value={draftLaunchDate} onChange={(e) => setDraftLaunchDate(e.target.value)} /></div>
            <div className="panel"><label>Moderation Override</label><input defaultValue={drawer.moderation} /></div>
            <div className="panel"><label>Visibility Override</label><input defaultValue={drawer.visibility} /></div>
            <div className="panel">
              <button
                className="primary"
                onClick={() => runProductAction(drawer.id, 'quick_edit', { moderation: drawer.moderation, visibility: drawer.visibility }, `${drawer.id} updated`)}
              >
                Save Product Controls
              </button>
              <button
                onClick={() => runProductAction(drawer.id, 'schedule_launch', { launchAt: draftLaunchDate || new Date().toISOString() }, `${drawer.id} launch scheduled`)}
              >
                Schedule Launch
              </button>
            </div>
          </div>
        </aside>
      )}

      {toast && <div className="toast-live">{toast}</div>}
    </div>
  );
}

