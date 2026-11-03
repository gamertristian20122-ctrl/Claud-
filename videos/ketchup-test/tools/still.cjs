// Screenshot a still HTML page at 1080x1920: node tools/still.mjs stills/shot1.html out.png
const { chromium } = require('playwright');
const path = require('node:path');
(async () => {
const [, , src, out] = process.argv;
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
await page.goto('file://' + path.resolve(src));
await page.evaluate(() => document.fonts.ready);
await page.waitForTimeout(300);
await page.screenshot({ path: out });
await browser.close();
})();
