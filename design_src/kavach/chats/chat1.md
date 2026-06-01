# Kavach Scam Shield

_Started 2026-06-01 17:00 UTC_

---

## User

The brief in one breath: Kavach is a calm, protective shield (not a siren) for elderly users + families. Accessibility-first — huge text, high contrast, big tap targets, works for someone panicking. Risk colors map to our engine: SAFE green #1f9d55 · CAUTION amber #f0b400 · HIGH red #e63946. Six screens; the Live Shield screen (in SAFE/CAUTION/HIGH states) is the hero that wins the demo.



Paste this into Claude design:

Design a Flutter mobile app UI called Kavach — an on-device shield that listens to phone calls on speaker and warns elderly users and families about AI voice-clone scams in real time. Tone: calm, trustworthy, protective — a shield, not a siren. Accessibility-first: very large text, high contrast, huge tap targets, minimal words, usable by a panicking non-tech-savvy elder. Risk colors: SAFE green #1f9d55, CAUTION amber #f0b400, HIGH red #e63946. Design these screens: (1) onboarding/permission, (2) Watchword (family safe-word) setup, (3) Guardian contact setup, (4) Home with a big "Start Guardian Mode" button, (5) the Live Shield screen in all three states (SAFE/CAUTION/HIGH) — a huge risk banner, 1–3 plain-language explanation lines (e.g. "This caller is rushing you, asking for gift cards, and telling you to keep it secret"), tactic chips, big buttons "Hang up & call them back on their real number" and "I'm safe", a Watchword prompt, and a Guardian-alert status, (6) optional post-call summary. Must support long translated strings (Hindi/Tamil). Give me clean Flutter widget code (Material 3, light+dark) that's light enough for a 4 GB phone. The HIGH state is the hero — make it unmistakable but not panic-inducing.

https://github.com/Anbu-00001/Kavach

## Assistant

_[tool: list_files]_

I'll start by exploring the design system and the GitHub repo, then ask you a few focused questions before building.

_[tool: github_get_tree]_

The design system is empty. Let me check the GitHub repo.

_[tool: github_read_file]_

Let me explore the core and docs to understand the actual data the UI binds to.

_[tool: github_get_tree]_

_[tool: github_get_tree]_

Let me read the key files: the UI brief, the engine, the taxonomy, and labels.

_[tool: github_read_file]_

_[tool: github_read_file]_

_[tool: github_read_file]_

_[tool: questions_v2]_

I have a strong understanding of the engine now — real risk levels, colors, 8 scam tactics each with pre-vetted explanations and actions, and the demo arc. Before I build, a few focused questions.

One important note up front: my medium is **HTML** — I'll build a high-fidelity, *interactive* clickable prototype of the Kavach app inside a realistic phone frame (light + dark, accessibility-first, all 6 screens, the Live Shield animating SAFE→CAUTION→HIGH). This is the right artifact for design review and demos. I can't emit production Flutter/Dart code, but the prototype becomes an exact visual spec your team ports. Flagging so expectations are set.

## User

Questions answered:
- scope: All 6 screens + Live Shield in all 3 states (full prototype)
- theme: Light (default) + dark toggle
- visual_direction: Warm & human — soft, reassuring, designed for a scared grandparent
- shield_motif: 3
- live_shield_layout: 1
- languages: Not this round — English only, design for it but don't build the toggle
- tweaks: Decide for me
- elder_mode: Decide for me

## Assistant

_[tool: update_todos]_

Got it. Light-default, warm & human, concentric "listening rings" shield, top-banner Live Shield, English-only. I'll build one fully interactive prototype in an Android phone frame (this is an Android/OPPO target), with the demo arc playable and a Tweaks panel. Let me set up.

_[tool: copy_starter_component]_

_[tool: read_file]_

_[tool: delete_file]_

The starter frame is locked to Material teal/Roboto and a fixed status bar — but my Live Shield needs full-bleed risk color to the very top, plus warm custom theming. I'll build a custom phone shell for full control. Let me remove the starter and grab the tweaks panel.

_[tool: copy_starter_component]_

_[tool: write_file]_

Now I'll commit to the design system and write the data layer grounded in the taxonomy.

**Kavach "warm shield" system:** Hanken Grotesque throughout (warm, humanist, huge x-height — legible at arm's length). Warm cream/sand neutrals (never cold gray). Brand = calm protective teal `#0E7C86` for idle/identity, so the SAFE green only ever means "verdict: normal." Big pill buttons (64px), generous radii, accessibility text-scale. Concentric "listening rings" shield. Live Shield = full-bleed risk banner up top, plain-language "why" + chips + actions below.

_[tool: write_file]_

Now the shared UI primitives — custom phone shell, the listening-rings shield, buttons, chips, icons — all theme-and-scale aware via context.

_[tool: write_file]_

## Assistant

_[tool: list_files]_

Let me check current project state before continuing.

_[tool: write_file]_

Data and UI primitives are in place. Now the setup screens (brand mark, onboarding, watchword, guardian, home).

_[tool: write_file]_

Now the hero — Live Shield (all three states) plus the post-call summary.

_[tool: write_file]_

Now the app controller — navigation, the playable demo timeline, theme provider, and the Tweaks panel.

_[tool: write_file]_

Finally, the main HTML that wires it all together.

_[tool: update_todos]_

Let me verify it loads cleanly before reviewing visually.

_[tool: show_html]_

_[tool: show_html]_

_[tool: get_webview_logs]_

_[tool: save_screenshot]_

No JS errors (font fetch is just the sandbox network; it'll load for the user). Let me screenshot the flow to check rendering across screens and states.

_[tool: view_image]_

_[tool: view_image]_

Onboarding looks excellent — calm, warm, clear hierarchy. Let me check the home screen reload worked.

_[tool: grep]_

The reload didn't navigate — my localStorage key guess was wrong. Let me find the actual key.

_[tool: grep]_

_[tool: str_replace_edit]_

`useTweaks` resets to defaults each load (it persists through the host, not localStorage). To inspect the hero states I'll temporarily point the default screen at the Live Shield, screenshot the three states + dark, then revert.

_[tool: save_screenshot]_

_[tool: view_image]_

_[tool: save_screenshot]_

The screenshot didn't reload the edited file. Let me reload first.

_[tool: view_image]_

_[tool: save_screenshot]_

The HIGH money shot looks strong. Let me scroll to verify chips, watchword, guardian status, and transcript below.

_[tool: view_image]_

_[tool: save_screenshot]_

_[tool: view_image]_

_[tool: save_screenshot]_

Let me precisely target the scroll container via the known DOM path and confirm it scrolls.

_[tool: view_image]_

_[tool: save_screenshot]_

The capture keeps resetting scroll — let me surface the scroll metrics directly into the page so I can read them.

_[tool: view_image]_

_[tool: str_replace_edit]_

Confirmed: the scroll container is `sh1443 / ch798` — it overflows and scrolls correctly; the capture tool just resets scrollTop. No layout bug. Let me revert the default to onboarding.

_[tool: delete_file]_

Let me clean up the debug screenshots, then hand off.

_[tool: done]_

_[tool: str_replace_edit]_

The Google Fonts CDN is blocked in this preview sandbox. Let me swap to the Bunny Fonts mirror (same family, privacy-friendly) which typically isn't blocked.

_[tool: done]_

Clean. The Bunny Fonts mirror loads Hanken Grotesque without issue. Let me fork the verifier for a thorough sweep.

_[tool: fork_verifier_agent]_

_[tool: update_todos]_

**Kavach is built** — a fully interactive, accessibility-first prototype in an Android phone frame, grounded in your real engine (taxonomy explanations, risk thresholds, and colors lifted verbatim from `kavach-core`).

**What's there**
- **All 6 screens, navigable:** Onboarding/permission → Watchword setup → Guardian setup → Home → Live Shield → Post-call summary.
- **Live Shield in all 3 states** — full-bleed risk banner up top, a climbing SAFE→CAREFUL→SCAM meter, plain-language "why" lines, tactic chips, the Watchword reveal card, Guardian-alert status, and a live transcript strip. The HIGH state is the money shot.
- **Playable demo arc:** on Home → "See how it works" runs the cloned-grandson scam — shield climbs SAFE→CAUTION→HIGH in real time as the transcript rolls, then the Guardian alert fires to Priya.
- **Design system:** warm "paper" neutrals (never cold gray), calm teal brand so SAFE-green only ever means *verdict*, Hanken Grotesque, 66px tap targets, concentric listening-rings shield.

**Tweaks panel** (toolbar toggle): Dark mode · Text size (100–165%) · Shield accent · jump Risk state · Detail level (Balanced / Minimal "elder mode") · Play demo · jump to any Screen.

**Notes / next steps**
- English only this round, but type and layout already absorb long strings — Hindi/Tamil is a content swap, not a redesign.
- This is the visual spec your team ports to Flutter; the risk colors, tactic chips, and explanation strings map 1:1 to `Verdict`.
- Happy to add the multilingual toggle, a real "incoming call" pre-screen, or lay the three Live Shield states side-by-side on a canvas for stakeholder review — just say which.

