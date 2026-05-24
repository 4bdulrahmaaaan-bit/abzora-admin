#!/usr/bin/env node
import { readFile } from 'node:fs/promises';

const baseUrl = process.env.BACKEND_BASE_URL || 'http://localhost:5000';
const token = process.env.ADMIN_BEARER_TOKEN || '';
const matrixPath = process.argv[2] || 'scripts/device_lab_matrix.json';

if (!token) {
  console.error('Missing ADMIN_BEARER_TOKEN');
  process.exit(1);
}

const payload = JSON.parse(await readFile(matrixPath, 'utf8'));
const response = await fetch(`${baseUrl}/ar/ops/device-lab/runs`, {
  method: 'POST',
  headers: {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    name: `matrix-${new Date().toISOString().replace(/[:.]/g, '-')}`,
    scenario: payload.scenario || 'soak_45m',
    deviceMatrix: Array.isArray(payload.devices) ? payload.devices : [],
  }),
});

if (!response.ok) {
  const body = await response.text();
  console.error(body);
  process.exit(1);
}
const body = await response.json();
console.log(JSON.stringify(body, null, 2));
