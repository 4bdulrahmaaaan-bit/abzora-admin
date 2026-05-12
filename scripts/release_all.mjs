import { spawn } from 'node:child_process';
import process from 'node:process';

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
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
  console.log('[release:all] starting full ABZORA AR release checks...');
  const npmCmd = process.platform === 'win32' ? 'npm.cmd' : 'npm';
  await run(npmCmd, ['run', 'release:backend']);
  await run(npmCmd, ['run', 'release:ar-assets']);
  await run(npmCmd, ['run', 'release:admin']);
  console.log('[release:all] all checks passed.');
}

main().catch((error) => {
  console.error('[release:all] failed:', error.message);
  process.exitCode = 1;
});
