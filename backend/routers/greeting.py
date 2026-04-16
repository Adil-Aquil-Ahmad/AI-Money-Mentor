import asyncio
import logging
import json
import math
from datetime import datetime, timezone
from fastapi import APIRouter, Query
from pydantic import BaseModel

from services.stock_service import get_stock_data, get_stock_news, resolve_symbol
from services.intelligence_service import get_finance_intelligence
from database import get_db, get_cached_greeting, set_cached_greeting

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
async def get_greeting(user_id: int = Query(default=1), force_refresh: bool = Query(default=False)):
    """
    Called once when the app opens. Returns:
    - Per-asset P&L (today's change + since-invested change + sentiment/trends)
    - Final greeting text composed by the backend
    """
    logger.info("=== GREETING START for user_id=%d ===", user_id)
    
    # 0. Check cache
    now = datetime.now(timezone.utc)
    date_str = now.strftime('%Y-%m-%d')
    if not force_refresh:
        cached_json = await get_cached_greeting(user_id, date_str)
        if cached_json:
            try:
                data = json.loads(cached_json)
                logger.info("=== GREETING SERVED FROM DB CACHE ===")
                return GreetingResponse(**data)
            except Exception as e:
                logger.error("Failed to parse cached greeting: %s", e)

    # 1. Load investments
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
                "purchase_date": row[8],
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

    # 2. Extract specific stocks for intelligence fetch
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
        amount_invested = float(inv.get("amount_invested") or 0)
        
        days_held = 30
        if inv.get("purchase_date"):
            try:
                purchased = datetime.strptime(str(inv["purchase_date"]), "%Y-%m-%d")
                calculated = (datetime.now() - purchased).days
                if calculated > 0:
                    days_held = calculated
            except Exception:
                pass
                
        price_data, intelligence = await asyncio.gather(
            get_stock_data(symbol),
            get_finance_intelligence(symbol, amount_invested, days_held),
            return_exceptions=True,
        )

        result = {**inv}
        result.pop("_resolved_symbol", None)
        result["days_held"] = days_held

        if isinstance(intelligence, dict):
            result["sentiment"] = intelligence.get("sentiment", "Neutral")
            result["insight"] = intelligence.get("insight", "")
            result["alert"] = intelligence.get("alert")
            
            # Prefer intelligence struct if no price_data 
            result["current_price"] = intelligence.get("current_price", 0)
            result["today_change_pct"] = intelligence.get("today_change_percent", 0)

        if isinstance(price_data, dict):
            current_price = float(price_data.get("price") or result.get("current_price") or 0)
            today_change_pct = float(price_data.get("change_percent") or result.get("today_change_pct") or 0)
            result["current_price"] = current_price
            result["today_change_pct"] = today_change_pct

            qty = float(inv.get("quantity") or 0)
            avg_price = float(inv.get("avg_price") or 0)

            if qty > 0 and avg_price > 0 and current_price > 0:
                invested_cost = qty * avg_price
                current_val = qty * current_price
                result["total_gain_pct"] = round(((current_val - invested_cost) / invested_cost) * 100, 2)
                result["total_gain_abs"] = round(current_val - invested_cost, 2)
                result["current_value"] = round(current_val, 2)

            elif avg_price > 0 and amount_invested > 0 and current_price > 0:
                qty_derived = amount_invested / avg_price
                current_val = qty_derived * current_price
                result["total_gain_pct"] = round(((current_val - amount_invested) / amount_invested) * 100, 2)
                result["total_gain_abs"] = round(current_val - amount_invested, 2)
                result["current_value"] = round(current_val, 2)

            elif amount_invested > 0 and current_price > 0:
                result["current_value"] = round(amount_invested, 2)
                
        # Fill in fallback totals if intelligence computed it and we don't have it
        if "total_gain_pct" not in result and isinstance(intelligence, dict):
            t_pct = intelligence.get("total_change_percent")
            if t_pct is not None:
                result["total_gain_pct"] = t_pct
                if amount_invested > 0:
                    result["total_gain_abs"] = round(amount_invested * float(t_pct) / 100.0, 2)
                    
        # Sanitize any NaNs or Infs that will crash json.dumps
        def _clean_float(val):
            if val is None: return None
            try:
                v = float(val)
                if math.isnan(v) or math.isinf(v): return 0.0
                return v
            except:
                return 0.0
                
        for k, v in list(result.items()):
            if isinstance(v, float):
                result[k] = _clean_float(v)

        return result

    enriched = await asyncio.gather(*[_enrich(inv) for inv in stock_investments[:4]])  # Limit to 4 to avoid overly long loading times
    enriched = [e for e in enriched if isinstance(e, dict)]

    # 3. Build greeting text
    now = datetime.now(timezone.utc)
    hour = now.hour + 5  # IST offset approx
    if hour < 12:
        time_greeting = "Good morning"
    elif hour < 17:
        time_greeting = "Good afternoon"
    else:
        time_greeting = "Good evening"

    lines = [f"{time_greeting}! Here's your daily portfolio intelligence update:\n"]

    for e in enriched:
        name = (e.get("name") or e.get("symbol") or "Investment").upper()
        today_pct = e.get("today_change_pct")
        total_pct = e.get("total_gain_pct")
        total_abs = e.get("total_gain_abs")
        current_price = e.get("current_price")
        days = e.get("days_held")
        amount_invested = e.get("amount_invested", 0)
        sentiment = e.get("sentiment")
        insight = e.get("insight")

        line_parts = [f"• {name}"]
        currency = "₹"

        # Current Price
        if current_price:
            line_parts.append(f"  Current Price: {currency}{current_price:,.2f}")

        # Today's Change
        if today_pct is not None:
            arrow = "▲" if today_pct >= 0 else "▼"
            today_rupees = ""
            if amount_invested and today_pct:
                rupees = amount_invested * today_pct / 100
                today_rupees = f" (₹{abs(rupees):,.0f})"
            line_parts.append(f"  Today: {arrow} {abs(today_pct):.2f}%{today_rupees}")

        # Total Change
        
        current_value = e.get("current_value")
        
        if total_pct is not None:
            arrow = "▲" if total_pct >= 0 else "▼"
            days_str = f" ({days} days)" if days and days > 0 else ""
            
            if current_value is not None:
                val_str = f"{currency}{current_value:,.0f}"
                line_parts.append(f"  Total{days_str}: {arrow} {abs(total_pct):.2f}% ({val_str})")
            elif total_abs is not None:
                final_val = amount_invested + total_abs
                val_str = f"{currency}{final_val:,.0f}"
                line_parts.append(f"  Total{days_str}: {arrow} {abs(total_pct):.2f}% ({val_str})")
        elif days and days > 0:
            line_parts.append(f"  Held for {days} days (add avg buy price for full P&L)")

        # Sentiment and Insight
        if sentiment:
            # Map sentiment colors or format
            line_parts.append(f"  Sentiment: {sentiment}")
            if insight:
                line_parts.append(f"  Insight: {insight}")

        # Alerts
        if e.get("alert"):
            line_parts.append(f"  {e.get('alert')}")

        lines.append("\n".join(line_parts))

    lines.append("\nWhat would you like to explore today?")
    greeting_text = "\n\n".join(lines)

    logger.info("=== GREETING COMPLETE (%d chars) ===", len(greeting_text))
    
    response = GreetingResponse(
        greeting=greeting_text,
        portfolio_changes=enriched,
        news_sentiment="",
        has_portfolio=True,
    )
    
    # Save cache
    try:
        await set_cached_greeting(user_id, date_str, json.dumps(response.model_dump() if hasattr(response, 'model_dump') else response.dict()))
    except Exception as e:
        logger.error("Failed to cache greeting output: %s", e)
        
    return response
