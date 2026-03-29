"""
Chrysos — Morning Brief / Greeting Endpoint
Calculates portfolio P&L changes (since investment date + since yesterday),
fetches latest news for each stock holding, runs sentiment analysis via
llama-3.3-70b, and returns a structured first-message greeting.
"""
import asyncio
import logging
from datetime import datetime, timezone
from fastapi import APIRouter, Query
from pydantic import BaseModel

from services.stock_service import get_stock_data, get_stock_news, resolve_symbol
from engine.llm_client import generate_with_model
from database import get_db

router = APIRouter()
logger = logging.getLogger("greeting")
logger.setLevel(logging.DEBUG)
if not logger.handlers:
    import sys
    h = logging.StreamHandler(sys.stdout)
    h.setFormatter(logging.Formatter(
        "\033[96m[GREETING]\033[0m %(asctime)s — %(message)s", datefmt="%H:%M:%S"
    ))
    logger.addHandler(h)


class GreetingResponse(BaseModel):
    greeting: str
    portfolio_changes: list
    news_sentiment: str
    has_portfolio: bool


@router.get("/api/chat/greeting", response_model=GreetingResponse)
async def get_greeting(user_id: int = Query(default=1)):
    """
    Called once when the app opens. Returns:
    - Per-asset P&L (today's change + since-invested change)
    - News headlines with AI sentiment for each stock
    - Final greeting text composed by the backend (NOT the AI)
    """
    logger.info("=== GREETING START for user_id=%d ===", user_id)

    # ── 1. Load investments from DB ──────────────────────────────────────────
    investments = []
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id, type, name, symbol, amount_invested, quantity, avg_price, "
            "sip_amount, COALESCE(purchase_date, DATE(created_at)) as purchase_date "
            "FROM current_investments WHERE user_id = ? ORDER BY id",
            (user_id,),
        )
        rows = await cursor.fetchall()
        for row in rows:
            investments.append({
                "id": row[0],
                "type": row[1],
                "name": row[2],
                "symbol": row[3],
                "amount_invested": float(row[4] or 0),
                "quantity": float(row[5]) if row[5] else None,
                "avg_price": float(row[6]) if row[6] else None,
                "sip_amount": float(row[7]) if row[7] else None,
                "purchase_date": row[8],  # e.g. "2025-01-01"
            })
    except Exception as e:
        logger.warning("DB error: %s", e)
    finally:
        await db.close()

    if not investments:
        return GreetingResponse(
            greeting="Hello! I'm Chrysos, your financial advisor. You haven't added any investments yet. Head to Portfolio to add your first holding!",
            portfolio_changes=[],
            news_sentiment="",
            has_portfolio=False,
        )

    # ── 2. For each stock investment, fetch live price + news ────────────────
    # Filter investments that can be enriched with live prices
    # Include stocks/crypto even if symbol is in the name field
    def _get_symbol(inv: dict) -> str | None:
        sym = (inv.get("symbol") or "").strip()
        if sym:
            return resolve_symbol(sym) or sym
        name = (inv.get("name") or "").strip()
        if inv["type"] in ("stock", "mutual_fund", "sip", "crypto") and name:
            return resolve_symbol(name)
        return None

    stock_investments = [
        {**inv, "_resolved_symbol": _get_symbol(inv)}
        for inv in investments
        if inv["type"] in ("stock", "mutual_fund", "sip", "crypto")
        and _get_symbol(inv)
    ]

    async def _enrich(inv: dict) -> dict:
        symbol = inv.get("_resolved_symbol") or inv.get("symbol", "")
        price_data, news = await asyncio.gather(
            get_stock_data(symbol),
            get_stock_news(symbol, limit=3),
            return_exceptions=True,
        )

        result = {**inv}
        result.pop("_resolved_symbol", None)

        if isinstance(price_data, dict):
            current_price = float(price_data.get("price") or 0)
            today_change_pct = float(price_data.get("change_percent") or 0)
            result["current_price"] = current_price
            result["today_change_pct"] = today_change_pct

            amount_invested = float(inv.get("amount_invested") or 0)
            qty = float(inv.get("quantity") or 0)
            avg_price = float(inv.get("avg_price") or 0)

            # Case 1: quantity + avg_price both available
            if qty > 0 and avg_price > 0 and current_price > 0:
                invested_cost = qty * avg_price
                current_val = qty * current_price
                result["total_gain_pct"] = round(((current_val - invested_cost) / invested_cost) * 100, 2)
                result["total_gain_abs"] = round(current_val - invested_cost, 2)
                result["current_value"] = round(current_val, 2)

            # Case 2: avg_price + amount_invested (derive qty)
            elif avg_price > 0 and amount_invested > 0 and current_price > 0:
                qty_derived = amount_invested / avg_price
                current_val = qty_derived * current_price
                result["total_gain_pct"] = round(((current_val - amount_invested) / amount_invested) * 100, 2)
                result["total_gain_abs"] = round(current_val - amount_invested, 2)
                result["current_value"] = round(current_val, 2)

            # Case 3: only amount_invested — use today's change_percent to extrapolate
            elif amount_invested > 0 and current_price > 0:
                # We can still show today's change on the invested amount
                # Cannot show since-invested gain without cost basis, but today's move is real
                result["current_value"] = round(amount_invested, 2)
                # We'll show today change only; skip total_gain since no cost basis

            if inv.get("purchase_date"):
                try:
                    purchased = datetime.strptime(str(inv["purchase_date"]), "%Y-%m-%d")
                    days_held = (datetime.now() - purchased).days
                    result["days_held"] = days_held
                except Exception:
                    pass

        if isinstance(news, list):
            result["news"] = news

        return result

    enriched = await asyncio.gather(*[_enrich(inv) for inv in stock_investments])
    enriched = [e for e in enriched if isinstance(e, dict)]

    # ── 3. Hardcoded P&L change block (no LLM) ───────────────────────────────
    portfolio_changes = []
    for e in enriched:
        change = {
            "name": e.get("name"),
            "symbol": e.get("symbol"),
            "current_price": e.get("current_price"),
            "prev_close": e.get("prev_close"),
            "today_change_pct": e.get("today_change_pct"),
            "total_gain_pct": e.get("total_gain_pct"),
            "total_gain_abs": e.get("total_gain_abs"),
            "current_value": e.get("current_value"),
            "amount_invested": e.get("amount_invested"),
            "days_held": e.get("days_held"),
            "news": e.get("news", []),
        }
        portfolio_changes.append(change)
        logger.info("P&L %s: price=%.2f today=%.2f%% total=%.2f%%",
                    e.get("name"), e.get("current_price", 0),
                    e.get("today_change_pct", 0), e.get("total_gain_pct", 0))

    # ── 4. News sentiment via llama-3.3-70b ──────────────────────────────────
    all_headlines = []
    for e in enriched:
        for n in e.get("news", []):
            all_headlines.append(f"[{e['name']}] {n['headline']}")

    news_sentiment = ""
    if all_headlines:
        headlines_text = "\n".join(all_headlines[:9])  # max 9 headlines
        sentiment_prompt = (
            "You are a financial news analyst. Analyze the sentiment of these headlines "
            "for the user's portfolio stocks. Be concise (2–3 sentences). "
            "Rate the overall market mood as Bullish/Neutral/Bearish and explain why.\n\n"
            f"Headlines:\n{headlines_text}"
        )
        try:
            news_sentiment = await generate_with_model(
                model="llama-3.3-70b-versatile",
                system_prompt="You are a concise financial news sentiment analyst. Be very brief.",
                user_prompt=sentiment_prompt,
            )
            logger.info("Sentiment: %s", news_sentiment[:80])
        except Exception as e:
            logger.warning("Sentiment LLM failed: %s", e)
            news_sentiment = "Market news is available above."

    # ── 5. Build hardcoded greeting text ─────────────────────────────────────
    now = datetime.now(timezone.utc)
    hour = now.hour + 5  # IST offset approx
    if hour < 12:
        time_greeting = "Good morning"
    elif hour < 17:
        time_greeting = "Good afternoon"
    else:
        time_greeting = "Good evening"

    lines = [f"{time_greeting}! Here's your daily portfolio update:\n"]

    for e in enriched:
        name = e.get("name") or e.get("symbol") or "Investment"
        today_pct = e.get("today_change_pct")
        total_pct = e.get("total_gain_pct")
        total_abs = e.get("total_gain_abs")
        current_val = e.get("current_value")
        current_price = e.get("current_price")
        prev_close = e.get("prev_close")
        days = e.get("days_held")
        amount_invested = e.get("amount_invested", 0)

        line_parts = [f"• {name}"]

        # Row 1: Current price vs yesterday
        if current_price and prev_close:
            price_change = current_price - prev_close
            price_arrow = "▲" if price_change >= 0 else "▼"
            # Format prices — use $ for US stocks (no .NS suffix), ₹ for Indian
            currency = "$" if (e.get("symbol") or "").endswith((".NS", ".BO")) is False \
                and "." not in (e.get("symbol") or "") else "₹"
            line_parts.append(
                f"  Price: {currency}{current_price:,.2f} "
                f"({price_arrow} {currency}{abs(price_change):,.2f} from yesterday's {currency}{prev_close:,.2f})"
            )
        elif current_price:
            line_parts.append(f"  Current Price: ₹{current_price:,.2f}")

        # Row 2: Today's % change
        if today_pct is not None:
            arrow = "▲" if today_pct >= 0 else "▼"
            today_rupees = ""
            if amount_invested and today_pct:
                rupees = amount_invested * today_pct / 100
                today_rupees = f" (₹{abs(rupees):,.0f} on your ₹{amount_invested:,.0f})"
            line_parts.append(f"  Today: {arrow} {abs(today_pct):.2f}%{today_rupees}")

        # Row 3: Since invested
        if total_pct is not None and total_abs is not None:
            arrow = "▲" if total_pct >= 0 else "▼"
            status = "gain" if total_pct >= 0 else "loss"
            days_str = f" over {days}d" if days and days > 0 else ""
            line_parts.append(
                f"  Since invested: {arrow} {abs(total_pct):.2f}% ({status} of ₹{abs(total_abs):,.0f}{days_str})"
            )
        elif days and days > 0 and today_pct is not None:
            # Only today's change available — note missing cost basis
            line_parts.append(f"  Held for {days} days (add avg buy price for full P&L)")

        lines.append("\n".join(line_parts))

    if news_sentiment:
        lines.append(f"\n📰 Market Sentiment: {news_sentiment}")

    lines.append("\nWhat would you like to explore today?")
    greeting_text = "\n\n".join(lines)

    logger.info("=== GREETING COMPLETE (%d chars) ===", len(greeting_text))
    return GreetingResponse(
        greeting=greeting_text,
        portfolio_changes=portfolio_changes,
        news_sentiment=news_sentiment,
        has_portfolio=True,
    )
