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


def call_features(text, tok, sess, det, order):
    """Return (max fused risk, union of tactics, max tactics CO-OCCURRING in one window)."""
    best = 0.0
    tac = set()
    max_cooccur = 0
    for w in windows(text):
        e = tok(w, return_tensors="np", padding="max_length", max_length=MAX_LEN,
                truncation=True, return_token_type_ids=False)
        logits = sess.run(None, {"input_ids": e["input_ids"].astype(np.int64),
                                 "attention_mask": e["attention_mask"].astype(np.int64)})[0]
        probs = 1.0 / (1.0 + np.exp(-logits[0]))
        conf = {order[i]: float(p) for i, p in enumerate(probs) if p >= 0.5}
        best = max(best, det.fuse(conf))
        tac |= set(conf)
        max_cooccur = max(max_cooccur, len(conf))  # tactics together in a single window
    return best, tac, max_cooccur


def main():
    from collections import Counter
    engine = load_engine()

    bb = list(csv.DictReader(open(os.path.join(EXT, "bothbosu_test.csv"))))
    bb_scam, bb_legit = [], []
    for r in bb:
        text = re.sub(r"\b(Suspect|Innocent)\s*:\s*", " ", r["dialogue"])
        s, tac, co = call_features(text, *engine)
        (bb_scam if r["labels"] == "1" else bb_legit).append((s, tac, co))

    ftc = [r for r in csv.DictReader(open(os.path.join(EXT, "ftc_metadata.csv")))
           if r.get("language") == "en" and r.get("transcript", "").strip()]
    ftc_feats = [call_features(r["transcript"], *engine) for r in ftc]

    rules = [
        ("HIGH score (>=0.75)", lambda s, t, co: s >= 0.75),
        (">=2 CO-OCCURRING tactics", lambda s, t, co: co >= 2),
        (">=3 CO-OCCURRING tactics", lambda s, t, co: co >= 3),
    ]
    print(f"\nDecision-rule comparison (co-occurring = tactics together in ONE window):")
    print(f"{'rule':>26} | {'BB recall':>9} {'BB prec':>8} {'BB acc':>7} | {'FTC recall':>11}")
    print("-" * 72)
    for name, rule in rules:
        tp = sum(rule(*x) for x in bb_scam); fn = len(bb_scam) - tp
        fp = sum(rule(*x) for x in bb_legit); tn = len(bb_legit) - fp
        rec = tp / (tp + fn or 1); prec = tp / (tp + fp or 1); acc = (tp + tn) / (len(bb_scam) + len(bb_legit))
        ftc_rec = sum(rule(*x) for x in ftc_feats) / len(ftc_feats)
        print(f"{name:>26} | {rec:>8.0%} {prec:>8.0%} {acc:>7.0%} | {ftc_rec:>11.0%}")
    print(f"\n(BB: {len(bb_scam)} scam / {len(bb_legit)} legit | FTC: {len(ftc_feats)} real English robocalls)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
