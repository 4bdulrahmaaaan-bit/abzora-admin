'use client';

import { useEffect, useMemo, useState } from 'react';
import dynamic from 'next/dynamic';
import { listTemplates, upsertTemplate } from '../../lib/api';
import { GarmentTemplate } from '../../lib/types';

const TemplatePreview = dynamic(
  () => import('../../components/TemplatePreview').then((mod) => mod.TemplatePreview),
  { ssr: false },
);

export default function TemplatesPage() {
  const [templates, setTemplates] = useState<GarmentTemplate[]>([]);
  const [token, setToken] = useState('');
  const [status, setStatus] = useState('');
  const [form, setForm] = useState({
    slug: '',
    name: '',
    category: 'shirt',
    lod0: '',
    lod1: '',
    lod2: '',
    rigProfile: 'unisex_torso_v1',
    colorHex: '#C6A769',
  });

  useEffect(() => {
    listTemplates()
      .then(setTemplates)
      .catch((error: Error) => setStatus(error.message));
  }, []);

  const sortedTemplates = useMemo(
    () => [...templates].sort((a, b) => a.slug.localeCompare(b.slug)),
    [templates],
  );

  async function saveTemplate() {
    try {
      setStatus('Saving template...');
      const saved = await upsertTemplate(token, {
        slug: form.slug,
        name: form.name,
        category: form.category,
        rigProfile: form.rigProfile,
        defaultColorHex: form.colorHex,
        modelUrls: { lod0: form.lod0, lod1: form.lod1, lod2: form.lod2 },
      });
      setTemplates((current) => {
        const existing = current.find((item) => item.id === saved.id);
        if (!existing) {
          return [...current, saved];
        }
        return current.map((item) => (item.id === saved.id ? saved : item));
      });
      setStatus('Template saved');
    } catch (error) {
      setStatus((error as Error).message);
    }
  }

  return (
    <>
      <h2>Template Management</h2>
      <p>Upload and configure reusable AR garment templates with version-safe config.</p>
      <div className="grid two">
        <div className="panel">
          <h3>Create / Edit Template</h3>
          <div className="grid">
            <input
              placeholder="Admin JWT token"
              value={token}
              onChange={(event) => setToken(event.target.value)}
            />
            <input
              placeholder="slug"
              value={form.slug}
              onChange={(event) => setForm((prev) => ({ ...prev, slug: event.target.value }))}
            />
            <input
              placeholder="name"
              value={form.name}
              onChange={(event) => setForm((prev) => ({ ...prev, name: event.target.value }))}
            />
            <select
              value={form.category}
              onChange={(event) => setForm((prev) => ({ ...prev, category: event.target.value }))}
            >
              <option value="shirt">shirt</option>
              <option value="t-shirt">t-shirt</option>
              <option value="kurta">kurta</option>
              <option value="jacket">jacket</option>
              <option value="pants">pants</option>
            </select>
            <input
              placeholder="lod0 model URL"
              value={form.lod0}
              onChange={(event) => setForm((prev) => ({ ...prev, lod0: event.target.value }))}
            />
            <input
              placeholder="lod1 model URL"
              value={form.lod1}
              onChange={(event) => setForm((prev) => ({ ...prev, lod1: event.target.value }))}
            />
            <input
              placeholder="lod2 model URL"
              value={form.lod2}
              onChange={(event) => setForm((prev) => ({ ...prev, lod2: event.target.value }))}
            />
            <input
              placeholder="rig profile"
              value={form.rigProfile}
              onChange={(event) => setForm((prev) => ({ ...prev, rigProfile: event.target.value }))}
            />
            <input
              placeholder="#C6A769"
              value={form.colorHex}
              onChange={(event) => setForm((prev) => ({ ...prev, colorHex: event.target.value }))}
            />
            <button className="primary" onClick={saveTemplate}>
              Save Template
            </button>
            <small>{status}</small>
          </div>
        </div>
        <TemplatePreview />
      </div>
      <div className="panel">
        <h3>Template Registry</h3>
        <table className="table">
          <thead>
            <tr>
              <th>Slug</th>
              <th>Category</th>
              <th>Rig</th>
              <th>LOD0</th>
              <th>Updated</th>
            </tr>
          </thead>
          <tbody>
            {sortedTemplates.map((template) => (
              <tr key={template.id}>
                <td>{template.slug}</td>
                <td>{template.category}</td>
                <td>{template.rigProfile || '-'}</td>
                <td>{template.modelUrls?.lod0 || '-'}</td>
                <td>{template.updatedAt || '-'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
