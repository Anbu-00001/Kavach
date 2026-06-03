"""Fine-tune a tiny transformer for multi-label scam-tactic detection (CPU-friendly).

Replaces the keyword reference detector's `detect_tactics` with a model that emits per-tactic
probabilities. Same 8-class label space (taxonomy.json), so the fusion/explanation logic is
unchanged. Default model is intentionally tiny so it quantizes to a few MB for the OPPO A18.

Run:  python3 core/train_classifier.py [--model prajjwal1/bert-tiny] [--epochs 8]
"""

from __future__ import annotations

import argparse
import json
import os

import torch
from torch.utils.data import DataLoader, Dataset
from transformers import AutoModelForSequenceClassification, AutoTokenizer

from build_dataset import TACTICS  # single source of truth for the label space

HERE = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(HERE, "datasets")
LABEL2ID = {t: i for i, t in enumerate(TACTICS)}


def read_split(name: str) -> list[dict]:
    with open(os.path.join(DATA_DIR, f"{name}.jsonl"), encoding="utf-8") as fh:
        return [json.loads(line) for line in fh if line.strip()]


def multihot(labels: list[str]) -> list[float]:
    v = [0.0] * len(TACTICS)
    for lab in labels:
        v[LABEL2ID[lab]] = 1.0
    return v


class CallDataset(Dataset):
    def __init__(self, rows, tokenizer, max_len=48):
        self.enc = tokenizer([r["text"] for r in rows], truncation=True,
                             padding="max_length", max_length=max_len, return_tensors="pt")
        self.y = torch.tensor([multihot(r["labels"]) for r in rows], dtype=torch.float)

    def __len__(self):
        return len(self.y)

    def __getitem__(self, i):
        return {"input_ids": self.enc["input_ids"][i],
                "attention_mask": self.enc["attention_mask"][i],
                "labels": self.y[i]}


@torch.no_grad()
def evaluate(model, loader, thr=0.5):
    model.eval()
    tp = fp = tn = fn = 0           # product-level: scam (any tactic) vs legit
    lab_tp = lab_fp = lab_fn = 0    # micro per-tactic
    for batch in loader:
        logits = model(input_ids=batch["input_ids"], attention_mask=batch["attention_mask"]).logits
        prob = torch.sigmoid(logits)
        pred = (prob >= thr).int()
        true = batch["labels"].int()
        # per-tactic micro counts
        lab_tp += int(((pred == 1) & (true == 1)).sum())
        lab_fp += int(((pred == 1) & (true == 0)).sum())
        lab_fn += int(((pred == 0) & (true == 1)).sum())
        # product decision: is anything flagged?
        pred_scam = pred.sum(dim=1) > 0
        true_scam = true.sum(dim=1) > 0
        tp += int((pred_scam & true_scam).sum())
        fp += int((pred_scam & ~true_scam).sum())
        fn += int((~pred_scam & true_scam).sum())
        tn += int((~pred_scam & ~true_scam).sum())
    n = tp + fp + tn + fn
    acc = (tp + tn) / n if n else 0.0
    rec = tp / (tp + fn) if (tp + fn) else 1.0
    prec = tp / (tp + fp) if (tp + fp) else 1.0
    micro_f1 = (2 * lab_tp) / (2 * lab_tp + lab_fp + lab_fn) if lab_tp else 0.0
    return {"acc": acc, "scam_recall": rec, "precision": prec, "false_alarms": fp,
            "tactic_micro_f1": micro_f1}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="prajjwal1/bert-tiny")
    ap.add_argument("--epochs", type=int, default=8)
    ap.add_argument("--batch", type=int, default=16)
    # NOTE: 5e-4 suits the tiny default (bert-tiny). For a real transformer like
    # all-MiniLM-L6-v2, use ~3e-5 — higher LRs collapse the head to all-zeros
    # (val recall 0%, loss flat). See docs/EVALUATION.md "retrain" notes.
    ap.add_argument("--lr", type=float, default=5e-4)
    ap.add_argument("--out", default=os.path.join(HERE, "model", "intent"))
    ap.add_argument("--threads", type=int, default=5,
                    help="cap CPU threads to keep the laptop cool (default 5 of 12)")
    args = ap.parse_args()

    torch.manual_seed(0)
    # Thermal safety: never grab every core. Capped by default so long sessions don't overheat.
    torch.set_num_threads(max(1, min(args.threads, os.cpu_count() or 4)))

    try:
        tok = AutoTokenizer.from_pretrained(args.model)
    except ValueError:
        # some tiny-BERT repos ship only a slow (WordPiece) tokenizer; that's fine for training
        tok = AutoTokenizer.from_pretrained(args.model, use_fast=False)
    model = AutoModelForSequenceClassification.from_pretrained(
        args.model, num_labels=len(TACTICS), problem_type="multi_label_classification",
        id2label={i: t for i, t in enumerate(TACTICS)}, label2id=LABEL2ID)

    train_loader = DataLoader(CallDataset(read_split("train"), tok), batch_size=args.batch, shuffle=True)
    val_loader = DataLoader(CallDataset(read_split("val"), tok), batch_size=64)

    opt = torch.optim.AdamW(model.parameters(), lr=args.lr)
    print(f"model={args.model}  params={sum(p.numel() for p in model.parameters())/1e6:.1f}M  "
          f"epochs={args.epochs}")
    for ep in range(1, args.epochs + 1):
        model.train()
        total = 0.0
        for batch in train_loader:
            opt.zero_grad()
            out = model(input_ids=batch["input_ids"], attention_mask=batch["attention_mask"],
                        labels=batch["labels"])
            out.loss.backward()
            opt.step()
            total += out.loss.item()
        m = evaluate(model, val_loader)
        print(f"  ep{ep:2d}  loss={total/len(train_loader):.4f}  "
              f"scam_recall={m['scam_recall']:.0%}  precision={m['precision']:.0%}  "
              f"false_alarms={m['false_alarms']}  tactic_f1={m['tactic_micro_f1']:.2f}")

    os.makedirs(args.out, exist_ok=True)
    model.save_pretrained(args.out)
    tok.save_pretrained(args.out)
    with open(os.path.join(args.out, "labels.json"), "w") as fh:
        json.dump(TACTICS, fh)
    print(f"\nsaved -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
