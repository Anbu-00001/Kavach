"""Kavach reference detector (host-side, stdlib only).

This is the *reference / evaluation* implementation of the linguistic-intent layer — NOT the
shipping code. It validates the scam-tactic taxonomy and risk fusion today, with no phone and no
ML, and it doubles as the labeling guide + eval harness for the tiny on-device classifier that
will replace the keyword matcher later.

Run:  python3 core/reference_detector.py            # evaluate on the seed dataset
      python3 core/reference_detector.py "<text>"   # score one line
"""

from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass

HERE = os.path.dirname(os.path.abspath(__file__))
TAXONOMY_PATH = os.path.join(HERE, "taxonomy.json")
SEED_PATH = os.path.join(HERE, "datasets", "seed_calls.jsonl")


def load_taxonomy(path: str = TAXONOMY_PATH) -> dict:
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


@dataclass
class Verdict:
    score: float
    level: str
    level_label: str
    tactics: list[str]
    explanations: list[str]
    actions: list[str]


class Detector:
    """Reference detector: cue matching -> noisy-OR fusion -> combo boosts -> risk level.

    The shipping app swaps `detect_tactics` for a quantized classifier emitting per-tactic
    confidences; the fusion + explanation logic below stays identical.
    """

    def __init__(self, taxonomy: dict | None = None):
        self.tax = taxonomy or load_taxonomy()
        self.tactics = {t["id"]: t for t in self.tax["tactics"]}
        # risk levels sorted high -> low so the first match wins
        self.levels = sorted(self.tax["risk_levels"], key=lambda r: r["min_score"], reverse=True)
        self.combo_boosts = self.tax["fusion"]["combo_boosts"]
        self.acoustic_weight = self.tax["fusion"]["acoustic_weight"]

    def detect_tactics(self, text: str) -> dict[str, float]:
        """Return {tactic_id: confidence} for tactics whose cues appear in the text."""
        low = text.lower()
        hits: dict[str, float] = {}
        for tid, t in self.tactics.items():
            if any(cue in low for cue in t["cues"]):
                hits[tid] = 1.0  # reference layer is binary; the ML layer will be probabilistic
        return hits

    def fuse(self, tactic_conf: dict[str, float], acoustic: float = 0.0) -> float:
        """Noisy-OR over per-tactic (weight * confidence), plus combo boosts and acoustic signal."""
        prod = 1.0
        for tid, conf in tactic_conf.items():
            w = self.tactics[tid]["weight"]
            prod *= (1.0 - w * conf)
        score = 1.0 - prod
        present = set(tactic_conf)
        for combo in self.combo_boosts:
            if set(combo["tactics"]).issubset(present):
                score += combo["boost"]
        score += self.acoustic_weight * max(0.0, min(1.0, acoustic))
        return max(0.0, min(1.0, score))

    def risk_level(self, score: float) -> tuple[str, str]:
        for lvl in self.levels:
            if score >= lvl["min_score"]:
                return lvl["id"], lvl["label"]
        return self.levels[-1]["id"], self.levels[-1]["label"]

    def assess(self, text: str, acoustic: float = 0.0) -> Verdict:
        conf = self.detect_tactics(text)
        score = self.fuse(conf, acoustic)
        level, label = self.risk_level(score)
        ordered = sorted(conf, key=lambda tid: self.tactics[tid]["weight"], reverse=True)
        return Verdict(
            score=round(score, 3),
            level=level,
            level_label=label,
            tactics=ordered,
            explanations=[self.tactics[t]["explanation"] for t in ordered],
            actions=[self.tactics[t]["action"] for t in ordered],
        )


def _evaluate(det: Detector) -> int:
    """Score the seed set. A 'scam' line should reach CAUTION+; a 'legit' line should stay SAFE."""
    with open(SEED_PATH, "r", encoding="utf-8") as fh:
        rows = [json.loads(line) for line in fh if line.strip()]

    tp = fp = tn = fn = 0
    tactic_correct = tactic_total = 0
    failures = []
    for row in rows:
        v = det.assess(row["text"])
        flagged = v.level != "SAFE"
        is_scam = row["label"] == "scam"
        if is_scam and flagged:
            tp += 1
        elif is_scam and not flagged:
            fn += 1
            failures.append(("MISSED SCAM", row["text"], v))
        elif not is_scam and flagged:
            fp += 1
            failures.append(("FALSE ALARM", row["text"], v))
        else:
            tn += 1
        # per-tactic recall on scam rows
        for want in row["tactics"]:
            tactic_total += 1
            if want in v.tactics:
                tactic_correct += 1

    total = len(rows)
    acc = (tp + tn) / total if total else 0.0
    prec = tp / (tp + fp) if (tp + fp) else 1.0
    rec = tp / (tp + fn) if (tp + fn) else 1.0
    print("Kavach reference detector — seed evaluation")
    print("-" * 48)
    print(f"  lines           : {total}")
    print(f"  scam recall     : {rec:.0%}  (caught {tp}/{tp + fn} scam lines)")
    print(f"  precision       : {prec:.0%}  (false alarms: {fp})")
    print(f"  accuracy        : {acc:.0%}")
    print(f"  tactic recall   : {tactic_correct}/{tactic_total} expected tactics found")
    if failures:
        print("\n  failures:")
        for kind, text, v in failures:
            print(f"   [{kind}] ({v.level} {v.score}) {text}")
    else:
        print("\n  no failures — every scam flagged, every legit call clean.")
    # exit non-zero if we miss scams or accuracy regresses, so CI/host runs can gate on it
    return 0 if (fn == 0 and acc >= 0.9) else 1


def _score_one(det: Detector, text: str) -> int:
    v = det.assess(text)
    print(f'"{text}"\n')
    print(f"  risk   : {v.level} ({v.level_label})  score={v.score}")
    print(f"  tactics: {', '.join(v.tactics) or 'none'}")
    for ex, ac in zip(v.explanations, v.actions):
        print(f"   • {ex}\n     → {ac}")
    return 0


def main(argv: list[str]) -> int:
    det = Detector()
    if len(argv) > 1:
        return _score_one(det, " ".join(argv[1:]))
    return _evaluate(det)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
