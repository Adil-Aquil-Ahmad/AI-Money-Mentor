"""
AI Money Mentor — Memory Extractor
Auto-detects goals, preferences, life events, and insights from chat messages.
Stores them in the memory table for long-term personalization.
"""
import re
import logging
from database import get_db

logger = logging.getLogger("memory")
logger.setLevel(logging.DEBUG)
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter(
        "\033[34m[MEMORY]\033[0m %(asctime)s — %(message)s", datefmt="%H:%M:%S"
    ))
    logger.addHandler(handler)

# Pattern → (type, importance_score, content_template)
PATTERNS = [
    # Goals (importance: 5)
    (r"(?:i\s+)?want\s+to\s+(buy|save\s+for|build|get|purchase)\s+(.+?)(?:\.|$)",
     "goal", 5, lambda m: f"Wants to {m.group(1)} {m.group(2).strip()}"),

    (r"my\s+goal\s+is\s+(?:to\s+)?(.+?)(?:\.|$)",
     "goal", 5, lambda m: m.group(1).strip().capitalize()),

    (r"(?:planning|plan)\s+to\s+(.+?)(?:\.|$)",
     "goal", 4, lambda m: f"Planning to {m.group(1).strip()}"),

    (r"(?:saving|save)\s+(?:up\s+)?for\s+(.+?)(?:\.|$)",
     "goal", 4, lambda m: f"Saving for {m.group(1).strip()}"),

    # Life events (importance: 5)
    (r"(?:i\s+)?(?:just\s+)?got\s+(?:a\s+|my\s+)?(?:new\s+)?(?:first\s+)?job",
     "event", 5, lambda m: "Got a new job"),

    (r"(?:i\s+)?got\s+(?:a\s+)?(?:bonus|promotion)",
     "event", 4, lambda m: f"Got a {m.group(0).split('got ')[-1].strip()}"),

    (r"(?:i\s+)?(?:just\s+)?got\s+married",
     "event", 5, lambda m: "Got married"),

    (r"(?:i\s+)?(?:am\s+)?(?:expecting|having)\s+(?:a\s+)?(?:baby|child|kid)",
     "event", 5, lambda m: "Expecting a child"),

    (r"(?:starting|started)\s+(?:a\s+)?(?:business|startup|company)",
     "event", 5, lambda m: "Starting a business"),

    (r"(?:i\s+)?(?:just\s+)?(?:bought|purchased)\s+(.+?)(?:\.|$)",
     "event", 4, lambda m: f"Bought {m.group(1).strip()}"),

    # Preferences (importance: 3)
    (r"(?:i\s+)?prefer\s+(.+?)(?:\.|$)",
     "preference", 3, lambda m: f"Prefers {m.group(1).strip()}"),

    (r"(?:i\s+)?(?:like|love)\s+(?:to\s+)?(?:invest\s+in\s+)?(.+?)(?:\.|$)",
     "preference", 3, lambda m: f"Likes {m.group(1).strip()}"),

    (r"(?:i\s+)?(?:don't|do\s+not)\s+(?:want|like)\s+(.+?)(?:\.|$)",
     "preference", 3, lambda m: f"Avoids {m.group(1).strip()}"),

    # Income/salary mentions (importance: 4)
    (r"(?:my\s+)?salary\s+(?:is\s+)?(?:₹|rs\.?\s*)?(\d[\d,]*)",
     "insight", 4, lambda m: f"Salary is ₹{m.group(1).replace(',', '')}"),

    (r"(?:i\s+)?earn\s+(?:₹|rs\.?\s*)?(\d[\d,]*)",
     "insight", 4, lambda m: f"Earns ₹{m.group(1).replace(',', '')}"),

    # Debt mentions (importance: 4)
    (r"(?:i\s+)?(?:have|took)\s+(?:a\s+)?(?:loan|emi|debt)\s+(?:of\s+)?(?:₹|rs\.?\s*)?(\d[\d,]*)",
     "insight", 4, lambda m: f"Has loan/debt of ₹{m.group(1).replace(',', '')}"),
]


async def extract_and_store(user_id: int, message: str) -> list:
    """
    Scan a user message for important info and store as memories.
    Returns list of extracted memories.
    """
    msg_lower = message.lower().strip()
    extracted = []

    for pattern, mem_type, importance, content_fn in PATTERNS:
        match = re.search(pattern, msg_lower, re.IGNORECASE)
        if match:
            content = content_fn(match)
            if content and len(content) > 3:
                # Avoid duplicate memories
                exists = await _memory_exists(user_id, content)
                if not exists:
                    await _store_memory(user_id, mem_type, content, importance)
                    extracted.append({
                        "type": mem_type,
                        "content": content,
                        "importance": importance,
                    })
                    logger.info("Extracted %s (score=%d): %s", mem_type, importance, content)

    if not extracted:
        logger.debug("No memories extracted from: '%s'", msg_lower[:80])

    return extracted


async def get_top_memories(user_id: int, limit: int = 5) -> list:
    """Fetch top memories by importance score for context injection."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT type, content, importance_score FROM memory "
            "WHERE user_id = ? ORDER BY importance_score DESC, created_at DESC LIMIT ?",
            (user_id, limit),
        )
        rows = await cursor.fetchall()
        return [{"type": r[0], "content": r[1], "importance": r[2]} for r in rows]
    finally:
        await db.close()


async def _memory_exists(user_id: int, content: str) -> bool:
    """Check if a similar memory already exists."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT COUNT(*) FROM memory WHERE user_id = ? AND content = ?",
            (user_id, content),
        )
        count = (await cursor.fetchone())[0]
        return count > 0
    finally:
        await db.close()


async def _store_memory(user_id: int, mem_type: str, content: str, importance: int):
    """Insert a new memory entry."""
    db = await get_db()
    try:
        await db.execute(
            "INSERT INTO memory (user_id, type, content, importance_score) VALUES (?, ?, ?, ?)",
            (user_id, mem_type, content, importance),
        )
        await db.commit()
    finally:
        await db.close()
