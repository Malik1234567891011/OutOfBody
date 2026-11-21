// Click through the whole flow like a user, for each device type.
// Fails loudly if a screen can't be advanced. Prints the screen path.
import { chromium } from 'playwright'

const base = 'http://127.0.0.1:5191/'
const browser = await chromium.launch({ channel: 'chrome' })
const page = await browser.newPage({ viewport: { width: 460, height: 920 } })
const errors = []
page.on('pageerror', (e) => errors.push(e.message))
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()))

const curId = () => page.$eval('.devnav span', (e) => e.textContent.split('· ')[1])

async function run(deviceLabel, tried) {
  await page.goto(base)
  const path = []
  for (let guard = 0; guard < 60; guard++) {
    const id = await curId()
    path.push(id)
    const d = page.locator('.device')
    const click = async (sel, i = 0) => { await d.locator(sel).nth(i).click(); await page.waitForTimeout(380) }
    if (id === 'pw3') { await click('.cta'); break }
    if (id === 'device') { await d.getByText(deviceLabel, { exact: true }).click(); await page.waitForTimeout(380); continue }
    if (id === 'tried') { await d.getByText(tried, { exact: true }).click(); await page.waitForTimeout(380); continue }
    if (id === 'disposable' || id === 'pouches') { await click('.seg-b', 1); await click('.opt', 2); await click('.cta'); continue }
    if (id === 'about') { await d.locator('.field').fill('Malik'); await click('.seg-b', 0); await click('.cta'); continue }
    if (id === 'analyzing') { await page.waitForTimeout(5500); continue }
    if (id === 'sos') { await d.locator('.sos-orb').click({ force: true }); await page.waitForTimeout(13000); await click('.cta'); continue }
    if (id === 'notify') { await click('.cta'); await d.getByText('Allow', { exact: true }).click(); await page.waitForTimeout(380); continue }
    if (id === 'commit') {
      const box = await d.locator('canvas').boundingBox()
      await page.mouse.move(box.x + 30, box.y + 100); await page.mouse.down()
      await page.mouse.move(box.x + 120, box.y + 40, { steps: 8 }); await page.mouse.move(box.x + 220, box.y + 120, { steps: 8 }); await page.mouse.up()
      await click('.cta'); continue
    }
    // multi-select screens: pick two then continue
    const multi = await d.locator('.opt-mark.square').count()
    if (multi) { await click('.opt', 0); await click('.opt', 2); await click('.cta'); continue }
    // single-select: tap 2nd option (auto-advances)
    if (await d.locator('.opt').count()) { await click('.opt', 1); continue }
    await click('.cta')
  }
  const end = await page.locator('.device').innerText()
  console.log(`${deviceLabel} / ${tried}: ${path.length} screens -> ${end.includes('Welcome in') ? 'REACHED END' : 'STUCK'}\n  ${path.join(' > ')}`)
}

for (const [d, t] of [['Disposable vape', '2–5 times'], ['Pod vape', 'No, this is my first time'], ['Refillable vape', 'Once'], ['Nicotine pouches', "I've lost count"], ['Vape and pouches', '2–5 times']]) {
  await run(d, t)
}
console.log(errors.length ? 'ERRORS:\n' + [...new Set(errors)].join('\n') : 'no console errors')
await browser.close()
