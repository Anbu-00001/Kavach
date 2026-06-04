# Kavach — Demo Video Script & Shot List (≈ 2:45)

**The answer to "when do I hit record":** you record in **3 separate takes**, then stitch them.
You never have to nail it all in one go. Takes A and B are the only ones that matter; Take C is optional polish.

- **Take A — the phone demo** (screen + the spoken warning). 🔴 Record this first, it's the hero.
- **Take B — the voiceover** (you reading the script over the edited footage). 🔴 Record after editing picture.
- **Take C — a 8-sec talking-head** intro ("Hi, we're team … and this is Kavach"). Optional.

Total target **2:30–3:00**. Both hackathons cap ~3 min — do **not** go over.

---

## ✅ Pre-flight (5 minutes, do this before any recording)

1. **Charge the A18, set brightness ~80%, turn on Do Not Disturb** (no notifications mid-take).
2. **Airplane mode ON** — and *leave it on the whole demo.* This is your privacy proof on camera: a scam shield that works with the radio off.
3. **Volume to max** (so the spoken warning is loud on camera).
4. **Pick your capture method** (see "How to capture" below). Recommended: **film the physical phone with a second phone** for the climax (you hear the warning + see the screen), and use **scrcpy screen-record** for crisp UI cutaways.
5. **Stage the demo** so it triggers the *spoken* warning:
   - On the Kavach home, in **"Live voice language"**, tap **தமிழ் (Tamil)** or **हिंदी (Hindi)** — this sets the language the phone will *speak* the warning in.
   - That's it. The **"See how it works"** demo will now escalate SAFE → CAUTION → HIGH and the phone will **speak the warning in that language + buzz**. Reliable, repeatable, no external audio needed.
6. Optional fully-live take: ask me to generate a **Tamil/Hindi scam clip**; play it from your laptop next to the phone with **"Go live now."** Then the transcription is real-time too. (Higher wow, slightly riskier — have the scripted demo as backup.)

---

## 🎬 The shot list (picture). 🔴 = hit record.

| # | Time | On screen | Action | 🔴 |
|---|---|---|---|---|
| 1 | 0:00–0:08 | **You / title card** "कवच Kavach" | 8-sec intro or hard cut to the stat | Take C (optional) |
| 2 | 0:08–0:22 | Title → one stat line | Hold on the problem (digital arrest) | — (slides) |
| 3 | 0:22–0:34 | Kavach home, **airplane mode visible in status bar** | Slow pan; show "Nothing ever leaves your phone" | 🔴 A |
| 4 | 0:34–0:48 | Tap **தமிழ்** in language picker, then scroll to **"See how it works"** | Set up the demo | 🔴 A |
| 5 | 0:48–1:05 | **Live shield: SAFE → "Be careful"** | Let it climb; transcript fills in | 🔴 A |
| 6 | **1:05–1:25** | **"Likely a scam" — screen flips red AND the phone SPEAKS the Tamil warning + buzzes** | **Hold here. Don't talk over it. Let the phone's voice land.** | 🔴 **A (the money shot)** |
| 7 | 1:25–1:42 | Tap a verdict → **"WHAT TRIGGERED THIS → 'gift cards'"** + per-tactic % | Show the real reasoning | 🔴 A |
| 8 | 1:42–1:55 | Slide: eval numbers + "detects the script across the whole call" | cutaway to slides | — |
| 9 | 1:55–2:12 | Terminal/slide: `aapt dump permissions … INTERNET count: 0` (or just hold on airplane mode) | The privacy proof | 🔴 A or slide |
| 10 | 2:12–2:35 | Slide: who it's for (elderly, illiterate, rural) + scalability | impact | — |
| 11 | 2:35–2:45 | Title card + repo/team | close | Take C |

> The single most important 20 seconds is **shot #6.** Frame the physical phone, stay silent, let it
> say *"நிறுத்துங்கள். இது மோசடி அழைப்பாக இருக்கலாம்…"* and buzz. That's the moment a judge remembers.

---

## 🎙️ Take B — Voiceover (read this over the picture)

> *(0:08)* "Phone scams are the most expensive everyday crime on earth. In India, the 'digital arrest'
> scam alone took **nineteen thousand crore rupees** last year — mostly from elderly people who were
> kept on a call for hours and told to stay quiet."
>
> *(0:22)* "Every tool out there protects the bank, not the person on the call. And it usually shows a
> warning **on a screen** — to someone who often **can't read it.** So we built Kavach."
>
> *(0:34)* "It runs entirely on a four-thousand-rupee phone. **Airplane mode is on** — nothing it hears
> ever leaves the device. It doesn't ask *'is the voice fake?'* It listens for the **manipulation
> script** every scam uses — urgency, secrecy, 'transfer to a safe account,' fake police."
>
> *(0:48)* "Watch it follow this call. Safe… then careful as the pressure builds…"
>
> *(1:05, let the phone speak, then:)* "…and when it's sure, it doesn't just flash red. **It speaks
> up — out loud, in the user's own language — and buzzes.** For someone who can't read the screen,
> *this* is the warning that saves them."
>
> *(1:25)* "And it's a real model, not a script. Tap the verdict and it shows the exact words it relied
> on — **'gift cards'** — found by re-scoring the sentence on-device. Its actual reasoning."
>
> *(1:42)* "It tracks tactics across the **whole call**, so the slow scams that spread the trap over
> fifteen minutes still add up. On real fraud-call data that catches **40% more** than scoring one
> sentence at a time."
>
> *(1:55)* "And the privacy isn't a promise — it's architecture. The app ships with **no internet
> permission at all.** It physically cannot send your call anywhere."
>
> *(2:12)* "Half of India's illiterate population is over fifty. This is for them — and for every family
> watching a parent get talked out of their savings. On-device, offline, free to run, in their own
> language."
>
> *(2:35)* "Kavach. It catches the script, not the voice — and it speaks up before the money's gone."

Keep it conversational; a tiny stumble is fine and reads as human. Re-record any line you flub — it's a separate take.

---

## 🛠️ How to capture (pick one)

**Easiest reliable (recommended):**
- **Film the phone with a second phone** for shots #5–7 (the demo + spoken warning + buzz). You get the audio and the human feel.
- For crisp UI cutaways (#3, #4, #7 close-up), use **scrcpy** on your laptop:
  - `scrcpy --record=ui.mp4 --max-size 1080` (mirrors + records the screen). Android 14 → it also records device audio, so the spoken warning is captured cleanly. Stop with Ctrl-C.
- Edit in **CapCut / DaVinci Resolve (free)**: lay slides + screen-record on the timeline, drop the phone-film over shot #6, add Take B voiceover, export 1080p.

**No-laptop option:** the A18's built-in **Screen Recorder** (enable internal audio) for the UI, and film shot #6 with a second phone. Stitch in CapCut on the phone.

> `adb screenrecord` is **not** ideal here — it doesn't capture the spoken-warning audio. Use scrcpy or the built-in recorder.

---

## Slides to pull for the cutaways (#1, #8, #9, #10, #11)
Export these from the pitch deck (`docs/pitch_deck.html` → open in Chrome → screenshot/print the relevant slides), or just screen-record the deck. Slides 1, 2, 7, 8, 10 map to shots 1, 2, 8, 9, 10.
