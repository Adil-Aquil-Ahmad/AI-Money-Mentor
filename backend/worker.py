import logging
import asyncio
from datetime import datetime
import time

from database import get_db
from services.intelligence_service import get_finance_intelligence
from services.stock_service import get_stock_data, resolve_symbol
from services.firebase_service import send_push_notification

logger = logging.getLogger("worker")
logger.setLevel(logging.INFO)

# In-Memory Idempotency safeguards
_processing_locks = set()
_queue_index = 0

async def build_global_queue():
    """
    Scrapes the entire DB across all users to build a master inverted index:
    { "AAPL": { "users": [1, 3], "priority": 1 } }
    Priority: 1 = Portfolio (HIGH), 2 = Watchlist (MEDIUM), 3 = Market (LOW)
    """
    queue_map = {}
    db = await get_db()
    
    try:
        # Load Portfolio (High Priority 1)
        c1 = await db.execute("SELECT user_id, symbol FROM current_investments WHERE type != 'cash'")
        for row in await c1.fetchall():
            uid, sym = row[0], row[1]
            if not sym: continue
            rsym = resolve_symbol(sym) or sym
            if rsym not in queue_map:
                queue_map[rsym] = {"users": set(), "priority": 1}
            queue_map[rsym]["users"].add(uid)
            queue_map[rsym]["priority"] = min(queue_map[rsym]["priority"], 1)
            
        # Load Watchlist (Medium Priority 2)
        c2 = await db.execute("SELECT user_id, stock_symbol FROM watchlist")
        for row in await c2.fetchall():
            uid, sym = row[0], row[1]
            if not sym: continue
            rsym = resolve_symbol(sym) or sym
            if rsym not in queue_map:
                queue_map[rsym] = {"users": set(), "priority": 2}
            queue_map[rsym]["users"].add(uid)
            queue_map[rsym]["priority"] = min(queue_map[rsym]["priority"], 2)
            
    except Exception as e:
        logger.error("Failed to build global DB queue: %s", e)
    finally:
        await db.close()

    return queue_map

async def analyze_and_dispatch(symbol: str, user_ids: set):
    """Processes LLM checks for a single stock and maps to subscribed users."""
    if symbol in _processing_locks:
        return
    _processing_locks.add(symbol)
    
    try:
        # Check LLM Intelligence
        intel = await get_finance_intelligence(symbol, 1000.0, 30)
        # Check Price (to get % change native if LLM abstracted it)
        price_data = await get_stock_data(symbol)
        
        if not isinstance(intel, dict) or not isinstance(price_data, dict):
            return  # Failsafe skipping
            
        sentiment = intel.get("sentiment", "Neutral")
        change_pct = price_data.get("change_percent", 0.0)
        has_spike = intel.get("insight", "").lower().find("unusually high") != -1 or intel.get("trend_spike", False)
        
        # SMART RULESET
        alert_type = None
        message = None
        confidence = 0.5
        
        if change_pct < -5.0:
            alert_type = "CRITICAL_ALERT"
            message = f"Critical drop detected: {symbol} is down {abs(change_pct):.2f}%."
            confidence = 0.95
        elif change_pct < -3.0 and sentiment == 'Negative':
            alert_type = "STRONG_NEGATIVE"
            message = f"Strong negative momentum for {symbol}: Down {abs(change_pct):.2f}% paired with negative news sentiment."
            confidence = 0.85
        elif sentiment == 'Negative' and has_spike:
            alert_type = "NEGATIVE_TREND"
            message = f"Warning: High search volatility combined with bad news sentiment detected for {symbol}."
            confidence = 0.70
        elif sentiment == 'Positive' and change_pct > 0.5:
            alert_type = "OPPORTUNITY"
            message = f"Positive signals detected: {symbol} shows strong news sentiment and paired upward trend."
            confidence = 0.80
            
        if not alert_type:
            return  # No trigger met!
            
        # We have an alert! Forward to applicable users
        db = await get_db()
        try:
            for uid in user_ids:
                # 30-Minute cooldown checker
                now = time.time()
                cooldown_check = await db.execute(
                    "SELECT last_triggered_at FROM alerts WHERE user_id = ? AND stock_symbol = ? ORDER BY id DESC LIMIT 1",
                    (uid, symbol)
                )
                cd_row = await cooldown_check.fetchone()
                
                if cd_row and cd_row[0]:
                    try:
                        # Parsing SQLite timestamp fallback string
                        last_t = datetime.strptime(cd_row[0][:19], "%Y-%m-%d %H:%M:%S").timestamp()
                        if now - last_t < 1800:  # 30 mins (1800s)
                            continue  # Cooldown bypass
                    except: pass
                    
                # Store natively
                current_time_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                await db.execute(
                    "INSERT INTO alerts (user_id, stock_symbol, type, message, confidence, last_triggered_at) VALUES (?, ?, ?, ?, ?, ?)",
                    (uid, symbol, alert_type, message, confidence, current_time_str)
                )
                await db.commit()
                
                # Fetch FCM Token for User
                u_check = await db.execute("SELECT fcm_token FROM users WHERE id = ?", (uid,))
                token_row = await u_check.fetchone()
                if token_row and token_row[0]:
                    alert_titles = {
                        "CRITICAL_ALERT": "🚨 Critical Drop Alert",
                        "STRONG_NEGATIVE": "⚠️ Negative Momentum",
                        "NEGATIVE_TREND": "⚠️ Volatility Warning",
                        "OPPORTUNITY": "💡 Market Opportunity"
                    }
                    send_push_notification(token_row[0], alert_titles.get(alert_type, "Chrysos Alert"), message, {"symbol": symbol})

        except Exception as filter_err:
            logger.error("DB Alert Mapping Failed: %s", filter_err)
        finally:
            await db.close()

    except Exception as e:
        logger.error("Background LLM scan failed for %s: %s", symbol, e)
    finally:
        _processing_locks.discard(symbol)


async def _scan_portfolios():
    """Timer tick callback."""
    global _queue_index
    logger.info("--- Waking Background Scanner ---")
    
    queue_map = await build_global_queue()
    if not queue_map:
        return
        
    # Sort into ranked array
    sorted_symbols = sorted(queue_map.keys(), key=lambda sym: queue_map[sym]["priority"])
    
    # Slice 5 round-robin
    if _queue_index >= len(sorted_symbols):
        _queue_index = 0
        
    s_slice = sorted_symbols[_queue_index : _queue_index + 5]
    _queue_index += 5
    
    logger.info("Scanning batch: %s", s_slice)
    
    tasks = []
    for sym in s_slice:
        tasks.append(analyze_and_dispatch(sym, queue_map[sym]["users"]))
        
    await asyncio.gather(*tasks)
    
def start_scheduler():
    """Initializes the interval loops globally natively bound to the FastAPI host."""
    try:
        from apscheduler.schedulers.asyncio import AsyncIOScheduler
        scheduler = AsyncIOScheduler()
        # Triggers strictly every 5 minutes 
        scheduler.add_job(_scan_portfolios, 'interval', minutes=5, id="portfolio_scanner", replace_existing=True)
        scheduler.start()
        logger.info("✅ APScheduler engaged natively. Monitoring active.")
    except ImportError:
        logger.warning("apscheduler not installed properly! Cannot run background tasks.")
