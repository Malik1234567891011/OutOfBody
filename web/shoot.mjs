// Screenshot every screen for one or more presets.
// usage: node shoot.mjs [preset ...]   -> shots/<preset>/<nn>_<id>.png
import { chromium } from 'playwright'
import { mkdirSync } from 'fs'

const presets = process.argv.slice(2).length ? process.argv.slice(2) : ['disposable']
const base = 'http://127.0.0.1:5191/'
let browser
try { browser = await chromium.launch() } catch { browser = await chromium.launch({ channel: 'chrome' }) }
const page = await browser.newPage({ viewport: { width: 460, height: 920 }, deviceScaleFactor: 2 })

for (const p of presets) {
  mkdirSync(`shots/${p}`, { recursive: true })
  await page.goto(`${base}?preset=${p}&still`)
  await page.waitForSelector('.devnav select')
  const list = await page.$$eval('.devnav option', (o) => o.map((x) => x.textContent))
  for (const [i, id] of list.entries()) {
    await page.goto(`${base}?preset=${p}&s=${id}&bare&still`)
    await page.waitForSelector('.device')
    await page.waitForTimeout(450)
    await page.locator('.device').screenshot({ path: `shots/${p}/${String(i + 1).padStart(2, '0')}_${id}.png` })
  }
  console.log(p, list.length, 'screens')
}
await browser.close()
