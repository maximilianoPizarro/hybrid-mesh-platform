#!/usr/bin/env node
/**
 * Batch-capture workshop hero PNGs from live hub cluster UI.
 * Reads scripts/workshop-screenshot-manifest.yaml and uses Playwright.
 *
 * Usage:
 *   KUBECONFIG=/tmp/hub-kubeconfig node scripts/capture-workshop-screenshots.mjs
 *   node scripts/capture-workshop-screenshots.mjs --only 20-acs-kuadrant.png
 */
import { chromium } from 'playwright';
import { readFileSync, mkdirSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const MANIFEST = join(__dirname, 'workshop-screenshot-manifest.yaml');

function parseManifest(text) {
  const hubMatch = text.match(/^hub_domain:\s*(.+)$/m);
  const hubDomain = hubMatch?.[1]?.trim() ?? '';
  const vpMatch = text.match(/width:\s*(\d+)[\s\S]*?height:\s*(\d+)/);
  const viewport = {
    width: parseInt(vpMatch?.[1] ?? '1440', 10),
    height: parseInt(vpMatch?.[2] ?? '900', 10),
  };

  const shots = [];
  const blocks = text.split(/\n  - filename:/).slice(1);
  for (const block of blocks) {
    const filename = block.match(/^ (.+\.png)/)?.[1]?.trim();
    const dest = block.match(/dest:\s*(.+)/)?.[1]?.trim();
    const url = block.match(/url:\s*"(.+?)"/)?.[1]?.trim();
    const waitFor = block.match(/wait_for:\s*"(.+?)"/)?.[1]?.trim();
    const preserve = /preserve:\s*true/.test(block);
    if (filename && dest && url) {
      shots.push({ filename, dest, url, waitFor, preserve });
    }
  }
  return { hubDomain, viewport, shots };
}

function expandUrl(url, hubDomain) {
  return url.replaceAll('{hub_domain}', hubDomain);
}

function getToken() {
  try {
    return execSync('oc whoami -t', { encoding: 'utf8' }).trim();
  } catch {
    throw new Error('oc whoami -t failed — set KUBECONFIG to hub');
  }
}

async function authConsole(page, hubDomain, token) {
  const authUrl = `https://console-openshift-console.${hubDomain}/?access_token=${encodeURIComponent(token)}`;
  await page.goto(authUrl, { waitUntil: 'domcontentloaded', timeout: 120000 });
  await page.waitForTimeout(3000);
}

async function captureOne(page, shot, hubDomain, viewport) {
  const url = expandUrl(shot.url, hubDomain);
  console.log(`  → ${shot.filename}: ${url}`);
  await page.setViewportSize(viewport);
  try {
    await page.goto(url, { waitUntil: 'networkidle', timeout: 90000 });
  } catch {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 90000 });
  }
  if (shot.waitFor) {
    try {
      await page.getByText(shot.waitFor, { exact: false }).first().waitFor({ timeout: 15000 });
    } catch {
      await page.waitForTimeout(4000);
    }
  } else {
    await page.waitForTimeout(3000);
  }
  const outPath = join(ROOT, shot.dest);
  mkdirSync(dirname(outPath), { recursive: true });
  await page.screenshot({ path: outPath, fullPage: false });
  console.log(`    saved ${shot.dest}`);
}

async function main() {
  const only = process.argv.includes('--only')
    ? process.argv[process.argv.indexOf('--only') + 1]
    : null;

  const manifest = parseManifest(readFileSync(MANIFEST, 'utf8'));
  const token = getToken();
  let shots = manifest.shots;
  if (only) {
    shots = shots.filter((s) => s.filename === only || s.filename.includes(only));
    if (!shots.length) {
      console.error(`No match for --only ${only}`);
      process.exit(1);
    }
  }

  console.log(`Hub: ${manifest.hubDomain}, ${shots.length} screenshots`);
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: manifest.viewport,
    ignoreHTTPSErrors: true,
  });
  const page = await context.newPage();

  await authConsole(page, manifest.hubDomain, token);
  console.log('Console auth OK');

  for (const shot of shots) {
    if (shot.preserve) {
      console.log(`  skip (preserve) ${shot.filename}`);
      continue;
    }
    try {
      await captureOne(page, shot, manifest.hubDomain, manifest.viewport);
    } catch (err) {
      console.error(`    FAIL ${shot.filename}: ${err.message}`);
    }
  }

  await browser.close();
  console.log('Done.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
