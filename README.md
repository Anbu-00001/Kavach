# Kavach — the offline scam-call shield for the phone you already own

> **कवच** *(kavach)* — "armor / shield". Kavach listens to a live phone call **entirely on
> your device** and warns you the moment a caller starts running an AI voice-clone scam —
> *before* the money leaves your hands. No cloud. No account. No data ever leaves the phone.

---

## The problem (2026)

AI voice-cloning fraud is the defining scam of 2026. A clone needs only a few seconds of audio
scraped from social media, then calls a parent or grandparent: *"It's me, I'm in jail, wire the
money now, and please don't tell anyone."*

- **~$8B** in projected global losses this year; **$2.3B** already stolen from elderly Americans.
- **1 in 4** people have encountered a voice-clone scam.
- **70%** of people cannot tell a cloned voice from a real one.
- **Only 15%** of victims report it — out of shame.

## Why nothing today protects the victim

Every shipping detector — OmniSpeech, Aurigin, Pindrop, Reality Defender, Sensity — is **cloud,
acoustic-only, and built for banks and call-centers.** They protect *institutions*. The
grandmother on her personal phone has **zero** protection. And independent reviews show these
tools **break on compressed, phone-quality audio** — the pure "is the voice fake?" arms race is
one even the funded players are losing.

## The Kavach insight

> **Stop fighting the voice. Fight the *script*.**

Voices keep getting more perfect — but the **social-engineering playbook never changes**:
manufactured urgency, a secrecy demand, an untraceable-payment request, authority impersonation,
a distress hook, isolation. **A flawless clone reading a scam still trips that pattern.** So
Kavach's primary signal isn't the audio waveform — it's the *intent of the conversation*.

## How it works — three signals, fused, all on-device

| Layer | What it does | What runs |
| --- | --- | --- |
| 🗣️ **Linguistic intent** *(the hero)* | Scores the live transcript against the scam-tactic taxonomy | Tiny quantized classifier (~20–60 MB), **not** a big LLM |
| 🎙️ **Acoustic cues** *(support)* | Flags synthetic-voice tells: prosody flatness, missing breath, spectral artifacts | Rust DSP, CPU-only |
| 🔑 **Identity + Watchword** | Caller-ID heuristics + prompts a pre-set **family safe-word** a clone can't know | App logic |

These fuse into a **risk level + a plain-language explanation** ("This caller is rushing you,
asking for gift cards, and telling you to keep it secret — three hallmarks of a scam"), plus:

- a one-tap **circuit breaker** — hang up and call the real person back on their known number;
- an opt-in **Guardian alert** — quietly notify a trusted family member of a high-risk call;
- the **Watchword** challenge — the family safe-word a real loved one would know.

## Why it runs on a $80 phone (and why that's the whole point)

Kavach deliberately uses **no large language model.** Speech-to-text uses the phone's offline
recognizer or Vosk; intent uses a small fine-tuned classifier; explanations are **templated and
pre-vetted** (deterministic — they can never hallucinate to a panicking user). Total model
footprint stays in the low hundreds of MB, **fully offline on a 4 GB device.**

> Every competitor needs a datacenter or a flagship phone.
> **Kavach runs offline on the exact phone the actual victims own.**

You also *cannot* ethically or legally stream a vulnerable person's live calls to a cloud API.
On-device isn't a feature here — it's the only acceptable design.

## Honest scope

This is an **early-warning and intervention** tool that buys the victim time to think — not a
guarantee that blocks 100% of scams. The linguistic layer is the hero; the acoustic layer is a
*supporting* signal (and a deliberately humble one, since phone audio defeats acoustic detectors).

## Status

🚧 Built for the **Beyond Tomorrow Summit** hackathon. See [docs/](docs/) for architecture and the
scam-tactic taxonomy that powers detection.
