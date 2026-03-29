"""
Chrysos — Hybrid LLM Client (v3 — HYBRID ROUTING)
Provider chain: Groq API (Primary) -> Ollama Local (Secondary) -> None (Template Fallback).
"""
import hashlib
import httpx
import os
import logging
from typing import Optional
from database import get_db


def _load_env_file():
    """Load backend/.env into process env when present."""
    env_path = os.path.join(os.path.dirname(__file__), "..", ".env")
    if not os.path.exists(env_path):
        return
    try:
        with open(env_path, "r", encoding="utf-8") as handle:
            for raw_line in handle:
                line = raw_line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                if key and key not in os.environ:
                    os.environ[key] = value
    except Exception:
        pass

# ── Logging ──────────────────────────────────────────────────────────────
logger = logging.getLogger("llm_client")
logger.setLevel(logging.DEBUG)
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter(
        "\033[36m[LLM]\033[0m %(asctime)s — %(message)s", datefmt="%H:%M:%S"
    ))
    logger.addHandler(handler)

_load_env_file()

# ── In-memory cache ──────────────────────────────────────────────────────
_cache: dict = {}
_CACHE_MAX = 200
_CACHE_VERSION = "v2-template-lock"
_last_model_used = "none"

# ── Provider config (env vars) ───────────────────────────────────────────
OLLAMA_URL   = os.getenv("OLLAMA_URL",   "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen3:1.7b")

# Groq API Defaults
API_URL   = os.getenv("LLM_API_URL",   "https://api.groq.com/openai/v1/chat/completions")
API_KEY   = os.getenv("LLM_API_KEY",   "")
API_MODEL = os.getenv("LLM_API_MODEL", "llama-3.3-70b-versatile")

# Multi-Router tier models
LLM_LIGHTWEIGHT = os.getenv("LLM_LIGHTWEIGHT", "llama-3.1-8b-instant")
LLM_MIDWEIGHT   = os.getenv("LLM_MIDWEIGHT",   "llama-4-scout-17b-16e-instruct")
LLM_HEAVYWEIGHT = os.getenv("LLM_HEAVYWEIGHT",  "llama-3.3-70b-versatile")
USE_MULTI_ROUTER = os.getenv("USE_MULTI_ROUTER", "false").lower() == "true"


def set_model_used(label: str):
    global _last_model_used
    _last_model_used = label
    logger.info("MODEL USED: %s", label)


def get_model_used() -> str:
    return _last_model_used


async def is_online() -> bool:
    """Detect if internet is available by pinging Groq API."""
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            await client.get("https://api.groq.com")
            return True
    except Exception:
        return False


async def generate(system_prompt: str, user_prompt: str) -> Optional[str]:
    """
    Try LLM providers in hybrid order: API -> Local.
    Returns the generated text, or None if ALL fail (triggering template fallback).
    """
    cache_key = _make_key(system_prompt, user_prompt)

    # ── Check cache ──────────────────────────────────────────────────
    cached = await _get_cached(cache_key)
    if cached:
        set_model_used("cache-hit")
        logger.info("✅ CACHE HIT — returning cached response")
        return cached

    logger.info("Cache miss — evaluating routing logic…")
    logger.debug("System prompt (first 200 chars): %s", system_prompt[:200])
    logger.debug("User prompt (first 300 chars): %s", user_prompt[:300])

    response: Optional[str] = None
    online = await is_online()

    try:
        # ── PRIMARY: External API (Groq) ─────────────────────────────────
        if online and API_KEY:
            api_models = _candidate_api_models()
            logger.info("Internet active. Trying PRIMARY API models: %s", api_models)
            for model_name in api_models:
                response = await _try_api(system_prompt, user_prompt, model_name)
                if response:
                    set_model_used(f"api:{model_name}")
                    logger.info("✅ LLM CALLED SUCCESSFULLY via API")
                    break
            if not response:
                logger.info("❌ API failed or returned empty for all configured models. Falling back to LOCAL.")
        elif not online:
            logger.info("No interent detected. Skipping API.")
        elif not API_KEY:
            logger.info("No API_KEY provided. Skipping API.")

        # ── SECONDARY: Local LLM (Ollama) ─────────────────────────────────
        if not response:
            logger.info("Trying SECONDARY: Local Ollama (%s)", OLLAMA_MODEL)
            response = await _try_ollama(system_prompt, user_prompt)
            if response:
                set_model_used(f"local:{OLLAMA_MODEL}")
                logger.info("✅ LLM CALLED SUCCESSFULLY via Local Ollama")
            else:
                logger.info("❌ Local Ollama failed.")

    except Exception as e:
        logger.error("Error during routing: %s. Forcing Local Fallback.", e)
        # ── SAFETY NET: Force Local LLM ─────────────────────────────────
        if not response:
            logger.info("Trying SAFETY NET: Local Ollama (%s)", OLLAMA_MODEL)
            response = await _try_ollama(system_prompt, user_prompt)
            if response:
                set_model_used(f"local:{OLLAMA_MODEL}")

    if response:
        await _set_cached(cache_key, response)
        return response

    # ── All LLMs failed ─────────────────────────────────────────
    set_model_used("none")
    logger.warning("⚠️  ALL LLMs FAILED — System must use Template Fallback")
    return None


async def generate_with_model(model: str, system_prompt: str, user_prompt: str) -> Optional[str]:
    """Call a specific model directly — used by multi-router task executor."""
    result = await _try_api(system_prompt, user_prompt, model)
    if result:
        set_model_used(f"api:{model}")
        return result
    # Try heavyweight as safety net
    if model != LLM_HEAVYWEIGHT:
        result = await _try_api(system_prompt, user_prompt, LLM_HEAVYWEIGHT)
        if result:
            set_model_used(f"api:{LLM_HEAVYWEIGHT}(fallback)")
            return result
    return None


async def generate_tiered(tier: str, system_prompt: str, user_prompt: str) -> Optional[str]:
    """Generate using a specific tier — lightweight, midweight, or heavyweight."""
    tier_model_map = {
        "lightweight": LLM_LIGHTWEIGHT,
        "midweight":   LLM_MIDWEIGHT,
        "heavyweight": LLM_HEAVYWEIGHT,
    }
    model = tier_model_map.get(tier, LLM_HEAVYWEIGHT)
    return await generate_with_model(model, system_prompt, user_prompt)


# ═══════════════════════════════════════════════════════════════════════════
# Provider implementations
# ═══════════════════════════════════════════════════════════════════════════
async def _try_api(system: str, user: str, model_name: str) -> Optional[str]:
    """External OpenAI-compatible API (Groq)."""
    try:
        logger.info("Trying API model: %s", model_name)
        async with httpx.AsyncClient(timeout=httpx.Timeout(5.0, connect=3.0)) as client:
            r = await client.post(
                API_URL,
                headers={
                    "Authorization": f"Bearer {API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": model_name,
                    "messages": [
                        {"role": "system", "content": system},
                        {"role": "user", "content": user},
                    ],
                    "max_tokens": 250,
                    "temperature": 0.6,
                },
            )
            if r.status_code == 200:
                text = r.json()["choices"][0]["message"]["content"].strip()
                return text if text else None
            else:
                logger.warning("API model %s returned %d: %s", model_name, r.status_code, r.text[:160])
    except Exception as e:
        logger.debug("API call error for model %s: %s", model_name, e)
    return None


def _candidate_api_models() -> list[str]:
    models = [
        API_MODEL,
        "llama-3.3-70b-versatile",
        "llama-3.1-8b-instant",
    ]
    ordered = []
    seen = set()
    for item in models:
        if item and item not in seen:
            ordered.append(item)
            seen.add(item)
    return ordered


async def _try_ollama(system: str, user: str) -> Optional[str]:
    """Ollama local server with retry — /api/chat endpoint."""
    for attempt in range(2):  # Retry once
        try:
            async with httpx.AsyncClient(timeout=httpx.Timeout(600.0, connect=60.0)) as client:
                r = await client.post(
                    f"{OLLAMA_URL}/api/chat",
                    json={
                        "model": OLLAMA_MODEL,
                        "messages": [
                            {"role": "system", "content": system},
                            {"role": "user", "content": user},
                        ],
                        "stream": False,
                        "options": {
                            "temperature": 0.6,
                            "num_predict": 250,
                        },
                    },
                )
                if r.status_code == 200:
                    data = r.json()
                    text = data.get("message", {}).get("content", "").strip()
                    if text:
                        return text
        except Exception as e:
            logger.debug("Ollama error (attempt %d): %s", attempt + 1, type(e).__name__)
    return None


# ═══════════════════════════════════════════════════════════════════════════
# Caching layer
# ═══════════════════════════════════════════════════════════════════════════
def _make_key(system: str, user: str) -> str:
    raw = f"{_CACHE_VERSION}|{system[:100]}|{user}".encode()
    return hashlib.sha256(raw).hexdigest()[:32]


async def _get_cached(key: str) -> Optional[str]:
    if key in _cache:
        return _cache[key]
    try:
        db = await get_db()
        cursor = await db.execute(
            "SELECT response FROM response_cache WHERE cache_key = ?", (key,)
        )
        row = await cursor.fetchone()
        await db.close()
        if row:
            _cache[key] = row[0]
            return row[0]
    except Exception:
        pass
    return None


async def _set_cached(key: str, response: str):
    if len(_cache) >= _CACHE_MAX:
        oldest = next(iter(_cache))
        del _cache[oldest]
    _cache[key] = response
    try:
        db = await get_db()
        await db.execute(
            "INSERT OR REPLACE INTO response_cache (cache_key, response) VALUES (?, ?)",
            (key, response),
        )
        await db.commit()
        await db.close()
    except Exception:
        pass
