// kavach-data.jsx — palette, type scale, taxonomy data, demo script
// All values grounded in kavach-core: taxonomy.json risk_levels + tactics.

// ── Risk levels (engine: SAFE 0.0 / CAUTION 0.45 / HIGH 0.75) ──
const RISK = {
  SAFE: {
    id: 'SAFE',
    label: 'Looks normal',
    banner: 'Listening',
    sub: 'Nothing looks wrong.',
    color: '#1f9d55',
    colorDark: '#2bb56b',
  },
  CAUTION: {
    id: 'CAUTION',
    label: 'Be careful',
    banner: 'Be careful',
    sub: 'This call has some scam signs.',
    color: '#f0b400',
    colorDark: '#f5c233',
  },
  HIGH: {
    id: 'HIGH',
    label: 'Likely a scam',
    banner: 'Likely a scam',
    sub: "Don't send money or codes.",
    color: '#e63946',
    colorDark: '#ff5a64',
  },
};

// ── Scam-tactic taxonomy (id → short chip label + plain-language explanation) ──
const TACTICS = {
  URGENCY:                { chip: 'Rushing you',          weight: 0.7,  explain: 'This caller is rushing you. Real family and real banks let you take your time.' },
  SECRECY:                { chip: 'Keep it secret',       weight: 0.85, explain: 'This caller wants you to keep it secret. Scammers do this so no one can warn you.' },
  UNTRACEABLE_PAYMENT:    { chip: 'Gift cards · wire',     weight: 0.95, explain: 'This caller wants gift cards, crypto, or a wire transfer. No real family member or agency is ever paid this way.' },
  AUTHORITY_IMPERSONATION:{ chip: 'Claims to be official', weight: 0.75, explain: 'This caller claims to be the police, a bank, or the government. Real officials never demand payment over the phone.' },
  DISTRESS_HOOK:          { chip: 'Scary story',           weight: 0.8,  explain: 'This caller is using fear about a loved one to stop you thinking clearly. That panic is the attack.' },
  ISOLATION:              { chip: "Won't let you hang up", weight: 0.8,  explain: "This caller won't let you hang up — so no one else can warn you it's a scam." },
  IDENTITY_PROBE:         { chip: 'Wants codes · PIN',     weight: 0.9,  explain: 'This caller is asking for a code, PIN, or password. Real institutions never ask you to read these out.' },
  RELATIONSHIP_SPOOF:     { chip: '"It\'s me" voice',      weight: 0.6,  explain: 'This caller claims to be family but excuses a strange voice. AI clones sound a little off.' },
};

// ── Demo arc: a cloned-voice "grandson in trouble" scam climbing SAFE→CAUTION→HIGH ──
// Each beat: ms offset, who speaks, line, the active tactics, level, score (0..1), guardian status.
const DEMO_BEATS = [
  { at: 0,     who: 'them', line: 'Hello? Hi grandma… it\'s me.',                                          tactics: [],                                                       level: 'SAFE',    score: 0.12, guardian: 'idle' },
  { at: 3200,  who: 'them', line: 'I know it\'s been a while. My voice sounds a bit off — I\'ve got a cold.', tactics: ['RELATIONSHIP_SPOOF'],                                   level: 'SAFE',    score: 0.31, guardian: 'idle' },
  { at: 7000,  who: 'them', line: 'Listen — I\'m in trouble. There\'s been an accident and I need your help right now.', tactics: ['DISTRESS_HOOK', 'URGENCY'],                  level: 'CAUTION', score: 0.58, guardian: 'idle' },
  { at: 11200, who: 'them', line: 'Please don\'t tell mom or dad. Just go buy some gift cards and read me the numbers — hurry, before it\'s too late.', tactics: ['UNTRACEABLE_PAYMENT', 'SECRECY', 'URGENCY', 'DISTRESS_HOOK', 'RELATIONSHIP_SPOOF'], level: 'HIGH', score: 0.93, guardian: 'alerting' },
  { at: 15000, who: 'sys',  line: 'Guardian alert sent.',                                                  tactics: ['UNTRACEABLE_PAYMENT', 'SECRECY', 'URGENCY', 'DISTRESS_HOOK', 'RELATIONSHIP_SPOOF'], level: 'HIGH', score: 0.93, guardian: 'sent' },
];

// Canned verdict per level — used when jumping states via Tweaks (no live demo running).
// explanations are the highest-weight active tactics, plain-language, never generated.
const VERDICTS = {
  SAFE: {
    transcript: [{ who: 'them', line: 'Hi, is this a good time to talk?' }],
    tactics: [],
    explanations: ["I'm listening to this call. So far, it sounds normal."],
    guardian: 'idle',
    score: 0.12,
  },
  CAUTION: {
    transcript: [
      { who: 'them', line: 'Listen — I\'m in trouble. There\'s been an accident.' },
      { who: 'them', line: 'I need your help right now, I don\'t have much time.' },
    ],
    tactics: ['DISTRESS_HOOK', 'URGENCY'],
    explanations: [TACTICS.DISTRESS_HOOK.explain],
    guardian: 'idle',
    score: 0.58,
  },
  HIGH: {
    transcript: [
      { who: 'them', line: 'Please don\'t tell mom or dad.' },
      { who: 'them', line: 'Just buy some gift cards and read me the numbers — hurry.' },
    ],
    tactics: ['UNTRACEABLE_PAYMENT', 'SECRECY', 'URGENCY', 'DISTRESS_HOOK', 'RELATIONSHIP_SPOOF'],
    explanations: [
      TACTICS.UNTRACEABLE_PAYMENT.explain,
      TACTICS.SECRECY.explain,
      TACTICS.DISTRESS_HOOK.explain,
    ],
    guardian: 'sent',
    score: 0.93,
  },
};

// ── Palette (warm "paper" neutrals; risk colors fixed from engine) ──
function palette(dark, accent) {
  const a = accent || '#0E7C86';
  if (dark) {
    return {
      bg: '#15110D', surface: '#211C16', surface2: '#2C261E', surfaceUp: '#322B22',
      ink: '#F7F0E6', inkSoft: '#BCAF9C', inkFaint: '#867B6A',
      line: '#3A332A', lineSoft: '#2C261E',
      brand: '#34C0CB', brandInk: '#0B2E31', brandTint: '#16302F',
      onColor: '#1A130C',
      shadow: '0 18px 50px rgba(0,0,0,0.55)',
      accent: a,
      safe: '#2bb56b', caution: '#f5c233', high: '#ff5a64',
      safeTint: '#163024', cautionTint: '#332b12', highTint: '#3a1c1f',
    };
  }
  return {
    bg: '#FBF6EF', surface: '#FFFFFF', surface2: '#F4ECE0', surfaceUp: '#FFFFFF',
    ink: '#241F19', inkSoft: '#6E6557', inkFaint: '#A2998A',
    line: '#E9DECF', lineSoft: '#F0E8DB',
    brand: a, brandInk: '#063E44', brandTint: '#E1F0F1',
    onColor: '#FFFFFF',
    shadow: '0 16px 44px rgba(74,58,38,0.13)',
    accent: a,
    safe: '#1f9d55', caution: '#f0b400', high: '#e63946',
    safeTint: '#E4F4EA', cautionTint: '#FBF0D2', highTint: '#FBE4E6',
  };
}

// Risk color resolved for current theme
function riskColor(level, dark) {
  const r = RISK[level];
  return dark ? r.colorDark : r.color;
}
function riskTint(level, pal) {
  return level === 'SAFE' ? pal.safeTint : level === 'CAUTION' ? pal.cautionTint : pal.highTint;
}
// Ink that reads on a tint chip of this risk (amber needs dark ink)
function riskInk(level, dark) {
  if (dark) return { SAFE: '#7ee0a6', CAUTION: '#f7d06a', HIGH: '#ff9aa1' }[level];
  return { SAFE: '#0d6b38', CAUTION: '#7a5800', HIGH: '#b21e2b' }[level];
}

Object.assign(window, {
  RISK, TACTICS, DEMO_BEATS, VERDICTS,
  palette, riskColor, riskTint, riskInk,
});
