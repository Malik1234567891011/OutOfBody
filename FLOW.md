# Onboarding flow — why each screen is where it is

Prototype: `cd web && npm run dev` → http://127.0.0.1:5191 (devnav under the phone jumps to any screen; `?preset=disposable|pod|pouch|combo&s=<id>` loads answers).
Studied first: Quittr (~60 screens), QuitSure ($45K/mo, 48 screens), Cal AI (31 screens).

| # | Screen | Why it's here |
|---|---|---|
| 1 | Welcome (breathing lungs) | One promise, one button. "100% private, no account" because Quittr leaked 600K users. |
| 2 | What do you use | Sets the unit (hits vs pouches) and the math. Easiest possible first tap. |
| 3 | How long | Feeds "already spent since you started". |
| 4 | Device details (1 screen) | Disposable: puffs on box + days it lasts → liquid mL. Pods/mL/pouches equivalents. |
| 5 | Strength | Canada caps at 20 mg/mL, US is mostly 5% — needed for real mg. |
| 6 | First hit after waking | Strongest single item of the Fagerström dependence test. |
| 7 | Times a day you pick it up | The loggable unit for the budget (nobody can log 700 puffs). |
| 8 | Triggers (multi) | Reused on the notifications screen. |
| 9 | Weekly spend | Feeds the cost shock. |
| 10 | Cost reveal | QuitSure pattern: a big number of their own money, then a CTA in their voice ("I want that money back"). |
| 11–12 | Tried before / what made it hard | Surfaces past failure so 13 can reframe it. |
| 13 | "It wasn't a willpower problem" | QuitSure/Quittr reframe: cold-turkey crash vs step-down chart. Sells the method. |
| 14 | Why quit (multi) | Their reasons come back on the plan-ready screen and in SOS. |
| 15 | Name + age | Personalizes everything after; 18+ only. |
| 16 | Analyzing | Labor illusion (Cal AI / Quittr): makes the result feel earned. |
| 17 | Results | The hook: "your vape ≈ 3.2 packs a day", mg, $/yr, dependence gauge. Estimates labelled as estimates. |
| 18 | Lungs before/after (vape users only) | Emotional peak after the numbers. Pouch users skip it (pouches don't touch lungs). |
| 19 | How fast | Gives agency + a "Recommended" tag from their dependence. |
| 20 | Plan | The product, shown: weekly budget bars and a dated finish line. |
| 21 | Lock-screen widget demo | Shows the core action before paying. |
| 22 | Craving SOS demo | Interactive — they feel the product work once. |
| 23 | Notifications | Asked with their own triggers on screen, right before the paywall reminder promise. |
| 24 | Signature | Quittr commitment pattern; consistency bias. |
| 25 | Plan ready | Cal AI/Quittr dated plan: "nicotine-free by Jan 1, 2027" → paywall. |
| P1 | "We want you to try OutOfBody for free" | App playing inside a phone (Cal AI). |
| P2 | Reminder bell + trial timeline | Lowers trial fear (RECIME+ style). |
| P3 | Photo + 7 DAYS FREE card, $39.99 CAD/yr ($0.77/wk) | Atlas page 3 layout. |

Screens per path: pouch 22, pod 24, disposable/refill 25, vape+pouches 26 (+3 paywall).

Math (web/src/calc.ts, copy 1:1 to Swift): Juul's figure (0.7 mL 5% pod ≈ a pack) → ~2 mg liquid nicotine ≈ 1 cigarette; 6 mg pouch ≈ 1 cigarette; disposable liquid by size 2/8/13/18 mL.
