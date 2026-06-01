"""Kavach on-device detection engine (reference implementation).

Ties the pieces together exactly as the phone will: the quantized ONNX classifier emits per-tactic
probabilities -> the taxonomy's fusion logic combines them (with combo boosts + the acoustic
signal) -> a risk level and pre-vetted, plain-language explanations come out. This Python version
is the spec the Flutter/Dart port mirrors 1:1, and it's how we evaluate the full pipeline on the
host before it ever touches a phone.

Run:  python3 core/kavach_engine.py "<transcript text>" [acoustic_signal 0..1]
"""

from __future__ import annotations

import os
import sys

import numpy as np

from reference_detector import Detector, Verdict  # reuse fusion + risk + explanation logic

HERE = os.path.dirname(os.path.abspath(__file__))
ONNX_INT8 = os.path.join(HERE, "model", "intent", "intent.int8.onnx")
MODEL_DIR = os.path.join(HERE, "model", "intent")
MAX_LEN = 48


class OnnxDetector(Detector):
    """Same taxonomy + fusion as the reference detector, but tactics come from the ONNX model.

    `prob_floor` keeps low-confidence tactic activations out of the fusion so noise doesn't
    inflate the risk score; the model's own probabilities (not a hard 1.0) feed the noisy-OR,
    which is strictly more faithful than the keyword reference.
    """

    def __init__(self, prob_floor: float = 0.5, taxonomy=None):
        super().__init__(taxonomy)
        import onnxruntime as ort
        from transformers import AutoTokenizer
        self.tok = AutoTokenizer.from_pretrained(MODEL_DIR)
        self.sess = ort.InferenceSession(ONNX_INT8, providers=["CPUExecutionProvider"])
        self.prob_floor = prob_floor
        # model output order == taxonomy tactic order (enforced in build_dataset.TACTICS)
        self.order = [t["id"] for t in self.tax["tactics"]]

    def detect_tactics(self, text: str) -> dict[str, float]:
        e = self.tok(text, return_tensors="np", padding="max_length", max_length=MAX_LEN,
                     truncation=True, return_token_type_ids=False)
        logits = self.sess.run(None, {"input_ids": e["input_ids"].astype(np.int64),
                                      "attention_mask": e["attention_mask"].astype(np.int64)})[0]
        probs = 1.0 / (1.0 + np.exp(-logits[0]))
        return {self.order[i]: float(p) for i, p in enumerate(probs) if p >= self.prob_floor}


def assess(text: str, acoustic: float = 0.0, detector: Detector | None = None) -> Verdict:
    det = detector or OnnxDetector()
    return det.assess(text, acoustic=acoustic)


def main(argv: list[str]) -> int:
    if not os.path.exists(ONNX_INT8):
        print(f"no quantized model at {ONNX_INT8} — run train_classifier.py then export_onnx.py")
        return 1
    if len(argv) < 2:
        print('usage: python3 core/kavach_engine.py "<text>" [acoustic 0..1]')
        return 2
    text = argv[1]
    acoustic = float(argv[2]) if len(argv) > 2 else 0.0
    v = assess(text, acoustic)
    print(f'"{text}"  (acoustic={acoustic})\n')
    print(f"  risk   : {v.level} ({v.level_label})  score={v.score}")
    print(f"  tactics: {', '.join(v.tactics) or 'none'}")
    for ex, ac in zip(v.explanations, v.actions):
        print(f"   • {ex}\n     → {ac}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
