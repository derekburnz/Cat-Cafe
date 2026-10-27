const { chromium } = require('playwright');
(async () => {
  const dir = process.argv[2];
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
  await page.goto('file://' + dir + '/atlas.html');
  await page.screenshot({ path: dir + '/UI_IconSheet.png', omitBackground: true, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  // a preview on a mid background to judge the outlines
  await page.evaluate(() => { document.body.style.background = '#7a8a99'; });
  await page.screenshot({ path: dir + '/preview.png', clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  await browser.close();
})();
