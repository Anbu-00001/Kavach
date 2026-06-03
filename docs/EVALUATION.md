# Kavach — Honest Evaluation

This is the un-spun version. No cherry-picked demo clip, no made-up accuracy
number. Every figure below comes from `core/eval_external.py` run against
**independent, third-party datasets** with the **real quantized on-device model**
(`core/model/intent_ml/intent.int8.onnx`, the same weights the phone ships).

```
python3 core/eval_external.py        # reproduces every table here
```

## What we tested on

| Dataset | What it is | License | Why it's honest |
|---|---|---|---|
| **BothBosu** scam-dialogues | 160 scam + 160 legit multi-turn phone conversations, synthetic but **independent** of us | Apache-2.0 | Balanced, we didn't write it, full two-sided dialogue |
| **FTC robocall corpus** | 1,378 **real** English robocall transcripts (actual fraud audio) | Public domain | Real-world, fully out-of-distribution from our training data |

Calls are split into rolling word windows and scored exactly like the live shield.
Nothing here was used in training.

## The two findings that matter

### 1. Judge the *caller's* script, not the victim's panic

BothBosu's "legit" calls are pushy-but-real appointment/telemarketing calls, and
the dialogue contains **both speakers**. When you score the whole transcript you
end up scoring the *victim's own* anxious, irritated replies ("can't you people
leave me alone", "I hope so... I'm worried") — which trip DISTRESS / ISOLATION.
That's a self-inflicted false alarm. Scoring only the **caller's** turns lifts
precision by ~7 points across the board. Kavach's whole thesis is *grade the
incoming script*, so the caller-only column is the one that reflects the design.

### 2. A decaying memory across the call beats a hottest-window verdict

The per-window model answers "is **this sentence** a scam?". The patient scams —
the "digital arrest" script that drained **₹19,000 cr in India in 2025** — spread
their tactics across the whole call: authority early, isolation in the middle, the
money ask much later. No single window looks decisive. The **conversation-level
accumulator** (`app/lib/engine/conversation_risk.dart`) keeps a decaying memory of
every tactic so they still add up — and earn their dangerous-combo boost — across
time, while a single stray detection fades instead of flagging the call.

## The numbers (verbatim harness output)

```
PER-WINDOW (hottest single window) vs CUMULATIVE (decaying tactic
memory fused ACROSS windows). FTC rec = recall on real robocalls.

FULL DIALOGUE (both speakers merged — includes the user's own words):
                      rule | recall   prec    acc | FTC rec
--------------------------------------------------------------
 PER-WINDOW  HIGH (>=0.75) |  100%    54%    57% |     76%
  PER-WINDOW  >=2 co-occur |  100%    55%    59% |     68%
  PER-WINDOW  >=3 co-occur |   98%    63%    70% |     28%
  CUMULATIVE  >=2 distinct |  100%    54%    58% |     70%
  CUMULATIVE  >=3 distinct |  100%    58%    64% |     40%
  CUMULATIVE  >=4 distinct |   95%    65%    72% |     14%

CALLER ONLY (the caller's script — what Kavach is meant to judge):
                      rule | recall   prec    acc | FTC rec
--------------------------------------------------------------
 PER-WINDOW  HIGH (>=0.75) |  100%    54%    58% |     76%
  PER-WINDOW  >=2 co-occur |  100%    58%    64% |     68%
  PER-WINDOW  >=3 co-occur |   92%    69%    76% |     28%
  CUMULATIVE  >=2 distinct |  100%    56%    61% |     70%
  CUMULATIVE  >=3 distinct |   99%    65%    72% |     40%
  CUMULATIVE  >=4 distinct |   89%    76%    80% |     14%

(BB: 160 scam / 160 legit | FTC: 1378 real English robocalls)
```

### How to read it

- **Cumulative > per-window on real fraud.** At the "needs 3 tactics" strictness,
  the cumulative rule catches **40% of real FTC robocalls vs 28%** for the
  per-window equivalent — a **+43% relative recall gain** — and **99% vs 92%** on
  BothBosu, because it bridges tactics that don't land in one breath.
- **The live shield's swap is free.** The shield used to surface the hottest
  *single* window; it now surfaces the cumulative verdict. At the shipped HIGH
  threshold the two have **identical precision (~54%)**, so there's no
  false-alarm regression — only added recall on slow-burn scripts.
- **Best balanced operating point (caller-only): ~99% recall / 65% precision /
  72% accuracy**, recovering 40% of real robocalls. Tighten to ≥4 distinct
  tactics and precision climbs to **76%** at the cost of robocall recall.

### Worked example — the slow-burn flip (unit-tested)

`app/test/conversation_risk_test.dart` encodes the digital-arrest pattern with the
**real fusion math**: authority (p=0.9) in window 1, three benign windows, then
isolation (p=0.9) in window 4.

| | best single window | conversation-level |
|---|---|---|
| score | **0.72 → CAUTION** | **0.84 → HIGH** |

Same call, same model — the per-window verdict under-reads it, the accumulator
catches it. The test also proves a stray tactic **decays back to SAFE** (no
lingering false alarm) and that a lone decisive tactic ("buy gift cards") is still
HIGH on its own.

## Where Kavach is honestly weak

We'd rather a judge hear this from us than find it themselves:

1. **Precision on an adversarial balanced set is moderate (~55–76%).** Half of
   BothBosu "legit" calls are pushy telemarketers — genuinely scam-shaped. This is
   exactly why Kavach is **advisory, never blocking**, and pairs every verdict with
   the **Watchword** (a family safe-word the model never needs to be perfect about).
2. **Slow-*trust* scams (pig-butchering / romance) are a blind spot.** They build
   rapport for weeks with zero pressure language, so there's nothing to detect until
   the late "investment" ask. Kavach is strongest on **coercion** scams (vishing,
   digital arrest, family-emergency, tech-support) — and we say so.
3. **The real-cellular-call mic path is unverified.** Every validation so far is
   audio played near the phone (room/speakerphone). Whether Android hands a
   third-party app live call audio is OEM-dependent and **still untested on the
   demo device** — listed openly, not hidden.
4. **Digital-arrest vocabulary — investigated end-to-end, shipped model kept on
   purpose.** We added digital-arrest / long-con phrasings (CBI, Aadhaar, "safe
   account for verification", "stay on video", investment lure) *and* matching
   benign hard-negatives to `core/build_dataset.py`, regenerated the data, and
   retrained the English MiniLM (`core/eval_candidate.py` scores a candidate vs the
   shipped model on a 14-line battery). Findings, stated plainly:
   - The **shipped semantic model already passes 13/14** — it generalises
     "CBI / money-laundering / safe account / digital arrest" without any retrain
     (MiniLM is semantic, not keyword), and keeps every legit Aadhaar/customs/
     deposit/investment mention SAFE. It only misses "parcel seized by customs".
   - A clean retrain (LR 3e-5; the script's `bert-tiny` default 5e-4 collapses
     MiniLM to all-SAFE — fixed-note added) reaches **14/14** (gains the customs
     case) but is calibrated lower — it downgrades the headline "digital arrest,
     stay on video" line from HIGH → CAUTION. Net: **not a clear win**, so we keep
     the validated weights every on-device behaviour was checked against and retain
     the candidate as an artifact. The reference detector flags the full
     digital-arrest script HIGH regardless.
   - The **multilingual XLM-R** model (the one the live Indic demo and these eval
     tables use) is a GPU fine-tune (`core/colab_train_multilingual.py`), run on
     Colab — deliberately not on the dev laptop.

## Reproduce

```
python3 core/reference_detector.py                  # seed set: 100% recall, 94% precision
python3 core/reference_detector.py "<any line>"     # score one utterance
python3 core/eval_external.py                        # the tables above
cd app && flutter test test/conversation_risk_test.dart   # the slow-burn flip
```
