// kavach-ui.jsx — theme context + shared primitives (phone shell, shield, buttons, chips, icons)

const ThemeCtx = React.createContext({ pal: palette(false), dark: false, scale: 1 });
const useTheme = () => React.useContext(ThemeCtx);

const FONT = "'Hanken Grotesque', system-ui, sans-serif";

// ───────────────────────── Phone shell ─────────────────────────
// Full-bleed: content paints to the very top; status bar floats over it.
function PhoneShell({ children, statusTone = 'dark', bg, navTone }) {
  const { pal } = useTheme();
  const nt = navTone || statusTone;
  return (
    <div style={{
      width: 392, height: 812, borderRadius: 46, padding: 7,
      background: pal.dark ? '#0c0a07' : '#2b2620',
      boxShadow: pal.shadow, boxSizing: 'border-box', flexShrink: 0,
    }}>
      <div style={{
        position: 'relative', width: '100%', height: '100%',
        borderRadius: 39, overflow: 'hidden', background: bg || pal.bg,
        fontFamily: FONT,
      }}>
        <div style={{ position: 'absolute', inset: 0, overflowY: 'auto', overflowX: 'hidden' }}>
          {children}
        </div>
        <StatusBar tone={statusTone} />
        <NavPill tone={nt} />
      </div>
    </div>
  );
}

function StatusBar({ tone = 'dark' }) {
  const c = tone === 'light' ? '#fff' : '#241F19';
  return (
    <div style={{
      position: 'absolute', top: 0, left: 0, right: 0, height: 46,
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '0 24px', pointerEvents: 'none', zIndex: 30,
    }}>
      <span style={{ fontFamily: FONT, fontSize: 15, fontWeight: 700, color: c, letterSpacing: 0.2 }}>9:41</span>
      <div style={{
        position: 'absolute', left: '50%', top: 12, transform: 'translateX(-50%)',
        width: 11, height: 11, borderRadius: 99, background: '#000',
      }} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, opacity: 0.95 }}>
        <svg width="17" height="13" viewBox="0 0 17 13"><path d="M1 9l3-1v4H1zM6 6l3-1v7H6zM11 2l3-1v11h-3z" fill={c}/></svg>
        <svg width="16" height="13" viewBox="0 0 16 13"><path d="M8 11.5L.8 4.3a10 10 0 0114.4 0L8 11.5z" fill={c}/></svg>
        <svg width="24" height="13" viewBox="0 0 24 13"><rect x="1" y="1.5" width="19" height="10" rx="2.5" fill="none" stroke={c} strokeOpacity="0.5"/><rect x="2.6" y="3" width="14" height="7" rx="1.3" fill={c}/><rect x="21" y="4.5" width="1.6" height="4" rx="0.8" fill={c}/></svg>
      </div>
    </div>
  );
}

function NavPill({ tone = 'dark' }) {
  const c = tone === 'light' ? 'rgba(255,255,255,0.85)' : 'rgba(36,31,25,0.4)';
  return (
    <div style={{ position: 'absolute', bottom: 9, left: 0, right: 0, display: 'flex', justifyContent: 'center', zIndex: 30, pointerEvents: 'none' }}>
      <div style={{ width: 128, height: 5, borderRadius: 99, background: c }} />
    </div>
  );
}

// ───────────────────────── Listening-rings shield ─────────────────────────
function Shield({ size = 200, color, listening = false, glyph = 'rings' }) {
  const { pal } = useTheme();
  const c = color || pal.brand;
  const id = React.useMemo(() => 'sh' + Math.random().toString(36).slice(2, 7), []);
  return (
    <div style={{ width: size, height: size, position: 'relative' }}>
      <svg width={size} height={size} viewBox="0 0 200 200" style={{ display: 'block' }}>
        <circle cx="100" cy="100" r="92" fill="none" stroke={c} strokeOpacity="0.16" strokeWidth="3" />
        <circle cx="100" cy="100" r="66" fill="none" stroke={c} strokeOpacity="0.34" strokeWidth="3" />
        <circle cx="100" cy="100" r="40" fill="none" stroke={c} strokeOpacity="0.6" strokeWidth="3" />
        <circle cx="100" cy="100" r="17" fill={c} />
        {listening && (
          <circle cx="100" cy="100" r="17" fill="none" stroke={c} strokeWidth="2.5">
            <animate attributeName="r" values="17;92" dur="3s" repeatCount="indefinite" />
            <animate attributeName="stroke-opacity" values="0.55;0" dur="3s" repeatCount="indefinite" />
          </circle>
        )}
      </svg>
    </div>
  );
}

// ───────────────────────── Buttons ─────────────────────────
function Button({ label, onClick, kind = 'primary', color, icon, sub, disabled }) {
  const { pal, scale } = useTheme();
  const [down, setDown] = React.useState(false);
  let bg, fg, border = 'none';
  const accent = color || pal.brand;
  if (kind === 'primary')  { bg = accent; fg = pal.onColor; }
  else if (kind === 'danger') { bg = pal.high; fg = '#fff'; }
  else if (kind === 'secondary') { bg = 'transparent'; fg = pal.ink; border = `2px solid ${pal.line}`; }
  else if (kind === 'soft') { bg = pal.surface2; fg = pal.ink; }
  else { bg = 'transparent'; fg = pal.inkSoft; }
  return (
    <button
      onClick={onClick} disabled={disabled}
      onPointerDown={() => setDown(true)} onPointerUp={() => setDown(false)} onPointerLeave={() => setDown(false)}
      style={{
        width: '100%', minHeight: 66, padding: '12px 22px', border, borderRadius: 22,
        background: bg, color: fg, cursor: 'pointer', fontFamily: FONT,
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12,
        transform: down ? 'scale(0.975)' : 'scale(1)', transition: 'transform .12s ease, filter .12s',
        filter: down ? 'brightness(0.96)' : 'none', opacity: disabled ? 0.5 : 1,
        boxShadow: kind === 'primary' || kind === 'danger' ? '0 8px 20px rgba(0,0,0,0.12)' : 'none',
      }}>
      {icon && <span style={{ display: 'flex', flexShrink: 0 }}>{icon}</span>}
      <span style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', lineHeight: 1.15 }}>
        <span style={{ fontSize: 21 * scale, fontWeight: 800, letterSpacing: 0.1 }}>{label}</span>
        {sub && <span style={{ fontSize: 14 * scale, fontWeight: 600, opacity: 0.85, marginTop: 3 }}>{sub}</span>}
      </span>
    </button>
  );
}

// ───────────────────────── Chip ─────────────────────────
function Chip({ label, level }) {
  const { pal, dark, scale } = useTheme();
  const tint = level ? riskTint(level, pal) : pal.surface2;
  const ink = level ? riskInk(level, dark) : pal.inkSoft;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 7,
      padding: '9px 15px', borderRadius: 99, background: tint, color: ink,
      fontFamily: FONT, fontSize: 15.5 * scale, fontWeight: 700, whiteSpace: 'nowrap',
    }}>
      <span style={{ width: 7, height: 7, borderRadius: 99, background: ink, opacity: 0.8 }} />
      {label}
    </span>
  );
}

// ───────────────────────── Icons ─────────────────────────
const Ic = {
  mic: (c, s = 26) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10a7 7 0 0014 0M12 17v4"/></svg>,
  shield: (c, s = 26) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 3l7 3v5c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6z"/></svg>,
  phoneOff: (c, s = 26) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 3l18 18M9.5 5.4A14 14 0 008 5C5 5 3 6 3 8c0 1 .3 2 .8 3M11 9.5c.6 1.2 1.6 2.3 2.9 3.2M16 16c1 .5 2 .8 3 .8 2 0 3-2 1.5-4"/></svg>,
  check: (c, s = 26) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="M4 12.5l5 5L20 6"/></svg>,
  key: (c, s = 26) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="8" cy="8" r="4.5"/><path d="M11 11l9 9M17 17l2-2M14 14l2.5-2.5"/></svg>,
  user: (c, s = 26) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-6 8-6s8 2 8 6"/></svg>,
  bell: (c, s = 26) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M6 9a6 6 0 0112 0c0 5 2 6 2 6H4s2-1 2-6M10 20a2 2 0 004 0"/></svg>,
  phone: (c, s = 26) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M5 4h4l2 5-2.5 1.5a11 11 0 005 5L15 13l5 2v4c0 1-1 2-2 2A16 16 0 013 6c0-1 1-2 2-2z"/></svg>,
  chevron: (c, s = 26) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M9 6l6 6-6 6"/></svg>,
  lock: (c, s = 26) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="4" y="10" width="16" height="11" rx="2.5"/><path d="M8 10V7a4 4 0 018 0v3"/></svg>,
  eye: (c, s = 22) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/></svg>,
  arrowLeft: (c, s = 24) => <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M15 6l-6 6 6 6"/></svg>,
};

Object.assign(window, {
  ThemeCtx, useTheme, FONT, PhoneShell, StatusBar, NavPill, Shield, Button, Chip, Ic,
});
