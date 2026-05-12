import { spawn } from 'node:child_process';
import { access } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const backendDir = path.join(root, 'backend');

const backendChecks = [
  'controllers/tryOnController.js',
  'controllers/garmentTemplateController.js',
  'controllers/productController.js',
  'routes/arRoutes.js',
  'validation/schemaValidator.js',
  'validation/schemas/arSchemas.js',
  'models/GarmentTemplate.js',
  'models/GarmentConfig.js',
  'models/FitProfile.js',
];

function run(command, args, cwd = root) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd,
      stdio: 'inherit',
      shell: false,
    });
    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`${command} ${args.join(' ')} failed with code ${code}`));
      }
    });
    child.on('error', reject);
  });
}

async function ensureBackendExists() {
  await access(backendDir);
}

async function main() {
  console.log('[release:backend] verifying backend AR files...');
  await ensureBackendExists();
  for (const file of backendChecks) {
    await run('node', ['--check', file], backendDir);
  }
  console.log('[release:backend] all Node syntax checks passed.');
}

main().catch((error) => {
  console.error('[release:backend] failed:', error.message);
  process.exitCode = 1;
});
