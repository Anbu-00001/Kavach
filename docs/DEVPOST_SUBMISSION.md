# Kavach — Devpost submission

*Copy-paste ready. Each section maps to a Devpost field. Written to read clear to both a human judge
AND the Round-1 AI evaluator (which scores **problem understanding** + **technical clarity**) — in a
real human voice, not corporate-robot voice. Every number here is backed; see
[EVALUATION.md](EVALUATION.md) and [RELEASE_PERMISSIONS.txt](RELEASE_PERMISSIONS.txt).*

---

## Tagline (one line)
**An offline, on-device shield that catches a phone scam by its manipulation *script* — not the
voice — and warns the victim *out loud, in their own language*, before the money's gone. Runs on a
$80 phone, with no internet permission at all.**

---

## Elevator pitch (≤ 200 characters)
Kavach hears a call on-device and flags the manipulation tactics every scam uses, then *speaks* the
warning aloud in Hindi/Tamil/Telugu. 100% offline. No internet permission. Runs on a ₹6,000 phone.

---

## The problem (and why it actually matters — especially in India)

Phone scams are the most expensive everyday crime, and AI voice cloning just removed the last tell.
The damage in India is staggering and accelerating:

- Indians lost **₹22,845 crore (~$2.7B) to cyber fraud in 2024 — a 206% jump** over 2023 (I4C / MHA).
- The **"digital arrest" scam alone drained ~₹19,000 crore in 2025**; I4C logged **92,000+** such
  cases in 2024. Fraudsters pose as CBI/ED/police, put an elderly victim on a hours-long video call,
  cut off their family, and bleed them dry "to clear their name."
- **60% of 2024 fraud victims were making their first-ever digital payment.** (Globally: FTC reports
  $12.5B lost in 2024; FBI IC3 logged ~$4.9B from Americans 60+, avg loss **$83,000**, up 43%.)

And the people who actually lose the money usually **can't read a warning on a screen.** In India
**half the illiterate population is over 50**, only **~11% of rural elders are digitally literate**,
and a cheap phone often has no Tamil/Hindi text-to-speech voice installed.

Here's what bugged us: **everything that exists protects institutions, not the person on the call.**
Carrier filters block numbers (scammers rotate them). Deepfake-voice detectors ask "is the voice
fake?" — useless when a *real human* reads the script. And they're all cloud services that would
have to **stream a vulnerable person's private call to a server** — shady, and in many places
illegal.

## What it does

Kavach turns the phone the victim already owns into a quiet bodyguard. Put the call on speaker, and it:

1. **Transcribes on-device** — offline streaming ASR (English via Vosk; **Tamil + ~99 languages via
   a bundled Whisper-tiny** model through sherpa-onnx).
2. **Scores the transcript against 8 manipulation tactics** — manufactured urgency, secrecy, untraceable
   payment (gift cards / crypto / wire / "transfer to a safe account"), authority impersonation,
   distress hook, isolation / stay-on-the-line, credential-OTP probe, relationship spoof.
3. **Accumulates risk across the *whole call*, not one sentence.** A conversation-level engine keeps
   a decaying memory of every tactic, so the patient scripts — the digital-arrest pattern where
   authority comes early and the money ask comes 15 minutes later — still add up. (On real FTC
   robocalls this lifts recall from **28% → 40%** vs scoring single windows.)
4. **Warns in plain language *and out loud*.** A big banner flips to **"Likely a scam,"** and — this
   is the part we're proudest of — Kavach **speaks the warning aloud in the user's language**
   ("Stop. This may be a scam. Don't send money or share any code. Hang up and call your family.")
   and **buzzes the phone**. Colour + voice + vibration, so it reaches someone who can't read, see
   well, or hear well. The clips and on-screen lines are **pre-recorded / pre-vetted — never
   AI-generated** — so it can't hallucinate to a panicking person.
5. **Shows its reasoning.** Tap a verdict and Kavach highlights the *exact words* the model relied on
   ("gift cards") via on-device occlusion attribution — its real reasoning, not a canned line.
6. **Hands over a human circuit-breaker** — the **Watchword** (a family safe-word a clone can't know)
   and one-tap "hang up and call the real person back."

It runs two ways on the same pipeline: a **live shield** (screen on) and a **background guardian**
(screen off, foreground service) whose notification flips to a warning the moment the script turns
dangerous. There's also a **Layer-0 unknown-caller** overlay that offers to shield calls from numbers
not in your contacts.

## How we built it

- **The thesis → a taxonomy.** The whole social-engineering playbook is encoded as 8 weighted tactics
  with cues and pre-vetted explanations in one `taxonomy.json` that drives *both* training labels and
  runtime fusion. Single source of truth, mirrored 1:1 across Python, Rust, and Dart.
- **Intent classifier.** Fine-tuned `all-MiniLM-L6-v2` as an 8-label multi-label classifier, **int8
  ONNX (22.9 MB)**, via ONNX Runtime on-device. A pure-Dart WordPiece tokenizer reproduces the Python
  token IDs exactly (parity-tested).
- **Multilingual (the painful part).** For 12 languages we use `paraphrase-multilingual-MiniLM`
  (int8 ONNX, ~118 MB) whose XLM-R **SentencePiece** tokenizer is rough to reimplement in Dart — so we
  cross-compiled the Hugging Face `tokenizers` Rust crate to a native arm64 lib (`libkavach_core.so`)
  and call it over `dart:ffi`. Token IDs match Python exactly.
- **Conversation-level risk.** `conversation_risk.dart` — a decaying-max memory per tactic, re-fused
  every window with the same taxonomy fusion, so spread-out tactics still combine. Unit-tested on the
  slow-burn flip (per-window CAUTION → cumulative HIGH).
- **Universal live ASR.** Whisper-tiny multilingual (int8, ~104 MB) + Silero VAD via sherpa-onnx —
  one model for Tamil + every Indian language + ~99 more. (Solving a nasty dual-`onnxruntime` native
  conflict to make it coexist with the classifier runtime took most of a day.)
- **Spoken warnings (accessibility).** Pre-recorded clips bundled in `res/raw`, played by a native
  Kotlin `MediaPlayer` on the accessibility audio stream + a vibration waveform — **no TTS voice
  needed**, works on the cheapest phone, adds **zero** dependencies and only the `VIBRATE` permission.
- **Privacy by construction.** The release `AndroidManifest.xml` declares **no `INTERNET`
  permission** — the app literally cannot transmit.

## Does it actually work on a real call? (the honest answer)

Since **Android 10, third-party apps cannot tap the call's remote-audio stream** — Google blocks it
(and OEMs like Samsung block it harder). We didn't fight that; we designed *with* it. Kavach is an
**ambient speakerphone guardian** — it listens to the room on speaker, the way a careful relative
beside you would. That's the only OS-sanctioned path, and it's *more* private: we never touch the
private call stream, which is exactly why we can ship with no internet permission. Likewise, the
spoken warning plays on the phone's **speaker** so the *victim* hears it (Android won't let any app
inject audio into the cellular uplink — which is fine, the warning is for the victim, not the scammer).

## What we verified on real hardware (OPPO A18, 4 GB, ColorOS)

- **Real on-device inference, not a script.** Live, unseen Hindi: `अभी गिफ्ट कार्ड खरीदो…` → **HIGH
  1.00** `[UNTRACEABLE_PAYMENT, SECRECY]`; a Hindi delivery note → **SAFE 0.00**. Tamil scam clip →
  **HIGH 0.91**. Engine loads in ~2.9 s.
- **The spoken warning + buzz fire on escalation** — confirmed through `dumpsys` (accessibility-stream
  audio + the exact CAUTION/HIGH vibration waveforms).
- **No internet, provably.** `aapt dump permissions` on the **release** APK → **`INTERNET` count: 0**
  (proof saved in [RELEASE_PERMISSIONS.txt](RELEASE_PERMISSIONS.txt)).
- **Honest accuracy, on independent data.** Against 1,378 **real FTC robocalls** + a balanced 160/160
  BothBosu set with the real on-device model: the conversation-level rule reaches **~99% recall / 65%
  precision** (caller-side) and recovers **40% of real robocalls vs 28%** for single-window scoring.
  We're upfront that precision on adversarial pushy-telemarketer calls is moderate — which is *why*
  Kavach is **advisory, never a blocker**, and pairs every verdict with the Watchword. Full method +
  weak spots in [EVALUATION.md](EVALUATION.md).

## Challenges we ran into

- **You can't tap a phone call on Android** → redesigned around the ambient speakerphone guardian
  (above).
- **SentencePiece on a phone** → real Rust tokenizer behind FFI instead of a janky reimplementation.
- **Dual `onnxruntime`** → the Whisper lib and the classifier lib each shipped a different ONNX
  Runtime; aligned both on 1.13.0 (app-jniLibs override + API pin) so they coexist.
- **The Android-14 foreground-service crash (this one hurt).** `startForeground()` kept killing the
  process on ColorOS with `CannotPostForegroundServiceNotificationException` *even with* notifications
  granted — the notification *channel* was never created on this ROM. We create it explicitly now. Dug
  out of on-device `dumpsys`/`logcat`, not guesswork. (ColorOS also suppresses app logcat, so we
  verified the spoken alert through system services instead.)

## Accomplishments we're proud of

- **It speaks up for the person who can't read the screen** — voice + vibration in their own language,
  offline, on a phone with no TTS voice installed. That's the difference between a cool demo and an
  actually-helpful tool for an elderly, illiterate victim.
- **It genuinely runs offline on a $80 phone** — ASR, tokenizer, classifier, fusion, spoken alerts.
- **Privacy you can audit in one line** — release APK, `INTERNET` count 0. Not a promise; a fact.
- **An honest eval on real fraud data**, with the weak spots named out loud.

## What we learned

Constraints make the product. "Run offline on a cheap phone, for someone who can't read" forced every
decision that made Kavach better than the cloud incumbents — private, hallucination-proof, accessible,
and scalable at ~$0 marginal cost. And the invariant in fraud isn't the tech, it's the
**manipulation** — so we fight the part that never changes.

## What's next

- Test during a live *cellular* call across more OEMs (we've validated ambient room audio + the full
  pipeline; the on-call mic path is OEM-dependent and next on the list).
- A real acoustic synthetic-voice signal into the (already-wired) fusion slot.
- Native-speaker re-recordings of the warning clips; more Indian languages.
- Opt-in Guardian SMS/alert to a trusted relative on a HIGH-risk call; field testing with elders.

## Built with
`flutter` · `dart` · `rust` · `dart:ffi` · `kotlin` · `onnxruntime` · `sherpa-onnx` · `whisper` ·
`vosk` · `silero-vad` · `huggingface-tokenizers` · `all-minilm-l6-v2` ·
`paraphrase-multilingual-minilm` · `flutter_background_service` · `flutter_local_notifications` ·
`android` · `cargo-ndk`

## Submission checklist
- [ ] GitHub repo URL
- [ ] Demo video (≤ ~3 min) — **open on the airplane-mode / no-internet shot, end on the phone
      *speaking* the Tamil/Hindi warning**
- [ ] Pitch deck
- [x] Screenshots — see [screenshots/](screenshots/) + [CAPTIONS.md](screenshots/CAPTIONS.md)
- [x] Release APK (`app-release.apk`) + [RELEASE_PERMISSIONS.txt](RELEASE_PERMISSIONS.txt) no-internet proof
