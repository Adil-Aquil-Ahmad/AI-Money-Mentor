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
    Fetch real-time stock data for a single symbol.
    Returns structured dict or None on failure.
    """
    import asyncio

    # Check cache — return stale data if available and rate-limited
    now = time.time()
    if symbol in _cache:
        data, ts = _cache[symbol]
        if now - ts < _CACHE_TTL:
            logger.info("Cache hit for %s", symbol)
            return data

    logger.info("Fetching live data for %s...", symbol)
    try:
        loop = asyncio.get_event_loop()
        data = await loop.run_in_executor(None, _fetch_sync, symbol)
        if data:
            _cache[symbol] = (data, now)
        elif symbol in _cache:
            # Return stale cache rather than None on failure
            logger.warning("Returning stale cache for %s", symbol)
            return _cache[symbol][0]
        return data
    except Exception as e:
        logger.error("Failed to fetch %s: %s", symbol, e)
        if symbol in _cache:
            return _cache[symbol][0]  # stale is better than nothing
        return None


def _fetch_sync(symbol: str) -> Optional[dict]:
    """Synchronous yfinance fetch."""
    try:
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
                    }
            except Exception:
                pass
            return None

        price = info.get("regularMarketPrice") or info.get("currentPrice", 0)
        prev_close = info.get("regularMarketPreviousClose") or info.get("previousClose", 0)
        change_pct = ((price - prev_close) / prev_close * 100) if prev_close else 0
        market_cap = info.get("marketCap", 0)
        pe_ratio = info.get("trailingPE") or info.get("forwardPE")
        week52_high = info.get("fiftyTwoWeekHigh")
        week52_low = info.get("fiftyTwoWeekLow")
        name = info.get("shortName") or info.get("longName") or symbol
        volume = info.get("regularMarketVolume") or info.get("volume")
        sector = info.get("sector")

        # Determine trend from recent history
        trend = "flat"
        if change_pct > 0.5:
            trend = "upward"
        elif change_pct < -0.5:
            trend = "downward"

        result = {
            "symbol": symbol,
            "name": name,
            "price": round(price, 2),
            "prev_close": round(prev_close, 2) if prev_close else None,
            "change": round(price - prev_close, 2) if prev_close else None,
            "change_percent": round(change_pct, 2),
            "trend": trend,
            "volume": volume,
            "sector": sector,
        }

        if market_cap:
            if market_cap >= 1e12:
                result["market_cap"] = f"{market_cap/1e12:.1f}T"
            elif market_cap >= 1e9:
                result["market_cap"] = f"{market_cap/1e9:.1f}B"
            else:
                result["market_cap"] = f"{market_cap/1e7:.0f}Cr"

        if pe_ratio:
            result["pe_ratio"] = round(pe_ratio, 1)

        if week52_high and week52_low:
            result["52w_range"] = f"{week52_low:.0f} - {week52_high:.0f}"

        return result

    except Exception as e:
        logger.error("yfinance error for %s: %s", symbol, e)
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
    """Fetch recent Yahoo Finance news items for a symbol."""
    import asyncio

    now = time.time()
    cache_key = f"{symbol}:{limit}"
    if cache_key in _news_cache:
        data, ts = _news_cache[cache_key]
        if now - ts < _CACHE_TTL:
            logger.info("News cache hit for %s", symbol)
            return data

    try:
        loop = asyncio.get_event_loop()
        news_items = await loop.run_in_executor(None, _fetch_news_sync, symbol, limit)
        _news_cache[cache_key] = (news_items, now)
        return news_items
    except Exception as e:
        logger.error("Failed to fetch news for %s: %s", symbol, e)
        return []


def _fetch_news_sync(symbol: str, limit: int = 3) -> list:
    """Synchronous yfinance news fetch."""
    try:
        yf = _prepare_yfinance()
        ticker = yf.Ticker(symbol)
        raw_news = getattr(ticker, "news", None) or []
        items = []
        for entry in raw_news[:limit]:
            title = (entry.get("title") or "").strip()
            if not title:
                continue
            items.append({
                "headline": title,
                "url": entry.get("link") or entry.get("canonicalUrl", {}).get("url"),
                "source": entry.get("publisher") or "Yahoo Finance",
                "published_at": entry.get("providerPublishTime"),
            })
        return items
    except Exception as e:
        logger.error("yfinance news error for %s: %s", symbol, e)
        return []
