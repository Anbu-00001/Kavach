"""Translation-AUGMENTED multilingual training for Kavach (Colab GPU).

Why: zero-shot cross-lingual transfer from English-only training is weak for distant / non-Latin
languages (Hindi, Tamil missed entirely in testing). The fix — same as the published KorCCVi work —
is to machine-translate the English dataset into target languages and train on the union, so the
classifier head learns the multilingual regions of the embedding space directly.

Pipeline (all on Colab GPU, laptop stays cool):
  1. Upload train.jsonl, val.jsonl, seed_calls.jsonl.
  2. Translate every line into TARGET_LANGS with NLLB-200 (labels are preserved).
  3. Train paraphrase-multilingual-MiniLM-L12-v2 on English + all translations.
  4. Evaluate per-language recall on a translated val set (honest multilingual numbers).
  5. Export int8 ONNX + tokenizer and download.

HOW TO RUN: Colab -> GPU (T4) runtime -> paste this whole file into a cell -> Run. Upload the 3
jsonl files when prompted. Drop the downloaded files into core/model/intent_ml/.
"""

import json
import os
import subprocess
import sys

IN_COLAB = "google.colab" in sys.modules
ENCODER = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
NLLB = "facebook/nllb-200-distilled-600M"
TACTICS = ["URGENCY", "SECRECY", "UNTRACEABLE_PAYMENT", "AUTHORITY_IMPERSONATION",
           "DISTRESS_HOOK", "ISOLATION", "IDENTITY_PROBE", "RELATIONSHIP_SPOOF"]
L2I = {t: i for i, t in enumerate(TACTICS)}
MAX_LEN = 48
OUT = "intent_ml"

# Target languages (NLLB codes): India-heavy + global. English is always kept as-is.
TARGET_LANGS = {
    "hin_Deva": "Hindi", "tam_Taml": "Tamil", "tel_Telu": "Telugu", "ben_Beng": "Bengali",
    "spa_Latn": "Spanish", "fra_Latn": "French", "deu_Latn": "German", "por_Latn": "Portuguese",
    "arb_Arab": "Arabic", "zho_Hans": "Chinese", "rus_Cyrl": "Russian",
    "kor_Hang": "Korean",  # added so real Korean KorCCVi data is a fair validation, not zero-shot
}


def main():
    if IN_COLAB:
        subprocess.run("pip -q install transformers sentencepiece sacremoses onnx onnxruntime onnxscript",
                       shell=True, check=True)

    import torch
    from torch.utils.data import DataLoader, Dataset
    from transformers import (AutoModelForSeq2SeqLM, AutoModelForSequenceClassification,
                              AutoTokenizer)

    dev = "cuda" if torch.cuda.is_available() else "cpu"
    print("device:", dev)

    # --- data ---
    if IN_COLAB:
        from google.colab import files
        print("Upload train.jsonl, val.jsonl, seed_calls.jsonl…")
        files.upload()
        load = lambda n: [json.loads(x) for x in open(n) if x.strip()]
    else:
        d = os.path.join(os.path.dirname(os.path.abspath(__file__)), "datasets")
        load = lambda n: [json.loads(x) for x in open(os.path.join(d, n)) if x.strip()]
    train_rows, val_rows = load("train.jsonl"), load("val.jsonl")

    # --- translation augmentation ---
    mt_tok = AutoTokenizer.from_pretrained(NLLB)
    mt = AutoModelForSeq2SeqLM.from_pretrained(NLLB).to(dev).eval()
    mt_tok.src_lang = "eng_Latn"

    @torch.no_grad()
    def translate(texts, tgt, bs=32):
        out = []
        bos = mt_tok.convert_tokens_to_ids(tgt)
        for i in range(0, len(texts), bs):
            chunk = texts[i:i + bs]
            enc = mt_tok(chunk, return_tensors="pt", padding=True, truncation=True,
                         max_length=64).to(dev)
            gen = mt.generate(**enc, forced_bos_token_id=bos, max_length=80, num_beams=1)
            out += mt_tok.batch_decode(gen, skip_special_tokens=True)
        return out

    def augment(rows, langs):
        texts = [r["text"] for r in rows]
        aug = list(rows)  # keep English originals
        for code, name in langs.items():
            print(f"  translating {len(texts)} lines -> {name} ({code})")
            tr = translate(texts, code)
            aug += [{"text": t, "labels": r["labels"]} for t, r in zip(tr, rows)]
        return aug

    print("augmenting train set…")
    train_aug = augment(train_rows, TARGET_LANGS)
    print(f"train: {len(train_rows)} -> {len(train_aug)} lines across {len(TARGET_LANGS)+1} languages")
    # multilingual val: English + translations, tracked per-language for honest metrics
    val_by_lang = {"English": val_rows}
    val_texts = [r["text"] for r in val_rows]
    for code, name in TARGET_LANGS.items():
        tr = translate(val_texts, code)
        val_by_lang[name] = [{"text": t, "labels": r["labels"]} for t, r in zip(tr, val_rows)]

    del mt  # free GPU memory before training
    torch.cuda.empty_cache() if dev == "cuda" else None

    # --- train classifier ---
    tok = AutoTokenizer.from_pretrained(ENCODER)
    model = AutoModelForSequenceClassification.from_pretrained(
        ENCODER, num_labels=8, problem_type="multi_label_classification",
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

    tl = DataLoader(DS(train_aug), batch_size=32, shuffle=True)
    opt = torch.optim.AdamW(model.parameters(), lr=3e-5)

    @torch.no_grad()
    def recall_for(rows):
        model.eval()
        tp = fp = fn = 0
        ds = DS(rows)
        dl = DataLoader(ds, batch_size=64)
        for b in dl:
            lo = model(input_ids=b["input_ids"].to(dev),
                       attention_mask=b["attention_mask"].to(dev)).logits.cpu()
            pred = (lo.sigmoid() >= 0.5).int()
            true = b["labels"].int()
            ps, ts = pred.sum(1) > 0, true.sum(1) > 0
            tp += int((ps & ts).sum()); fp += int((ps & ~ts).sum()); fn += int((~ps & ts).sum())
        return tp / (tp + fn or 1), tp / (tp + fp or 1)

    for ep in range(1, 7):
        model.train()
        tot = 0.0
        for b in tl:
            opt.zero_grad()
            out = model(input_ids=b["input_ids"].to(dev),
                        attention_mask=b["attention_mask"].to(dev), labels=b["labels"].to(dev))
            out.loss.backward()
            opt.step()
            tot += out.loss.item()
        print(f"ep{ep} loss={tot/len(tl):.4f}")

    print("\nper-language val (recall / precision):")
    for name, rows in val_by_lang.items():
        rec, prec = recall_for(rows)
        print(f"  {name:11} recall={rec:.0%}  precision={prec:.0%}")

    # --- save + export int8 ---
    os.makedirs(OUT, exist_ok=True)
    model.cpu().save_pretrained(OUT)
    tok.save_pretrained(OUT)
    json.dump(TACTICS, open(os.path.join(OUT, "labels.json"), "w"))

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
    print(f"\nint8 ONNX: {os.path.getsize(int8)/1e6:.1f} MB")

    if IN_COLAB:
        from google.colab import files
        for f in ["intent.int8.onnx", "labels.json", "config.json", "tokenizer.json",
                  "tokenizer_config.json", "special_tokens_map.json", "sentencepiece.bpe.model"]:
            p = os.path.join(OUT, f)
            if os.path.exists(p):
                files.download(p)


if __name__ == "__main__":
    main()
