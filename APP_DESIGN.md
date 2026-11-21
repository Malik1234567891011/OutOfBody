# OutOfBody — the app after the paywall

Approved onboarding promises five things. The app exists to keep each one, every day:

| Onboarding promise | Where the app keeps it |
|---|---|
| "A daily budget that shrinks every week" | Today ring + Plan tab + weekly step-down day |
| "Log in one tap from your lock screen" | Lock-screen + home widgets, Control Center control, in-app + button |
| "Cravings pass. We'll get you through them" | SOS flow, reachable from everywhere |
| "We'll show up when it's hardest" | Local notifications at the user's own triggers |
| "Nicotine-free by <date>" / "Keep $X a year" | Countdown + money kept on Today; Free mode after quit day |

What we studied (screensdesign): Quittr in-app (screens 61–191), QuitSure in-app (48–74), Cal AI home.
Borrowed concepts, not screens:
- Post-purchase "welcome" sequence that sets expectations (Quittr 67–74: "sometimes there are bumps").
- One hero number + one big emergency button on home (Quittr seed/orb + red Panic Button; QuitSure "Today I smoked − 0 +").
- Panic flow = interrupt → reason → breathing guide (Quittr 113–122).
- Relapse = "Don't worry about it", never a cliff (Quittr 87).
- Setup checklist that turns into the habit (Quittr to-do list 99–107; QuitSure coach marks 48–51).
- Benefit progress list (Quittr 124) — we keep it honest: progress = plan progress, not fake medical %.
Dropped on purpose: community/leaderboards (needs free users; filter #13), content blocker (not relevant to vaping), AI chat (cost + claims risk; maybe later).

## Core loop (what a normal day looks like)
1. 8:00 notification: "Today's budget: 23 hits." Open → Today screen shows the ring full.
2. Through the day: tap the lock-screen widget each pickup. Ring drains. At 80% used → gentle heads-up notification.
3. A trigger moment (after lunch, a check-in they chose) → notification → if craving, SOS → breathe 90 s → "craving beaten" +1.
4. 21:00 evening check-in: how did today go (3 moods) + one line. Under budget → small celebration. Over → "Slips don't reset anything."
5. Every 7 days: step-down day. Weekly review screen → new, lower budget.
6. Quit day: budget reaches 0 → celebration → app switches to Free mode (days nicotine-free, SOS stays, "I slipped" logging without shame).

## Navigation
Three tabs (thumb-reachable, nothing more): **Today · Plan · You**. SOS is a floating red-coral pill above the tab bar on every tab (Quittr's always-visible Panic Button).

## Screens

### W. Welcome sequence (once, right after purchase) — 5 screens, tap to continue
- W1 "You're in, Malik." Big check, confetti burst. Sub: "Your plan starts today. Here's how it works."
- W2 How a day works: 3 numbered rows with icons — "Tap every time you pick it up", "Stay under today's budget", "Hit SOS when a craving hits".
- W3 Honest expectations (Quittr's "bumps"): "Some days will be easy. Some won't. Going over isn't failure; it's data. We adjust, you keep going."
- W4 Add the widget (the core habit): animated mock of long-press lock screen → Customize → add OutOfBody. Buttons "Show me how" (3-step guide) / "I'll do it later".
- W5 First commitment: "Today's budget: 23 hits." Button "I'm in for today" (= first pledge) → Today.

### T. Today (home)
Top → bottom:
- Header: "Hey Malik" + chip "Day 3 · Week 1".
- Hero ring (largest thing on screen): hits left today, big number in the middle, "hits left today". Colors: accent (≥30% left), warn (<30%), danger when over ("+4 over"). Ring drains with animation per log.
- Primary: "+ Log a hit" big pill (haptic). After tap, toast "Logged · Undo" (5 s).
- Two tiles: "Kept so far $9" (money) · "Cravings beaten 4".
- Plan card: "This week 23/day → next week 19" + mini step bars + "Nicotine-free in 42 days".
- Today's timeline strip: dots per hour where hits were logged (tiny, shows pattern).
- Check-in card (contextual): morning "Commit to today's 23?" [I'm in]; evening "How did today go?" [😌 good / 😐 ok / 😣 hard].
- Setup checklist card until done (Quittr to-do): Add lock-screen widget · Turn on check-ins · Try SOS once · Read your reasons. Disappears when complete.

States: first day empty; under budget; near (80%); over budget; step-down day (banner "New budget today: 19"); Free mode (after quit day).

### S. SOS (full-screen sheet, from the floating pill, widget, or notification)
- S1 Interrupt: "Breathe. This craving will pass in a few minutes." Their #1 reason in big text ("Stop feeling controlled by it"). Three choices: **Breathe with me** (primary) · **Read my reasons** · **I'm going to vape anyway**.
- S2 Breathe: 90-second guided orb (in 4 · hold 4 · out 6), haptic ticks, countdown ring. Skip available after 20 s.
- S3 "Did it pass?" → **Yes** → S4 win: "Craving beaten. That's 5." confetti; counts toward stats. **Not yet** → another round or the reasons list.
- Reasons: their reasons + their signature image + date "You signed this Nov 21".
- "Going to vape anyway": no shame. "Okay. Make it a small one. Log it so the plan stays honest." [Log 1 hit] — harm-reduction, keeps data truthful.

### P. Plan (progress)
- Lungs header: the two lung illustrations cross-faded by plan progress (0% irritated → 100% clear), label "Plan progress 34%". (Illustration of progress, never a medical claim.)
- Step-down timeline: horizontal weeks W1…W6 with budget per week, current week highlighted, finish flag "Jan 2".
- Last 7 days chart: bars = hits per day, dashed line = budget; under budget days green.
- Your patterns: hour-of-day heat strip from logs ("Most hits 12–2 pm and after 9 pm") — derived from real logs; shows after 2 days of data.
- What's changing (honest timeline tied to the plan, checks off as days pass): "First week under budget", "Nicotine cut in half" (when budget ≤50% of start), "Last step", "Nicotine-free", "72 h nicotine-free: nicotine is out of your body", "2–4 weeks free: cravings fade", "1–3 months free: easier breathing".
- Totals: money kept, nicotine avoided (mg), cravings beaten, days under budget.
- Adaptive suggestion (when over budget 3 of last 4 days): card "This step feels steep. Stay on 23 another week?" [Stay another week] [Keep going]. Moves quit date by a week. (Real value; nothing else does this.)

### Y. You
- Profile header: name, "Nicotine-free by Jan 2, 2027", day count.
- My reasons (editable list) · My pledge (signature).
- Plan settings: pace (2/4/6/8 weeks), what I use (re-runs the device questions), restart plan.
- Check-ins: list of scheduled notifications with toggles + times (morning, triggers, evening, 80% heads-up, step-down eve).
- Widgets: setup guide.
- Subscription · Restore purchases · Terms · Privacy · "Your data stays on this phone" note · Erase all data.

### R. Weekly step-down review (full screen, on the first open of a new week)
"Week 1 done." Average 21/day vs budget 23. Days under budget 5/7. Cravings beaten 9. → "New budget: 19 a day." [Let's go]. If the week went badly: "Rough week. Want to stay on 23 one more week?" (same adaptive logic).

### Q. Quit day + Free mode
- Quit day screen: big "You're nicotine-free." date, total kept, total cravings beaten. Share card (image) optional.
- Free mode Today: hero = "Day 4 nicotine-free" counter (days + hours), health milestones next up ("72 h: nicotine out of your body — in 6 h"), SOS stays, money kept keeps counting. "I slipped" button logs a slip: "One slip isn't a relapse. Day count keeps your best; tomorrow is day 1 of the next run." Keeps value in the next billing period (renewal filter #10).

### Notifications (local, scheduled on device)
- Morning 8:00 budget. Evening 21:00 check-in.
- Trigger check-ins from onboarding answers (meals 12:30 + 18:30, wake 7:30, drive 17:30, bed 22:00, stress/bored 15:00, drink Fri 21:00, social Sat 20:00, work 10:30).
- 80% heads-up (fired right after a log that crosses 80%).
- Step-down eve ("Tomorrow your budget drops to 19. You've got this.").
- Trial reminder on day 5 of the trial (we promised it on paywall page 2).
All editable in You → Check-ins.

### Widgets & controls (iOS)
- Lock screen circular: ring + hits left. Rectangular: "14 left · tap to log". Tap = log via AppIntent (iOS 17 interactive).
- Home screen small: ring + "+" button (interactive). Medium: ring + week bars + SOS button (opens app to SOS).
- Control Center control (iOS 18): "Log a hit". Action Button support via the same intent.

### Celebrations (small, earned)
First day under budget · 3 days in a row under · first craving beaten · every 10 cravings · each step-down · halfway · quit day · 72 h free · 30 days free.

## Data (all on device, shared with widgets via App Group)
- `Answers` (from onboarding), `Plan` {startDate, weeks, budgets[]}, `extraWeeks` (adaptive).
- `LogEntry` {id, at, source: app|widget|control|sos}.
- `Craving` {id, at, outcome: beaten|gaveIn, method: breathe|reasons}.
- `CheckIn` {date, kind: morning|evening, mood?, note?}.
- `Slip` {at} (Free mode).
Derived: today used/left, day/week index, money kept (= (yearly/365) × days × (1 − used/start avg)), nicotine avoided, under-budget days, patterns.

## Design system
Same tokens as onboarding (dark #07090E, surfaces #11151D/#171C26, accent mint #4FE3B8, danger #FF6B6B, warn #FFB547, SF Pro). Big numbers tabular. One primary action per screen. Haptics on every log and every win.
