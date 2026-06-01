// kavach-screens-live.jsx — Live Shield (SAFE/CAUTION/HIGH) + post-call summary

// Ink that reads on the solid risk banner (amber needs dark ink)
function bannerInk(level) {
  return level === 'CAUTION' ? '#3a2c00' : '#ffffff';
}

function RiskMeter({ level }) {
  const idx = { SAFE: 0, CAUTION: 1, HIGH: 2 }[level];
  const ink = bannerInk(level);
  const labels = ['Safe', 'Careful', 'Scam'];
  return (
    <div style={{ marginTop: 4 }}>
      <div style={{ display: 'flex', gap: 6 }}>
        {[0, 1, 2].map((i) => (
          <div key={i} style={{
            flex: 1, height: 7, borderRadius: 99,
            background: i <= idx ? ink : (ink === '#ffffff' ? 'rgba(255,255,255,0.28)' : 'rgba(58,44,0,0.22)'),
            transition: 'background .3s',
          }} />
        ))}
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 7 }}>
        {labels.map((l, i) => (
          <span key={l} style={{ fontFamily: FONT, fontSize: 12.5, fontWeight: 800, letterSpacing: 0.5, textTransform: 'uppercase', color: ink, opacity: i === idx ? 1 : 0.45 }}>{l}</span>
        ))}
      </div>
    </div>
  );
}

function ExplainCard({ text, level }) {
  const { pal, dark, scale } = useTheme();
  return (
    <div style={{
      display: 'flex', gap: 13, alignItems: 'flex-start', padding: '16px 17px',
      borderRadius: 18, background: pal.surface, border: `1.5px solid ${pal.lineSoft}`,
    }}>
      <div style={{ flexShrink: 0, width: 12, height: 12, borderRadius: 99, marginTop: 7, background: riskColor(level, dark) }} />
      <p style={{ margin: 0, fontFamily: FONT, fontSize: 19 * scale, lineHeight: 1.4, fontWeight: 600, color: pal.ink, textWrap: 'pretty' }}>{text}</p>
    </div>
  );
}

function WatchwordCard({ watchword }) {
  const { pal, scale } = useTheme();
  const [show, setShow] = React.useState(false);
  return (
    <div style={{ padding: '17px 18px', borderRadius: 20, background: pal.brandTint, border: `1.5px solid ${pal.dark ? pal.line : 'transparent'}` }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
        {Ic.key(pal.brand, 24)}
        <span style={{ fontFamily: FONT, fontSize: 18.5 * scale, fontWeight: 800, color: pal.dark ? pal.ink : pal.brandInk }}>Not sure it's really them?</span>
      </div>
      <p style={{ margin: '9px 0 0', fontFamily: FONT, fontSize: 17 * scale, lineHeight: 1.35, fontWeight: 600, color: pal.inkSoft }}>
        Ask them your family safe-word. A real loved one will know it.
      </p>
      <button onClick={() => setShow((s) => !s)} style={{
        marginTop: 13, width: '100%', padding: '14px 18px', borderRadius: 14, cursor: 'pointer',
        border: `2px dashed ${pal.brand}`, background: pal.surface,
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
        fontFamily: FONT, fontSize: 21 * scale, fontWeight: 800, color: pal.ink, letterSpacing: show ? 0.5 : 3,
      }}>
        {show ? watchword : '••••••'}
        <span style={{ opacity: 0.6 }}>{Ic.eye(pal.inkSoft, 20)}</span>
      </button>
      <div style={{ marginTop: 8, textAlign: 'center', fontFamily: FONT, fontSize: 13.5 * scale, fontWeight: 700, color: pal.inkFaint }}>
        {show ? 'Ask for it — never say it first' : 'Tap to reveal'}
      </div>
    </div>
  );
}

function GuardianStatus({ status, name }) {
  const { pal, dark, scale } = useTheme();
  if (status === 'idle') {
    return (
      <Row bg={pal.surface2} icon={Ic.bell(pal.inkSoft, 22)} ink={pal.inkSoft}>
        Guardian <b style={{ color: pal.ink }}>{name}</b> is ready to be alerted
      </Row>
    );
  }
  if (status === 'alerting') {
    return (
      <Row bg={riskTint('CAUTION', pal)} icon={<Spinner color={riskInk('CAUTION', dark)} />} ink={riskInk('CAUTION', dark)}>
        Alerting <b>{name}</b>…
      </Row>
    );
  }
  return (
    <Row bg={riskTint('SAFE', pal)} icon={Ic.check(riskInk('SAFE', dark), 22)} ink={riskInk('SAFE', dark)}>
      <b>{name}</b> has been told about this call
    </Row>
  );
}

function Row({ children, bg, icon, ink }) {
  const { scale } = useTheme();
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 16px', borderRadius: 16, background: bg }}>
      <span style={{ flexShrink: 0, display: 'flex' }}>{icon}</span>
      <span style={{ fontFamily: FONT, fontSize: 16.5 * scale, fontWeight: 600, color: ink, lineHeight: 1.3 }}>{children}</span>
    </div>
  );
}

function Spinner({ color }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke={color} strokeOpacity="0.25" strokeWidth="3"/><path d="M12 3a9 9 0 019 9" fill="none" stroke={color} strokeWidth="3" strokeLinecap="round"><animateTransform attributeName="transform" type="rotate" from="0 12 12" to="360 12 12" dur="0.9s" repeatCount="indefinite"/></path></svg>
  );
}

function TranscriptStrip({ lines }) {
  const { pal, scale } = useTheme();
  const last = lines.slice(-2);
  return (
    <div style={{ padding: '13px 16px', borderRadius: 16, background: pal.surface2 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 7 }}>
        <span style={{ width: 7, height: 7, borderRadius: 99, background: pal.high }} />
        <span style={{ fontFamily: FONT, fontSize: 12.5 * scale, fontWeight: 800, letterSpacing: 0.6, textTransform: 'uppercase', color: pal.inkFaint }}>Live transcript</span>
      </div>
      {last.map((l, i) => (
        <div key={i} style={{ fontFamily: FONT, fontSize: 15.5 * scale, lineHeight: 1.35, fontWeight: 500, color: i === last.length - 1 ? pal.ink : pal.inkFaint, marginTop: i ? 4 : 0 }}>
          <span style={{ fontWeight: 800, color: pal.inkSoft }}>Caller:</span> "{l.line}"
        </div>
      ))}
    </div>
  );
}

// ───────────────────────── 5 · LIVE SHIELD (hero) ─────────────────────────
function LiveShield({ level, explanations, tactics, guardianStatus, transcript, watchword, guardianName, detail, onHangup, onSafe, live }) {
  const { pal, dark, scale } = useTheme();
  const r = RISK[level];
  const color = riskColor(level, dark);
  const ink = bannerInk(level);
  const minimal = detail === 'minimal';
  const showChips = !minimal && tactics.length > 0;
  const showTranscript = !minimal && transcript && transcript.length > 0;
  const exps = minimal ? explanations.slice(0, 1) : explanations;

  return (
    <div style={{ minHeight: '100%', display: 'flex', flexDirection: 'column', background: pal.bg }}>
      {/* Banner — full-bleed risk color to the very top */}
      <div style={{ background: color, padding: '54px 24px 24px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ width: 9, height: 9, borderRadius: 99, background: ink, animation: live ? 'kvpulse 1.4s ease-in-out infinite' : 'none' }} />
            <span style={{ fontFamily: FONT, fontSize: 13.5, fontWeight: 800, letterSpacing: 0.8, textTransform: 'uppercase', color: ink, opacity: 0.9 }}>Live · on call</span>
          </div>
          <span style={{ fontFamily: FONT, fontSize: 14, fontWeight: 700, color: ink, opacity: 0.8 }}>Unknown number</span>
        </div>

        <div style={{ marginTop: 18, display: 'flex', alignItems: 'center', gap: 14 }}>
          <Shield size={62} color={ink} listening={live && level === 'SAFE'} />
          <div style={{ minWidth: 0 }}>
            <div style={{ fontFamily: FONT, fontSize: 38 * scale, lineHeight: 1.04, fontWeight: 800, color: ink, letterSpacing: -0.5, textWrap: 'balance' }}>{r.banner}</div>
          </div>
        </div>
        <p style={{ margin: '12px 0 18px', fontFamily: FONT, fontSize: 21 * scale, lineHeight: 1.25, fontWeight: 700, color: ink, opacity: 0.95 }}>{r.sub}</p>
        <RiskMeter level={level} />
      </div>

      {/* Body */}
      <div style={{ flex: 1, padding: '20px 22px 0', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {exps.map((e, i) => <ExplainCard key={i} text={e} level={level} />)}

        {showChips && (
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 9, marginTop: 2 }}>
            {tactics.map((id) => <Chip key={id} label={TACTICS[id].chip} level={level} />)}
          </div>
        )}

        {level === 'HIGH' && <WatchwordCard watchword={watchword} />}

        {level !== 'SAFE' && <GuardianStatus status={guardianStatus} name={guardianName} />}

        {showTranscript && <TranscriptStrip lines={transcript} />}
      </div>

      {/* Actions — sticky */}
      <div style={{ position: 'sticky', bottom: 0, padding: '16px 22px 30px', display: 'flex', flexDirection: 'column', gap: 11, background: `linear-gradient(to top, ${pal.bg} 74%, transparent)` }}>
        {level === 'SAFE' ? (
          <Button label="End call" kind="soft" onClick={onSafe} />
        ) : (
          <>
            <Button label="Hang up & call back" sub="on their real number" kind="danger" icon={Ic.phoneOff('#fff', 24)} onClick={onHangup} />
            <Button label="I'm safe — dismiss" kind="secondary" onClick={onSafe} />
          </>
        )}
      </div>
    </div>
  );
}

// ───────────────────────── 6 · Post-call summary ─────────────────────────
function Summary({ level, tactics, guardianName, guardianStatus, go }) {
  const { pal, dark, scale } = useTheme();
  const wasScam = level === 'HIGH' || level === 'CAUTION';
  return (
    <Screen
      header={<BrandMark />}
      footer={<>
        <Button label="Back to home" onClick={() => go('home')} />
        {wasScam && <Button label="Block this number" kind="secondary" onClick={() => go('home')} />}
      </>}
    >
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', paddingTop: 22 }}>
        <div style={{ position: 'relative', width: 132, height: 132, borderRadius: 99, background: riskTint('SAFE', pal), display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {Ic.check(pal.safe, 64)}
        </div>
        <h1 style={{ fontFamily: FONT, fontSize: 32 * scale, lineHeight: 1.12, fontWeight: 800, color: pal.ink, margin: '22px 0 0', textWrap: 'balance' }}>
          {wasScam ? "You're safe." : 'Call ended.'}
        </h1>
        <p style={{ fontFamily: FONT, fontSize: 19 * scale, lineHeight: 1.4, fontWeight: 500, color: pal.inkSoft, margin: '12px 8px 0', textWrap: 'pretty' }}>
          {wasScam
            ? 'You did the right thing. When in doubt, hang up and call back on a number you already know.'
            : 'Kavach was listening and nothing looked wrong.'}
        </p>
      </div>

      {wasScam && (
        <div style={{ marginTop: 26, padding: '18px 18px', borderRadius: 20, background: pal.surface, border: `1.5px solid ${pal.lineSoft}` }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 13 }}>
            <span style={{ fontFamily: FONT, fontSize: 13.5 * scale, fontWeight: 800, letterSpacing: 0.6, textTransform: 'uppercase', color: pal.inkFaint }}>What Kavach noticed</span>
            <span style={{ marginLeft: 'auto', padding: '5px 12px', borderRadius: 99, background: riskTint(level, pal), color: riskInk(level, dark), fontFamily: FONT, fontSize: 13.5 * scale, fontWeight: 800 }}>{RISK[level].banner}</span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 11 }}>
            {tactics.slice(0, 4).map((id) => (
              <div key={id} style={{ display: 'flex', gap: 11, alignItems: 'flex-start' }}>
                <div style={{ flexShrink: 0, width: 9, height: 9, borderRadius: 99, marginTop: 8, background: riskColor(level, dark) }} />
                <div style={{ fontFamily: FONT, fontSize: 16.5 * scale, lineHeight: 1.35, fontWeight: 600, color: pal.ink }}>{TACTICS[id].chip}</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {wasScam && guardianStatus === 'sent' && (
        <div style={{ marginTop: 12 }}>
          <Row bg={riskTint('SAFE', pal)} icon={Ic.check(riskInk('SAFE', dark), 22)} ink={riskInk('SAFE', dark)}>
            <b>{guardianName}</b> was notified about this call
          </Row>
        </div>
      )}
    </Screen>
  );
}

Object.assign(window, { LiveShield, Summary, RiskMeter, ExplainCard, WatchwordCard, GuardianStatus, TranscriptStrip, Row, Spinner, bannerInk });
