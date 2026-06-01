// kavach-screens-setup.jsx — brand mark + onboarding, watchword, guardian, home

function BrandMark({ tone }) {
  const { pal } = useTheme();
  const c = tone === 'light' ? '#fff' : pal.ink;
  const accent = tone === 'light' ? '#fff' : pal.brand;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <svg width="26" height="26" viewBox="0 0 200 200"><circle cx="100" cy="100" r="88" fill="none" stroke={accent} strokeOpacity="0.25" strokeWidth="10"/><circle cx="100" cy="100" r="56" fill="none" stroke={accent} strokeOpacity="0.5" strokeWidth="10"/><circle cx="100" cy="100" r="20" fill={accent}/></svg>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
        <span style={{ fontFamily: FONT, fontSize: 22, fontWeight: 800, color: c, letterSpacing: 0.2 }}>Kavach</span>
        <span style={{ fontFamily: FONT, fontSize: 17, fontWeight: 600, color: c, opacity: 0.4 }}>कवच</span>
      </div>
    </div>
  );
}

function ProgressDots({ step, total }) {
  const { pal } = useTheme();
  return (
    <div style={{ display: 'flex', gap: 7 }}>
      {Array.from({ length: total }).map((_, i) => (
        <div key={i} style={{
          width: i === step ? 26 : 9, height: 9, borderRadius: 99,
          background: i === step ? pal.brand : pal.line, transition: 'width .2s',
        }} />
      ))}
    </div>
  );
}

function Screen({ children, footer, header, bg }) {
  const { pal } = useTheme();
  return (
    <div style={{ minHeight: '100%', display: 'flex', flexDirection: 'column', background: bg || pal.bg }}>
      <div style={{ padding: '60px 26px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', minHeight: 30 }}>{header}</div>
      <div style={{ flex: 1, padding: '0 26px', display: 'flex', flexDirection: 'column' }}>{children}</div>
      {footer && (
        <div style={{
          position: 'sticky', bottom: 0, padding: '18px 22px 30px',
          display: 'flex', flexDirection: 'column', gap: 12,
          background: `linear-gradient(to top, ${bg || pal.bg} 72%, transparent)`,
        }}>{footer}</div>
      )}
    </div>
  );
}

function BackBtn({ onClick }) {
  const { pal } = useTheme();
  return (
    <button onClick={onClick} style={{
      width: 46, height: 46, borderRadius: 99, border: `2px solid ${pal.line}`,
      background: pal.surface, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', padding: 0,
    }}>{Ic.arrowLeft(pal.ink)}</button>
  );
}

// ───────────────────────── 1 · Onboarding / permission ─────────────────────────
function Onboarding({ go }) {
  const { pal, scale } = useTheme();
  return (
    <Screen
      header={<BrandMark />}
      footer={<>
        <Button label="Turn on protection" sub="Kavach will ask to use the microphone" icon={Ic.mic(pal.onColor, 24)} onClick={() => go('watchword')} />
        <div style={{ textAlign: 'center', fontSize: 14.5 * scale, fontWeight: 600, color: pal.inkFaint }}>It only listens while you're on a call.</div>
      </>}
    >
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', paddingTop: 18 }}>
        <Shield size={184} listening />
        <h1 style={{ fontFamily: FONT, fontSize: 33 * scale, lineHeight: 1.12, fontWeight: 800, color: pal.ink, margin: '26px 0 0', textWrap: 'balance' }}>
          A quiet shield<br />on every call.
        </h1>
        <p style={{ fontFamily: FONT, fontSize: 19.5 * scale, lineHeight: 1.45, fontWeight: 500, color: pal.inkSoft, margin: '16px 4px 0', textWrap: 'pretty' }}>
          Kavach listens to your calls on speaker and warns you if someone is trying to scam you.
        </p>
      </div>
      <div style={{
        marginTop: 24, padding: '18px 18px', borderRadius: 22, background: pal.brandTint,
        display: 'flex', alignItems: 'center', gap: 14,
      }}>
        <div style={{ flexShrink: 0, width: 46, height: 46, borderRadius: 14, background: pal.surface, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{Ic.lock(pal.brand, 24)}</div>
        <div style={{ fontFamily: FONT, fontSize: 17 * scale, lineHeight: 1.35, fontWeight: 700, color: pal.dark ? pal.ink : pal.brandInk }}>
          Nothing ever leaves your phone.<br />
          <span style={{ fontWeight: 600, color: pal.inkSoft }}>No cloud. No account.</span>
        </div>
      </div>
    </Screen>
  );
}

// ───────────────────────── 2 · Watchword setup ─────────────────────────
const WORD_IDEAS = ['Marigold', 'Banyan', 'Jubilee', 'Monsoon'];
function Watchword({ go, watchword, setWatchword }) {
  const { pal, scale } = useTheme();
  return (
    <Screen
      header={<><BackBtn onClick={() => go('onboarding')} /><ProgressDots step={0} total={2} /><div style={{ width: 46 }} /></>}
      footer={<Button label="Save safe-word" onClick={() => go('guardian')} disabled={!watchword.trim()} />}
    >
      <div style={{ width: 64, height: 64, borderRadius: 20, background: pal.brandTint, display: 'flex', alignItems: 'center', justifyContent: 'center', marginTop: 6 }}>{Ic.key(pal.brand, 30)}</div>
      <h1 style={{ fontFamily: FONT, fontSize: 30 * scale, lineHeight: 1.15, fontWeight: 800, color: pal.ink, margin: '20px 0 0' }}>Set a family safe-word</h1>
      <p style={{ fontFamily: FONT, fontSize: 18.5 * scale, lineHeight: 1.45, fontWeight: 500, color: pal.inkSoft, margin: '12px 0 0', textWrap: 'pretty' }}>
        Pick a word only your family knows. A real loved one can say it — a scammer or a voice clone can't.
      </p>

      <input
        value={watchword}
        onChange={(e) => setWatchword(e.target.value)}
        placeholder="Type a word…"
        style={{
          marginTop: 22, width: '100%', boxSizing: 'border-box', padding: '20px 22px',
          borderRadius: 20, border: `2px solid ${watchword.trim() ? pal.brand : pal.line}`,
          background: pal.surface, color: pal.ink, fontFamily: FONT,
          fontSize: 26 * scale, fontWeight: 800, outline: 'none', letterSpacing: 0.3,
        }}
      />
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, marginTop: 16 }}>
        {WORD_IDEAS.map((w) => (
          <button key={w} onClick={() => setWatchword(w)} style={{
            padding: '11px 18px', borderRadius: 99, cursor: 'pointer', fontFamily: FONT,
            border: `2px solid ${pal.line}`, background: pal.surface, color: pal.inkSoft,
            fontSize: 16 * scale, fontWeight: 700,
          }}>{w}</button>
        ))}
      </div>
      <div style={{ marginTop: 'auto', paddingTop: 22, display: 'flex', gap: 11, alignItems: 'flex-start' }}>
        <span style={{ marginTop: 2 }}>{Ic.eye(pal.inkFaint, 20)}</span>
        <p style={{ fontFamily: FONT, fontSize: 16 * scale, lineHeight: 1.4, fontWeight: 600, color: pal.inkFaint, margin: 0 }}>
          You'll only ever <b style={{ color: pal.inkSoft }}>ask</b> for this word — never say it first.
        </p>
      </div>
    </Screen>
  );
}

// ───────────────────────── 3 · Guardian setup ─────────────────────────
const CONTACTS = [
  { name: 'Priya', rel: 'Daughter', tone: '#0E7C86' },
  { name: 'Arjun', rel: 'Son', tone: '#7A5AE0' },
  { name: 'Meera', rel: 'Neighbour', tone: '#C76A2B' },
  { name: 'Dr. Rao', rel: 'Family doctor', tone: '#1f9d55' },
];
function Guardian({ go, guardian, setGuardian }) {
  const { pal, scale } = useTheme();
  return (
    <Screen
      header={<><BackBtn onClick={() => go('watchword')} /><ProgressDots step={1} total={2} /><div style={{ width: 46 }} /></>}
      footer={<Button label="Finish setup" onClick={() => go('home')} disabled={!guardian} />}
    >
      <div style={{ width: 64, height: 64, borderRadius: 20, background: pal.brandTint, display: 'flex', alignItems: 'center', justifyContent: 'center', marginTop: 6 }}>{Ic.bell(pal.brand, 30)}</div>
      <h1 style={{ fontFamily: FONT, fontSize: 30 * scale, lineHeight: 1.15, fontWeight: 800, color: pal.ink, margin: '20px 0 0' }}>Choose your Guardian</h1>
      <p style={{ fontFamily: FONT, fontSize: 18.5 * scale, lineHeight: 1.45, fontWeight: 500, color: pal.inkSoft, margin: '12px 0 0', textWrap: 'pretty' }}>
        On a dangerous call, Kavach can quietly alert one person you trust.
      </p>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 11, marginTop: 22 }}>
        {CONTACTS.map((c) => {
          const sel = guardian === c.name;
          return (
            <button key={c.name} onClick={() => setGuardian(c.name)} style={{
              display: 'flex', alignItems: 'center', gap: 15, padding: '14px 16px', cursor: 'pointer',
              borderRadius: 20, textAlign: 'left', width: '100%',
              border: `2px solid ${sel ? pal.brand : pal.line}`,
              background: sel ? pal.brandTint : pal.surface,
            }}>
              <div style={{ width: 52, height: 52, borderRadius: 99, background: c.tone, color: '#fff', flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: FONT, fontWeight: 800, fontSize: 21 * scale }}>{c.name[0]}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontFamily: FONT, fontSize: 20 * scale, fontWeight: 800, color: pal.ink }}>{c.name}</div>
                <div style={{ fontFamily: FONT, fontSize: 16 * scale, fontWeight: 600, color: pal.inkSoft }}>{c.rel}</div>
              </div>
              <div style={{ width: 30, height: 30, borderRadius: 99, flexShrink: 0, border: `2px solid ${sel ? pal.brand : pal.line}`, background: sel ? pal.brand : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                {sel && Ic.check('#fff', 18)}
              </div>
            </button>
          );
        })}
      </div>
      <div style={{ marginTop: 'auto', paddingTop: 20, fontFamily: FONT, fontSize: 15.5 * scale, lineHeight: 1.4, fontWeight: 600, color: pal.inkFaint }}>
        They're only messaged on a HIGH-risk call, and they'll see what was detected.
      </div>
    </Screen>
  );
}

// ───────────────────────── 4 · Home ─────────────────────────
function Home({ go, armed, setArmed, watchword, guardian, startDemo }) {
  const { pal, scale } = useTheme();
  return (
    <Screen
      header={<>
        <BrandMark />
        <button onClick={() => go('onboarding')} style={{ width: 44, height: 44, borderRadius: 99, border: 'none', background: pal.surface2, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>{Ic.user(pal.inkSoft, 22)}</button>
      </>}
      footer={armed ? <>
        <Button label="See how it works" sub="Plays a sample scam call" kind="primary" icon={Ic.phone(pal.onColor, 22)} onClick={startDemo} />
        <Button label="Stop Guardian Mode" kind="ghost" onClick={() => setArmed(false)} />
      </> : <>
        <Button label="Start Guardian Mode" icon={Ic.shield(pal.onColor, 24)} onClick={() => setArmed(true)} />
        <div style={{ textAlign: 'center', fontSize: 14.5 * scale, fontWeight: 600, color: pal.inkFaint }}>You can stop any time.</div>
      </>}
    >
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', paddingTop: 30 }}>
        <Shield size={210} listening={armed} color={armed ? pal.safe : pal.brand} />
        <div style={{
          marginTop: 8, padding: '8px 16px', borderRadius: 99,
          background: armed ? riskTint('SAFE', pal) : pal.surface2,
          color: armed ? riskInk('SAFE', pal.dark) : pal.inkSoft,
          fontFamily: FONT, fontSize: 15.5 * scale, fontWeight: 800, letterSpacing: 0.4, textTransform: 'uppercase',
        }}>{armed ? '● Listening' : 'Ready'}</div>
        <h1 style={{ fontFamily: FONT, fontSize: 31 * scale, lineHeight: 1.15, fontWeight: 800, color: pal.ink, margin: '18px 0 0', textWrap: 'balance' }}>
          {armed ? "Guardian Mode is on." : "You're protected."}
        </h1>
        <p style={{ fontFamily: FONT, fontSize: 19 * scale, lineHeight: 1.4, fontWeight: 500, color: pal.inkSoft, margin: '12px 6px 0', textWrap: 'pretty' }}>
          {armed ? "I'm listening for scams in the background. Carry on as normal." : "Turn on Guardian Mode and I'll watch your calls for scams."}
        </p>
      </div>
      <div style={{ marginTop: 26, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <ReadyRow icon={Ic.key(pal.brand, 22)} label="Family safe-word" value={watchword || 'Not set'} />
        <ReadyRow icon={Ic.bell(pal.brand, 22)} label="Guardian" value={guardian ? `${guardian}` : 'Not set'} />
      </div>
    </Screen>
  );
}

function ReadyRow({ icon, label, value }) {
  const { pal, scale } = useTheme();
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px', borderRadius: 18, background: pal.surface, border: `1.5px solid ${pal.lineSoft}` }}>
      <div style={{ width: 42, height: 42, borderRadius: 12, background: pal.brandTint, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>{icon}</div>
      <div style={{ flex: 1, fontFamily: FONT, fontSize: 17 * scale, fontWeight: 600, color: pal.inkSoft }}>{label}</div>
      <div style={{ fontFamily: FONT, fontSize: 17 * scale, fontWeight: 800, color: pal.ink }}>{value}</div>
      <span style={{ marginLeft: 2 }}>{Ic.check(pal.safe, 22)}</span>
    </div>
  );
}

Object.assign(window, { BrandMark, ProgressDots, Screen, BackBtn, Onboarding, Watchword, Guardian, Home, ReadyRow });
