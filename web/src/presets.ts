import type { Answers } from './calc'

// Presets let screenshots jump straight to any screen with realistic answers.
export const PRESETS: Record<string, Answers> = {
  disposable: { device: 'disposable', duration: '1to3y', dispSize: 6000, dispDays: 5, strength: 50, hitsPerDay: 30, firstHit: '5to30', triggers: ['meals', 'stress', 'bored'], weeklySpend: 22, tried: 'few', hardParts: ['cravings', 'irritable'], reasons: ['money', 'breathe', 'control'], name: 'Malik', age: '18–24' },
  pod: { device: 'pod', duration: '3to5y', podsPerDay: 1, strength: 50, hitsPerDay: 50, firstHit: 'lt5', triggers: ['wake', 'drive', 'work'], weeklySpend: 40, tried: 'once', hardParts: ['stress'], reasons: ['health', 'fit'], name: 'Sam', age: '25–34' },
  pouch: { device: 'pouch', duration: '1to3y', pouchesPerDay: 12, pouchMg: 6, firstHit: '5to30', triggers: ['work', 'meals'], weeklySpend: 40, tried: 'never', reasons: ['money', 'anxiety'], name: 'Jordan', age: '25–34' },
  combo: { device: 'combo', duration: '3to5y', dispSize: 6000, dispDays: 5, strength: 50, pouchesPerDay: 7, pouchMg: 6, hitsPerDay: 30, firstHit: 'lt5', triggers: ['wake', 'stress', 'drink'], weeklySpend: 62, tried: 'lost', hardParts: ['cravings', 'friends'], reasons: ['control', 'money'], name: 'Alex', age: '18–24' },
}
