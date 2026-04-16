"""
Chrysos — Stock Service
Fetches real-time stock data via yfinance.
Includes 5-minute in-memory caching to avoid API rate limits.
"""
import time
import re
import logging
import os
from typing import Optional
from queue_manager import add_log

logger = logging.getLogger("stock_service")
logger.setLevel(logging.DEBUG)
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter(
        "\033[35m[STOCK]\033[0m %(asctime)s — %(message)s", datefmt="%H:%M:%S"
    ))
    logger.addHandler(handler)

# ── In-memory cache (symbol → (data, timestamp)) ──
_cache: dict = {}
_news_cache: dict = {}
_CACHE_TTL = 600  # 10 minutes (avoids yfinance rate limits during normal use)
_YF_READY = False

# ── Common Indian stock symbols (NSE) ──
SYMBOL_MAP = {
    # Large-cap
    "reliance": "RELIANCE.NS",
    "tcs": "TCS.NS",
    "infosys": "INFY.NS",
    "infy": "INFY.NS",
    "hdfc": "HDFCBANK.NS",
    "hdfc bank": "HDFCBANK.NS",
    "icici": "ICICIBANK.NS",
    "icici bank": "ICICIBANK.NS",
    "sbi": "SBIN.NS",
    "kotak": "KOTAKBANK.NS",
    "wipro": "WIPRO.NS",
    "hcl": "HCLTECH.NS",
    "hcl tech": "HCLTECH.NS",
    "bharti airtel": "BHARTIARTL.NS",
    "airtel": "BHARTIARTL.NS",
    "bajaj finance": "BAJFINANCE.NS",
    "lt": "LT.NS",
    "larsen": "LT.NS",
    "itc": "ITC.NS",
    "maruti": "MARUTI.NS",
    "asian paints": "ASIANPAINT.NS",
    "adani": "ADANIENT.NS",
    "tata motors": "TATAMOTORS.NS",
    "tata steel": "TATASTEEL.NS",
    "tech mahindra": "TECHM.NS",
    "axis bank": "AXISBANK.NS",
    "sun pharma": "SUNPHARMA.NS",
    "titan": "TITAN.NS",
    "ultratech": "ULTRACEMCO.NS",
    "power grid": "POWERGRID.NS",
    "ntpc": "NTPC.NS",
    "ongc": "ONGC.NS",
    # Indices
    "nifty": "^NSEI",
    "nifty 50": "^NSEI",
    "sensex": "^BSESN",
    "bank nifty": "^NSEBANK",
    # US large-cap
    "apple": "AAPL",
    "microsoft": "MSFT",
    "google": "GOOGL",
    "alphabet": "GOOGL",
    "amazon": "AMZN",
    "tesla": "TSLA",
    # Commodities / crypto proxies
    "gold": "GC=F",
    "bitcoin": "BTC-USD",
    "btc": "BTC-USD",
    "ethereum": "ETH-USD",
    "eth": "ETH-USD",
}

# Default stocks to show when user asks generically about "stocks" or "market"
DEFAULT_STOCKS = ["RELIANCE.NS", "TCS.NS", "HDFCBANK.NS", "INFY.NS", "^NSEI"]
MOVER_CANDIDATES = [
    "RELIANCE.NS",
    "TCS.NS",
    "INFY.NS",
    "HDFCBANK.NS",
    "ICICIBANK.NS",
    "SBIN.NS",
    "LT.NS",
    "ITC.NS",
    "BHARTIARTL.NS",
    "TATAMOTORS.NS",
    "SUNPHARMA.NS",
    "NTPC.NS",
]


def _resolve_symbol(name: str) -> Optional[str]:
    """Resolve a common name to a yfinance ticker symbol."""
    name_clean = name.strip()
    name_lower = name_clean.lower()

    # 1. Direct match in our map
    if name_lower in SYMBOL_MAP:
        return SYMBOL_MAP[name_lower]

    # 2. Already a full yfinance symbol (has . or starts with ^)
    if "." in name_clean or name_clean.startswith("^"):
        return name_clean.upper()

    # 3. Pure uppercase ticker that looks like a US stock (2-5 chars, all alpha)
    #    e.g. AAPL, MSFT, TSLA — try as-is
    if name_clean.isupper() and name_clean.isalpha() and 2 <= len(name_clean) <= 5:
        # Check if it\'s likely an Indian stock by seeing if it\'s in NSE
        # Known US tickers — don\'t append .NS
        us_like = {"AAPL", "MSFT", "GOOGL", "GOOG", "AMZN", "TSLA", "NVDA", "META",
                   "NFLX", "UBER", "LYFT", "SNAP", "TWTR", "BABA", "V", "MA",
                   "PYPL", "JPM", "GS", "BAC", "WMT", "KO", "PEP", "DIS"}
        if name_clean in us_like:
            return name_clean
        # Otherwise assume NSE Indian stock
        return f"{name_clean}.NS"

    # 4. Fallback: append .NS
    return f"{name_clean.upper()}.NS"


def resolve_symbol(name: str) -> Optional[str]:
    """Public symbol resolver used by portfolio services."""
    if not name:
        return None
    return _resolve_symbol(name)


def _prepare_yfinance():
    """Configure yfinance to use a writable cache location."""
    global _YF_READY
    import yfinance as yf

    if not _YF_READY:
        cache_dir = os.path.join(os.path.dirname(__file__), "..", "data", "yf_cache")
        os.makedirs(cache_dir, exist_ok=True)
        try:
            yf.set_tz_cache_location(cache_dir)
        except Exception:
            pass
        _YF_READY = True
    return yf


def extract_stock_names(message: str) -> list:
    """Extract stock names/symbols from user message."""
    found = []
    message_lower = message.lower()

    # Check known names (longest first to avoid partial matches)
    sorted_names = sorted(SYMBOL_MAP.keys(), key=len, reverse=True)
    for name in sorted_names:
        if name in message_lower:
            symbol = SYMBOL_MAP[name]
            if symbol not in found:
                found.append(symbol)
            # Remove matched text to avoid double-matching
            message_lower = message_lower.replace(name, "")

    # Also match uppercase ticker-like words (e.g. "TCS", "INFY")
    tickers = re.findall(r'\b([A-Z]{2,10})\b', message)
    for t in tickers:
        t_lower = t.lower()
        if t_lower in SYMBOL_MAP:
            sym = SYMBOL_MAP[t_lower]
            if sym not in found:
                found.append(sym)

    return found


async def get_stock_data(symbol: str) -> Optional[dict]:
    """
    Fetch real-time stock data for a single symbol using a multi-tiered fallback strategy.
    Returns structured dict or None on failure.
    """
    import asyncio
    import httpx
    
    # Check cache
    now = time.time()
    if symbol in _cache:
        data, ts = _cache[symbol]
        if now - ts < _CACHE_TTL:
            return data

    logger.info("Fetching live data for %s...", symbol)
    add_log(f"Fetching Live Market Data: [{symbol}]", "System", "info")
    is_intl = symbol.endswith((".NS", ".BO"))
    clean_symbol = symbol.replace('.NS', '').replace('.BO', '')
    
    async def fetch_massive() -> Optional[dict]:
        massive_api_key = "sUsgxkVL4jX5zN4ymgRVGIyuaWZQPkbx"
        url = f"https://api.massive.com/v2/aggs/ticker/{clean_symbol}/prev?apiKey={massive_api_key}"
        async with httpx.AsyncClient(timeout=10.0) as client:
            res = await client.get(url)
            res.raise_for_status()
            data = res.json()
            if data.get("status") in ("OK", "DELAYED") and data.get("resultsCount", 0) > 0:
                res_obj = data["results"][0]
                price = res_obj.get("c", 0.0)
                prev = res_obj.get("o", price)
                change_pct = ((price - prev) / prev * 100) if prev else 0
                trend = "upward" if change_pct > 0.5 else "downward" if change_pct < -0.5 else "flat"
                return {
                    "symbol": symbol,
                    "name": clean_symbol,
                    "price": round(price, 2),
                    "prev_close": round(prev, 2) if prev else None,
                    "change": round(price - prev, 2) if prev else None,
                    "change_percent": round(change_pct, 2),
                    "trend": trend,
                    "volume": res_obj.get("v", 0),
                    "sector": "Technology",
                }
        return None

    def fetch_yf_sync() -> Optional[dict]:
        yf = _prepare_yfinance()
        ticker = yf.Ticker(symbol)
        info = ticker.info
        if not info or info.get("regularMarketPrice") is None:
            # Try fast_info as fallback
            try:
                fi = ticker.fast_info
                price = getattr(fi, "last_price", None)
                prev = getattr(fi, "previous_close", None)
                if price:
                    change_pct = ((price - prev) / prev * 100) if prev else 0
                    change_abs = round(price - prev, 2) if prev else None
                    return {
                        "symbol": symbol,
                        "name": symbol.replace(".NS", "").replace("^", ""),
                        "price": round(price, 2),
                        "prev_close": round(prev, 2) if prev else None,
                        "change": change_abs,
                        "change_percent": round(change_pct, 2),
                        "trend": "upward" if change_pct > 0 else "downward" if change_pct < 0 else "flat",
                        "volume": getattr(fi, "last_volume", None),
                        "sector": "Unknown"
                    }
            except Exception:
                pass
            return None
            
        price = info.get("regularMarketPrice") or info.get("currentPrice", 0)
        prev_close = info.get("regularMarketPreviousClose") or info.get("previousClose", 0)
        change_pct = ((price - prev_close) / prev_close * 100) if prev_close else 0
        trend = "upward" if change_pct > 0.5 else "downward" if change_pct < -0.5 else "flat"
        return {
            "symbol": symbol,
            "name": info.get("shortName") or info.get("longName") or clean_symbol,
            "price": round(price, 2),
            "prev_close": round(prev_close, 2) if prev_close else None,
            "change": round(price - prev_close, 2) if prev_close else None,
            "change_percent": round(change_pct, 2),
            "trend": trend,
            "volume": info.get("regularMarketVolume", 0),
            "sector": info.get("sector"),
        }

    async def fetch_av() -> Optional[dict]:
        av_key = "Q0CP2O3LZSFY6XTE"
        # Wait for AV due to strict limits
        await asyncio.sleep(1)
        av_symbol = symbol.replace('.NS', '.BSE') if is_intl else symbol
        url = f"https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol={av_symbol}&apikey={av_key}"
        async with httpx.AsyncClient(timeout=10.0) as client:
            res = await client.get(url)
            res.raise_for_status()
            data = res.json()
            if "Global Quote" in data and data["Global Quote"]:
                quote = data["Global Quote"]
                price = float(quote.get("05. price", 0))
                prev = float(quote.get("08. previous close", price))
                change_pct = float(quote.get("10. change percent", "0").replace("%", ""))
                trend = "upward" if change_pct > 0.5 else "downward" if change_pct < -0.5 else "flat"
                return {
                    "symbol": symbol,
                    "name": clean_symbol,
                    "price": round(price, 2),
                    "prev_close": round(prev, 2) if prev else None,
                    "change": round(price - prev, 2) if prev else None,
                    "change_percent": round(change_pct, 2),
                    "trend": trend,
                    "volume": int(quote.get("06. volume", 0)),
                    "sector": "Unknown",
                }
        return None

    # Routing strategy
    result = None
    loop = asyncio.get_event_loop()
    
    if is_intl:
        # Int: YFinance -> Alpha Vantage
        try:
            result = await loop.run_in_executor(None, fetch_yf_sync)
        except Exception as e:
            logger.warning("YF fallback for %s: %s", symbol, e)
        if not result:
            try:
                result = await fetch_av()
            except Exception as e:
                logger.error("AV fallback failed for %s: %s", symbol, e)
    else:
        # US: Massive -> YFinance -> Alpha Vantage
        try:
            result = await fetch_massive()
        except Exception as e:
            logger.warning("Massive API error for %s: %s", symbol, e)
        if not result:
            try:
                result = await loop.run_in_executor(None, fetch_yf_sync)
            except Exception as e:
                logger.warning("YF fallback for %s: %s", symbol, e)
        if not result:
            try:
                result = await fetch_av()
            except Exception as e:
                logger.error("AV fallback failed for %s: %s", symbol, e)
                
    if result:
        # User Directive: Convert all US holdings to INR by 92.9 multiplier
        if not is_intl:
            rate = 92.90
            if result.get("price") is not None:
                result["price"] = round(result["price"] * rate, 2)
            if result.get("prev_close") is not None:
                result["prev_close"] = round(result["prev_close"] * rate, 2)
            if result.get("change") is not None:
                result["change"] = round(result["change"] * rate, 2)
                
        _cache[symbol] = (result, now)
        try:
            from database import set_cached_stock_price
            from datetime import datetime, timezone
            date_str = datetime.now(timezone.utc).strftime('%Y-%m-%d')
            await set_cached_stock_price(symbol, result.get("price", 0), result.get("prev_close"), date_str)
        except Exception as e:
            logger.error("Failed to sync stock price to DB cache: %s", e)
        return result
        
    if symbol in _cache:
        return _cache[symbol][0]
        
    # Terminal Fallback
    try:
        from database import get_cached_stock_price
        cached = await get_cached_stock_price(symbol)
        if cached:
            logger.warning("Yielding OFFLINE database fallback for %s", symbol)
            return {
                "symbol": symbol,
                "name": clean_symbol,
                "price": cached["price"],
                "prev_close": cached.get("prev_close"),
                "change": None,
                "change_percent": 0.0,
                "trend": "flat",
                "volume": 0,
                "sector": "Offline",
                "_is_offline": True,
            }
    except Exception as e:
        logger.error("Offline DB fallback failed for %s: %s", symbol, e)
        
    return None


async def get_multiple_stocks_data(symbols: list) -> list:
    """Fetch data for multiple symbols concurrently."""
    import asyncio
    tasks = [get_stock_data(s) for s in symbols[:8]]  # Max 8 stocks
    results = await asyncio.gather(*tasks, return_exceptions=True)
    return [r for r in results if isinstance(r, dict)]


async def get_market_overview() -> list:
    """Fetch default market overview stocks."""
    return await get_multiple_stocks_data(DEFAULT_STOCKS)


async def get_market_movers(limit: int = 5) -> list:
    """Fetch a simple top-movers list from a stable basket using yfinance."""
    results = await get_multiple_stocks_data(MOVER_CANDIDATES)
    positive = [item for item in results if item.get("change_percent") is not None]
    positive.sort(key=lambda item: item.get("change_percent", 0), reverse=True)
    return positive[:limit]


async def get_stock_news(symbol: str, limit: int = 3) -> list:
    """Fetch recent news items for a symbol via NewsAPI."""
    import httpx
    from datetime import datetime, timedelta

    now = time.time()
    cache_key = f"{symbol}:{limit}"
    if cache_key in _news_cache:
        data, ts = _news_cache[cache_key]
        if now - ts < _CACHE_TTL:
            logger.info("News cache hit for %s", symbol)
            return data

    try:
        # Prepare the query
        clean_symbol = symbol.replace('.NS', '').replace('.BO', '')
        # Try to resolve to full company name or use the symbol if not found
        query = clean_symbol
        for k, v in SYMBOL_MAP.items():
            if v == symbol:
                query = k
                break
                
        # Only fetch news from the last 7 days
        from_date = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')
        
        url = f"https://newsapi.org/v2/everything?q={query}&from={from_date}&sortBy=relevancy&apiKey=88a32572d97c4c6bbe6506310a8be9a3"
        
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url)
            response.raise_for_status()
            data = response.json()
            
            items = []
            for article in data.get("articles", [])[:limit]:
                title = (article.get("title") or "").strip()
                if not title or title == "[Removed]":
                    continue
                items.append({
                    "headline": title.split(" - ")[0], # Cleanup trailing source
                    "url": article.get("url"),
                    "source": article.get("source", {}).get("name") or "NewsAPI",
                    "published_at": article.get("publishedAt"),
                })
                
            _news_cache[cache_key] = (items, now)
            return items
            
    except Exception as e:
        logger.error("Failed to fetch news for %s: %s", symbol, e)
        return []
