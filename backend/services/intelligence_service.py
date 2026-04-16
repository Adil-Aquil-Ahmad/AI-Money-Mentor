import asyncio
import logging
import json
import time
from datetime import datetime, timedelta
import httpx
from engine.llm_client import generate_with_model
from services.stock_service import get_stock_news, resolve_symbol
from queue_manager import add_log

logger = logging.getLogger("intelligence_service")
logger.setLevel(logging.DEBUG)
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter(
        "\033[92m[INTELLIGENCE]\033[0m %(asctime)s — %(message)s", datefmt="%H:%M:%S"
    ))
    logger.addHandler(handler)

async def _get_trends(symbol: str) -> bool:
    """
    Safely try to fetch Google Trends. Returns True if there's a recent spike.
    """
    def _fetch():
        try:
            from pytrends.request import TrendReq
            pytrend = TrendReq(hl='en-US', tz=360, retries=0, backoff_factor=0.1)
            # Remove .NS for Indian stocks to get better search results
            clean_symbol = symbol.replace('.NS', '').replace('.BO', '')
            pytrend.build_payload(kw_list=[clean_symbol], timeframe='now 7-d')
            df = pytrend.interest_over_time()
            if df.empty:
                return False
            
            # Simple spike detection: current > double the mean
            mean_interest = df[clean_symbol].mean()
            last_interest = df[clean_symbol].iloc[-1]
            if mean_interest > 10 and last_interest > (mean_interest * 1.5):
                return True
            return False
        except Exception as e:
            logger.warning("pytrends failed for %s: %s", symbol, e)
            return False

    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _fetch)

def _parse_llm_json(response_text: str) -> dict:
    """Strictly extra JSON from LLM response."""
    default = {"sentiment": "Neutral", "insight": "Market trends are stable."}
    if not response_text:
        return default
    
    text = response_text.strip()
    # Remove markdown code blocks if present
    if text.startswith("```"):
        lines = text.splitlines()
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].startswith("```"):
            lines = lines[:-1]
        text = "\n".join(lines).strip()
    
    try:
        data = json.loads(text)
        return {
            "sentiment": data.get("sentiment", "Neutral"),
            "insight": data.get("insight", default["insight"])
        }
    except json.JSONDecodeError:
        logger.error("Failed to parse LLM JSON: %s", text)
        return default

_hist_cache = {}
_CACHE_TTL = 900 # 15 minutes of caching for historical data

async def get_finance_intelligence(raw_symbol: str, initial_investment: float, n_days: int) -> dict:
    logger.info("Generating intelligence for %s over %d days", raw_symbol, n_days)
    add_log(f"Compiling Portfolio Intelligence: {raw_symbol} Tracking History ({n_days}d)", "Worker", "info")
    
    symbol = resolve_symbol(raw_symbol) or raw_symbol
    
    # Run fetch operations concurrently
    async def fetch_historical_data():
        import httpx
        from datetime import datetime, timedelta
        import yfinance as yf
        import asyncio
        
        cache_key = f"{symbol}:{n_days}"
        now = time.time()
        if cache_key in _hist_cache:
            data, ts = _hist_cache[cache_key]
            if now - ts < _CACHE_TTL:
                return data

        is_intl = symbol.endswith((".NS", ".BO"))
        clean_symbol = symbol.replace('.NS', '').replace('.BO', '')
        
        start_date = (datetime.now() - timedelta(days=n_days + 15)).strftime('%Y-%m-%d')
        end_date = datetime.now().strftime('%Y-%m-%d')

        async def _massive():
            massive_api_key = "sUsgxkVL4jX5zN4ymgRVGIyuaWZQPkbx"
            url = f"https://api.massive.com/v2/aggs/ticker/{clean_symbol}/range/1/day/{start_date}/{end_date}?adjusted=true&sort=asc&apiKey={massive_api_key}"
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.get(url)
                res.raise_for_status()
                data = res.json()
                hist = []
                if data.get("status") in ("OK", "DELAYED") and "results" in data:
                    hist = [item.get("c") for item in data["results"]]
                info = {}
                if hist:
                    info["currentPrice"] = hist[-1]
                    if len(hist) > 1:
                        info["previousClose"] = hist[-2]
                return info, hist

        def _yf():
            # fetch N + 5 days to ensure we have enough trading days
            ticker = yf.Ticker(symbol)
            period_str = f"{n_days + 10}d"
            h = ticker.history(period=period_str)
            if h.empty:
                return {}, []
            hist = h["Close"].tolist()
            info = {}
            if hist:
                info["currentPrice"] = hist[-1]
                if len(hist) > 1:
                    info["previousClose"] = hist[-2]
            return info, hist

        async def _av():
            av_key = "Q0CP2O3LZSFY6XTE"
            await asyncio.sleep(1)
            av_symbol = symbol.replace('.NS', '.BSE') if is_intl else symbol
            url = f"https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol={av_symbol}&outputsize=compact&apikey={av_key}"
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.get(url)
                res.raise_for_status()
                data = res.json()
                ts_key = "Time Series (Daily)"
                if ts_key not in data:
                    return {}, []
                
                # dates are sorted descending by default, we need ascending
                dates = sorted(data[ts_key].keys())
                hist = [float(data[ts_key][d]["4. close"]) for d in dates[-(n_days+10):]]
                
                info = {}
                if hist:
                    info["currentPrice"] = hist[-1]
                    if len(hist) > 1:
                        info["previousClose"] = hist[-2]
                return info, hist

        result = ({}, [])
        loop = asyncio.get_event_loop()
        
        if is_intl:
            try:
                result = await loop.run_in_executor(None, _yf)
                if not result[1]: raise Exception("Empty YF history")
            except Exception as e:
                logger.warning("YF history failed for %s: %s", symbol, e)
                try:
                    result = await _av()
                except Exception as e:
                    logger.error("AV history fallback failed for %s: %s", symbol, e)
        else:
            try:
                result = await _massive()
                if not result[1]: raise Exception("Empty Massive history")
            except Exception as e:
                logger.warning("Massive history failed for %s: %s", symbol, e)
                try:
                    result = await loop.run_in_executor(None, _yf)
                    if not result[1]: raise Exception("Empty YF history fallback")
                except Exception as e:
                    logger.warning("YF history fallback failed for %s: %s", symbol, e)
                    try:
                        result = await _av()
                    except Exception as e:
                        logger.error("AV history fallback failed for %s: %s", symbol, e)
                        
        if not result[1] or len(result[1]) == 0:
            try:
                from database import get_cached_stock_price
                cached = await get_cached_stock_price(symbol)
                if cached:
                    logger.warning("Yielding OFFLINE database fallback for Intelligence %s", symbol)
                    result = ({"currentPrice": cached["price"], "previousClose": cached.get("prev_close")}, [cached["price"]])
            except Exception as e:
                logger.error("Offline DB fallback failed for %s: %s", symbol, e)
                
        _hist_cache[cache_key] = (result, now)
        return result

    results = await asyncio.gather(
        fetch_historical_data(),
        get_stock_news(symbol, limit=4),
        _get_trends(symbol),
        return_exceptions=True
    )
    
    yf_result = results[0]
    news_items = results[1]
    has_spike = results[2]
    
    if isinstance(yf_result, Exception):
        logger.error("API history fallback failed: %s", yf_result)
        info, hist = {}, None
    else:
        info, hist = yf_result
        
    if isinstance(news_items, Exception):
        news_items = []
    if isinstance(has_spike, Exception):
        has_spike = False

    # Extract price calculations
    current_price = info.get("regularMarketPrice") or info.get("currentPrice") or 0.0
    prev_close = info.get("regularMarketPreviousClose") or info.get("previousClose") or 0.0
    
    if not current_price and hist:
        current_price = hist[-1]
    
    today_change_percent = 0.0
    today_change_value = 0.0
    if current_price and prev_close:
        today_change_percent = round(((current_price - prev_close) / prev_close) * 100, 2)
        today_change_value = round((initial_investment * (today_change_percent / 100)), 2)

    total_change_percent = 0.0
    total_value = initial_investment

    if hist and len(hist) > 0:
        # Get price N days ago (approx close)
        # We go back N indices if available
        target_idx = -min(n_days + 1, len(hist))
        price_n_days_ago = hist[target_idx]
        
        if price_n_days_ago > 0:
            total_change_percent = round(((current_price - price_n_days_ago) / price_n_days_ago) * 100, 2)
            total_value = round(initial_investment * (1 + (total_change_percent / 100)), 2)

    # Compile news for LLM
    headlines = []
    for item in news_items:
        headlines.append(f"- {item.get('headline')}")
    news_text = "\n".join(headlines) if headlines else "No recent notable news."

    # Generate LLM insight
    stock_name = info.get("shortName") or raw_symbol
    trend_context = "Google Search interest is unusually high for this stock right now." if has_spike else "Normal search interest."
    
    system_prompt = (
        "You are an expert financial analyst. Analyze the following news headlines and trend signals for a stock. "
        "Provide your analysis STRICTLY in JSON format with exactly two keys: "
        "'sentiment' (must be exactly 'Positive', 'Neutral', or 'Negative') and 'insight' (a short 1-to-2 line explanation).\n"
        "Do not include any markdown formatting, thoughts, or explanations outside the JSON."
    )
    
    user_prompt = (
        f"Stock: {stock_name} ({symbol})\n"
        f"Recent News:\n{news_text}\n"
        f"Search Trends: {trend_context}\n\n"
        "Output ONLY valid JSON."
    )
    
    llm_response = await generate_with_model("llama-3.1-8b-instant", system_prompt, user_prompt)
    analysis = _parse_llm_json(llm_response)
    
    # Risk Alert Logic
    alert = None
    if today_change_percent <= -3.0 or analysis["sentiment"] == "Negative" or has_spike:
        triggers = []
        if today_change_percent <= -3.0: triggers.append(f"sudden price drop ({today_change_percent}%)")
        if analysis["sentiment"] == "Negative": triggers.append("negative news sentiment")
        if has_spike: triggers.append("unusual search trend activity")
        
        if triggers:
            alert = f"⚠️ Alert: {stock_name} is showing unusual activity due to " + " and ".join(triggers) + "."

    return {
        "stock": stock_name,
        "symbol": symbol,
        "current_price": round(current_price, 2),
        "today_change_percent": today_change_percent,
        "today_change_value": today_change_value,
        "total_change_percent": total_change_percent,
        "total_value": total_value,
        "sentiment": analysis["sentiment"],
        "insight": analysis["insight"],
        "alert": alert
    }
