# Round-1 AI Evaluation — prep & cheat-sheet

The rules describe Round 1 as an **"AI-powered conversational evaluation platform"** that assesses
**problem understanding** and **technical clarity** before any human sees the project. Most teams
will prep for a human pitch and get filtered here. This doc is how we *pass the filter.*

## How to play the AI round
- **Answer the question asked, then stop.** The AI scores clarity; rambling lowers signal.
- **Lead with the one-sentence answer, then one sentence of evidence.** Claim → proof.
- **Use the same concrete nouns every time** (8 tactics, int8 ONNX, Vosk, Rust FFI, no INTERNET
  permission, OPPO A18). Consistency reads as mastery.
- **Never invent a number.** If you don't have it, say what you *did* measure. The fastest way to
  lose this round is a stat you can't defend.
- **Honesty is a feature here.** Stating limits pre-empts the AI's "but isn't this unreliable?"
  follow-up and reads as engineering maturity.

---

## The 30-second core (memorize this)
"Kavach is an on-device scam-call shield. Instead of asking *is this voice fake* — which fails the
moment a real human reads a script — it detects the **8 manipulation tactics every scam uses**:
urgency, secrecy, gift-card payment, fake authority, distress, isolation, OTP probes, and
relationship spoofs. It runs a small int8 classifier and offline speech-to-text entirely on a $80
phone, with **no internet permission at all**, and warns the victim in plain language before they
pay. It's advisory — it buys time and prompts a family safe-word — not a black-box blocker."

---

## Anticipated questions → crisp answers

**Q. What problem are you solving?**
Phone scams are the most expensive everyday crime — $12.5B reported lost in the US in 2024, $4.9B
from seniors alone (FBI), average loss $83K. In India the "digital arrest" script alone drained
**₹19,000 cr in 2025** (I4C reported 92,000+ cases in 2024). AI voice cloning removed the last tell.
And *every* existing defense protects institutions, not the person on the call.

**Q. How is this different from existing scam/spam/deepfake tools?**
Three differences. (1) Spam filters block *numbers*; scammers rotate them. (2) Deepfake-voice
detectors ask "is the voice synthetic?" — useless when a real human reads the script, and they
degrade on phone audio. (3) Those are cloud services that must stream the call to a server. We
analyze the **conversation's intent**, on-device, with no network.

**Q. Why detect the script instead of the voice?**
Because the voice is the part that keeps improving and the script is the part that never changes.
Urgency + secrecy + untraceable payment is the same playbook whether the voice is a stranger or a
perfect clone. We test it directly: in one run our ASR misheard "accident" as "axe" and the system
*still* flagged the distress-hook tactic, because it isn't keyword matching — it's intent.

**Q. Walk me through the technical pipeline.**
Mic captures the speakerphone audio → **Vosk** offline streaming ASR → tokenizer (**Dart WordPiece**
for English, **Rust SentencePiece over `dart:ffi`** for multilingual) → a fine-tuned **MiniLM int8
ONNX** classifier outputs 8 tactic probabilities → **risk fusion** (noisy-OR over weighted
probabilities + dangerous-combo boosts) → a risk level with a pre-written explanation. Everything
on-device.

**Q. What model, and why so small?**
`all-MiniLM-L6-v2` fine-tuned as an 8-label multi-label classifier, quantized to **int8 ONNX,
22.9 MB**. Small because manipulation detection is a *narrow* classification problem — it doesn't
need a multi-billion-parameter LLM, and a small model is what fits and runs offline on a 4 GB phone.

**Q. Why not just use an LLM?**
Three reasons: a 3–4B LLM won't fit/run on the target phone; a generative model could **hallucinate
advice** to a panicking user; and we don't need generation — we need classification plus *pre-vetted,
deterministic* explanations. The constraint is the differentiator.

**Q. How do you do multilingual on-device?**
The multilingual model uses an XLM-R **SentencePiece** tokenizer that's impractical to reimplement
in Dart. So we cross-compiled Hugging Face's Rust `tokenizers` crate to a native arm64 library and
call it via FFI. We verified the token IDs match the Python reference exactly. 12 languages, still
offline.

**Q. How accurate is it? / What's your F1?**
We measured it on **two independent third-party datasets** with the real on-device model, not a
demo clip — full method and tables in [EVALUATION.md](EVALUATION.md). On 1,378 **real FTC robocall
transcripts** and a balanced 160/160 set of independent scam/legit dialogues (BothBosu), the best
operating point is ~**99% recall / 65% precision** judging the caller's script. We tune toward
**recall** on purpose — a missed scam costs a life's savings, a false alarm costs a few seconds —
and keep a human in the loop. We're upfront that precision on adversarial pushy-telemarketer "legit"
calls is moderate; that's *why* it's advisory, not a blocker.

**Q. A clever scammer won't say "gift card" — they tell a slow, believable story. Don't you miss that?**
That's the scam we engineered for. The patient script — India's "digital arrest" fraud, **₹19,000 cr
lost in 2025** — deploys its tactics *across the whole call*: fake CBI authority early, "don't
disconnect" isolation in the middle, the "transfer to a safe account" ask much later. A
hottest-window detector misses it because no single sentence is decisive. So the shield runs a
**conversation-level accumulator** (`conversation_risk.dart`): a decaying memory that fuses tactics
across time so they still add up and trigger the dangerous-combo boost. Measured gain: at the
"needs 3 tactics" bar it catches **40% of real robocalls vs 28%** for the per-window equivalent
(+43% relative), and it's unit-tested — an authority-now/isolation-later call that the per-window
verdict reads as CAUTION (0.72), the accumulator reads as HIGH (0.84). And because we detect *intent*
not keywords (it's a fine-tuned semantic model), paraphrases like "prepaid voucher" or "secure
account" still land.

**Q. What scam *would* you miss? (be honest)**
Slow-**trust** scams — pig-butchering / romance — where the attacker builds rapport for weeks with
zero pressure language and the "investment" ask comes last. There's nothing manipulative to detect
until very late. We're strongest on **coercion** scams (vishing, digital arrest, family-emergency,
tech-support) and we say so. The Watchword and "call back on a trusted number" prompt are the
safety net for what the model can't see.

**Q. What about false alarms on a real, anxious call — "Dad, I'm in hospital, send money"?**
It may well flag that as CAUTION — distress + a money ask is genuinely scam-shaped, and we'd rather
over-warn than miss. Crucially we **never block**; we surface a plain-language nudge and the
**Watchword**, the family safe-word the real person knows. A true emergency passes it in two
seconds; a cloned-voice scammer can't.

**Q. Isn't this unreliable / what are the limits?**
Yes, it's probabilistic — we're explicit that it's **advisory, not a guarantee.** The linguistic
layer is the hero; the acoustic layer is wired in but down-weighted (0.15) because phone audio
defeats acoustic detectors. It listens on **speakerphone** (Android forbids tapping the call
stream). Mitigation: we pair detection with a human circuit-breaker — the **Watchword** safe-word
and a "call back on a trusted number" prompt — so the final decision is always the user's.

**Q. How do you protect privacy / what about the other person on the call?**
By architecture, not promise. The app ships with **no `INTERNET` permission**, so it physically
cannot transmit. Audio is processed in a rolling window in memory and **never recorded or stored**;
we keep only transient transcript text to render the verdict, and we classify the **script, not the
person** — no voiceprint, no identity, no profile. (Full reasoning in
[PRIVACY_AND_CLASSIFICATION.md](PRIVACY_AND_CLASSIFICATION.md).)

**Q. Does it actually run, or is it a mockup?**
It runs on a real 4 GB OPPO A18. Both layers are validated on-device: the foreground **live shield**
and a background **foreground-service guardian** whose notification flips to a warning on HIGH. We
debugged real Android-14 foreground-service issues on the actual ROM to get there.

**Q. Is it scalable / what's the business case?**
Extremely — *because* it's on-device. No servers and no per-call inference cost means it scales to a
billion phones at ~$0 marginal cost, works in low-connectivity regions, and runs on the cheap phones
the most-vulnerable users actually own. Distribution is a standard app install; updates are
model-file swaps. It's also deployable where streaming call audio to the cloud is illegal.

**Q. Who is it for / real-world impact?**
The people losing the money: elderly users and their families, and anyone in a region where phone
fraud is rampant. The impact is direct — interrupting one HIGH-risk call can prevent an $83K average
loss. The 12-language support is aimed at exactly the markets where this fraud is exploding.

**Q. What's the innovation, in one line?**
Moving scam detection from "is the voice fake" (a losing arms race) to "is this conversation a
manipulation" (an invariant), and putting it **entirely on the victim's own offline phone.**

**Q. What did you build during the hackathon vs. before?**
The on-device pipeline — Dart WordPiece tokenizer, ONNX classifier integration, risk fusion, the
Vosk live loop, the Rust SentencePiece FFI, and the two-layer foreground/background service — were
built and validated for this hackathon. (The acoustic DSP draws on prior audio work; it's wired into
fusion but intentionally down-weighted and isn't the live verdict driver.)

**Q. What's next?**
A real acoustic signal into the fusion slot; live multilingual ASR (intent is already multilingual);
an opt-in Guardian alert to a family member; and field testing with elderly users.

---

## Words to avoid (they trigger skeptical follow-ups you can't win)
- "100% accurate," "blocks all scams," "guaranteed" → we're **advisory**.
- "Real-time deepfake detection" → we detect the **script**, not the deepfake.
- Any precise stat we can't source. Cite **FTC / FBI IC3** or say "we measured X on-device."

## Words to keep saying (they score)
on-device · offline · **no internet permission** · the *script*, not the voice · 8 manipulation
tactics · **conversation-level accumulator** · **digital arrest** · int8 ONNX · Rust FFI · 12
languages · runs on a $80 / 4 GB phone · advisory · Watchword · **measured on FTC + BothBosu** ·
private by architecture · scales at ~$0 marginal cost.
