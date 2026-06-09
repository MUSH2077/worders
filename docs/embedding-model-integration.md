# WORDERS Embedding Model Integration

## Current Decision

WORDERS uses `EmbeddingService` as the single runtime interface for semantic word matching.

Recommended production source:

- fastText Common Crawl / Wikipedia Chinese word vectors.
- Preprocess outside Godot.
- Export only words used by `resources/word_bank.json` plus common player-facing candidates.
- Save as a compact JSON file compatible with `resources/embedding_vectors.json`.

DeepSeek remains the AI opponent/chat model. It is not used as the embedding backend because the current DeepSeek public API surface is centered on chat completions, JSON output, and tool calls rather than a dedicated embedding endpoint.

## Runtime Contract

`EmbeddingService` exposes:

- `load_model(path)`
- `get_vector(word)`
- `similarity(word_a, word_b)`
- `sentence_similarity(words)`
- `bonus_for_words(words)`
- `model_status()`

`ScoringEngine.ScoreBreakdown` now includes:

- `embedding_bonus`
- `embedding_similarity`

The battle prediction UI shows semantic similarity as `Sem` / `语义`.

## JSON Format

```json
{
  "source": "preprocessed fastText cc.zh.300 reduced to gameplay words",
  "dimensions": 8,
  "vectors": {
    "dragon": [0.92, 0.82, 0.18, 0.10, 0.20, 0.12, 0.16, 0.08]
  }
}
```

The current file is a small gameplay seed model. It is intentionally lightweight so tests and packaged builds stay fast.

## Fallback

If a word is not found in the vector JSON but exists in `WordBank`, `EmbeddingService` generates a deterministic profile vector from the word's part of speech and content category.

If the word is unknown, semantic similarity is `0`, and the game keeps the existing soft-constraint behavior: unknown words are playable, unverified, and not blocked.

## Judgment Pipeline (L1/L2/L3)

Word judgment is layered so the word bank stays a fast local floor without being the only source of truth:

- **L1 — `ConstraintValidator`** (local, always on): exact `WordBank` lookup with alias normalization. Emits a structured `ConstraintResult.trace` of `SlotJudgment` entries (`source = word_bank | alias | unknown | empty`, `pos_ok`, `content_ok`, `matched`, `flags`). The trace is copied onto `ScoreBreakdown.judgment_trace`.
- **L2 — `EmbeddingService`** (local): adjacent `similarity`, all-pairs `coherence`, and `bonus_for_words`.
- **L3 — optional DeepSeek review**: only consulted for `unknown` words, gated by the `judgment_mode` setting. Results are validated against the local enums, cached in `user://`, and may either annotate the trace only or feed `constraint_bonus`/`penalty` depending on `ds_judgment_affects_score`.

### Word bank aliases

`resources/word_bank.json` accepts an optional `"aliases"` map of `variant -> canonical`. `WordBank.find_entries` falls back to the canonical entry when the exact surface form is missing (simplified/traditional, suffix forms like `咆哮着`, simple synonyms). This widens L1 coverage without inflating the entry list.
