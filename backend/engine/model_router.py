"""
Chrysos — Model Router (Multi-Router Step 2)
Routes each subtask to the most cost-efficient model tier based on task type.

Tiers (weakest → strongest):
  lightweight  → llama-3.1-8b-instant   (math, simple Q&A)
  midweight    → llama-4-scout-17b       (structured reasoning)
  heavyweight  → llama-3.3-70b-versatile (final synthesis, deep advice)
  offline      → qwen3:1.7b / Ollama    (decomposition only, free)
  data_api     → yfinance               (live stock data, zero LLM cost)
"""
import os
import logging
from typing import Literal

logger = logging.getLogger("model_router")
logger.setLevel(logging.DEBUG)
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter(
        "\033[34m[ROUTER]\033[0m %(asctime)s — %(message)s", datefmt="%H:%M:%S"
    ))
    logger.addHandler(handler)

# ── Model registry ────────────────────────────────────────────────────────────
ModelTier = Literal["lightweight", "midweight", "heavyweight", "offline"]

MODEL_REGISTRY: dict[ModelTier, list[str]] = {
    "lightweight": [
        os.getenv("LLM_LIGHTWEIGHT", "llama-3.1-8b-instant"),
        "allam-2-7b",
    ],
    "midweight": [
        os.getenv("LLM_MIDWEIGHT", "llama-4-scout-17b-16e-instruct"),
        "moonshotai/kimi-k2-instruct",
    ],
    "heavyweight": [
        os.getenv("LLM_HEAVYWEIGHT", "llama-3.3-70b-versatile"),
        "llama-3.3-70b-versatile",           # explicit fallback
    ],
    "offline": [
        os.getenv("OLLAMA_MODEL", "qwen3:1.7b"),
    ],
}

# ── Task type → tier mapping ──────────────────────────────────────────────────
TASK_TIER_MAP: dict[str, ModelTier] = {
    # New schema (tool/calculation/analysis/final)
    "tool":        "lightweight",   # yfinance results just need quick formatting
    "calculation": "lightweight",   # percentage calcs, SIP math
    "analysis":    "midweight",     # compare options, risk assessment
    "final":       "heavyweight",   # final human-readable recommendation
    # Legacy schema (kept for backward compat)
    "data_fetch":  "lightweight",
    "math":        "lightweight",
    "reasoning":   "midweight",
    "synthesis":   "heavyweight",
}

# ── Confidence-based escalation thresholds ────────────────────────────────────
ESCALATION_THRESHOLD = 0.6   # below this confidence, escalate one tier


def route_task(task: dict) -> tuple[ModelTier, str]:
    """
    Return (tier_name, model_name) for a given subtask.
    Escalates to a stronger tier when task confidence is below threshold.
    """
    task_type  = task.get("type", "synthesis")
    confidence = float(task.get("confidence", 1.0))

    base_tier = TASK_TIER_MAP.get(task_type, "heavyweight")

    # Escalate if confidence is low
    if confidence < ESCALATION_THRESHOLD:
        base_tier = _escalate(base_tier)
        logger.info(
            "Task '%s' (conf=%.2f) escalated → %s",
            task.get("description", "?")[:60], confidence, base_tier,
        )

    model = _pick_model(base_tier)
    logger.info(
        "Routed task [%s] type=%s conf=%.2f → tier=%s model=%s",
        task.get("id"), task_type, confidence, base_tier, model,
    )
    return base_tier, model


def route_all(tasks: list[dict]) -> list[dict]:
    """
    Attach routing metadata to every subtask.
    Returns an enriched task list ready for the executor.
    """
    routed = []
    for task in tasks:
        tier, model = route_task(task)
        routed.append({**task, "tier": tier, "model": model})
    return routed


# ── Helpers ───────────────────────────────────────────────────────────────────

_TIER_ORDER: list[ModelTier] = ["lightweight", "midweight", "heavyweight"]

def _escalate(tier: ModelTier) -> ModelTier:
    """Move one step up the tier ladder, capping at heavyweight."""
    idx = _TIER_ORDER.index(tier) if tier in _TIER_ORDER else 0
    return _TIER_ORDER[min(idx + 1, len(_TIER_ORDER) - 1)]


def _pick_model(tier: ModelTier) -> str:
    """Return the primary model for a tier."""
    models = MODEL_REGISTRY.get(tier, MODEL_REGISTRY["heavyweight"])
    return models[0]


def primary_model(tier: ModelTier) -> str:
    """Public helper: get first model for a tier."""
    return _pick_model(tier)


def fallback_model(tier: ModelTier) -> str:
    """Public helper: get fallback model for a tier (index 1 if available)."""
    models = MODEL_REGISTRY.get(tier, MODEL_REGISTRY["heavyweight"])
    return models[1] if len(models) > 1 else models[0]
