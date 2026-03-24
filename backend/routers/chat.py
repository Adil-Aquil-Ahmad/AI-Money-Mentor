"""
AI Money Mentor — Chat Router (v4 — Stock Data + Auth + Memory)
Pipeline: Auth -> Intent -> Rules -> Memory -> Stock Data -> Context -> LLM -> Response
"""
import logging
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from auth_middleware import get_current_user
from database import get_db
from engine.intent_parser import parse_intent
from engine.intent_registry import augment_intent_with_profile
from engine.rule_engine import apply_rules
from engine.response_generator import generate_response
from engine.memory_extractor import extract_and_store, get_top_memories
from engine.profile_normalizer import normalize_profile
from engine.pipeline_debug import trace_event
from engine import llm_client
from services.portfolio_service import build_portfolio_snapshot
from services.stock_service import extract_stock_names, get_multiple_stocks_data, get_market_overview, get_market_movers

logger = logging.getLogger("chat")
logger.setLevel(logging.DEBUG)
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter(
        "\033[32m[CHAT]\033[0m %(asctime)s — %(message)s", datefmt="%H:%M:%S"
    ))
    logger.addHandler(handler)

router = APIRouter()

# Intents that should trigger stock data fetching
STOCK_INTENTS = {"best_stocks", "invest_now"}
PORTFOLIO_INTENTS = {"good_portfolio", "rebalance_portfolio", "diversify_portfolio"}


class ChatMessage(BaseModel):
    message: str


@router.post("/chat")
async def chat(msg: ChatMessage, user_id: int = Depends(get_current_user)):
    """Process a user message through the full LLM-primary AI pipeline."""
    logger.info("=== NEW MESSAGE: \"%s\" (user_id=%d) ===", msg.message[:80], user_id)
    db = await get_db()

    try:
        # Step 1: Save user message
        await db.execute(
            "INSERT INTO chat_history (user_id, role, content) VALUES (?, 'user', ?)",
            (user_id, msg.message),
        )
        await db.commit()

        # Step 2: Extract memories from user message
        memories_extracted = await extract_and_store(user_id, msg.message)
        if memories_extracted:
            logger.info("Step 2: Extracted %d memories", len(memories_extracted))

        # Step 3: Fetch user profile
        cursor = await db.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        row = await cursor.fetchone()
        # Step 4: Fetch recent chat history
        cursor = await db.execute(
            "SELECT role, content FROM chat_history WHERE user_id = ? ORDER BY id DESC LIMIT 10",
            (user_id,),
        )
        history_rows = await cursor.fetchall()
        chat_history = [{"role": r[0], "content": r[1]} for r in reversed(history_rows)]

        # Step 5: Fetch top memories
        top_memories = await get_top_memories(user_id, limit=5)
        logger.info("Step 5: %d memories loaded for context", len(top_memories))

        profile = normalize_profile(dict(row) if row else {}, msg.message, top_memories)

        # Step 6: Parse intent
        intent = await parse_intent(msg.message)
        intent = augment_intent_with_profile(intent, profile)
        logger.info(
            "Step 6: Intent = %s | Intents = %s | Raw = %s | Amounts = %s",
            intent["intent"], intent.get("intents"), intent.get("raw_intents"), intent["amounts"]
        )
        trace_event("intent_parser", {
            "message": msg.message,
            "intent": intent["intent"],
            "intents": intent.get("intents"),
            "raw_intents": intent.get("raw_intents"),
            "amounts": intent.get("amounts"),
        })

        # Step 7: Rule engine (DATA ONLY — no text)
        rule_output = apply_rules(intent, profile)
        logger.info("Step 7: RULE DATA computed")
        trace_event("rule_engine", {
            "profile_summary": rule_output.get("profile_summary"),
            "financial_snapshot": rule_output.get("financial_snapshot"),
            "strategy": rule_output.get("strategy"),
        })

        # Save detected intent
        await db.execute(
            "UPDATE chat_history SET intent = ? WHERE id = ("
            "  SELECT id FROM chat_history WHERE user_id = ? AND role = 'user' ORDER BY id DESC LIMIT 1"
            ")",
            (intent["intent"], user_id),
        )
        await db.commit()

        # Step 8: Fetch live stock data (if stock-related query)
        stock_data = []
        symbols = extract_stock_names(msg.message)
        if any(item in STOCK_INTENTS for item in intent.get("intents", [intent["intent"]])) or symbols:
            if symbols:
                logger.info("Step 8: Fetching stock data for %s", symbols)
                stock_data = await get_multiple_stocks_data(symbols)
            elif "invest_now" in intent.get("intents", []):
                logger.info("Step 8: No specific stocks found, fetching market movers")
                stock_data = await get_market_movers()
            else:
                # Generic stock query — show market overview
                logger.info("Step 8: No specific stocks found, fetching market overview")
                stock_data = await get_market_overview()

            logger.info("Step 8: Got %d stock data entries", len(stock_data))
            if stock_data:
                logger.info("Step 8: Stocks: %s",
                    ", ".join(f"{s['name']}=Rs{s['price']}" for s in stock_data))
        else:
            logger.info("Step 8: Skipping stock fetch (intent=%s)", intent["intent"])

        portfolio_context = None
        lowered_message = msg.message.lower()
        wants_portfolio = any(item in PORTFOLIO_INTENTS for item in intent.get("intents", [])) or any(
            token in lowered_message for token in ["portfolio", "my investments", "current investments", "holdings"]
        )
        if wants_portfolio or profile.get("current_investments", 0) > 0:
            portfolio_context = await build_portfolio_snapshot(db, user_id, include_news=True)
            if portfolio_context.get("assets"):
                logger.info("Step 8b: Loaded portfolio context with %d assets", len(portfolio_context["assets"]))
                trace_event("portfolio_context", {
                    "summary": portfolio_context.get("summary"),
                    "health_score": portfolio_context.get("health_score"),
                    "winners": portfolio_context.get("winners"),
                    "losers": portfolio_context.get("losers"),
                    "news": portfolio_context.get("news", [])[:5],
                })

        # Step 9: LLM generates the FINAL response (using all context)
        logger.info("Step 9: CALLING LLM...")
        response_text, used_llm = await generate_response(
            intent, rule_output, profile, chat_history, top_memories,
            stock_data=stock_data,
            portfolio_context=portfolio_context,
        )
        trace_event("final_output", {
            "intent": intent["intent"],
            "intents": intent.get("intents"),
            "used_llm": used_llm,
            "model_used": llm_client.get_model_used(),
            "response": response_text,
        })
        logger.info("Step 9: LLM RESPONSE (used_llm=%s): %s", used_llm, response_text[:100])

        # Step 10: Save AI response
        await db.execute(
            "INSERT INTO chat_history (user_id, role, content) VALUES (?, 'assistant', ?)",
            (user_id, response_text),
        )
        await db.commit()
        logger.info("=== PIPELINE COMPLETE (llm=%s, stocks=%d) ===", used_llm, len(stock_data))

        return {
            "response": response_text,
            "intent": intent["intent"],
            "amounts": intent["amounts"],
            "used_llm": used_llm,
            "model_used": llm_client.get_model_used(),
            "memories_extracted": memories_extracted,
            "stock_data": stock_data if stock_data else None,
            "portfolio_context": portfolio_context if portfolio_context else None,
        }

    except Exception as e:
        logger.error("Pipeline error: %s", e, exc_info=True)
        raise
    finally:
        await db.close()


@router.get("/chat/history")
async def get_history(user_id: int = Depends(get_current_user), limit: int = 50):
    """Retrieve chat history for the authenticated user."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id, role, content, intent, created_at FROM chat_history "
            "WHERE user_id = ? ORDER BY id DESC LIMIT ?",
            (user_id, limit),
        )
        rows = await cursor.fetchall()
        return {
            "messages": [
                {"id": r[0], "role": r[1], "content": r[2], "intent": r[3], "created_at": r[4]}
                for r in reversed(rows)
            ]
        }
    finally:
        await db.close()


@router.delete("/chat/history")
async def clear_history(user_id: int = Depends(get_current_user)):
    """Clear chat history for the authenticated user."""
    db = await get_db()
    try:
        await db.execute("DELETE FROM chat_history WHERE user_id = ?", (user_id,))
        await db.commit()
        return {"status": "cleared"}
    finally:
        await db.close()
