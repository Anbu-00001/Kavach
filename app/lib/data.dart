// data.dart — risk levels, scam-tactic taxonomy, demo arc, canned verdicts.
// Mirrors core/taxonomy.json + core/reference_detector.py. Explanations are pre-vetted (never generated).
import 'package:flutter/material.dart';
import 'theme.dart';

class Risk {
  final String id, label, banner, sub;
  final Color color, colorDark;
  const Risk(this.id, this.label, this.banner, this.sub, this.color, this.colorDark);
}

final Map<String, Risk> kRisk = {
  'SAFE': Risk('SAFE', 'Looks normal', 'Listening', 'Nothing looks wrong.', hx('#1f9d55'), hx('#2bb56b')),
  'CAUTION': Risk('CAUTION', 'Be careful', 'Be careful', 'This call has some scam signs.', hx('#f0b400'), hx('#f5c233')),
  'HIGH': Risk('HIGH', 'Likely a scam', 'Likely a scam', "Don't send money or codes.", hx('#e63946'), hx('#ff5a64')),
};

class Tactic {
  final String chip;
  final double weight;
  final String explain;
  const Tactic(this.chip, this.weight, this.explain);
}

final Map<String, Tactic> kTactics = {
  'URGENCY': const Tactic('Rushing you', 0.7, 'This caller is rushing you. Real family and real banks let you take your time.'),
  'SECRECY': const Tactic('Keep it secret', 0.85, 'This caller wants you to keep it secret. Scammers do this so no one can warn you.'),
  'UNTRACEABLE_PAYMENT': const Tactic('Gift cards · wire', 0.95, 'This caller wants gift cards, crypto, or a wire transfer. No real family member or agency is ever paid this way.'),
  'AUTHORITY_IMPERSONATION': const Tactic('Claims to be official', 0.75, 'This caller claims to be the police, a bank, or the government. Real officials never demand payment over the phone.'),
  'DISTRESS_HOOK': const Tactic('Scary story', 0.8, 'This caller is using fear about a loved one to stop you thinking clearly. That panic is the attack.'),
  'ISOLATION': const Tactic("Won't let you hang up", 0.8, "This caller won't let you hang up — so no one else can warn you it's a scam."),
  'IDENTITY_PROBE': const Tactic('Wants codes · PIN', 0.9, 'This caller is asking for a code, PIN, or password. Real institutions never ask you to read these out.'),
  'RELATIONSHIP_SPOOF': const Tactic('"It\'s me" voice', 0.6, 'This caller claims to be family but excuses a strange voice. AI clones sound a little off.'),
};

class Beat {
  final int at;
  final String who, line, level, guardian;
  final List<String> tactics;
  final double score;
  const Beat(this.at, this.who, this.line, this.tactics, this.level, this.score, this.guardian);
}

/// A cloned-voice "grandson in trouble" scam climbing SAFE→CAUTION→HIGH.
final List<Beat> kDemoBeats = [
  const Beat(0, 'them', "Hello? Hi grandma… it's me.", [], 'SAFE', 0.12, 'idle'),
  const Beat(3200, 'them', "I know it's been a while. My voice sounds a bit off — I've got a cold.", ['RELATIONSHIP_SPOOF'], 'SAFE', 0.31, 'idle'),
  const Beat(7000, 'them', "Listen — I'm in trouble. There's been an accident and I need your help right now.", ['DISTRESS_HOOK', 'URGENCY'], 'CAUTION', 0.58, 'idle'),
  const Beat(11200, 'them', "Please don't tell mom or dad. Just go buy some gift cards and read me the numbers — hurry, before it's too late.", ['UNTRACEABLE_PAYMENT', 'SECRECY', 'URGENCY', 'DISTRESS_HOOK', 'RELATIONSHIP_SPOOF'], 'HIGH', 0.93, 'alerting'),
  const Beat(15000, 'sys', 'Guardian alert sent.', ['UNTRACEABLE_PAYMENT', 'SECRECY', 'URGENCY', 'DISTRESS_HOOK', 'RELATIONSHIP_SPOOF'], 'HIGH', 0.93, 'sent'),
];

class Verdict {
  final String level, guardian;
  final List<Map<String, String>> transcript;
  final List<String> tactics, explanations;
  final double score;
  bool live;
  Verdict(this.level, this.transcript, this.tactics, this.explanations, this.guardian, this.score, {this.live = false});
}

final Map<String, Verdict> kVerdicts = {
  'SAFE': Verdict('SAFE', [
    {'who': 'them', 'line': 'Hi, is this a good time to talk?'}
  ], [], ["I'm listening to this call. So far, it sounds normal."], 'idle', 0.12),
  'CAUTION': Verdict('CAUTION', [
    {'who': 'them', 'line': "Listen — I'm in trouble. There's been an accident."},
    {'who': 'them', 'line': "I need your help right now, I don't have much time."},
  ], ['DISTRESS_HOOK', 'URGENCY'], [kTactics['DISTRESS_HOOK']!.explain], 'idle', 0.58),
  'HIGH': Verdict('HIGH', [
    {'who': 'them', 'line': "Please don't tell mom or dad."},
    {'who': 'them', 'line': 'Just buy some gift cards and read me the numbers — hurry.'},
  ], ['UNTRACEABLE_PAYMENT', 'SECRECY', 'URGENCY', 'DISTRESS_HOOK', 'RELATIONSHIP_SPOOF'], [
    kTactics['UNTRACEABLE_PAYMENT']!.explain,
    kTactics['SECRECY']!.explain,
    kTactics['DISTRESS_HOOK']!.explain,
  ], 'sent', 0.93),
};

List<String> deriveExp(String level, List<String> tactics) {
  if (level == 'SAFE') return ["I'm listening to this call. So far, it sounds normal."];
  final sorted = [...tactics]..sort((a, b) => kTactics[b]!.weight.compareTo(kTactics[a]!.weight));
  return sorted.take(level == 'HIGH' ? 3 : 1).map((id) => kTactics[id]!.explain).toList();
}

Verdict buildVerdict(String level) {
  final v = kVerdicts[level]!;
  return Verdict(level, v.transcript, v.tactics, v.explanations, v.guardian, v.score, live: false);
}

// ── risk color helpers ──
Color riskColor(String level, bool dark) => dark ? kRisk[level]!.colorDark : kRisk[level]!.color;
Color riskTint(String level, Pal p) =>
    level == 'SAFE' ? p.safeTint : level == 'CAUTION' ? p.cautionTint : p.highTint;
Color riskInk(String level, bool dark) {
  if (dark) return {'SAFE': hx('#7ee0a6'), 'CAUTION': hx('#f7d06a'), 'HIGH': hx('#ff9aa1')}[level]!;
  return {'SAFE': hx('#0d6b38'), 'CAUTION': hx('#7a5800'), 'HIGH': hx('#b21e2b')}[level]!;
}

Color bannerInk(String level) => level == 'CAUTION' ? hx('#3a2c00') : Colors.white;
