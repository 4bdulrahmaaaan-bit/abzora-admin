#!/usr/bin/env node
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

const datasetVersion = process.argv[2] || 'dataset-v2';
const count = Math.max(500, Math.min(100000, Number(process.argv[3] || 5000)));
const root = process.cwd();
const datasetDir = path.join(root, 'backend', 'storage', 'ar-datasets');
const outPath = path.join(datasetDir, `${datasetVersion}.json`);

function row() {
  const shoulderWidth = 0.35 + (Math.random() * 0.35);
  const torsoRatio = 0.85 + (Math.random() * 0.4);
  const hipWaistRatio = 0.8 + (Math.random() * 0.5);
  const poseStability = 0.45 + (Math.random() * 0.5);
  const garmentEaseAllowance = -0.1 + (Math.random() * 0.35);
  const fabricStretch = Math.random();
  const noise = (Math.random() - 0.5) * 0.05;
  const fitConfidence = Math.max(
    0,
    Math.min(
      1,
      0.16
      + 0.24 * shoulderWidth
      + 0.17 * torsoRatio
      + 0.18 * hipWaistRatio
      + 0.23 * poseStability
      + 0.11 * fabricStretch
      - 0.08 * Math.abs(garmentEaseAllowance)
      + noise,
    ),
  );
  return {
    shoulderWidth,
    torsoRatio,
    hipWaistRatio,
    poseStability,
    garmentEaseAllowance,
    fabricStretch,
    fitConfidence,
  };
}

const data = Array.from({ length: count }, row);
await mkdir(datasetDir, { recursive: true });
await writeFile(outPath, JSON.stringify(data));
console.log(`Dataset generated: ${outPath} (${count} rows)`);
