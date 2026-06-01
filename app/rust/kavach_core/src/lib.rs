//! kavach-core — the shared Rust brain.
//!
//! Today: scam-tactic risk **fusion** (a faithful port of `core/reference_detector.py` /
//! `core/kavach_engine.py`), so host tests and the on-device JNI library behave identically.
//! Next: tokenization (HF `tokenizers` crate over `tokenizer.json`) and acoustic DSP cues.
//!
//! The Kotlin layer runs Vosk (ASR) and ONNX Runtime (the classifier); it hands the per-tactic
//! probabilities to `Engine::assess`, which returns the fused risk level + the pre-vetted,
//! plain-language explanation shown on the shield. Fusion lives here once — never duplicated.

use serde::Deserialize;

#[derive(Deserialize)]
struct Tactic {
    id: String,
    #[allow(dead_code)]
    name: String,
    weight: f32,
    explanation: String,
    action: String,
}

#[derive(Deserialize)]
struct RiskLevel {
    id: String,
    label: String,
    min_score: f32,
}

#[derive(Deserialize)]
struct Combo {
    tactics: Vec<String>,
    boost: f32,
}

#[derive(Deserialize)]
struct Fusion {
    combo_boosts: Vec<Combo>,
    acoustic_weight: f32,
}

#[derive(Deserialize)]
struct Taxonomy {
    tactics: Vec<Tactic>,
    risk_levels: Vec<RiskLevel>,
    fusion: Fusion,
}

const TAXONOMY_JSON: &str = include_str!("../taxonomy.json");
const THRESHOLD: f32 = 0.5;

/// Fused result for one analysis window/call. `tactics`/`explanations`/`actions` are aligned and
/// ordered by tactic weight (most decisive first).
#[derive(Debug, Clone)]
pub struct Verdict {
    pub score: f32,
    pub level: String,
    pub level_label: String,
    pub tactics: Vec<String>,
    pub explanations: Vec<String>,
    pub actions: Vec<String>,
}

pub struct Engine {
    tax: Taxonomy,
    levels_desc: Vec<usize>, // risk-level indices sorted by min_score, high -> low
}

impl Engine {
    pub fn new() -> Self {
        let tax: Taxonomy = serde_json::from_str(TAXONOMY_JSON).expect("valid taxonomy.json");
        let mut levels_desc: Vec<usize> = (0..tax.risk_levels.len()).collect();
        levels_desc.sort_by(|&a, &b| {
            tax.risk_levels[b]
                .min_score
                .partial_cmp(&tax.risk_levels[a].min_score)
                .unwrap()
        });
        Engine { tax, levels_desc }
    }

    /// Tactic ids in model-output order (so callers can build the `probs` slice correctly).
    pub fn tactic_order(&self) -> Vec<String> {
        self.tax.tactics.iter().map(|t| t.id.clone()).collect()
    }

    /// `probs`: per-tactic probabilities in taxonomy order. `acoustic`: synthetic-voice signal [0,1].
    /// Noisy-OR over weighted tactics + dangerous-combo boosts + acoustic, mapped to a risk level.
    pub fn assess(&self, probs: &[f32], acoustic: f32) -> Verdict {
        let present: Vec<usize> = probs
            .iter()
            .enumerate()
            .filter(|(i, &p)| *i < self.tax.tactics.len() && p >= THRESHOLD)
            .map(|(i, _)| i)
            .collect();

        // noisy-OR over weight * prob
        let mut prod = 1.0f32;
        for &i in &present {
            prod *= 1.0 - self.tax.tactics[i].weight * probs[i];
        }
        let mut score = 1.0 - prod;

        // dangerous-combination boosts (e.g. payment + urgency)
        for c in &self.tax.fusion.combo_boosts {
            if c.tactics
                .iter()
                .all(|id| present.iter().any(|&i| &self.tax.tactics[i].id == id))
            {
                score += c.boost;
            }
        }
        score += self.tax.fusion.acoustic_weight * acoustic.clamp(0.0, 1.0);
        score = score.clamp(0.0, 1.0);

        let (level, level_label) = self.risk_level(score);

        let mut ordered = present.clone();
        ordered.sort_by(|&a, &b| {
            self.tax.tactics[b]
                .weight
                .partial_cmp(&self.tax.tactics[a].weight)
                .unwrap()
        });
        Verdict {
            score,
            level,
            level_label,
            tactics: ordered.iter().map(|&i| self.tax.tactics[i].id.clone()).collect(),
            explanations: ordered.iter().map(|&i| self.tax.tactics[i].explanation.clone()).collect(),
            actions: ordered.iter().map(|&i| self.tax.tactics[i].action.clone()).collect(),
        }
    }

    fn risk_level(&self, score: f32) -> (String, String) {
        for &i in &self.levels_desc {
            if score >= self.tax.risk_levels[i].min_score {
                return (
                    self.tax.risk_levels[i].id.clone(),
                    self.tax.risk_levels[i].label.clone(),
                );
            }
        }
        let last = *self.levels_desc.last().unwrap();
        (
            self.tax.risk_levels[last].id.clone(),
            self.tax.risk_levels[last].label.clone(),
        )
    }
}

impl Default for Engine {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn probs(engine: &Engine, set: &[(&str, f32)]) -> Vec<f32> {
        let order = engine.tactic_order();
        let mut v = vec![0.0f32; order.len()];
        for (id, p) in set {
            let idx = order.iter().position(|t| t == id).expect("known tactic id");
            v[idx] = *p;
        }
        v
    }

    #[test]
    fn legit_is_safe() {
        let e = Engine::new();
        let v = e.assess(&probs(&e, &[]), 0.0);
        assert_eq!(v.level, "SAFE");
        assert!(v.score < 1e-6);
        assert!(v.tactics.is_empty());
    }

    #[test]
    fn classic_scam_is_high() {
        let e = Engine::new();
        let p = probs(
            &e,
            &[("UNTRACEABLE_PAYMENT", 0.99), ("SECRECY", 0.95), ("DISTRESS_HOOK", 0.94)],
        );
        let v = e.assess(&p, 0.0);
        assert_eq!(v.level, "HIGH");
        assert!(v.score > 0.9, "score was {}", v.score);
        // most decisive tactic surfaces first, with a real explanation
        assert_eq!(v.tactics[0], "UNTRACEABLE_PAYMENT");
        assert!(!v.explanations[0].is_empty());
    }

    #[test]
    fn single_moderate_tactic_is_caution_not_high() {
        let e = Engine::new();
        let v = e.assess(&probs(&e, &[("URGENCY", 0.9)]), 0.0);
        assert_eq!(v.level, "CAUTION"); // 1-(1-0.7*0.9)=0.63 -> CAUTION, below HIGH(0.75)
    }

    #[test]
    fn acoustic_signal_nudges_score() {
        let e = Engine::new();
        let base = e.assess(&probs(&e, &[("URGENCY", 0.9)]), 0.0).score;
        let boosted = e.assess(&probs(&e, &[("URGENCY", 0.9)]), 1.0).score;
        assert!(boosted > base);
    }
}
