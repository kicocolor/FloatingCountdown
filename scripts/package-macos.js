const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const packager = require('electron-packager');

const projectRoot = path.resolve(__dirname, '..');
const releaseDir = path.join(projectRoot, 'release');
const appName = 'FloatingCountdown';
const electronVersion = require('electron/package.json').version;
const requestedArchs = new Set(process.argv.slice(2).map((arg) => arg.replace(/^--/, '')));
const supportedArchs = ['x64', 'arm64'];
const archs = requestedArchs.size > 0
  ? supportedArchs.filter((arch) => requestedArchs.has(arch))
  : supportedArchs;
const appFiles = [
  'main.js',
  'preload.js',
  'index.html',
  'styles.css',
  'renderer.js',
  'mini.html',
  'mini.css',
  'mini.js'
];

function createPackagingSource() {
  const sourceDir = fs.mkdtempSync(path.join(os.tmpdir(), 'floating-countdown-mac-'));
  const originalPackage = JSON.parse(fs.readFileSync(path.join(projectRoot, 'package.json'), 'utf8'));
  const packageForMac = {
    name: originalPackage.name,
    version: originalPackage.version,
    description: originalPackage.description,
    main: originalPackage.main,
    author: 'Floating Countdown',
    license: originalPackage.license
  };

  for (const file of appFiles) {
    fs.copyFileSync(path.join(projectRoot, file), path.join(sourceDir, file));
  }

  fs.writeFileSync(path.join(sourceDir, 'package.json'), `${JSON.stringify(packageForMac, null, 2)}\n`);
  return sourceDir;
}

function zipApp(appPath, zipPath) {
  fs.rmSync(zipPath, { force: true });
  execFileSync('ditto', ['-c', '-k', '--sequesterRsrc', '--keepParent', appPath, zipPath], {
    stdio: 'inherit'
  });
}

async function packageArch(arch, sourceDir) {
  const outputDir = path.join(releaseDir, `${appName}-darwin-${arch}`);
  const appPath = path.join(outputDir, `${appName}.app`);
  const zipPath = path.join(releaseDir, `${appName}-darwin-${arch}.zip`);

  fs.rmSync(outputDir, { recursive: true, force: true });
  fs.mkdirSync(releaseDir, { recursive: true });

  console.log(`Packaging macOS ${arch}...`);

  await packager({
    dir: sourceDir,
    name: appName,
    executableName: appName,
    platform: 'darwin',
    arch,
    out: releaseDir,
    overwrite: true,
    prune: true,
    asar: true,
    electronVersion,
    quiet: false
  });

  zipApp(appPath, zipPath);
  console.log(`Created ${path.relative(projectRoot, zipPath)}`);
}

async function main() {
  if (archs.length === 0) {
    throw new Error('No valid architecture selected. Use --x64, --arm64, or no flag for both.');
  }

  const sourceDir = createPackagingSource();

  try {
    for (const arch of archs) {
      await packageArch(arch, sourceDir);
    }
  } finally {
    fs.rmSync(sourceDir, { recursive: true, force: true });
  }

  console.log('macOS app packages are ready.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
