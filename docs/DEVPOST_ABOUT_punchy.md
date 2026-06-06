# Kavach — Devpost "About the project" (punchy / human voice)

*Paste section-by-section into Devpost. Every number is backed (see EVALUATION.md, RELEASE_PERMISSIONS.txt).*

---

## 💡 Inspiration

It started with a number we couldn't shake: **₹19,000 crore.** That's what the "digital arrest" scam stole from Indian families in a *single year* — one phone call at a time.

Picture it: an elderly man gets a call. A "police officer" says his name is in a money-laundering case. *Stay on the line. Don't tell your family. Transfer the money to clear your name.* He's kept on that call for hours, cut off from everyone who'd talk sense into him. By the time anyone notices, his life's savings are gone.

And the part that genuinely made us angry: **every tool built to stop this protects the bank — not the terrified person actually on the call.** Worse, the few that warn the user do it with *text on a screen* — to people who often can't read it. In India, **half the illiterate population is over 50.**

We kept thinking about our own grandparents. One convincing call is all it takes. So we built the thing we wish existed for them.

## 📱 What it does

**Kavach** (कवच — "shield") is a scam-call bodyguard that lives on the phone they *already own.* Put the call on speaker and it listens — **100% offline** — for the manipulation script every scammer runs: fake police, manufactured urgency, "don't tell your family," "move your money to a safe account."

It never asks *"is this voice a deepfake?"* — that's useless the second a real human reads a script. **Kavach catches the play, not the voice.**

And when the call turns dangerous, it doesn't just flash a red screen. **It speaks the warning out loud, in the user's own language, and buzzes the phone:** *"Stop. This may be a scam. Don't send money or share any code. Hang up and call your family."* Colour + voice + vibration — so it reaches someone who can't read, can't see well, or can't hear well.

Then it shows its work: tap the verdict and Kavach highlights the **exact words** that gave the scam away — *"gift cards"* — its real on-device reasoning, not a canned line.

## 🛠️ How we built it

Everything runs on a **₹6,000 phone**. No cloud, no account, no LLM.

- **8 manipulation tactics** encoded in one taxonomy that drives *both* the training labels and the runtime fusion — single source of truth across Python, Rust, and Dart.
- **Intent classifier:** fine-tuned MiniLM, **int8 ONNX (22.9 MB)**, running on-device via ONNX Runtime.
- **12 languages:** XLM-R with a **SentencePiece tokenizer we cross-compiled from Rust** and call over `dart:ffi` — token IDs match Python *exactly*.
- **Universal live ASR:** Tamil + ~99 languages via **Whisper-tiny + Silero VAD** (sherpa-onnx); English on Vosk.
- **Conversation-level risk:** a **decaying memory** that fuses tactics across the *whole* call, so the slow-burn digital-arrest pattern still adds up instead of slipping through.
- **Spoken warnings:** pre-recorded clips played natively in Kotlin — no TTS voice needed on a cheap phone, and it **can't hallucinate** to a panicking user.
- **Privacy by construction:** the release app ships with **no `INTERNET` permission.** It *physically cannot* leak a call.

## 🧗 Challenges we ran into

- **You literally can't tap a phone call on Android** — Google blocks it (OEMs block it harder). So we stopped fighting it and designed *around* it: Kavach is an **ambient speakerphone guardian**, like a careful relative sitting beside you. Turns out that's *more* private — we never touch the call stream, which is exactly why we can ship with zero internet permission.
- **SentencePiece on a phone is brutal** → we shipped a real Rust tokenizer over FFI instead of a janky reimplementation.
- **Two ONNX runtimes** (Whisper's and the classifier's) fought each other on the device; aligning both took a full day.
- **The one that hurt:** an Android-14 foreground-service crash on ColorOS that kept killing our background guardian *even with* notifications granted — the notification *channel* was never created on that ROM. We dug it out of on-device `dumpsys`, not guesswork.

## 🏆 Accomplishments that we're proud of

- **It speaks up for the person who can't read the screen.** That single feature is the line between a cool demo and something that actually saves an 80-year-old.
- **It genuinely runs offline on an $80 phone** — ASR, tokenizer, classifier, spoken alerts, all of it. Validated on a real OPPO A18.
- **Privacy you can audit in one line:** release APK, `INTERNET` permission count = **0**. Not a promise — a fact.
- **An honest eval on real fraud data:** against **1,378 real FTC robocalls**, our conversation-level engine catches **40% vs 28%** for single-sentence scoring (**+43%**) — and we name our weak spots out loud instead of hiding them.

## 📚 What we learned

Constraints make the product. *"Run offline, on a cheap phone, for someone who can't read"* forced every decision that made Kavach better than the cloud incumbents — private, hallucination-proof, accessible, and scalable at ~$0 marginal cost.

And the real lesson: **in fraud, the tech keeps changing but the manipulation never does.** Voice clones get better every month. The playbook — urgency, secrecy, fake authority, "send the money now" — hasn't changed in decades. So we built Kavach to fight the part that never changes.

## 🚀 What's next for Kavach

- Field-test with real elders, across more phone models and OEMs.
- An opt-in alert to a trusted family member the moment a call goes HIGH-risk.
- Native-speaker re-recordings of the warning clips + more Indian languages.
- A real acoustic deepfake signal feeding the fusion slot we've already wired.

## 🧰 Built with

`flutter` · `dart` · `rust` · `dart-ffi` · `kotlin` · `onnx-runtime` · `sherpa-onnx` · `whisper` · `vosk` · `silero-vad` · `huggingface-tokenizers` · `all-minilm-l6-v2` · `paraphrase-multilingual-minilm` · `android` · `cargo-ndk`

## 🔗 Links

- **GitHub:** https://github.com/Anbu-00001/Kavach
- **Demo video:** _[paste your YouTube link]_
