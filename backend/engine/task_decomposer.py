"""
Chrysos — Task Decomposer (Multi-Router Step 1)
Uses Qwen3 1.7B (offline, via Ollama) to parse a user query into structured subtasks.
Falls back to regex-based rule decomposition if Ollama is unavailable.

Subtask Types:
  data_fetch   → pull live data (yfinance, APIs)  — no LLM cost
  math         → arithmetic, percentages          → lightweight model
  reasoning    → interpret data, compare options  → mid-weight model
  synthesis    → explain, advise, narrate         → heavyweight model
"""
import os
import re
import json
import logging
import httpx
from typing import Optional

logger = logging.getLogger("task_decomposer")
logger.setLevel(logging.DEBUG)
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter(
        "\033[35m[DECOMPOSE]\033[0m %(asctime)s — %(message)s", datefmt="%H:%M:%S"
    ))
    logger.addHandler(handler)

OLLAMA_URL   = os.getenv("OLLAMA_URL",   "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen3:1.7b")

# ── JSON schema for a decomposed task list ──────────────────────────────────
TASK_SCHEMA = {
    "type": "array",
    "items": {
        "type": "object",
        "required": ["id", "type"],
        "properties": {
            "id":          {"type": "integer"},
            "type":        {"type": "string", "enum": ["tool", "calculation", "analysis", "final"]},
            "action":      {"type": "string"},   # for tool tasks
            "input":       {"type": "string"},   # for tool tasks that take a parameter
            "description": {"type": "string"},   # for calculation/analysis/final tasks
        }
    }
}

# Exact system prompt specified by user
DECOMPOSE_SYSTEM = """You are NOT a chatbot.

You are a task planner for an AI system.

Your job:
* Break the user query into structured steps
* Assign each step a type:
  * "tool" (requires backend function)
  * "calculation" (for lightweight model)
  * "analysis" (for mid/heavy model)
  * "final" (synthesize final response)

You MUST:
* Use tools when real-time data is needed
* NEVER answer directly
* ALWAYS output JSON

Available tools:
* yfinance.get_stock_data(ticker)
* yfinance.get_trending_stocks()

Output format:
{
  "tasks": [
    {"id": 1, "type": "tool", "action": "get_trending_stocks"},
    {"id": 2, "type": "tool", "action": "get_stock_data", "input": "top_5_stocks"},
    {"id": 3, "type": "calculation", "description": "calculate percentage growth"},
    {"id": 4, "type": "analysis", "description": "evaluate best stocks"},
    {"id": 5, "type": "final", "description": "generate final response"}
  ]
}

Output ONLY the raw JSON with a "tasks" array. No explanation, no markdown, no prose."""


async def decompose_query(message: str) -> list[dict]:
    """
    Decompose a user query into structured subtasks.
    Tries Qwen3 1.7B offline first; falls back to rule-based decomposition.
    """
    offline_result = await _decompose_with_qwen3(message)
    if offline_result:
        logger.info("Decomposed via Qwen3 1.7B → %d subtasks", len(offline_result))
        return offline_result

    rule_result = _decompose_with_rules(message)
    logger.info("Decomposed via rules (Qwen3 unavailable) → %d subtasks", len(rule_result))
    return rule_result


# ── Offline decomposer (Qwen3 1.7B via Ollama) ──────────────────────────────

async def _decompose_with_qwen3(message: str) -> Optional[list[dict]]:
    """Ask the local Qwen3 1.7B model to decompose the query into JSON subtasks."""
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(15.0, connect=3.0)) as client:
            r = await client.post(
                f"{OLLAMA_URL}/api/chat",
                json={
                    "model": OLLAMA_MODEL,
                    "messages": [
                        {"role": "system", "content": DECOMPOSE_SYSTEM},
                        {"role": "user",   "content": message},
                    ],
                    "stream": False,
                    "options": {"temperature": 0.1, "num_predict": 300},
                },
            )
            if r.status_code != 200:
                return None

            raw = r.json().get("message", {}).get("content", "").strip()
            # Strip markdown fences if model wraps output
            raw = re.sub(r"^```(?:json)?\s*", "", raw)
            raw = re.sub(r"\s*```$", "", raw)
            parsed = json.loads(raw)
            # Handle both {"tasks": [...]} and bare [...] formats
            if isinstance(parsed, dict) and "tasks" in parsed:
                parsed = parsed["tasks"]
            if isinstance(parsed, list) and parsed:
                return _validate_tasks(parsed)

    except httpx.ConnectError:
        logger.debug("Qwen3 offline — Ollama not running")
    except json.JSONDecodeError as e:
        logger.debug("Qwen3 returned invalid JSON: %s", e)
    except Exception as e:
        logger.debug("Qwen3 decomposer error: %s", type(e).__name__)

    return None


# ── Rule-based fallback decomposer ──────────────────────────────────────────

_RULE_PATTERNS = [
    # tool patterns — always fetch live data first
    (r"stock|price|market|nifty|sensex|reliance|tcs|hdfc|infosys|trending|gainers",
     "tool", "get_trending_stocks", None, 0.9),
    (r"specific\s+stock|single\s+stock|ticker|symbol",
     "tool", "get_stock_data", "specified_ticker", 0.9),
    # calculation patterns
    (r"percent|%|growth|return|gain|p&l|loss|calculate|how\s+much|roi|increase",
     "calculation", "calculate percentage growth and financial metrics", None, 0.85),
    (r"sip\s+amount|monthly.*invest|invest.*monthly|afford",
     "calculation", "calculate monthly SIP or investment amounts", None, 0.80),
    # analysis patterns
    (r"should\s+i|which.*better|compare|vs |versus|risk|safe|best\s+stock.*invest",
     "analysis", "evaluate options and assess risk to recommend best allocation", None, 0.80),
    (r"diversif|rebalanc|allocat|split.*portfolio|portfolio.*split",
     "analysis", "analyse portfolio allocation and rebalancing strategy", None, 0.80),
    (r"emergenc|insurance|debt|loan|emi|budget|expense",
     "analysis", "assess financial health and risk factors", None, 0.75),
]

def _decompose_with_rules(message: str) -> list[dict]:
    """Deterministic rule-based task decomposition — no LLM required."""
    lower = message.lower()
    tasks: list[dict] = []
    seen_types: set[str] = set()
    task_id = 1

    for pattern, task_type, desc_or_action, input_val, confidence in _RULE_PATTERNS:
        if re.search(pattern, lower) and task_type not in seen_types:
            task: dict = {"id": task_id, "type": task_type, "confidence": confidence}
            if task_type == "tool":
                task["action"] = desc_or_action
                if input_val:
                    task["input"] = input_val
            else:
                task["description"] = desc_or_action
            tasks.append(task)
            seen_types.add(task_type)
            task_id += 1

    # Always end with a final step
    if "final" not in seen_types:
        tasks.append({
            "id": task_id,
            "type": "final",
            "description": "Synthesise all gathered information into a personalised financial recommendation",
            "confidence": 1.0,
        })

    # Minimum: one final task
    if not tasks:
        tasks.append({
            "id": 1, "type": "final",
            "description": "Answer the user's financial question with personalised advice",
            "confidence": 0.9,
        })

    return tasks


# ── Validation ───────────────────────────────────────────────────────────────

def _validate_tasks(raw: list) -> list[dict]:
    """Ensure each task has the required fields; drop or patch bad entries."""
    valid_types = {"data_fetch", "math", "reasoning", "synthesis"}
    out = []
    for i, item in enumerate(raw):
        if not isinstance(item, dict):
            continue
        task = {
            "id":          item.get("id", i + 1),
            "type":        item.get("type", "synthesis") if item.get("type") in valid_types else "synthesis",
            "description": str(item.get("description", "No description"))[:200],
            "confidence":  float(item.get("confidence", 0.8)),
        }
        out.append(task)
    return out or [{"id": 1, "type": "synthesis", "description": "Answer the query", "confidence": 0.8}]
