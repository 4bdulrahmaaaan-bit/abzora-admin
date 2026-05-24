#!/usr/bin/env node

/**
 * Enterprise AR operations launcher:
 * 1) create fit model run
 * 2) run garment certification pipeline
 * 3) start device-lab soak run
 */

const baseUrl = process.env.BACKEND_BASE_URL || 'http://localhost:5000';
const token = process.env.ADMIN_BEARER_TOKEN || '';

if (!token) {
  console.error('Missing ADMIN_BEARER_TOKEN');
  process.exit(1);
}

const headers = {
  Authorization: `Bearer ${token}`,
  'Content-Type': 'application/json',
};

async function post(path, body) {
  const response = await fetch(`${baseUrl}${path}`, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`${path} failed: ${response.status} ${text}`);
  }
  return response.json();
}

async function main() {
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');

  const fit = await post('/ar/ops/fit/runs', {
    name: `fit-train-${stamp}`,
    datasetVersion: process.env.AR_DATASET_VERSION || 'dataset-v2',
    trainingConfig: {
      modelType: 'gradient_boosted_tree',
      folds: 5,
      loss: 'mae',
      objective: 'fit_confidence',
    },
  });

  const garment = await post('/ar/ops/garment/jobs', {
    mode: process.env.AR_GARMENT_JOB_MODE || 'incremental',
  });

  const soak = await post('/ar/ops/device-lab/runs', {
    name: `soak-${stamp}`,
    scenario: process.env.AR_SOAK_SCENARIO || 'soak_45m',
    deviceMatrix: [
      { model: 'Pixel 7', tier: 'FLAGSHIP', targetFps: 55, thermalLoad: 0.52, sessionMinutes: 45 },
      { model: 'Galaxy A34', tier: 'MID', targetFps: 36, thermalLoad: 0.68, sessionMinutes: 45 },
      { model: 'iPhone 15 Pro', tier: 'PREMIUM_LIDAR', targetFps: 60, thermalLoad: 0.47, sessionMinutes: 45 },
      { model: 'Redmi Note 12', tier: 'LOW', targetFps: 30, thermalLoad: 0.74, sessionMinutes: 30 },
    ],
  });

  console.log(JSON.stringify({
    success: true,
    fitRunId: fit?.data?._id || '',
    garmentJobId: garment?.data?._id || '',
    deviceLabRunId: soak?.data?._id || '',
  }, null, 2));
}

main().catch((error) => {
  console.error(error.message || String(error));
  process.exit(1);
});
