# Kavach — Privacy & Classification

Two questions decide whether a victim-side call shield is trustworthy:
**how do you protect the privacy of the people on the call**, and
**how do you decide a call is a scam**. This is Kavach's answer, and how the
guarantees are enforced in the actual code — not just promised.

---

## 1 · How the privacy of the call is protected

### a. Everything runs on the device — provably
The whole detection pipeline — tokenizer, the MiniLM classifier (ONNX Runtime),
and the risk fusion — executes **locally on the phone**. There is no server, no
account, no upload.

This isn't a slogan; it's enforced by the Android manifest:

- `android/app/src/main/AndroidManifest.xml` (the **release** manifest) declares
  **no permissions at all** — in particular **no `android.permission.INTERNET`**.
  An app without that permission *cannot open a socket*. The OS guarantees it.
- `INTERNET` appears only in the `debug`/`profile` manifests, which Flutter needs
  for hot-reload during development. It is **never** in a shipped build.

So the strongest possible privacy statement is true here: the production app
**physically cannot transmit call content** anywhere, because it has no way to
reach the network.

### b. Audio is ephemeral — nothing is recorded
The design processes sound in a **rolling in-RAM buffer**: audio → on-device
speech-to-text → text window → classify → **discard**. 

- No audio file is ever written to storage.
- No transcript is persisted. The only thing saved to disk
  (`shared_preferences`, see `lib/store.dart`) is **setup**: the safe-word,
  the chosen Guardian, and the armed flag. No call data, ever.
- Because nothing is recorded, this is categorically **not** wiretapping. Real-
  time analysis that is immediately forgotten is the same legal/ethical class as
  a hearing aid, or a relative listening on speakerphone — not a recording device.

### c. On-device speech-to-text, not cloud STT
When live-mic capture lands, ASR uses **Vosk**, which runs **fully offline**.
We deliberately do **not** use Android's default `SpeechRecognizer`, because on
many phones that streams audio to Google's servers — which would break the whole
on-device promise. Offline ASR is a privacy requirement, not a convenience.

### d. Data minimisation — we don't profile anyone
Kavach computes exactly one thing per window: **8 tactic probabilities** for the
*current* utterance. It does **not**:

- identify or fingerprint the caller's voice (no speaker ID, no voiceprint),
- store who called or what number,
- build any profile of the caller or the user.

The scammer on the other end is never identified and never stored. We look at the
*manipulation pattern in the words* on a call the user is already party to, and
then forget it.

### e. Advisory to the user, not a report to anyone
The output is a **private, on-screen nudge to the user** (the person the call is
trying to defraud), who is running the tool on their own device for their own
protection and has consented. The only outbound signal is the **Guardian alert**,
which (1) is user-configured, (2) fires only on a HIGH-risk event, and (3) carries
a minimal "this call looks like a scam" — not a recording or transcript. In the
current build the Guardian step is a local simulation.

---

## 2 · How a call is classified as a scam

### a. We classify the *script*, not the *person* or the *voice*
This is the core idea — and it is also why Kavach is privacy-respecting and fair.
The model never sees *who* is calling. It scores the **manipulation tactics** in
what is *said*. The taxonomy (`core/taxonomy.json`) is 8 tactics:

| Tactic | Plain meaning |
|---|---|
| URGENCY | rushing you, no time to think |
| SECRECY | "don't tell anyone" |
| UNTRACEABLE_PAYMENT | gift cards, crypto, wire |
| AUTHORITY_IMPERSONATION | "this is the police / your bank / the tax office" |
| DISTRESS_HOOK | fear about a loved one to stop clear thinking |
| ISOLATION | "stay on the line, don't hang up" |
| IDENTITY_PROBE | asking for codes / PIN / password |
| RELATIONSHIP_SPOOF | "it's me" with an excuse for a strange voice |

A real bank, a real official, and a real grandchild do **none** of these. A scam
script does several at once.

### b. The pipeline (real, on-device, auditable)
```
text → WordPiece tokenize → MiniLM int8 classifier → 8 sigmoid probabilities
     → noisy-OR fusion (+ dangerous-combo boosts + acoustic cue) → score → risk level
```
- **Multi-label**: one sentence can carry several tactics, so we use sigmoid (not
  softmax) — "buy gift cards and don't tell anyone" lights up *payment* **and**
  *secrecy*.
- **Fusion** (`lib/engine/fusion.dart`, a 1:1 port of `app/rust/kavach_core` and
  `core/reference_detector.py`): noisy-OR over `weight × probability` for tactics
  above 0.5, **plus boosts for dangerous combinations** (money+urgency +0.20,
  money+secrecy +0.25, money+distress +0.30, …), **plus** an optional acoustic
  synthetic-voice cue (weight 0.15). Clamp to [0,1].
- **Risk levels**: `SAFE < 0.45 ≤ CAUTION < 0.75 ≤ HIGH`.

### c. Why it generalises (not a keyword list)
The classifier was trained on multi-label tactic data **with hard negatives**
(legit calls that mention banks/money/appointments), so it keys on the *pattern of
coercion*, not banned words. It holds up on fresh adversarial lines and on **real
public data** (FTC robocall corpus, BothBosu) — not just on its own templates.

### d. Honest about the ceiling → advisory by design
On **ambiguous conversational** calls there is a genuine **precision ceiling
(~55%)** — aggressive telemarketing vs. a scam is fuzzy even for a human. We do
not hide this; we design around it:

- **CAUTION generously, HIGH only on decisive tactic clusters.**
- **Human-in-the-loop**: Kavach advises; the user decides.
- **Multi-signal**: the strongest verification isn't the model at all — it's the
  **family safe-word**, something an AI voice-clone cannot know. The model's job is
  to *prompt* that check at the right moment.
- Measured behaviour: clean legit calls correctly stay **SAFE** (e.g. "your
  appointment is confirmed" → 0.00); blatant scams correctly hit **HIGH** (e.g.
  "buy gift cards now" → 0.85). Verified live on the device.

### e. Multilingual — scams aren't only in English
Voice-scam fraud in India is overwhelmingly in Hindi, Tamil, Telugu, etc. Kavach
ships **two tiers**, both fully on-device:
- **English** — a 22MB MiniLM with a pure-Dart WordPiece tokenizer (fast, always on).
- **Multilingual (12 languages)** — a 118MB XLM-R model. Its SentencePiece
  (Unigram + Precompiled normalizer) tokenizer can't be reproduced in Dart, so the
  bundled **Rust `kavach_core` library tokenizes it over FFI** — the HF `tokenizers`
  crate, identical to the training pipeline, verified against Python in host tests.

Verified live on the phone: *"अभी गिफ्ट कार्ड खरीदो… किसी को मत बताना"* → **HIGH**
(UNTRACEABLE_PAYMENT + SECRECY), while *"आपकी डिलीवरी कल आ जाएगी"* → **SAFE**. The
tactics are language-independent — coercion looks the same in any language.

### f. Transparency — the verdict is not a black box
The **"Try it yourself"** screen shows the model's **actual per-tactic confidence**
for any text you type (English or any of the 12 languages), on the phone, offline.
The verdict is auditable and reproducible — never a canned script. The on-device
integration tests (`integration_test/engine_test.dart`, `ml_test.dart`) assert these
real outputs.

---

## TL;DR
- **Privacy**: on-device only (release build has *no* INTERNET permission → cannot
  transmit), audio is never recorded (rolling RAM buffer, discarded), offline ASR,
  no voiceprinting/profiling, advisory to the consenting user.
- **Classification**: score the manipulation *script* (8 tactics), not the person
  or voice; multi-label model → noisy-OR fusion + combo boosts → SAFE/CAUTION/HIGH;
  generalises beyond keywords; honest ~55% precision ceiling on ambiguous calls →
  advisory + safe-word as the real verifier; fully transparent and on-device.
