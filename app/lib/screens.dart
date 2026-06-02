// screens.dart — the six Kavach screens, ported from the design bundle.
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';
import 'widgets.dart';
import 'engine/kavach_engine.dart';

// ════════════ 1 · Onboarding ════════════
class OnboardingScreen extends StatelessWidget {
  final VoidCallback onTurnOn;
  const OnboardingScreen({super.key, required this.onTurnOn});
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    return KScreen(
      header: const Align(alignment: Alignment.centerLeft, child: BrandMark()),
      footer: [
        KButton('Turn on protection', sub: 'Kavach will ask to use the microphone', icon: Icons.mic_none, onTap: onTurnOn),
        Text("It only listens while you're on a call.", textAlign: TextAlign.center, style: kfont(14.5 * t.scale, FontWeight.w600, p.inkFaint)),
      ],
      body: Column(children: [
        const SizedBox(height: 18),
        Shield(size: 184, color: p.brand, listening: true),
        const SizedBox(height: 26),
        Text('A quiet shield\non every call.', textAlign: TextAlign.center, style: kfont(33 * t.scale, FontWeight.w800, p.ink, height: 1.12)),
        const SizedBox(height: 16),
        Text('Kavach listens to your calls on speaker and warns you if someone is trying to scam you.',
            textAlign: TextAlign.center, style: kfont(19.5 * t.scale, FontWeight.w500, p.inkSoft, height: 1.45)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: p.brandTint, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.lock_outline, color: p.brand, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: RichText(text: TextSpan(children: [
              TextSpan(text: 'Nothing ever leaves your phone.\n', style: kfont(17 * t.scale, FontWeight.w700, p.dark ? p.ink : p.brandInk, height: 1.35)),
              TextSpan(text: 'No cloud. No account.', style: kfont(17 * t.scale, FontWeight.w600, p.inkSoft, height: 1.35)),
            ]))),
          ]),
        ),
      ]),
    );
  }
}

// ════════════ 2 · Watchword ════════════
class WatchwordScreen extends StatefulWidget {
  final String watchword;
  final ValueChanged<String> onChanged;
  final VoidCallback onBack, onSave;
  const WatchwordScreen({super.key, required this.watchword, required this.onChanged, required this.onBack, required this.onSave});
  @override
  State<WatchwordScreen> createState() => _WatchwordScreenState();
}

class _WatchwordScreenState extends State<WatchwordScreen> {
  late final TextEditingController c = TextEditingController(text: widget.watchword);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _set(String w) {
    c.text = w;
    c.selection = TextSelection.collapsed(offset: w.length);
    widget.onChanged(w);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    const ideas = ['Marigold', 'Banyan', 'Jubilee', 'Monsoon'];
    final set = c.text.trim().isNotEmpty;
    return KScreen(
      header: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [BackBtn(widget.onBack), const ProgressDots(0, 2), const SizedBox(width: 46)]),
      footer: [KButton('Save safe-word', disabled: !set, onTap: widget.onSave)],
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 6),
        Container(width: 64, height: 64, decoration: BoxDecoration(color: p.brandTint, borderRadius: BorderRadius.circular(20)), child: Icon(Icons.key_outlined, color: p.brand, size: 30)),
        const SizedBox(height: 20),
        Text('Set a family safe-word', style: kfont(30 * t.scale, FontWeight.w800, p.ink, height: 1.15)),
        const SizedBox(height: 12),
        Text("Pick a word only your family knows. A real loved one can say it — a scammer or a voice clone can't.",
            style: kfont(18.5 * t.scale, FontWeight.w500, p.inkSoft, height: 1.45)),
        const SizedBox(height: 22),
        TextField(
          controller: c,
          onChanged: (v) {
            widget.onChanged(v);
            setState(() {});
          },
          style: kfont(26 * t.scale, FontWeight.w800, p.ink, spacing: 0.3),
          decoration: InputDecoration(
            hintText: 'Type a word…',
            hintStyle: kfont(26 * t.scale, FontWeight.w800, p.inkFaint),
            filled: true, fillColor: p.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: set ? p.brand : p.line, width: 2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: p.brand, width: 2)),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final w in ideas)
            GestureDetector(
              onTap: () => _set(w),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.line, width: 2)),
                child: Text(w, style: kfont(16 * t.scale, FontWeight.w700, p.inkSoft)),
              ),
            ),
        ]),
        const SizedBox(height: 28),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.visibility_outlined, color: p.inkFaint, size: 20),
          const SizedBox(width: 11),
          Expanded(child: RichText(text: TextSpan(children: [
            TextSpan(text: "You'll only ever ", style: kfont(16 * t.scale, FontWeight.w600, p.inkFaint, height: 1.4)),
            TextSpan(text: 'ask', style: kfont(16 * t.scale, FontWeight.w800, p.inkSoft, height: 1.4)),
            TextSpan(text: ' for this word — never say it first.', style: kfont(16 * t.scale, FontWeight.w600, p.inkFaint, height: 1.4)),
          ]))),
        ]),
      ]),
    );
  }
}

// ════════════ 3 · Guardian ════════════
class GuardianScreen extends StatelessWidget {
  final String? guardian;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack, onFinish;
  const GuardianScreen({super.key, required this.guardian, required this.onSelect, required this.onBack, required this.onFinish});
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    const contacts = [
      ['Priya', 'Daughter', '#0E7C86'], ['Arjun', 'Son', '#7A5AE0'],
      ['Meera', 'Neighbour', '#C76A2B'], ['Dr. Rao', 'Family doctor', '#1f9d55'],
    ];
    return KScreen(
      header: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [BackBtn(onBack), const ProgressDots(1, 2), const SizedBox(width: 46)]),
      footer: [KButton('Finish setup', disabled: guardian == null, onTap: onFinish)],
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 6),
        Container(width: 64, height: 64, decoration: BoxDecoration(color: p.brandTint, borderRadius: BorderRadius.circular(20)), child: Icon(Icons.notifications_none, color: p.brand, size: 30)),
        const SizedBox(height: 20),
        Text('Choose your Guardian', style: kfont(30 * t.scale, FontWeight.w800, p.ink, height: 1.15)),
        const SizedBox(height: 12),
        Text('On a dangerous call, Kavach can quietly alert one person you trust.', style: kfont(18.5 * t.scale, FontWeight.w500, p.inkSoft, height: 1.45)),
        const SizedBox(height: 22),
        for (final c in contacts) ...[
          _ContactTile(name: c[0], rel: c[1], tone: hx(c[2]), selected: guardian == c[0], onTap: () => onSelect(c[0])),
          const SizedBox(height: 11),
        ],
        const SizedBox(height: 9),
        Text("They're only messaged on a HIGH-risk call, and they'll see what was detected.", style: kfont(15.5 * t.scale, FontWeight.w600, p.inkFaint, height: 1.4)),
      ]),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final String name, rel;
  final Color tone;
  final bool selected;
  final VoidCallback onTap;
  const _ContactTile({required this.name, required this.rel, required this.tone, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? p.brandTint : p.surface, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? p.brand : p.line, width: 2),
        ),
        child: Row(children: [
          CircleAvatar(radius: 26, backgroundColor: tone, child: Text(name[0], style: kfont(21 * t.scale, FontWeight.w800, Colors.white))),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: kfont(20 * t.scale, FontWeight.w800, p.ink)),
            Text(rel, style: kfont(16 * t.scale, FontWeight.w600, p.inkSoft)),
          ])),
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? p.brand : Colors.transparent, border: Border.all(color: selected ? p.brand : p.line, width: 2)),
            child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
          ),
        ]),
      ),
    );
  }
}

// ════════════ 4 · Home ════════════
class HomeScreen extends StatelessWidget {
  final bool armed;
  final String watchword;
  final String? guardian;
  final bool liveStarting;
  final String? liveError;
  final VoidCallback onArm, onStop, onDemo, onTry, onLive, onProfile;
  const HomeScreen({super.key, required this.armed, required this.watchword, required this.guardian, required this.liveStarting, required this.liveError, required this.onArm, required this.onStop, required this.onDemo, required this.onTry, required this.onLive, required this.onProfile});
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    return KScreen(
      header: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const BrandMark(),
        GestureDetector(onTap: onProfile, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: p.surface2, shape: BoxShape.circle), child: Icon(Icons.person_outline, color: p.inkSoft, size: 22))),
      ]),
      footer: armed
          ? [
              KButton(liveStarting ? 'Starting…' : 'Go live', sub: 'Listen to a real call on speaker', icon: liveStarting ? null : Icons.mic_none, disabled: liveStarting, onTap: onLive),
              KButton('See how it works', sub: 'Plays a sample scam call', kind: 'soft', icon: Icons.call, onTap: onDemo),
              KButton('Try it yourself', kind: 'ghost', icon: Icons.bolt, onTap: onTry),
            ]
          : [
              KButton('Start Guardian Mode', icon: Icons.shield_outlined, onTap: onArm),
              KButton('Try it yourself', kind: 'ghost', icon: Icons.bolt, onTap: onTry),
            ],
      body: Column(children: [
        const SizedBox(height: 30),
        Shield(size: 210, color: armed ? p.safe : p.brand, listening: armed),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: armed ? riskTint('SAFE', p) : p.surface2, borderRadius: BorderRadius.circular(99)),
          child: Text(armed ? '● LISTENING' : 'READY', style: kfont(15.5 * t.scale, FontWeight.w800, armed ? riskInk('SAFE', p.dark) : p.inkSoft, spacing: 0.4)),
        ),
        const SizedBox(height: 18),
        Text(armed ? 'Guardian Mode is on.' : "You're protected.", textAlign: TextAlign.center, style: kfont(31 * t.scale, FontWeight.w800, p.ink, height: 1.15)),
        const SizedBox(height: 12),
        Text(
          armed ? "I'm listening for scams in the background. Carry on as normal." : "Turn on Guardian Mode and I'll watch your calls for scams.",
          textAlign: TextAlign.center, style: kfont(19 * t.scale, FontWeight.w500, p.inkSoft, height: 1.4),
        ),
        const SizedBox(height: 26),
        _ReadyRow(icon: Icons.key_outlined, label: 'Family safe-word', value: watchword.isEmpty ? 'Not set' : watchword),
        const SizedBox(height: 10),
        _ReadyRow(icon: Icons.notifications_none, label: 'Guardian', value: guardian ?? 'Not set'),
        if (liveError != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.highTint, borderRadius: BorderRadius.circular(14)),
            child: Text(liveError!, style: kfont(14 * t.scale, FontWeight.w600, riskInk('HIGH', p.dark))),
          ),
        ],
        if (armed) ...[
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onStop,
            child: Text('Stop Guardian Mode', textAlign: TextAlign.center, style: kfont(15.5 * t.scale, FontWeight.w700, p.inkFaint)),
          ),
        ],
      ]),
    );
  }
}

class _ReadyRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _ReadyRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.lineSoft, width: 1.5)),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: p.brandTint, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: p.brand, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: kfont(17 * t.scale, FontWeight.w600, p.inkSoft))),
        Text(value, style: kfont(17 * t.scale, FontWeight.w800, p.ink)),
        const SizedBox(width: 6),
        Icon(Icons.check, color: p.safe, size: 22),
      ]),
    );
  }
}

// ════════════ 5 · Live Shield (hero) ════════════
class LiveShieldScreen extends StatelessWidget {
  final Verdict v;
  final String watchword;
  final String? guardianName;
  final bool minimal;
  final VoidCallback onHangup, onSafe;
  const LiveShieldScreen({super.key, required this.v, required this.watchword, required this.guardianName, required this.minimal, required this.onHangup, required this.onSafe});
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    final level = v.level;
    final r = kRisk[level]!;
    final color = riskColor(level, p.dark);
    final ink = bannerInk(level);
    final showChips = !minimal && v.tactics.isNotEmpty;
    final showTranscript = !minimal && v.transcript.isNotEmpty;
    final exps = minimal ? v.explanations.take(1).toList() : v.explanations;
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      color: p.bg,
      child: Column(children: [
        // Banner — full-bleed risk color
        Container(
          width: double.infinity,
          color: color,
          padding: EdgeInsets.fromLTRB(24, topPad + 18, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: ink, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('LIVE · ON CALL', style: kfont(13.5, FontWeight.w800, ink.withValues(alpha: 0.9), spacing: 0.8)),
              ]),
              Text('Unknown number', style: kfont(14, FontWeight.w700, ink.withValues(alpha: 0.8))),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              Shield(size: 62, color: ink, listening: v.live && level == 'SAFE'),
              const SizedBox(width: 14),
              Expanded(child: Text(r.banner, style: kfont(38 * t.scale, FontWeight.w800, ink, height: 1.04, spacing: -0.5))),
            ]),
            const SizedBox(height: 12),
            Text(r.sub, style: kfont(21 * t.scale, FontWeight.w700, ink.withValues(alpha: 0.95), height: 1.25)),
            const SizedBox(height: 18),
            _RiskMeter(level: level),
          ]),
        ),
        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
            child: Column(children: [
              for (final e in exps) Padding(padding: const EdgeInsets.only(bottom: 12), child: _ExplainCard(text: e, level: level)),
              if (showChips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(spacing: 9, runSpacing: 9, children: [
                    for (final id in v.tactics) KChip(kTactics[id]!.chip, tint: riskTint(level, p), ink: riskInk(level, p.dark)),
                  ]),
                ),
              if (level == 'HIGH') Padding(padding: const EdgeInsets.only(bottom: 12), child: _WatchwordCard(watchword: watchword)),
              if (level != 'SAFE') Padding(padding: const EdgeInsets.only(bottom: 12), child: _GuardianStatus(status: v.guardian, name: guardianName ?? 'your Guardian')),
              if (showTranscript) _TranscriptStrip(lines: v.transcript),
            ]),
          ),
        ),
        // Actions
        Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.bg.withValues(alpha: 0), p.bg], stops: const [0, 0.26])),
          child: level == 'SAFE'
              ? KButton('End call', kind: 'soft', onTap: onSafe)
              : Column(children: [
                  KButton('Hang up & call back', sub: 'on their real number', kind: 'danger', icon: Icons.call_end, onTap: onHangup),
                  const SizedBox(height: 11),
                  KButton("I'm safe — dismiss", kind: 'secondary', onTap: onSafe),
                ]),
        ),
      ]),
    );
  }
}

class _RiskMeter extends StatelessWidget {
  final String level;
  const _RiskMeter({required this.level});
  @override
  Widget build(BuildContext context) {
    final idx = {'SAFE': 0, 'CAUTION': 1, 'HIGH': 2}[level]!;
    final ink = bannerInk(level);
    const labels = ['SAFE', 'CAREFUL', 'SCAM'];
    final dim = ink == Colors.white ? Colors.white.withValues(alpha: 0.28) : hx('#3a2c00').withValues(alpha: 0.22);
    return Column(children: [
      Row(children: [
        for (var i = 0; i < 3; i++) ...[
          Expanded(child: Container(height: 7, decoration: BoxDecoration(color: i <= idx ? ink : dim, borderRadius: BorderRadius.circular(99)))),
          if (i < 2) const SizedBox(width: 6),
        ],
      ]),
      const SizedBox(height: 7),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var i = 0; i < 3; i++)
          Text(labels[i], style: kfont(12.5, FontWeight.w800, ink.withValues(alpha: i == idx ? 1 : 0.45), spacing: 0.5)),
      ]),
    ]);
  }
}

class _ExplainCard extends StatelessWidget {
  final String text, level;
  const _ExplainCard({required this.text, required this.level});
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.lineSoft, width: 1.5)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 7), child: Container(width: 12, height: 12, decoration: BoxDecoration(color: riskColor(level, p.dark), shape: BoxShape.circle))),
        const SizedBox(width: 13),
        Expanded(child: Text(text, style: kfont(19 * t.scale, FontWeight.w600, p.ink, height: 1.4))),
      ]),
    );
  }
}

class _WatchwordCard extends StatefulWidget {
  final String watchword;
  const _WatchwordCard({required this.watchword});
  @override
  State<_WatchwordCard> createState() => _WatchwordCardState();
}

class _WatchwordCardState extends State<_WatchwordCard> {
  bool show = false;
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      decoration: BoxDecoration(color: p.brandTint, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.dark ? p.line : Colors.transparent, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.key_outlined, color: p.brand, size: 24),
          const SizedBox(width: 11),
          Expanded(child: Text("Not sure it's really them?", style: kfont(18.5 * t.scale, FontWeight.w800, p.dark ? p.ink : p.brandInk))),
        ]),
        const SizedBox(height: 9),
        Text('Ask them your family safe-word. A real loved one will know it.', style: kfont(17 * t.scale, FontWeight.w600, p.inkSoft, height: 1.35)),
        const SizedBox(height: 13),
        GestureDetector(
          onTap: () => setState(() => show = !show),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.brand, width: 2, style: BorderStyle.solid)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(show ? widget.watchword : '••••••', style: kfont(21 * t.scale, FontWeight.w800, p.ink, spacing: show ? 0.5 : 3)),
              const SizedBox(width: 10),
              Icon(Icons.visibility_outlined, color: p.inkSoft, size: 20),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text(show ? 'Ask for it — never say it first' : 'Tap to reveal', style: kfont(13.5 * t.scale, FontWeight.w700, p.inkFaint))),
      ]),
    );
  }
}

class _GuardianStatus extends StatelessWidget {
  final String status;
  final String name;
  const _GuardianStatus({required this.status, required this.name});
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    if (status == 'idle') {
      return _InfoRow(bg: p.surface2, ink: p.inkSoft, icon: Icon(Icons.notifications_none, color: p.inkSoft, size: 22),
          rich: [TextSpan(text: 'Guardian '), TextSpan(text: name, style: kfont(16.5 * t.scale, FontWeight.w800, p.ink)), const TextSpan(text: ' is ready to be alerted')]);
    }
    if (status == 'alerting') {
      final ci = riskInk('CAUTION', p.dark);
      return _InfoRow(bg: riskTint('CAUTION', p), ink: ci, icon: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: ci)),
          rich: [const TextSpan(text: 'Alerting '), TextSpan(text: name, style: kfont(16.5 * t.scale, FontWeight.w800, ci)), const TextSpan(text: '…')]);
    }
    final si = riskInk('SAFE', p.dark);
    return _InfoRow(bg: riskTint('SAFE', p), ink: si, icon: Icon(Icons.check, color: si, size: 22),
        rich: [TextSpan(text: name, style: kfont(16.5 * t.scale, FontWeight.w800, si)), const TextSpan(text: ' has been told about this call')]);
  }
}

class _InfoRow extends StatelessWidget {
  final Color bg, ink;
  final Widget icon;
  final List<InlineSpan> rich;
  const _InfoRow({required this.bg, required this.ink, required this.icon, required this.rich});
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        icon,
        const SizedBox(width: 12),
        Expanded(child: RichText(text: TextSpan(style: kfont(16.5 * t.scale, FontWeight.w600, ink, height: 1.3), children: rich))),
      ]),
    );
  }
}

class _TranscriptStrip extends StatelessWidget {
  final List<Map<String, String>> lines;
  const _TranscriptStrip({required this.lines});
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    final last = lines.length > 2 ? lines.sublist(lines.length - 2) : lines;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: p.high, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('LIVE TRANSCRIPT', style: kfont(12.5 * t.scale, FontWeight.w800, p.inkFaint, spacing: 0.6)),
        ]),
        const SizedBox(height: 7),
        for (var i = 0; i < last.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
            child: RichText(text: TextSpan(children: [
              TextSpan(text: 'Caller: ', style: kfont(15.5 * t.scale, FontWeight.w800, p.inkSoft)),
              TextSpan(text: '"${last[i]['line']}"', style: kfont(15.5 * t.scale, FontWeight.w500, i == last.length - 1 ? p.ink : p.inkFaint, height: 1.35)),
            ])),
          ),
      ]),
    );
  }
}

// ════════════ 7 · Analyze (live, real model) ════════════
// Type/paste anything → the REAL on-device classifier + fusion run on this phone.
// This is the honest proof the engine isn't scripted: judges can try their own text.
class AnalyzeScreen extends StatefulWidget {
  final bool engineReady;
  final String? engineError;
  final bool mlReady, mlLoading;
  final String? mlError;
  final Future<void> Function() loadMultilingual;
  final EngineResult? Function(String text, bool multilingual) analyze;
  final VoidCallback onBack;
  const AnalyzeScreen({
    super.key,
    required this.engineReady,
    required this.engineError,
    required this.mlReady,
    required this.mlLoading,
    required this.mlError,
    required this.loadMultilingual,
    required this.analyze,
    required this.onBack,
  });
  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  final c = TextEditingController();
  EngineResult? result;
  bool ran = false;
  bool ml = false; // selected tier: false = English, true = multilingual

  static const examplesEn = [
    'Your appointment is confirmed for Tuesday at 3pm.',
    'Buy gift cards now and read me the numbers, hurry.',
    "This is the tax office. Pay the fine immediately or you'll be arrested.",
  ];
  // Hindi + Tamil scams (Devanagari/Tamil go through the Rust SentencePiece lib).
  static const examplesMl = [
    'अभी गिफ्ट कार्ड खरीदो और नंबर बताओ, किसी को मत बताना',
    'இப்போது கிஃப்ட் கார்டு வாங்கி எண்களை சொல்லுங்கள்',
    'आपकी डिलीवरी कल सुबह आ जाएगी, धन्यवाद',
  ];

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _selectTier(bool multilingual) {
    setState(() {
      ml = multilingual;
      result = null;
      ran = false;
    });
    if (multilingual) widget.loadMultilingual();
  }

  void _run() {
    final text = c.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    final r = widget.analyze(text, ml);
    // Debug-only diagnostic; never logs user text in a release build.
    if (kDebugMode) {
      debugPrint('KAVACH_ANALYZE[${ml ? "ml" : "en"}]: "${text.length > 40 ? '${text.substring(0, 40)}…' : text}" -> ${r?.level} ${r?.score.toStringAsFixed(2)} ${r?.tactics}');
    }
    setState(() {
      result = r;
      ran = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    final ready = ml ? widget.mlReady : widget.engineReady;
    final loading = ml && widget.mlLoading;
    final label = loading ? 'Loading languages…' : (ready ? 'Analyze on this phone' : 'Loading model…');
    final examples = ml ? examplesMl : examplesEn;
    return KScreen(
      header: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        BackBtn(widget.onBack),
        Text('Try it yourself', style: kfont(19 * t.scale, FontWeight.w800, p.ink)),
        const SizedBox(width: 46),
      ]),
      footer: [
        KButton(label, icon: (ready && !loading) ? Icons.bolt : null, disabled: !ready, onTap: _run),
        Text('Runs entirely on this phone. No internet, nothing stored.', textAlign: TextAlign.center, style: kfont(13.5 * t.scale, FontWeight.w600, p.inkFaint)),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 6),
        Text('What did the caller say?', style: kfont(26 * t.scale, FontWeight.w800, p.ink, height: 1.15)),
        const SizedBox(height: 10),
        Text('Paste or type any message. The real model — the same one that runs on a live call — scores it right here, offline.',
            style: kfont(16.5 * t.scale, FontWeight.w500, p.inkSoft, height: 1.4)),
        const SizedBox(height: 14),
        _TierToggle(ml: ml, mlLoading: widget.mlLoading, onSelect: _selectTier),
        const SizedBox(height: 16),
        TextField(
          controller: c,
          maxLines: 4,
          minLines: 3,
          style: kfont(18 * t.scale, FontWeight.w600, p.ink, height: 1.35),
          decoration: InputDecoration(
            hintText: 'e.g. "Grandma it\'s me, I\'m in trouble — don\'t tell anyone…"',
            hintStyle: kfont(16 * t.scale, FontWeight.w500, p.inkFaint, height: 1.35),
            filled: true, fillColor: p.surface,
            contentPadding: const EdgeInsets.all(18),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: p.line, width: 2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: p.brand, width: 2)),
          ),
        ),
        const SizedBox(height: 12),
        Text('OR TRY ONE', style: kfont(12.5 * t.scale, FontWeight.w800, p.inkFaint, spacing: 0.6)),
        const SizedBox(height: 8),
        Wrap(spacing: 9, runSpacing: 9, children: [
          for (final ex in examples)
            GestureDetector(
              onTap: () => setState(() => c.text = ex),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.line, width: 1.5)),
                child: Text(ex.length > 34 ? '${ex.substring(0, 32)}…' : ex, style: kfont(14 * t.scale, FontWeight.w600, p.inkSoft)),
              ),
            ),
        ]),
        if ((ml ? widget.mlError : widget.engineError) != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.highTint, borderRadius: BorderRadius.circular(14)),
            child: Text('Model failed to load: ${ml ? widget.mlError : widget.engineError}', style: kfont(14 * t.scale, FontWeight.w600, riskInk('HIGH', p.dark))),
          ),
        ],
        if (ran && result != null) ...[
          const SizedBox(height: 22),
          _ResultCard(result: result!),
        ],
      ]),
    );
  }
}

// Segmented English / multilingual tier selector.
class _TierToggle extends StatelessWidget {
  final bool ml, mlLoading;
  final ValueChanged<bool> onSelect;
  const _TierToggle({required this.ml, required this.mlLoading, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    Widget seg(String label, bool selected, VoidCallback onTap, {Widget? trailing}) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: selected ? p.brand : Colors.transparent, borderRadius: BorderRadius.circular(13)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label, style: kfont(15.5 * t.scale, FontWeight.w800, selected ? p.onColor : p.inkSoft)),
                if (trailing != null) ...[const SizedBox(width: 8), trailing],
              ]),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        seg('English', !ml, () => onSelect(false)),
        seg(
          '12 languages',
          ml,
          () => onSelect(true),
          trailing: mlLoading
              ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: ml ? p.onColor : p.inkSoft))
              : null,
        ),
      ]),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final EngineResult result;
  const _ResultCard({required this.result});
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    final level = result.level;
    final color = riskColor(level, p.dark);
    // tactic probabilities, highest first, for transparent "why".
    final order = const ['URGENCY', 'SECRECY', 'UNTRACEABLE_PAYMENT', 'AUTHORITY_IMPERSONATION', 'DISTRESS_HOOK', 'ISOLATION', 'IDENTITY_PROBE', 'RELATIONSHIP_SPOOF'];
    final ranked = [for (var i = 0; i < order.length && i < result.probs.length; i++) (order[i], result.probs[i])]
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return Container(
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: p.lineSoft, width: 1.5), boxShadow: p.shadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // verdict header band
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
          child: Row(children: [
            // .label reads as a verdict ("Looks normal" / "Be careful" / "Likely a scam");
            // .banner is the live-shield wording ("Listening") and is wrong here.
            Expanded(child: Text(kRisk[level]!.label, style: kfont(24 * t.scale, FontWeight.w800, bannerInk(level)))),
            Text('${(result.score * 100).round()}%', style: kfont(24 * t.scale, FontWeight.w800, bannerInk(level))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // why — pre-vetted explanations for fired tactics
            if (result.tactics.isEmpty)
              Text("Nothing in this message looks like a scam tactic.", style: kfont(17 * t.scale, FontWeight.w600, p.ink, height: 1.4))
            else
              for (final e in deriveExp(level, result.tactics))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 7), child: Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
                    const SizedBox(width: 11),
                    Expanded(child: Text(e, style: kfont(16.5 * t.scale, FontWeight.w600, p.ink, height: 1.4))),
                  ]),
                ),
            const SizedBox(height: 8),
            Text('MODEL CONFIDENCE PER TACTIC', style: kfont(12 * t.scale, FontWeight.w800, p.inkFaint, spacing: 0.6)),
            const SizedBox(height: 10),
            for (final (id, prob) in ranked.take(4)) _ProbBar(label: kTactics[id]!.chip, prob: prob, color: color, p: p, scale: t.scale),
            const SizedBox(height: 6),
            Text('Real output from the on-device model — not a script.', style: kfont(12.5 * t.scale, FontWeight.w600, p.inkFaint)),
          ]),
        ),
      ]),
    );
  }
}

class _ProbBar extends StatelessWidget {
  final String label;
  final double prob;
  final Color color;
  final Pal p;
  final double scale;
  const _ProbBar({required this.label, required this.prob, required this.color, required this.p, required this.scale});
  @override
  Widget build(BuildContext context) {
    final fired = prob >= 0.5;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [
        SizedBox(width: 116, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: kfont(14 * scale, FontWeight.w700, fired ? p.ink : p.inkSoft))),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: prob.clamp(0.0, 1.0), minHeight: 8, backgroundColor: p.surface2, color: fired ? color : p.inkFaint),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 38, child: Text('${(prob * 100).round()}%', textAlign: TextAlign.right, style: kfont(13.5 * scale, FontWeight.w700, fired ? p.ink : p.inkFaint))),
      ]),
    );
  }
}

// ════════════ 6 · Summary ════════════
class SummaryScreen extends StatelessWidget {
  final String level, guardianStatus;
  final List<String> tactics;
  final String? guardianName;
  final VoidCallback onHome;
  const SummaryScreen({super.key, required this.level, required this.guardianStatus, required this.tactics, required this.guardianName, required this.onHome});
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    final wasScam = level == 'HIGH' || level == 'CAUTION';
    return KScreen(
      header: const Align(alignment: Alignment.centerLeft, child: BrandMark()),
      footer: [
        KButton('Back to home', onTap: onHome),
        if (wasScam) KButton('Block this number', kind: 'secondary', onTap: onHome),
      ],
      body: Column(children: [
        const SizedBox(height: 22),
        Container(width: 132, height: 132, decoration: BoxDecoration(color: riskTint('SAFE', p), shape: BoxShape.circle), child: Icon(Icons.check, color: p.safe, size: 64)),
        const SizedBox(height: 22),
        Text(wasScam ? "You're safe." : 'Call ended.', textAlign: TextAlign.center, style: kfont(32 * t.scale, FontWeight.w800, p.ink, height: 1.12)),
        const SizedBox(height: 12),
        Text(
          wasScam ? 'You did the right thing. When in doubt, hang up and call back on a number you already know.' : 'Kavach was listening and nothing looked wrong.',
          textAlign: TextAlign.center, style: kfont(19 * t.scale, FontWeight.w500, p.inkSoft, height: 1.4),
        ),
        if (wasScam) ...[
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.lineSoft, width: 1.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('WHAT KAVACH NOTICED', overflow: TextOverflow.ellipsis, style: kfont(13.5 * t.scale, FontWeight.w800, p.inkFaint, spacing: 0.6))),
                const SizedBox(width: 10),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: riskTint(level, p), borderRadius: BorderRadius.circular(99)), child: Text(kRisk[level]!.banner, style: kfont(13.5 * t.scale, FontWeight.w800, riskInk(level, p.dark)))),
              ]),
              const SizedBox(height: 13),
              for (final id in tactics.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 8), child: Container(width: 9, height: 9, decoration: BoxDecoration(color: riskColor(level, p.dark), shape: BoxShape.circle))),
                    const SizedBox(width: 11),
                    Expanded(child: Text(kTactics[id]!.chip, style: kfont(16.5 * t.scale, FontWeight.w600, p.ink, height: 1.35))),
                  ]),
                ),
            ]),
          ),
          if (guardianStatus == 'sent') ...[
            const SizedBox(height: 12),
            _InfoRow(bg: riskTint('SAFE', p), ink: riskInk('SAFE', p.dark), icon: Icon(Icons.check, color: riskInk('SAFE', p.dark), size: 22),
                rich: [TextSpan(text: guardianName ?? 'Your Guardian', style: kfont(16.5 * t.scale, FontWeight.w800, riskInk('SAFE', p.dark))), const TextSpan(text: ' was notified about this call')]),
          ],
        ],
      ]),
    );
  }
}
