'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import { useLiveEvents } from './useLiveEvents';

const navItems = [
  { href: '/', label: 'Operations', icon: '◉' },
  { href: '/orders', label: 'Orders', icon: '◍' },
  { href: '/vendors', label: 'Vendors', icon: '◈' },
  { href: '/users', label: 'Users', icon: '◐' },
  { href: '/riders', label: 'Riders', icon: '◎' },
  { href: '/products', label: 'Products', icon: '▣' },
  { href: '/analytics', label: 'Analytics', icon: '◔' },
  { href: '/pricing', label: 'Pricing', icon: '◕' },
  { href: '/support', label: 'Support', icon: '◑' },
  { href: '/banners', label: 'Banners', icon: '◍' },
  { href: '/categories', label: 'Categories', icon: '◌' },
  { href: '/templates', label: 'Templates', icon: '◇' },
  { href: '/versions', label: 'Versions', icon: '◒' },
  { href: '/roles', label: 'Roles', icon: '◈' },
] as const;

export function AdminShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [compact, setCompact] = useState(false);
  const [paletteOpen, setPaletteOpen] = useState(false);
  const [healthPulse, setHealthPulse] = useState(94);
  const [q, setQ] = useState('');
  const [token, setToken] = useState('');
  const { connected, events } = useLiveEvents(token, { zoneId: 'global' });

  useEffect(() => {
    const saved = localStorage.getItem('abzoraAdminToken') || '';
    if (saved) setToken(saved);
  }, []);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        setPaletteOpen((v) => !v);
      }
      if (event.key === 'Escape') setPaletteOpen(false);
    };
    window.addEventListener('keydown', onKey);
    const pulse = window.setInterval(() => setHealthPulse((v) => Math.max(82, Math.min(99, v + (Math.random() > 0.5 ? 1 : -1)))), 3500);
    return () => {
      window.removeEventListener('keydown', onKey);
      window.clearInterval(pulse);
    };
  }, []);

  useEffect(() => {
    const latest = events[0];
    if (!latest) return;
    const isRisk = String(latest.eventType || '').toLowerCase().includes('alert');
    if (isRisk) {
      setHealthPulse((v) => Math.max(74, v - 2));
    } else {
      setHealthPulse((v) => Math.min(99, v + 1));
    }
  }, [events]);

  const crumbs = useMemo(() => pathname.split('/').filter(Boolean), [pathname]);
  const paletteItems = navItems.filter((item) => `${item.label} ${item.href}`.toLowerCase().includes(q.toLowerCase()));
  const latestEvent = events[0];

  return (
    <div className={`app-shell ${compact ? 'compact' : ''}`}>
      <aside className="sidebar ops-sidebar">
        <div className="sidebar-top">
          <h1 className="brand">ABZORA</h1>
          <button className="icon-btn" onClick={() => setCompact((v) => !v)}>{compact ? '→' : '←'}</button>
        </div>
        <p className="brand-subtitle">Ops Command Center</p>
        <div className="left-command-stack">
          <input placeholder="Search all ops modules" value={q} onChange={(e) => setQ(e.target.value)} />
          <div className="left-command-actions">
            <button>Run Detection</button>
            <button>Dispatch Queue</button>
            <button>AI Assist</button>
          </div>
          <div className="left-health-grid">
            <span className="live-pill">Health {healthPulse}%</span>
            <span className={`live-pill ${connected ? '' : 'warning'}`}>{connected ? 'Realtime' : 'Fallback'}</span>
            <span className="live-pill">Events {events.length}</span>
          </div>
        </div>
        <nav className="sidebar-nav">
          {navItems.map((item) => (
            <Link key={item.href} href={item.href} className={`sidebar-link ${pathname === item.href ? 'active' : ''}`}>
              <span className="sidebar-icon" aria-hidden>{item.icon}</span>
              <span className="sidebar-label">{item.label}</span>
            </Link>
          ))}
        </nav>
      </aside>

      <main className="content">
        <section className="crumbs panel ops-status-strip">
          <span>Dashboard</span>
          {crumbs.map((c) => <span key={c}>/ {c}</span>)}
          <span className="live-dot-wrap"><span className="live-dot" /> LIVE</span>
          {latestEvent && <span className="live-event-chip">{String(latestEvent.eventType || 'event')}</span>}
          <button className="palette-trigger" onClick={() => setPaletteOpen(true)}>⌘K</button>
        </section>

        {children}
      </main>

      {paletteOpen && (
        <div className="modal-backdrop" onClick={() => setPaletteOpen(false)}>
          <div className="panel command-palette" onClick={(e) => e.stopPropagation()}>
            <h3>Command Palette</h3>
            <input placeholder="Type to jump..." value={q} onChange={(e) => setQ(e.target.value)} autoFocus />
            <div className="palette-list">
              {paletteItems.map((item) => (
                <Link key={item.href} href={item.href} className="palette-item" onClick={() => setPaletteOpen(false)}>
                  <span>{item.icon}</span>
                  <span>{item.label}</span>
                </Link>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
