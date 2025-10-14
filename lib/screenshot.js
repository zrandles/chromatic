#!/usr/bin/env node

/**
 * Screenshot utility for UX analysis
 * Usage: node lib/screenshot.js <url> <output_path> [viewport_width] [viewport_height]
 */

const puppeteer = require('puppeteer');

async function takeScreenshot() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.error('Usage: node lib/screenshot.js <url> <output_path> [viewport_width] [viewport_height]');
    console.error('Example: node lib/screenshot.js http://localhost:3000/chromatic /tmp/chromatic.png 1280 800');
    process.exit(1);
  }

  const url = args[0];
  const outputPath = args[1];
  const viewportWidth = parseInt(args[2] || '1280');
  const viewportHeight = parseInt(args[3] || '800');

  console.log(`Taking screenshot of ${url}...`);
  console.log(`Viewport: ${viewportWidth}x${viewportHeight}`);
  console.log(`Output: ${outputPath}`);

  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: viewportWidth, height: viewportHeight });

  try {
    await page.goto(url, { waitUntil: 'networkidle0', timeout: 10000 });
    await page.screenshot({ path: outputPath, fullPage: true });
    console.log(`✅ Screenshot saved to ${outputPath}`);
  } catch (error) {
    console.error(`❌ Error taking screenshot: ${error.message}`);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

takeScreenshot();
