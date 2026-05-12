import { spawn } from 'node:child_process';
import { access } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const adminDir = path.join(root, 'admin-next');

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

async function main() {
  console.log('[release:admin] checking admin-next workspace...');
  await access(path.join(adminDir, 'package.json'));
  await access(path.join(adminDir, '.env.example'));

  console.log('[release:admin] running Next.js build...');
  const npmCmd = process.platform === 'win32' ? 'npm.cmd' : 'npm';
  await run(npmCmd, ['run', 'build'], adminDir);
  console.log('[release:admin] build passed.');
}

main().catch((error) => {
  console.error('[release:admin] failed:', error.message);
  process.exitCode = 1;
});
