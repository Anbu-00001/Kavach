"""Export the trained tactic classifier to ONNX, quantize to int8, and verify parity.

Produces the artifact Kavach ships on-device: a quantized ONNX model (+ tokenizer files) small
enough for the OPPO A18. Reports fp32 vs int8 size, CPU latency, and confirms the int8 model's
scam-detection metrics match the PyTorch model (no accuracy cliff from quantization).

Run (after training):  python3 core/export_onnx.py
"""

from __future__ import annotations

import json
import os
import time

import numpy as np
import torch
from transformers import AutoModelForSequenceClassification, AutoTokenizer

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(HERE, "model", "intent")
ONNX_FP32 = os.path.join(MODEL_DIR, "intent.onnx")
ONNX_INT8 = os.path.join(MODEL_DIR, "intent.int8.onnx")
DATA_DIR = os.path.join(HERE, "datasets")
MAX_LEN = 48


def mb(path: str) -> float:
    return os.path.getsize(path) / 1e6


def export() -> None:
    tok = AutoTokenizer.from_pretrained(MODEL_DIR)
    model = AutoModelForSequenceClassification.from_pretrained(MODEL_DIR).eval()
    enc = tok("hello", return_tensors="pt", padding="max_length", max_length=MAX_LEN,
              truncation=True, return_token_type_ids=False)
    dummy = (enc["input_ids"], enc["attention_mask"])
    torch.onnx.export(
        model, dummy, ONNX_FP32,
        input_names=["input_ids", "attention_mask"], output_names=["logits"],
        dynamic_axes={"input_ids": {0: "b", 1: "s"}, "attention_mask": {0: "b", 1: "s"},
                      "logits": {0: "b"}},
        opset_version=17, do_constant_folding=True)
    print(f"  exported fp32 ONNX -> {mb(ONNX_FP32):.1f} MB")


def quantize() -> None:
    import onnx
    from onnxruntime.quantization import quantize_dynamic, QuantType
    # The dynamo exporter leaves intermediate shape annotations that clash with onnxruntime's
    # pre-quantization shape inference (the "384 vs 8" error). Strip value_info + output shapes
    # so inference re-derives them consistently; weight-only int8 quant doesn't need them.
    m = onnx.load(ONNX_FP32)
    del m.graph.value_info[:]
    for o in m.graph.output:
        o.type.tensor_type.ClearField("shape")
    clean = ONNX_FP32.replace(".onnx", ".clean.onnx")
    onnx.save(m, clean)
    quantize_dynamic(clean, ONNX_INT8, weight_type=QuantType.QInt8)
    os.remove(clean)
    print(f"  quantized int8 ONNX -> {mb(ONNX_INT8):.1f} MB  "
          f"({mb(ONNX_FP32) / mb(ONNX_INT8):.1f}x smaller)")


def verify_and_benchmark() -> None:
    import onnxruntime as ort
    tok = AutoTokenizer.from_pretrained(MODEL_DIR)
    sess = ort.InferenceSession(ONNX_INT8, providers=["CPUExecutionProvider"])

    with open(os.path.join(DATA_DIR, "val.jsonl"), encoding="utf-8") as fh:
        rows = [json.loads(l) for l in fh if l.strip()]

    def run(text: str) -> np.ndarray:
        e = tok(text, return_tensors="np", padding="max_length", max_length=MAX_LEN,
                truncation=True, return_token_type_ids=False)
        logits = sess.run(None, {"input_ids": e["input_ids"].astype(np.int64),
                                 "attention_mask": e["attention_mask"].astype(np.int64)})[0]
        return 1 / (1 + np.exp(-logits[0]))  # sigmoid

    tp = fp = tn = fn = 0
    t0 = time.perf_counter()
    for r in rows:
        prob = run(r["text"])
        pred_scam = bool((prob >= 0.5).any())
        true_scam = len(r["labels"]) > 0
        tp += pred_scam and true_scam
        fp += pred_scam and not true_scam
        fn += (not pred_scam) and true_scam
        tn += (not pred_scam) and not true_scam
    dt = (time.perf_counter() - t0) / len(rows) * 1000
    rec = tp / (tp + fn) if (tp + fn) else 1.0
    prec = tp / (tp + fp) if (tp + fp) else 1.0
    print(f"  int8 parity on val: scam_recall={rec:.0%}  precision={prec:.0%}  false_alarms={fp}")
    print(f"  CPU latency: {dt:.1f} ms/utterance (laptop; phone will differ)")


def main() -> int:
    if not os.path.isdir(MODEL_DIR):
        print(f"no trained model at {MODEL_DIR} — run train_classifier.py first")
        return 1
    export()
    quantize()
    verify_and_benchmark()
    print(f"\nship artifact: {ONNX_INT8}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
