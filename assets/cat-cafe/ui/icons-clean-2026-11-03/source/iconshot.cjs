const { chromium } = require('playwright');
(async () => {
  const [file, outDir, only] = process.argv.slice(2); // only: comma list of names to render (default all)
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 256, height: 256 } });
  await page.goto('file://' + file);
  await page.evaluate(() => document.fonts.ready);
  const list = [['cats'], ['index'], ['quests'], ['upgrades'], ['decor'], ['store'], ['tutorial'], ['rewards'], ['feedback'], ['menu'], ['home'], ['cannon'], ['areas'], ['potion', '#ffd84a'], ['bowl'], ['coin'], ['fish'], ['bag'], ['crate'], ['trade'], ['caviar'], ['kibble'], ['tuna'], ['salmon'], ['sardines'], ['moonMilk'], ['starTreat'], ['spin'], ['potionTip'], ['potionLucky'], ['potionSwift'], ['potionSteady'], ['potionBigTip'], ['potionGoldRush'], ['potionQuickBait']];
  for (const [n, arg] of list) {
    if (only && !only.split(',').includes(n)) continue;
    await page.evaluate(([n, arg]) => window.show(n, arg), [n, arg]);
    await page.waitForTimeout(50);
    const el = await page.$('#i svg');
    await el.screenshot({ path: `${outDir}/Icon_Clean_${n[0].toUpperCase() + n.slice(1)}.png`, omitBackground: true });
  }
  await browser.close();
})();
