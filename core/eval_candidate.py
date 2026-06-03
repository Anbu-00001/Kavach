"""Compare a retrain CANDIDATE against the SHIPPED int8 model — does it gain on
digital-arrest scripts WITHOUT regressing the behaviours we already validated?

Run:  python3 core/eval_candidate.py [candidate_dir]
"""

from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from reference_detector import Detector  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MAX_LEN = 48
DET = Detector()
ORDER = [t["id"] for t in DET.tax["tactics"]]

# (text, must-fire tactics or None, expected verdict bucket: 'scam' | 'safe')
BATTERY = [
    # --- the digital-arrest gains we're after ---
    ("This is the CBI cyber crime branch, a money laundering case is registered against your Aadhaar.",
     {"AUTHORITY_IMPERSONATION"}, "scam"),
    ("Transfer the funds to a safe account for verification, it is fully refundable.",
     {"UNTRACEABLE_PAYMENT"}, "scam"),
    ("You are under digital arrest, stay on this video call and do not disconnect.",
     {"ISOLATION"}, "scam"),
    ("Your parcel was seized by customs and contained illegal items, you must cooperate.",
     {"AUTHORITY_IMPERSONATION"}, "scam"),
    ("Invest in this trading platform with guaranteed returns and double your money.",
     {"UNTRACEABLE_PAYMENT"}, "scam"),
    # --- previously-validated behaviours that must NOT regress ---
    ("Go to the store and buy three google play gift cards and read me the numbers.",
     {"UNTRACEABLE_PAYMENT"}, "scam"),
    ("Grandma it's me, my voice sounds off because I have a cold.",
     {"RELATIONSHIP_SPOOF"}, "scam"),
    ("There's been an accident and I need bail money right now, don't tell anyone.",
     None, "scam"),
    # --- legit / hard negatives that must stay SAFE ---
    ("Your Aadhaar update was successful, nothing further is needed from you.", None, "safe"),
    ("Customs cleared your parcel, it'll be delivered tomorrow with nothing to pay.", None, "safe"),
    ("I moved the deposit to our joint account like we agreed earlier.", None, "safe"),
    ("Hi, this is Dr. Mehta's office confirming your appointment on Thursday at ten.", None, "safe"),
    ("Hey it's Priya, are we still on for coffee this weekend?", None, "safe"),
    ("Your investment account statement for this month is ready to view whenever.", None, "safe"),
]


def onnx_probs(sess, tok):
    def f(text):
        e = tok(text, return_tensors="np", padding="max_length", max_length=MAX_LEN,
                truncation=True, return_token_type_ids=False)
        logits = sess.run(None, {"input_ids": e["input_ids"].astype(np.int64),
                                 "attention_mask": e["attention_mask"].astype(np.int64)})[0]
        return 1.0 / (1.0 + np.exp(-logits[0]))
    return f


def torch_probs(model, tok):
    import torch
    @torch.no_grad()
    def f(text):
        e = tok(text, return_tensors="pt", padding="max_length", max_length=MAX_LEN,
                truncation=True)
        logits = model(input_ids=e["input_ids"], attention_mask=e["attention_mask"]).logits
        return torch.sigmoid(logits)[0].numpy()
    return f


def verdict(probf, text):
    probs = probf(text)
    conf = {ORDER[i]: float(p) for i, p in enumerate(probs) if p >= 0.5}
    score = DET.fuse(conf)
    level, _ = DET.risk_level(score)
    return level, set(conf), score


def run(name, probf):
    print(f"\n=== {name} ===")
    gains = regress = ok = 0
    for text, must, bucket in BATTERY:
        level, fired, score = verdict(probf, text)
        flagged = level != "SAFE"
        want_flag = bucket == "scam"
        good = flagged == want_flag and (must is None or must.issubset(fired))
        tag = "ok " if good else "BAD"
        if good:
            ok += 1
        print(f"  [{tag}] {level:7} {score:.2f} {sorted(fired)}  | {text[:54]}")
    print(f"  passed {ok}/{len(BATTERY)}")
    return ok


def main():
    from transformers import AutoTokenizer
    import onnxruntime as ort

    cand = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "model", "intent_candidate")

    # shipped int8
    shipped_dir = os.path.join(HERE, "model", "intent")
    stok = AutoTokenizer.from_pretrained(shipped_dir)
    ssess = ort.InferenceSession(os.path.join(shipped_dir, "intent.int8.onnx"),
                                 providers=["CPUExecutionProvider"])
    run("SHIPPED (int8 on-device model)", onnx_probs(ssess, stok))

    # candidate (pytorch, pre-quantization)
    from transformers import AutoModelForSequenceClassification
    ctok = AutoTokenizer.from_pretrained(cand)
    cmodel = AutoModelForSequenceClassification.from_pretrained(cand).eval()
    run(f"CANDIDATE ({os.path.basename(cand)}, pytorch)", torch_probs(cmodel, ctok))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
