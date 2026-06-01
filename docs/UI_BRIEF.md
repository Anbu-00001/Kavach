# Kavach — UI / Design Brief

Hand this to a design pass (e.g. Claude). It's grounded in the real engine so the design binds to
data we actually produce and hits the demo beats.

## Who & tone
- **Users:** ordinary people + the elderly, and the family members who set it up for them.
- **Tone:** calm, trustworthy, protective — *not* alarmist. A shield, not a siren. Must be usable
  by someone who is panicking or not tech-savvy.
- **Accessibility is non-negotiable:** very large text, high contrast, huge tap targets, minimal
  words, one-handed use, works at arm's length. Support 12 languages (incl. Hindi, Tamil, Telugu,
  Bengali) — design must handle long translated strings and non-Latin scripts.

## Risk color system (from the engine)
- **SAFE** `#1f9d55` (green) — "Listening · looks normal"
- **CAUTION** `#f0b400` (amber) — "Be careful"
- **HIGH** `#e63946` (red) — "Likely a scam — stop"

## Data the UI binds to (produced by kavach-core `Verdict` + live pipeline)
- `level` (SAFE/CAUTION/HIGH), `level_label`, `score` (0–1)
- `tactics[]` (e.g. UNTRACEABLE_PAYMENT, SECRECY) → show as chips
- `explanations[]` — pre-vetted plain-language lines ("This caller is rushing you, asking for gift
  cards, and telling you to keep it secret")
- `actions[]` — what to do
- live `transcript` (rolling), `language` detected, `guardianStatus` (idle/alerting/sent),
  `watchword` (the family safe-word)

## Screens
1. **Onboarding / permission** — one calm screen explaining "Kavach listens to your calls on
   speaker and warns you about scams. Nothing leaves your phone." → grant mic.
2. **Watchword setup** — set a family safe-word a voice clone can't know.
3. **Guardian setup** — pick a trusted contact to alert on high-risk calls.
4. **Home** — big shield + one primary button: **Start Guardian Mode**. Calm, reassuring.
5. **LIVE SHIELD (hero screen)** — the screen that wins the demo. During a call:
   - Huge risk banner that fills with the risk color + `level_label`.
   - 1–2 plain-language `explanations` in large text (the "why").
   - `tactics[]` as small chips.
   - Big action buttons: **"Hang up & call them back on their real number"** and **"I'm safe"**.
   - **Watchword** prompt ("Ask them: <watchword>").
   - Guardian-alert status line.
   - Optional small live transcript strip.
6. **Post-call summary** (optional) — what was detected, reassurance.

## The three states to mock (LIVE SHIELD)
- **SAFE:** calm green, gentle "I'm listening, looks normal." Minimal.
- **CAUTION:** amber, "Be careful — this call has some scam signs," 1 explanation.
- **HIGH:** red, bold "Likely a scam — don't send money or codes," 2–3 explanations + big actions +
  Guardian-alerting badge. This is the money shot.

## Demo hero moment
A cloned-voice scam plays on speaker → shield climbs SAFE→CAUTION→HIGH in real time → HIGH screen
shows the plain explanation → Guardian alert fires to a family member's phone. Design for that arc.

## Tech constraints for the designer
- Flutter (Material 3 ok, but custom is welcome). Dark + light. Runs on a low-end 4 GB phone — keep
  it light (no heavy blur/animation that drops frames on an OPPO A18).
- It's an *advisory* tool: never claim certainty; CAUTION = "be careful", HIGH = "likely a scam".

---

## Paste-ready prompt for Claude design

> Design a Flutter mobile app UI called **Kavach** — an on-device shield that listens to phone
> calls on speaker and warns elderly users and families about AI voice-clone scams in real time.
> Tone: calm, trustworthy, protective — a shield, not a siren. **Accessibility-first**: very large
> text, high contrast, huge tap targets, minimal words, usable by a panicking non-tech-savvy
> elder. Risk colors: SAFE green `#1f9d55`, CAUTION amber `#f0b400`, HIGH red `#e63946`.
> Design these screens: (1) onboarding/permission, (2) Watchword (family safe-word) setup,
> (3) Guardian contact setup, (4) Home with a big "Start Guardian Mode" button, (5) the **Live
> Shield** screen in all three states (SAFE/CAUTION/HIGH) — a huge risk banner, 1–3 plain-language
> explanation lines (e.g. "This caller is rushing you, asking for gift cards, and telling you to
> keep it secret"), tactic chips, big buttons "Hang up & call them back on their real number" and
> "I'm safe", a Watchword prompt, and a Guardian-alert status, (6) optional post-call summary.
> Must support long translated strings (Hindi/Tamil). Give me clean Flutter widget code (Material 3,
> light+dark) that's light enough for a 4 GB phone. The HIGH state is the hero — make it
> unmistakable but not panic-inducing.
