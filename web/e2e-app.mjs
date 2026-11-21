// Click through the app after the paywall like a user. Fails loudly on any broken step.
// buy on paywall p3 -> Welcome -> Today -> log 3 -> undo 1 -> SOS breathe -> beaten -> tabs,
// plus check-ins, setup checklist, adaptive "stay another week", notification toggles and a free-mode slip.
import { chromium } from 'playwright'
import assert from 'assert/strict'

const base = 'http://127.0.0.1:5191/'
const browser = await chromium.launch({ channel: 'chrome' })
const page = await browser.newPage({ viewport: { width: 460, height: 920 } })
const errors = []
page.on('pageerror', (e) => errors.push(e.message))
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()))
const d = page.locator('.device')
const tap = async (text, opts = {}) => { await d.getByRole('button', { name: text, exact: true, ...opts }).first().click(); await page.waitForTimeout(350) }
const ringNum = () => d.locator('.hero-ring .ring-num').innerText()
const step = (s) => console.log('ok  ', s)

// 1. buy on paywall page 3
await page.goto(`${base}?preset=disposable&s=pw3`)
await tap('Start my free week')
await d.getByText("You're in, Malik.").waitFor()
step('paywall p3 -> welcome W1')

// 2. welcome W1..W5 (W4 through the widget guide)
await tap('Continue'); await d.getByText('How a day works').waitFor()
await tap('Continue'); await d.getByText("Some days will be easy. Some won't.").waitFor()
await tap('Continue'); await tap('Show me how')
await tap('I added it'); await d.getByText("Today's budget", { exact: true }).waitFor()
await tap("I'm in for today")
assert.equal(await ringNum(), '23')
step('welcome W1-W5 -> Today, budget 23')

// 3. log 3 hits, undo one
for (let i = 0; i < 3; i++) await tap('Log a hit')
assert.equal(await ringNum(), '20')
await d.locator('.toast button', { hasText: 'Undo' }).click()
await page.waitForTimeout(300)
assert.equal(await ringNum(), '21')
assert.equal(await d.locator('.strip-h .muted').innerText(), '2 hits')
step('log 3 -> 20 left, undo -> 21 left')
await page.waitForTimeout(5200)
assert.equal(await d.locator('.toast').count(), 0)
step('undo toast gone after 5 s')

// 4. SOS: breathe, skip after 20 s, mark beaten
await d.locator('.tab-sos').click()
await d.getByText('Breathe. This craving will pass in a few minutes.').waitFor()
await tap('Breathe with me')
assert.equal(await d.locator('.br-skip.hidden').count(), 1, 'skip hidden before 20 s')
const phases = new Set()
for (let i = 0; i < 11; i++) { phases.add(await d.locator('.br-ph').innerText()); await page.waitForTimeout(1000) }
assert.ok(phases.has('Breathe in') && phases.has('Hold'), 'breath phases advance: ' + [...phases])
await page.waitForTimeout(10000)
await tap('Skip to the end')
await tap('Yes, it passed')
await d.getByText("That's 1.").waitFor()
await tap('Back to today')
assert.equal(await d.locator('.tile2 .t2-k').nth(1).innerText(), '1')
step('SOS breathe -> skip at 20 s -> beaten, tile shows 1')
await d.getByText('First craving beaten').waitFor()
await tap('Nice')
step('celebration "First craving beaten" shown and dismissed')

// 5. setup checklist: SOS already ticked; turn on check-ins via the permission prompt
assert.ok(await d.locator('.setup-row.done', { hasText: 'Try SOS once' }).count())
await d.locator('.setup-row', { hasText: 'Turn on check-ins' }).click()
await tap('Allow')
assert.equal(await d.locator('.setup-h .muted').innerText(), '3 of 4')
await d.locator('.setup-row', { hasText: 'Read your reasons' }).click()
await tap('Done')
assert.equal(await d.locator('.setup').count(), 0, 'checklist disappears when complete')
step('setup checklist ticks off and disappears')

// 6. tabs
await tap('Plan'); await d.getByText('Plan progress').waitFor()
await tap('You'); await d.getByText('My reasons').waitFor()
const tg = d.locator('.notif-row .toggle').first()
const before = await tg.getAttribute('aria-checked')
await tg.click(); await page.waitForTimeout(200)
assert.notEqual(await tg.getAttribute('aria-checked'), before)
step('tabs switch; notification toggle flips')
await tap('Today'); await d.locator('.hero-ring').waitFor()

// 7. reload: state persisted in localStorage
await page.goto(`${base}?app=1&preset=disposable`)
await d.locator('.hero-ring').waitFor()
assert.equal(await ringNum(), '21')
step('reload keeps logs (localStorage)')

// 8. evening check-in
await page.goto(`${base}?app=1&preset=disposable&scenario=near&screen=none`)
await d.locator('.mood', { hasText: 'Good' }).click()
await d.locator('.ci-note').fill('Walked after dinner')
await tap('Save')
await d.getByText('Under budget today. That counts.').waitFor()
step('evening check-in saves with mood + note')

// 9. over budget state
await page.goto(`${base}?app=1&preset=disposable&scenario=over&screen=none`)
assert.equal(await ringNum(), '+4')
await tap('Log a hit')
assert.equal(await ringNum(), '+5')
step('over budget: +4 -> +5')

// 10. adaptive: stay another week moves quit date and repeats the budget
await page.goto(`${base}?app=1&preset=disposable&scenario=adaptive&tab=plan&screen=none`)
await d.getByText('This step feels steep.', { exact: false }).waitFor()
const weeksBefore = await d.locator('.wk:not(.flag)').count()
const finishBefore = await d.locator('.sec-t .muted').first().innerText()
await tap('Stay another week')
assert.equal(await d.locator('.wk:not(.flag)').count(), weeksBefore + 1)
const finishAfter = await d.locator('.sec-t .muted').first().innerText()
assert.notEqual(finishAfter, finishBefore)
assert.equal(await d.locator('.adaptive').count(), 0)
step(`adaptive stay: ${weeksBefore} -> ${weeksBefore + 1} weeks, ${finishBefore} -> ${finishAfter}`)

// 11. step-down review shows on first open of week 2
await page.goto(`${base}?app=1&preset=disposable&scenario=stepdown`)
await d.getByText('Week 1 done.').waitFor()
await tap("Let's go")
await d.getByText('New budget today:', { exact: false }).waitFor()
assert.equal(await ringNum(), '19')
step('review -> new budget 19 on Today')

// 12. quit day -> free mode -> slip
await page.goto(`${base}?app=1&preset=disposable&scenario=quitday`)
await d.getByText("nicotine-free.", { exact: false }).first().waitFor()
await tap('Start free mode')
await d.getByText('Free mode').waitFor()
await tap('I slipped'); await tap('Log the slip')
await d.getByText('Day 1 starts').waitFor()
step('quit day -> free mode -> slip resets the run')

// 13. vape anyway logs one hit
await page.goto(`${base}?app=1&preset=disposable&scenario=midweek&screen=none`)
const left0 = Number(await ringNum())
await d.locator('.tab-sos').click()
await tap("I'm going to vape anyway")
await tap('Log 1 hit')
assert.equal(Number(await ringNum()), left0 - 1)
step('"vape anyway" logs 1 hit')

console.log(errors.length ? 'ERRORS:\n' + [...new Set(errors)].join('\n') : 'no console errors')
await browser.close()
if (errors.length) process.exit(1)
