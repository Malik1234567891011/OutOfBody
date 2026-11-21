// Screenshot the post-paywall app: every scenario × tab (top + scrolled), then every overlay.
// usage: node shoot-app.mjs [preset]   -> shots/app/NN_<name>.png
import { chromium } from 'playwright'
import { mkdirSync, rmSync } from 'fs'

const preset = process.argv[2] ?? 'disposable'
const base = 'http://127.0.0.1:5191/'
const out = 'shots/app'
rmSync(out, { recursive: true, force: true })
mkdirSync(out, { recursive: true })
const browser = await chromium.launch({ channel: 'chrome' })
const page = await browser.newPage({ viewport: { width: 460, height: 920 }, deviceScaleFactor: 2 })
const errors = []
page.on('pageerror', (e) => errors.push(e.message))
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()))

let n = 0
async function shot(name, qs, scrolls = [0]) {
  await page.goto(`${base}?app=1&preset=${preset}&bare&still&${qs}`)
  await page.waitForSelector('.device .app')
  await page.waitForTimeout(500)
  for (const y of scrolls) {
    if (y) {
      const more = await page.$eval('.app-scroll', (el, y) => { const max = el.scrollHeight - el.clientHeight; el.scrollTo(0, y === 'end' ? max : Math.min(max, y)); return max > 4 }, y)
      if (!more) continue
      await page.waitForTimeout(150)
    }
    n++
    const file = `${out}/${String(n).padStart(2, '0')}_${name}${y ? (y === 'end' ? '_end' : '_more') : ''}.png`
    await page.locator('.device').screenshot({ path: file })
  }
}

const scenarios = ['day1', 'midweek', 'near', 'over', 'stepdown', 'adaptive', 'free', 'quitday']
for (const sc of scenarios) {
  for (const tab of ['today', 'plan', 'you']) {
    // screen=none keeps auto overlays (review, quit day) out of the tab shots; they get their own shots below
    await shot(`${sc}-${tab}`, `scenario=${sc}&tab=${tab}&screen=none`, tab === 'you' && sc !== 'day1' ? [0] : [0, 560, 'end'])
  }
}
for (const sc of ['you']) await shot(`midweek-you`, `scenario=midweek&tab=${sc}&screen=none`, [0, 560, 1100, 'end'])

const overlays = ['welcome1', 'welcome2', 'welcome3', 'welcome4', 'welcome5', 'sos1', 'sos2', 'sos3', 'sos4', 'reasons', 'vapeanyway', 'review', 'quitday', 'widgetguide', 'checkin-morning', 'checkin-evening']
for (const o of overlays) await shot(o, `screen=${o}`)
await shot('review-rough', 'scenario=rough&screen=review')

console.log(n, 'shots in', out)
console.log(errors.length ? 'ERRORS:\n' + [...new Set(errors)].join('\n') : 'no console errors')
await browser.close()
