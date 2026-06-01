"""Train the MULTILINGUAL Kavach intent classifier on Colab GPU (keeps the laptop cool).

WHY COLAB: paraphrase-multilingual-MiniLM-L12-v2 (~118M params) is ~5x our English model; training
it on the throttled laptop CPU would run 40+ min and hot. On a free Colab T4 it's a few minutes.
Inference, ONNX export, and the whole Flutter app stay local. Cross-lingual transfer means training
on our ENGLISH data yields a classifier that works zero-shot in 50+ languages.

HOW TO RUN (in Google Colab):
  1. Runtime -> Change runtime type -> Hardware accelerator: GPU (T4 is plenty).
  2. New cell:  %run colab_train_multilingual.py   (or paste this file's body into a cell)
  3. When prompted, upload core/datasets/train.jsonl, val.jsonl (and seed_calls.jsonl).
  4. It trains, exports an int8 ONNX, and downloads the artifacts. Drop them into
     core/model/intent_ml/ in the repo.

NOTE: this model's tokenizer is SentencePiece (XLM-R), not WordPiece. On-device we bake the
tokenizer into the graph with onnxruntime-extensions, so Dart just passes the raw string.
"""

import json
import os
import subprocess
import sys

IN_COLAB = "google.colab" in sys.modules
MODEL = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
TACTICS = ["URGENCY", "SECRECY", "UNTRACEABLE_PAYMENT", "AUTHORITY_IMPERSONATION",
           "DISTRESS_HOOK", "ISOLATION", "IDENTITY_PROBE", "RELATIONSHIP_SPOOF"]
L2I = {t: i for i, t in enumerate(TACTICS)}
MAX_LEN = 48
OUT = "intent_ml"


def main():
    if IN_COLAB:
        subprocess.run("pip -q install transformers onnx onnxruntime onnxscript sentencepiece",
                       shell=True, check=True)

    import torch
    from torch.utils.data import DataLoader, Dataset
    from transformers import AutoModelForSequenceClassification, AutoTokenizer

    # --- data ---
    if IN_COLAB:
        from google.colab import files
        print("Upload train.jsonl, val.jsonl (and optionally seed_calls.jsonl)…")
        files.upload()
        load = lambda n: [json.loads(x) for x in open(n) if x.strip()]
    else:
        d = os.path.join(os.path.dirname(os.path.abspath(__file__)), "datasets")
        load = lambda n: [json.loads(x) for x in open(os.path.join(d, n)) if x.strip()]
    train_rows, val_rows = load("train.jsonl"), load("val.jsonl")

    dev = "cuda" if torch.cuda.is_available() else "cpu"
    print("device:", dev, "| examples:", len(train_rows), "train /", len(val_rows), "val")

    tok = AutoTokenizer.from_pretrained(MODEL)
    model = AutoModelForSequenceClassification.from_pretrained(
        MODEL, num_labels=8, problem_type="multi_label_classification",
        id2label={i: t for i, t in enumerate(TACTICS)}, label2id=L2I).to(dev)

    def mh(labels):
        v = [0.0] * 8
        for l in labels:
            v[L2I[l]] = 1.0
        return v

    class DS(Dataset):
        def __init__(self, rows):
            self.e = tok([r["text"] for r in rows], truncation=True, padding="max_length",
                         max_length=MAX_LEN, return_tensors="pt")
            self.y = torch.tensor([mh(r["labels"]) for r in rows])

        def __len__(self):
            return len(self.y)

        def __getitem__(self, i):
            return {"input_ids": self.e["input_ids"][i],
                    "attention_mask": self.e["attention_mask"][i], "labels": self.y[i]}

    tl = DataLoader(DS(train_rows), batch_size=32, shuffle=True)
    vl = DataLoader(DS(val_rows), batch_size=64)
    opt = torch.optim.AdamW(model.parameters(), lr=3e-5)

    @torch.no_grad()
    def ev():
        model.eval()
        tp = fp = tn = fn = 0
        for b in vl:
            lo = model(input_ids=b["input_ids"].to(dev),
                       attention_mask=b["attention_mask"].to(dev)).logits.cpu()
            pred = (torch.sigmoid(lo) >= 0.5).int()
            true = b["labels"].int()
            ps, ts = pred.sum(1) > 0, true.sum(1) > 0
            tp += int((ps & ts).sum()); fp += int((ps & ~ts).sum())
            fn += int((~ps & ts).sum()); tn += int((~ps & ~ts).sum())
        return tp / (tp + fn or 1), tp / (tp + fp or 1), fp

    for ep in range(1, 11):
        model.train()
        tot = 0.0
        for b in tl:
            opt.zero_grad()
            out = model(input_ids=b["input_ids"].to(dev),
                        attention_mask=b["attention_mask"].to(dev), labels=b["labels"].to(dev))
            out.loss.backward()
            opt.step()
            tot += out.loss.item()
        rec, prec, fp = ev()
        print(f"ep{ep:2d} loss={tot/len(tl):.4f} scam_recall={rec:.0%} precision={prec:.0%} fp={fp}")

    os.makedirs(OUT, exist_ok=True)
    model.cpu().save_pretrained(OUT)
    tok.save_pretrained(OUT)
    json.dump(TACTICS, open(os.path.join(OUT, "labels.json"), "w"))

    # --- export int8 ONNX (same value_info-strip fix as export_onnx.py) ---
    import onnx
    from onnxruntime.quantization import quantize_dynamic, QuantType
    model.eval()
    e = tok("hello", return_tensors="pt", padding="max_length", max_length=MAX_LEN,
            truncation=True, return_token_type_ids=False)
    fp32 = os.path.join(OUT, "intent.onnx")
    torch.onnx.export(model, (e["input_ids"], e["attention_mask"]), fp32,
                      input_names=["input_ids", "attention_mask"], output_names=["logits"],
                      dynamic_axes={"input_ids": {0: "b", 1: "s"}, "attention_mask": {0: "b", 1: "s"},
                                    "logits": {0: "b"}}, opset_version=17, do_constant_folding=True)
    m = onnx.load(fp32)
    del m.graph.value_info[:]
    for o in m.graph.output:
        o.type.tensor_type.ClearField("shape")
    clean = os.path.join(OUT, "intent.clean.onnx")
    onnx.save(m, clean)
    int8 = os.path.join(OUT, "intent.int8.onnx")
    quantize_dynamic(clean, int8, weight_type=QuantType.QInt8)
    os.remove(clean)
    print(f"int8 ONNX: {os.path.getsize(int8)/1e6:.1f} MB")

    if IN_COLAB:
        from google.colab import files
        for f in ["intent.int8.onnx", "labels.json", "config.json", "tokenizer.json",
                  "tokenizer_config.json", "special_tokens_map.json", "sentencepiece.bpe.model",
                  "vocab.txt"]:
            p = os.path.join(OUT, f)
            if os.path.exists(p):
                files.download(p)


if __name__ == "__main__":
    main()
