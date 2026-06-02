# Kavach — Devpost submission

*Copy-paste ready. Each section maps to a Devpost field. Written to read clear to both a human judge
AND the Round-1 AI evaluator (which scores **problem understanding** + **technical clarity**) — but
in an actual human voice, not corporate-robot voice.*

---

## Tagline (one line)
**An offline, on-device shield that catches a phone scam by its manipulation *script* — not the
voice — and warns the victim before the money's gone. Runs on a $80 phone, with no internet
permission at all.**

---

## Elevator pitch (≤ 200 characters, for the Devpost summary box)
Kavach listens to a call on-device and flags the 8 manipulation tactics every scam uses — urgency,
secrecy, "buy gift cards," fake authority. 100% offline. No internet permission. Runs on a 4GB phone.

---

## The problem (what we're solving + why it actually matters)

Phone scams are basically the most expensive everyday crime now, and AI voice cloning just took away
the last defense people had. In 2024, **US consumers reported $12.5B lost to fraud; imposter scams
were $2.95B** (FTC). **Adults 60+ reported $2.4B** — around 4× the 2020 figure — and the FTC thinks
the true cost is **$10.1–81.5B** once you account for underreporting. The **FBI IC3** logged
**~$4.9B** stolen from Americans 60+ in 2024, average loss **$83,000**, up 43% in one year.
Phone-based government-impersonation and tech-support scams alone drove **>$1.3B**.

And here's the part that bugged us: **everything that exists protects institutions, not the person
on the call.** Carrier filters block numbers (scammers just rotate them). Deepfake-voice detectors
ask "is the voice fake?" — useless when a real human reads the script, and they break on
phone-quality audio. And all of them are cloud services that'd have to **stream a vulnerable
person's private call to a server**, which is both shady and, in a lot of places, illegal.

## What it does

Kavach turns the phone the victim already owns into a quiet little bodyguard. Call on speaker, and it:

1. **Transcribes the call on-device** (offline streaming ASR).
2. **Scores the transcript against 8 manipulation tactics** — manufactured urgency, secrecy demand,
   untraceable-payment ask (gift cards / crypto / wire), authority impersonation, emotional distress
   hook, isolation / stay-on-the-line, credential-OTP probe, and relationship spoof.
3. **Fuses them into a risk level** (SAFE / CAUTION / HIGH), and boosts dangerous *combos* (money +
   urgency, money + distress) because when those co-occur it's almost never anything but fraud.
4. **Warns in plain language with an actual action** — *"this caller is rushing you and asking for
   gift cards — that's how scammers take money they can't be forced to return. Hang up and call back
   on a number you trust."* Those lines are **pre-written and deterministic — never AI-generated** —
   so the app can't hallucinate to a freaked-out user.
5. **Hands over a human circuit-breaker:** the **Watchword** (a family safe-word a clone can't know)
   and a one-tap "hang up and call the real person back."

It works two ways, both running the same on-device pipeline:
- **Live shield** (screen on) — a big, plain banner updates as the call goes.
- **Background guardian** (screen off) — a foreground service keeps watching; the persistent
  notification flips to **"⚠️ Possible scam on this call"** the second the script turns dangerous.

## How we built it

- **The thesis → a taxonomy.** We encoded the whole social-engineering playbook as 8 tactics with
  weights, example cues, and pre-vetted explanations in one `taxonomy.json` that drives *both* the
  training labels and the runtime fusion. Single source of truth.
- **Intent classifier.** Fine-tuned `all-MiniLM-L6-v2` as an 8-label multi-label classifier,
  quantized to **int8 ONNX (22.9 MB)**, run through **ONNX Runtime** on-device. We wrote a pure-Dart
  **WordPiece tokenizer** that reproduces the Python token IDs exactly (verified by parity tests), so
  the phone and the training notebook agree bit-for-bit.
- **Multilingual, aka the painful part.** For 12 languages we use `paraphrase-multilingual-MiniLM`
  (int8 ONNX) — but its XLM-R **SentencePiece** tokenizer is rough to reimplement in Dart. So we
  cross-compiled the Hugging Face `tokenizers` Rust crate into a native arm64 library
  (`libkavach_core.so`) and call it over `dart:ffi`. Same tactics, a dozen languages, still offline.
- **Offline ASR.** Vosk small English model (~40 MB), proper streaming, <500 ms, fast enough on the A18.
- **Risk fusion.** Noisy-OR over weight·probability for the present tactics, plus dangerous-combo
  boosts, mapped to thresholds (CAUTION ≥ 0.45, HIGH ≥ 0.75). The fusion's also wired to take a
  down-weighted (0.15) acoustic synthetic-voice signal.
- **Background guardian (Layer 2).** A `microphone`-type foreground service
  (`flutter_background_service`) hosts a Dart isolate running the full pipeline with the screen off.
- **Privacy by construction.** The release `AndroidManifest.xml` declares **no `INTERNET`
  permission** — the app literally can't transmit.

## Challenges we ran into

- **You can't tap a phone call on Android.** Since Android 10, third-party apps can't grab the
  remote party's audio. So we redesigned around an **ambient speakerphone guardian** — the way a
  careful relative next to you would listen — which only needs `RECORD_AUDIO` and breaks no policy.
- **SentencePiece on a phone.** Instead of shipping a janky reimplementation, we put the real Rust
  tokenizer behind FFI. Getting cargo-ndk cross-compilation, padding/truncation, and the Dart↔Rust
  memory handoff right took a minute — but the token IDs match Python now, exactly.
- **ONNX IR-version mismatch.** Our exported models were IR v10; the on-device runtime capped at v9.
  We down-converted the graphs without retraining.
- **The Android-14 foreground-service crash (this one hurt).** On the OPPO/ColorOS ROM,
  `startForeground()` kept killing the process with
  `CannotPostForegroundServiceNotificationException` — *even after* the notification permission was
  granted. Turned out the notification *channel* was never created on this ROM. We now create it
  explicitly with `flutter_local_notifications` before starting the service. We dug this out of
  on-device `dumpsys`/`logcat`, not by guessing.

## Accomplishments we're proud of

- **It genuinely runs on a $80 phone.** Every piece — ASR, tokenizer, classifier, fusion — works
  offline on a 4 GB OPPO A18.
- **The thesis held up on messy real audio.** In a background test Vosk misheard "accident" as
  "axe," and Kavach *still* flagged HIGH on the distress-hook tactic — because it reads the *script*,
  not keywords. That moment kinda sold us on the whole approach.
- **Privacy you can audit in one line** — no internet permission. Not a privacy *promise*, an actual
  architectural fact.
- **Real multilingual** via a Rust FFI tokenizer, not an English-only demo wearing a costume.

## What we learned

- Constraints make the product. "It has to run offline on a cheap phone" forced every decision that
  ended up making Kavach *better* than the cloud incumbents — private, hallucination-proof,
  infinitely scalable.
- The invariant in fraud isn't the tech, it's the **manipulation**. So fight the part that doesn't
  change.

## What's next

- Feed a real acoustic synthetic-voice signal into the (already-wired) fusion slot.
- Live multilingual ASR (we have multilingual *intent* already; ASR is English-first for now).
- An opt-in Guardian alert that pings a trusted family member on a HIGH-risk call.
- Field testing with elderly users + their families; on-device model updates.

## Built with
`flutter` · `dart` · `rust` · `dart:ffi` · `onnxruntime` · `vosk` · `huggingface-tokenizers` ·
`all-minilm-l6-v2` · `paraphrase-multilingual-minilm` · `flutter_background_service` ·
`flutter_local_notifications` · `android` · `cargo-ndk`

## "Try it / links" checklist for the submission form
- [ ] GitHub repo URL
- [ ] Demo video (≤ ~3 min) — **open on the airplane-mode shot**
- [ ] Pitch deck (see [docs/PITCH_DECK.md](PITCH_DECK.md))
- [ ] Screenshots: home (armed), live shield on HIGH, the ⚠️ guardian notification, the analyze
      screen showing a non-English language
- [ ] APK or build instructions
