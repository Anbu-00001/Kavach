"""Evaluate the multilingual Kavach model on EXTERNAL datasets (honest, real-data numbers).

- FTC robocall corpus (public domain, REAL fraud audio transcripts): out-of-domain (robocalls,
  not interactive social-engineering calls) -> we report scam RECALL on the English subset.
- BothBosu multi-agent scam conversations (Apache-2.0, independent synthetic, balanced scam/legit):
  cross-distribution test -> recall / precision / accuracy.

Calls are windowed and scored by the MAX-risk window, mirroring the live shield. Run:
  python3 core/eval_external.py
"""

from __future__ import annotations

import csv
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from reference_detector import Detector  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MDIR = os.path.join(HERE, "model", "intent_ml")
EXT = os.path.join(HERE, "datasets", "external")
MAX_LEN = 48
csv.field_size_limit(10_000_000)


def load_engine():
    from transformers import AutoTokenizer
    import onnxruntime as ort
    tok = AutoTokenizer.from_pretrained(MDIR)
    sess = ort.InferenceSession(os.path.join(MDIR, "intent.int8.onnx"),
                                providers=["CPUExecutionProvider"])
    det = Detector()
    order = [t["id"] for t in det.tax["tactics"]]
    return tok, sess, det, order


def caller_turns(dialogue: str) -> str:
    """Keep only the CALLER's turns (BothBosu tags the caller 'Suspect', the user
    'Innocent'). Kavach judges the caller's *script*, so scoring the user's own
    anxious/irritated replies ('can't you people leave me alone') is a self-inflicted
    false alarm — we exclude them. Mirrors the live goal of grading the caller."""
    parts = re.split(r"\b(Suspect|Innocent)\s*:\s*", dialogue)
    out, i = [], 1
    while i + 1 < len(parts):
        if parts[i] == "Suspect":
            out.append(parts[i + 1].strip())
        i += 2
    return " ".join(out) if out else dialogue


def windows(text: str, size: int = 38, stride: int = 28, cap: int = 14):
    """Split text into overlapping word windows (the live shield scores rolling windows)."""
    words = text.split()
    if len(words) <= size:
        return [text] if text.strip() else []
    out = []
    for i in range(0, len(words), stride):
        out.append(" ".join(words[i:i + size]))
        if len(out) >= cap:
            break
    return out


def _window_probs(text, tok, sess):
    """Yield the 8-tactic probability vector for each rolling window of the call."""
    for w in windows(text):
        e = tok(w, return_tensors="np", padding="max_length", max_length=MAX_LEN,
                truncation=True, return_token_type_ids=False)
        logits = sess.run(None, {"input_ids": e["input_ids"].astype(np.int64),
                                 "attention_mask": e["attention_mask"].astype(np.int64)})[0]
        yield 1.0 / (1.0 + np.exp(-logits[0]))


def call_features(text, tok, sess, det, order):
    """PER-WINDOW (current shipping rule): each window scored independently.

    Returns (max fused risk, union of tactics, max tactics CO-OCCURRING in one window).
    A call is flagged on its single hottest window — which is why one benign window
    that trips a high-weight tactic (e.g. a legit 'gift card' mention) false-alarms.
    """
    best = 0.0
    tac = set()
    max_cooccur = 0
    for probs in _window_probs(text, tok, sess):
        conf = {order[i]: float(p) for i, p in enumerate(probs) if p >= 0.5}
        best = max(best, det.fuse(conf))
        tac |= set(conf)
        max_cooccur = max(max_cooccur, len(conf))  # tactics together in a single window
    return best, tac, max_cooccur


def call_cumulative(text, tok, sess, det, order, decay=0.85):
    """CONVERSATION-LEVEL (new): a decaying memory of tactics ACROSS windows.

    Each tactic keeps a decaying-max confidence: when it fires it stays 'warm' for a
    few turns, then fades. We re-fuse this accumulated vector every window, so tactics
    deployed minutes apart (authority early, payment late — the digital-arrest pattern)
    still combine and earn their combo boost, while a single stray detection decays
    away instead of flagging the whole call.

    Returns (peak cumulative fused risk, max DISTINCT tactics held in memory at once).
    """
    acc = {tid: 0.0 for tid in order}
    best_cum = 0.0
    max_distinct = 0
    for probs in _window_probs(text, tok, sess):
        for i, tid in enumerate(order):
            acc[tid] = max(acc[tid] * decay, float(probs[i]))
        conf = {tid: c for tid, c in acc.items() if c >= 0.5}
        best_cum = max(best_cum, det.fuse(conf))
        max_distinct = max(max_distinct, len(conf))
    return best_cum, max_distinct


def main():
    from collections import Counter
    engine = load_engine()

    bb = list(csv.DictReader(open(os.path.join(EXT, "bothbosu_test.csv"))))

    def split_bb(extract):
        scam, legit = [], []
        for r in bb:
            text = extract(r["dialogue"])
            feat = call_features(text, *engine) + call_cumulative(text, *engine)
            (scam if r["labels"] == "1" else legit).append(feat)
        return scam, legit

    # FULL = both speakers merged (worst case: includes the user's own words).
    # CALLER = only the caller's turns (what Kavach is actually meant to judge).
    full_scam, full_legit = split_bb(lambda d: re.sub(r"\b(Suspect|Innocent)\s*:\s*", " ", d))
    call_scam, call_legit = split_bb(caller_turns)

    ftc = [r for r in csv.DictReader(open(os.path.join(EXT, "ftc_metadata.csv")))
           if r.get("language") == "en" and r.get("transcript", "").strip()]
    ftc_feats = [call_features(r["transcript"], *engine) + call_cumulative(r["transcript"], *engine)
                 for r in ftc]

    # feature tuple = (win_score, win_tactics, win_cooccur, cum_score, cum_distinct)
    rules = [
        ("PER-WINDOW  HIGH (>=0.75)", lambda s, t, co, cs, cd: s >= 0.75),
        ("PER-WINDOW  >=2 co-occur", lambda s, t, co, cs, cd: co >= 2),
        ("PER-WINDOW  >=3 co-occur", lambda s, t, co, cs, cd: co >= 3),
        ("CUMULATIVE  >=2 distinct", lambda s, t, co, cs, cd: cd >= 2),
        ("CUMULATIVE  >=3 distinct", lambda s, t, co, cs, cd: cd >= 3),
        ("CUMULATIVE  >=4 distinct", lambda s, t, co, cs, cd: cd >= 4),
    ]

    def table(title, scam, legit):
        print(f"\n{title}")
        print(f"{'rule':>26} | {'recall':>6} {'prec':>6} {'acc':>6} | {'FTC rec':>7}")
        print("-" * 62)
        for name, rule in rules:
            tp = sum(rule(*x) for x in scam); fn = len(scam) - tp
            fp = sum(rule(*x) for x in legit); tn = len(legit) - fp
            rec = tp / (tp + fn or 1); prec = tp / (tp + fp or 1)
            acc = (tp + tn) / (len(scam) + len(legit))
            ftc_rec = sum(rule(*x) for x in ftc_feats) / len(ftc_feats)
            print(f"{name:>26} | {rec:>5.0%} {prec:>6.0%} {acc:>6.0%} | {ftc_rec:>7.0%}")

    print("PER-WINDOW (hottest single window) vs CUMULATIVE (decaying tactic")
    print("memory fused ACROSS windows). FTC rec = recall on real robocalls.")
    table("FULL DIALOGUE (both speakers merged — includes the user's own words):",
          full_scam, full_legit)
    table("CALLER ONLY (the caller's script — what Kavach is meant to judge):",
          call_scam, call_legit)
    print(f"\n(BB: 160 scam / 160 legit | FTC: {len(ftc_feats)} real English robocalls)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
