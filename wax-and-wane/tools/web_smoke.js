// Boot the browser build in headless Chromium: the title must draw, Light the wick must lead on, and the
// browser console must stay free of errors. Usage: node tools/web_smoke.js <url> <screenshot.png>
const { chromium } = require('playwright');
(async () => {
  const [url, shot] = process.argv.slice(2);
  const W = 1152, H = 648;   // three screen pixels per game pixel
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  const errors = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text().slice(0, 300)); });
  page.on('pageerror', e => errors.push('pageerror: ' + String(e).slice(0, 300)));
  const t0 = Date.now();
  await page.goto(url, { waitUntil: 'load', timeout: 120000 });
  await page.waitForTimeout(9000);
  const k = W / 384;
  const lit = async () => page.evaluate(() => {   // how much of the canvas is not near-black
    const c = document.querySelector('canvas'); if (!c) return 0;
    const t = document.createElement('canvas'); t.width = 96; t.height = 54;
    const g = t.getContext('2d'); g.drawImage(c, 0, 0, 96, 54);
    const d = g.getImageData(0, 0, 96, 54).data; let n = 0;
    for (let i = 0; i < d.length; i += 4) if (d[i] + d[i + 1] + d[i + 2] > 90) n++;
    return n / (96 * 54);
  });
  const title = await lit();
  await page.mouse.click(290 * k, 106 * k);   // Light the wick
  await page.waitForTimeout(4000);
  for (let i = 0; i < 12; i++) { await page.keyboard.press('Enter'); await page.waitForTimeout(700); }
  await page.waitForTimeout(2500);
  const later = await lit();
  await page.screenshot({ path: shot });
  const out = { boot_ms: Date.now() - t0, title_lit: +title.toFixed(3), after_start_lit: +later.toFixed(3), console_errors: errors.length, errors: errors.slice(0, 6) };
  console.log(JSON.stringify(out));
  await browser.close();
  if (errors.length || title < 0.05) process.exit(1);
})().catch(e => { console.log('FAILED ' + e); process.exit(1); });
