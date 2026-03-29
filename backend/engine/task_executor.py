"""
Chrysos — Task Executor (Multi-Router Step 3)
Executes routed subtasks in parallel using asyncio.gather().
Each task type has its own handler with fallback logic.
"""
import asyncio
import logging
import os
import httpx
from typing import Optional

logger = logging.getLogger("task_executor")
logger.setLevel(logging.DEBUG)
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter(
        "\033[33m[EXECUTOR]\033[0m %(asctime)s — %(message)s", datefmt="%H:%M:%S"
    ))
    logger.addHandler(handler)

API_URL = os.getenv("LLM_API_URL", "https://api.groq.com/openai/v1/chat/completions")
API_KEY = os.getenv("LLM_API_KEY", "")


async def execute_all(
    routed_tasks: list[dict],
    context: dict,
) -> list[dict]:
    """
    Run all routed subtasks concurrently.
    Returns a list of {task, result, success} dicts.
    context: {profile, rule_output, stock_data, intent}
    """
    coroutines = [_execute_one(task, context) for task in routed_tasks]
    results = await asyncio.gather(*coroutines, return_exceptions=True)

    output = []
    for task, result in zip(routed_tasks, results):
        if isinstance(result, Exception):
            logger.error("Task %s failed: %s", task.get("id"), result)
            output.append({"task": task, "result": None, "success": False, "error": str(result)})
        else:
            output.append({"task": task, "result": result, "success": bool(result)})
    return output


async def _execute_one(task: dict, context: dict) -> Optional[str]:
    """Dispatch a single subtask to the appropriate handler."""
    task_type = task.get("type", "synthesis")
    model     = task.get("model", "llama-3.3-70b-versatile")
    desc      = task.get("description", "")

    logger.info("Executing task[%s] type=%s model=%s", task.get("id"), task_type, model)

    if task_type == "data_fetch":
        return await _handle_data_fetch(desc, context)
    elif task_type == "math":
        return await _call_groq(model, _math_system(context), desc, fallback_tier="midweight")
    elif task_type == "reasoning":
        return await _call_groq(model, _reasoning_system(context), desc, fallback_tier="heavyweight")
    else:  # synthesis
        return await _call_groq(model, _synthesis_system(context), desc, fallback_tier=None)


# ── Task Handlers ─────────────────────────────────────────────────────────────

async def _handle_data_fetch(description: str, context: dict) -> str:
    """
    data_fetch / tool tasks: use already-pulled yfinance data from context,
    OR call yfinance directly if context is empty (e.g. intent was general_advice).
    """
    stock_data = context.get("stock_data", [])

    # If context already has data, format it immediately
    if stock_data:
        lines = []
        for s in stock_data[:6]:
            change = s.get("change_percent", 0)
            sign = "+" if change > 0 else ""
            lines.append(f"{s['name']}: Rs{s['price']:,.2f} ({sign}{change}%)")
        return "Live market data:\n" + "\n".join(f"- {l}" for l in lines)

    # Context empty — fetch live now
    logger.info("Tool task: fetching live market data directly from yfinance")
    try:
        import sys, os
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
        from engine.stock_fetcher import get_market_movers
        live = await get_market_movers()
        if live:
            lines = []
            for s in live[:6]:
                change = s.get("change_percent", 0)
                sign = "+" if change > 0 else ""
                lines.append(f"{s['name']}: Rs{s['price']:,.2f} ({sign}{change}%)")
            # Also update context so synthesis step can use it
            context["stock_data"] = live
            return "Live market data:\n" + "\n".join(f"- {l}" for l in lines)
    except Exception as e:
        logger.warning("Direct yfinance fetch failed in executor: %s", e)

    return f"Live stock data is temporarily unavailable (rate limited). {description}. Please advise based on general principles."


async def _call_groq(
    model: str,
    system: str,
    user_prompt: str,
    fallback_tier: Optional[str] = None,
) -> Optional[str]:
    """Call Groq API with the given model. Falls back to heavyweight if specified."""
    from engine.model_router import MODEL_REGISTRY

    for attempt_model in _model_fallback_chain(model, fallback_tier, MODEL_REGISTRY):
        try:
            async with httpx.AsyncClient(timeout=httpx.Timeout(30.0, connect=5.0)) as client:
                r = await client.post(
                    API_URL,
                    headers={"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"},
                    json={
                        "model": attempt_model,
                        "messages": [
                            {"role": "system", "content": system},
                            {"role": "user",   "content": user_prompt},
                        ],
                        "max_tokens": 300,
                        "temperature": 0.5,
                    },
                )
                if r.status_code == 200:
                    text = r.json()["choices"][0]["message"]["content"].strip()
                    if text:
                        logger.info("Task completed with model: %s (%d chars)", attempt_model, len(text))
                        return text
                else:
                    logger.warning("Model %s → HTTP %d: %s", attempt_model, r.status_code, r.text[:120])
        except Exception as e:
            logger.debug("Model %s failed: %s", attempt_model, type(e).__name__)

    return None


def _model_fallback_chain(primary: str, fallback_tier: Optional[str], registry: dict) -> list[str]:
    """Build ordered list of models to try: primary → fallback tier → heavyweight."""
    chain = [primary]
    if fallback_tier and fallback_tier in registry:
        for m in registry[fallback_tier]:
            if m not in chain:
                chain.append(m)
    # Always add heavyweight as last resort
    for m in registry.get("heavyweight", []):
        if m not in chain:
            chain.append(m)
    return chain


# ── System Prompts per Task Type ─────────────────────────────────────────────

def _math_system(context: dict) -> str:
    ps = context.get("rule_output", {}).get("profile_summary", {})
    return (
        "You are a financial calculation assistant. "
        "Perform the requested calculation accurately and show your working. "
        f"User's monthly savings: Rs{ps.get('monthly_savings', 0):,}. "
        f"Total savings: Rs{ps.get('total_savings', 0):,}. "
        "Return only the calculation result and a 1-sentence interpretation. No filler text."
    )


def _reasoning_system(context: dict) -> str:
    ps = context.get("rule_output", {}).get("profile_summary", {})
    return (
        "You are a financial reasoning assistant. "
        "Analyse the provided data, compare options, and give a structured assessment. "
        f"Risk profile: {ps.get('risk_profile', 'medium')}. "
        f"Goal: {ps.get('goal_name', 'general wealth building')}. "
        "Return 2-4 bullet points. No generic advice — base everything on the data."
    )


def _synthesis_system(context: dict) -> str:
    ps = context.get("rule_output", {}).get("profile_summary", {})
    strategy = context.get("rule_output", {}).get("strategy", {})
    return (
        "You are an expert Indian financial advisor. "
        "Combine the following subtask results into a single, clear, personalised recommendation. "
        f"User profile — Age: {ps.get('age', 'N/A')}, Income: Rs{ps.get('income', 0):,}, "
        f"Risk: {ps.get('risk_profile', 'medium')}, Goal: {ps.get('goal_name', 'wealth growth')}. "
        f"Primary strategy: {strategy.get('primary_priority', '')}. "
        "Target 120-180 words. Use the Priority / Why / Action Plan / What Not To Do structure."
    )
