// kavach-app.jsx — state, navigation, demo timeline, tweaks, mount

const SCREEN_LABELS = {
  'Onboarding': 'onboarding', 'Watchword': 'watchword', 'Guardian': 'guardian',
  'Home': 'home', 'Live Shield': 'live', 'Summary': 'summary',
};
const LABEL_BY_SCREEN = Object.fromEntries(Object.entries(SCREEN_LABELS).map(([k, v]) => [v, k]));

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "dark": false,
  "textScale": 100,
  "accent": "#0E7C86",
  "detail": "Balanced",
  "screen": "onboarding",
  "risk": "HIGH"
}/*EDITMODE-END*/;

function deriveExp(level, tactics) {
  if (level === 'SAFE') return ["I'm listening to this call. So far, it sounds normal."];
  const sorted = [...tactics].sort((a, b) => TACTICS[b].weight - TACTICS[a].weight);
  return sorted.slice(0, level === 'HIGH' ? 3 : 1).map((id) => TACTICS[id].explain);
}
function buildVerdict(level) {
  const v = VERDICTS[level];
  return { level, explanations: v.explanations, tactics: v.tactics, transcript: v.transcript, guardianStatus: v.guardian, live: false };
}

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const dark = !!t.dark;
  const accent = t.accent || '#0E7C86';
  const scale = (t.textScale || 100) / 100;
  const pal = React.useMemo(() => palette(dark, accent), [dark, accent]);
  const detail = t.detail === 'Minimal' ? 'minimal' : 'balanced';
  const screen = t.screen || 'onboarding';
  const risk = t.risk || 'HIGH';

  const [watchword, setWatchword] = React.useState('Marigold');
  const [guardian, setGuardian] = React.useState('Priya');
  const [armed, setArmed] = React.useState(false);
  const [demoActive, setDemoActive] = React.useState(false);
  const [liveData, setLiveData] = React.useState(() => buildVerdict('HIGH'));
  const [summaryData, setSummaryData] = React.useState({ level: 'HIGH', tactics: VERDICTS.HIGH.tactics, guardianStatus: 'sent' });
  const timers = React.useRef([]);
  const clearTimers = () => { timers.current.forEach(clearTimeout); timers.current = []; };

  const go = (s) => { if (s !== 'live') { clearTimers(); setDemoActive(false); } setTweak('screen', s); };

  const startDemo = () => {
    clearTimers();
    setDemoActive(true);
    setArmed(true);
    setTweak('screen', 'live');
    let acc = [];
    DEMO_BEATS.forEach((beat) => {
      const id = setTimeout(() => {
        acc = [...acc, { who: beat.who, line: beat.line }];
        setLiveData({
          level: beat.level,
          tactics: beat.tactics,
          explanations: deriveExp(beat.level, beat.tactics),
          transcript: acc.filter((l) => l.who === 'them'),
          guardianStatus: beat.guardian,
          live: true,
        });
      }, beat.at);
      timers.current.push(id);
    });
  };

  const onHangup = () => { clearTimers(); setDemoActive(false); setSummaryData({ level: liveData.level, tactics: liveData.tactics, guardianStatus: liveData.guardianStatus }); setTweak('screen', 'summary'); };
  const onSafe = () => { clearTimers(); setDemoActive(false); setArmed(true); setTweak('screen', 'home'); };

  const jumpRisk = (v) => { clearTimers(); setDemoActive(false); setTweak('risk', v); setLiveData(buildVerdict(v)); if (screen !== 'live') setTweak('screen', 'live'); };

  // When landing on Live Shield without a running demo, show the canned verdict for the chosen risk.
  React.useEffect(() => {
    if (screen === 'live' && !demoActive) setLiveData(buildVerdict(risk));
    // eslint-disable-next-line
  }, [screen]);

  React.useEffect(() => () => clearTimers(), []);

  // ── status / nav bar tone ──
  let statusTone = 'dark';
  if (dark) statusTone = 'light';
  else if (screen === 'live') statusTone = (liveData.level === 'CAUTION') ? 'dark' : 'light';
  const navTone = dark ? 'light' : 'dark';

  let body;
  if (screen === 'onboarding') body = <Onboarding go={go} />;
  else if (screen === 'watchword') body = <Watchword go={go} watchword={watchword} setWatchword={setWatchword} />;
  else if (screen === 'guardian') body = <Guardian go={go} guardian={guardian} setGuardian={setGuardian} />;
  else if (screen === 'home') body = <Home go={go} armed={armed} setArmed={setArmed} watchword={watchword} guardian={guardian} startDemo={startDemo} />;
  else if (screen === 'live') body = <LiveShield {...liveData} watchword={watchword} guardianName={guardian} detail={detail} onHangup={onHangup} onSafe={onSafe} />;
  else if (screen === 'summary') body = <Summary {...summaryData} guardianName={guardian} go={go} />;

  return (
    <ThemeCtx.Provider value={{ pal, dark, scale }}>
      <div style={{ minHeight: '100vh', width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '28px 16px', boxSizing: 'border-box', background: dark ? '#0c0a08' : '#efe7da' }}>
        <PhoneShell statusTone={statusTone} navTone={navTone} bg={pal.bg}>{body}</PhoneShell>
      </div>

      <TweaksPanel>
        <TweakSection label="Display" />
        <TweakToggle label="Dark mode" value={dark} onChange={(v) => setTweak('dark', v)} />
        <TweakSlider label="Text size" value={t.textScale || 100} min={100} max={165} step={5} unit="%" onChange={(v) => setTweak('textScale', v)} />
        <TweakColor label="Shield accent" value={accent} options={['#0E7C86', '#3F5BD9', '#8A4FBF', '#C76A2B']} onChange={(v) => setTweak('accent', v)} />

        <TweakSection label="Live Shield" />
        <TweakRadio label="Risk state" value={risk} options={['SAFE', 'CAUTION', 'HIGH']} onChange={jumpRisk} />
        <TweakRadio label="Detail level" value={t.detail || 'Balanced'} options={['Balanced', 'Minimal']} onChange={(v) => setTweak('detail', v)} />
        <TweakButton label="▶  Play the demo call" onClick={startDemo} />

        <TweakSection label="Navigate" />
        <TweakSelect label="Screen" value={LABEL_BY_SCREEN[screen] || 'Onboarding'} options={Object.keys(SCREEN_LABELS)} onChange={(lbl) => go(SCREEN_LABELS[lbl])} />
      </TweaksPanel>
    </ThemeCtx.Provider>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
