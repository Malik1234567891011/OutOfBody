import { fmtDate } from '../calc'
import { useStore, weekStats, addDays } from './store'
import { Confetti, Sheet, haptic } from './bits'
import type { Nav } from './AppShell'

// First open of a new week: how the last one went, then the new, lower budget.
export function Review({ nav }: { nav: Nav }) {
  const { s, d, update } = useStore()
  const w = d.reviewWeek ?? Math.max(1, d.weekIdx)
  const st = weekStats(s, w, d.t)
  const rough = st.under < 4
  const finish = (stay: boolean) => {
    haptic(20)
    update((x) => {
      const budgets = stay ? [...x.budgets.slice(0, w), x.budgets[w - 1], ...x.budgets.slice(w)] : x.budgets
      return { ...x, budgets, extraWeeks: x.extraWeeks + (stay ? 1 : 0), reviewed: [...x.reviewed, w] }
    })
    nav.open(null)
    if (stay) nav.toast(`Staying on ${st.budget} this week. New finish: ${fmtDate(new Date(addDays(d.quitAt, 7)))}`)
  }
  return (
    <Sheet className="review-sheet">
      {!rough && <Confetti top={200} n={30} />}
      <div className="rv-body">
        <p className="eyebrow center">Step-down day</p>
        <h1 className="hero rv-h">Week {w} done.</h1>
        <div className="rv-stats">
          <div className="rv-big">
            <div className="rv-k">{st.avg}<span>/day</span></div>
            <div className="rv-l">your average vs a budget of {st.budget}</div>
          </div>
          <div className="rv-grid">
            <div><b>{st.under}/{st.days}</b><span>days under budget</span></div>
            <div><b>{st.beaten}</b><span>cravings beaten</span></div>
          </div>
        </div>
        {!rough ? (
          <div className="rv-new">
            <div className="rv-new-l">New budget</div>
            <div className="rv-new-v">{st.next} <span>a day</span></div>
            <div className="rv-new-s">{st.next === 0 ? 'Zero week. The last step.' : `Down from ${st.budget}. Same method, smaller number.`}</div>
          </div>
        ) : (
          <div className="rv-new rough">
            <div className="rv-new-l">Rough week</div>
            <div className="rv-rough-t">Want to stay on {st.budget} one more week?</div>
            <div className="rv-new-s">It moves your finish line by 7 days. Better than a step that feels too steep.</div>
          </div>
        )}
      </div>
      <div className="sheet-bottom">
        {!rough ? <>
          <button className="cta cta-primary" onClick={() => finish(false)}>Let's go</button>
        </> : <>
          <button className="cta cta-primary" onClick={() => finish(true)}>Stay on {st.budget} another week</button>
          <button className="link" onClick={() => finish(false)}>Step down to {st.next} anyway</button>
        </>}
      </div>
    </Sheet>
  )
}
