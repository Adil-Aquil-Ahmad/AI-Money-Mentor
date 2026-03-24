"""
Portfolio tracking and news enrichment for current investments.
"""
import asyncio
import json
import zlib
from datetime import datetime

from services.stock_service import get_stock_data, get_stock_news, resolve_symbol


PRICE_ALERT_THRESHOLD = 3.0
POSITIVE_NEWS_KEYWORDS = {
    "beats", "beat", "surge", "up", "growth", "record", "strong", "profit",
    "rally", "approval", "upgrade", "expands", "gain", "wins",
}
NEGATIVE_NEWS_KEYWORDS = {
    "miss", "fall", "down", "drop", "weak", "loss", "lawsuit", "probe",
    "downgrade", "cut", "decline", "slump", "warning", "fraud",
}
DEFAULT_ASSET_SYMBOLS = {
    "gold": "GC=F",
    "crypto": "BTC-USD",
}


def normalize_asset_type(raw_type: str) -> str:
    text = str(raw_type or "other").strip().lower()
    if text in {"mutual fund", "mutual_fund", "fund"}:
        return "mutual_fund"
    if text in {"sip", "systematic investment plan"}:
        return "sip"
    if text in {"stock", "equity"}:
        return "stock"
    if text in {"gold", "commodity"}:
        return "gold"
    if text in {"crypto", "cryptocurrency"}:
        return "crypto"
    if text in {"cash", "liquid"}:
        return "cash"
    return text or "other"


def infer_asset_symbol(asset: dict) -> str | None:
    symbol = str(asset.get("symbol") or "").strip()
    if symbol:
        return resolve_symbol(symbol) or symbol.upper()

    asset_type = normalize_asset_type(asset.get("type"))
    name = str(asset.get("name") or "").strip()
    if asset_type == "stock" and name:
        return resolve_symbol(name)
    if asset_type in DEFAULT_ASSET_SYMBOLS:
        if asset_type == "crypto" and name:
            resolved = resolve_symbol(name)
            if resolved:
                return resolved
        return DEFAULT_ASSET_SYMBOLS[asset_type]
    return None


def _parse_meta(raw_meta) -> dict:
    if raw_meta in (None, "", {}):
        return {}
    if isinstance(raw_meta, dict):
        return raw_meta
    try:
        parsed = json.loads(raw_meta)
        return parsed if isinstance(parsed, dict) else {}
    except Exception:
        return {}


def _to_float(value) -> float:
    try:
        if value in (None, ""):
            return 0.0
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _classify_sentiment(headline: str) -> str:
    lowered = (headline or "").lower()
    positive_hits = sum(1 for token in POSITIVE_NEWS_KEYWORDS if token in lowered)
    negative_hits = sum(1 for token in NEGATIVE_NEWS_KEYWORDS if token in lowered)
    if positive_hits > negative_hits:
        return "positive"
    if negative_hits > positive_hits:
        return "negative"
    return "neutral"


def _compute_current_value(asset: dict, market_data: dict | None) -> float:
    amount_invested = _to_float(asset.get("amount_invested"))
    quantity = _to_float(asset.get("quantity"))
    avg_price = _to_float(asset.get("avg_price"))
    price = _to_float((market_data or {}).get("price"))

    if quantity > 0 and price > 0:
        return round(quantity * price, 2)
    if price > 0 and avg_price > 0 and amount_invested > 0:
        return round(amount_invested * (price / avg_price), 2)
    return round(amount_invested, 2)


def _asset_display_name(asset: dict) -> str:
    return str(asset.get("name") or asset.get("symbol") or "Asset").strip()


async def enrich_investment(asset: dict, include_news: bool = True) -> dict:
    enriched = dict(asset)
    asset_type = normalize_asset_type(asset.get("type"))
    symbol = infer_asset_symbol(asset)
    meta = _parse_meta(asset.get("meta_json"))
    market_data = await get_stock_data(symbol) if symbol and asset_type not in {"cash", "other"} else None
    news_items = []

    if include_news and symbol and asset_type in {"stock", "mutual_fund", "sip", "gold", "crypto"}:
        raw_news = await get_stock_news(symbol, limit=3)
        news_items = [{
            "headline": item.get("headline"),
            "url": item.get("url"),
            "source": item.get("source"),
            "published_at": item.get("published_at"),
            "sentiment": _classify_sentiment(item.get("headline", "")),
        } for item in raw_news if item.get("headline")]

    current_value = _compute_current_value(asset, market_data)
    amount_invested = _to_float(asset.get("amount_invested"))
    gain_loss = round(current_value - amount_invested, 2)
    gain_loss_percent = round((gain_loss / amount_invested) * 100, 2) if amount_invested > 0 else 0.0

    enriched.update({
        "type": asset_type,
        "name": _asset_display_name(asset),
        "symbol": symbol or asset.get("symbol"),
        "meta": meta,
        "current_price": _to_float((market_data or {}).get("price")),
        "change_percent": _to_float((market_data or {}).get("change_percent")),
        "trend": (market_data or {}).get("trend") or "flat",
        "sector": (market_data or {}).get("sector") or meta.get("sector"),
        "volume": (market_data or {}).get("volume"),
        "current_value": current_value,
        "gain_loss": gain_loss,
        "gain_loss_percent": gain_loss_percent,
        "news": news_items,
    })
    return enriched


async def refresh_user_investment_total(db, user_id: int) -> float:
    cursor = await db.execute(
        "SELECT COALESCE(SUM(amount_invested), 0) FROM current_investments WHERE user_id = ?",
        (user_id,),
    )
    total = float((await cursor.fetchone())[0] or 0)
    await db.execute(
        "UPDATE users SET current_investments = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
        (total, user_id),
    )
    await db.commit()
    return total


async def build_portfolio_snapshot(db, user_id: int, include_news: bool = True) -> dict:
    cursor = await db.execute(
        "SELECT * FROM current_investments WHERE user_id = ? ORDER BY created_at DESC, id DESC",
        (user_id,),
    )
    rows = await cursor.fetchall()
    raw_assets = [dict(row) for row in rows]

    if not raw_assets:
        return {
            "summary": {
                "total_invested": 0,
                "current_value": 0,
                "gain_loss": 0,
                "gain_loss_percent": 0,
                "asset_count": 0,
            },
            "allocation": [],
            "assets": [],
            "winners": [],
            "losers": [],
            "news": [],
            "notifications": [],
            "health_score": {
                "score": 0,
                "summary": "Add your current investments to track performance and concentration.",
                "diversification": "Not enough data",
                "concentration": "Not enough data",
                "risk": "Not enough data",
                "performance": "Not enough data",
            },
        }

    enriched = await asyncio.gather(*[
        enrich_investment(asset, include_news=include_news) for asset in raw_assets
    ])

    total_invested = round(sum(_to_float(item.get("amount_invested")) for item in enriched), 2)
    total_current = round(sum(_to_float(item.get("current_value")) for item in enriched), 2)
    gain_loss = round(total_current - total_invested, 2)
    gain_loss_percent = round((gain_loss / total_invested) * 100, 2) if total_invested > 0 else 0.0
    valuation_base = total_current or total_invested or 1.0

    type_totals = {}
    for item in enriched:
        current_value = _to_float(item.get("current_value")) or _to_float(item.get("amount_invested"))
        type_totals[item["type"]] = round(type_totals.get(item["type"], 0) + current_value, 2)
        item["allocation_percent"] = round((current_value / valuation_base) * 100, 2)

    allocation = [{
        "type": asset_type,
        "value": value,
        "allocation_percent": round((value / valuation_base) * 100, 2),
    } for asset_type, value in sorted(type_totals.items(), key=lambda pair: pair[1], reverse=True)]

    sorted_assets = sorted(enriched, key=lambda item: item.get("gain_loss_percent", 0), reverse=True)
    winners = [{
        "name": item["name"],
        "symbol": item.get("symbol"),
        "gain_loss_percent": item.get("gain_loss_percent", 0),
        "current_value": item.get("current_value", 0),
    } for item in sorted_assets[:3]]
    losers = [{
        "name": item["name"],
        "symbol": item.get("symbol"),
        "gain_loss_percent": item.get("gain_loss_percent", 0),
        "current_value": item.get("current_value", 0),
    } for item in sorted(sorted_assets, key=lambda item: item.get("gain_loss_percent", 0))[:3]]

    news_items = _collect_portfolio_news(enriched)
    if include_news:
        await _store_news_items(db, user_id, enriched)
        await _sync_notifications(db, user_id, enriched, news_items)

    notifications = await get_portfolio_notifications(db, user_id, limit=12)
    return {
        "summary": {
            "total_invested": total_invested,
            "current_value": total_current,
            "gain_loss": gain_loss,
            "gain_loss_percent": gain_loss_percent,
            "asset_count": len(enriched),
        },
        "allocation": allocation,
        "assets": enriched,
        "winners": winners,
        "losers": losers,
        "news": news_items[:8],
        "notifications": notifications,
        "health_score": _portfolio_health_score(enriched, total_current or total_invested),
    }


def _collect_portfolio_news(assets: list[dict]) -> list[dict]:
    news_items = []
    seen = set()
    for asset in assets:
        for item in asset.get("news", []):
            key = (asset.get("symbol"), item.get("headline"))
            if key in seen:
                continue
            seen.add(key)
            news_items.append({
                "asset_name": asset["name"],
                "symbol": asset.get("symbol"),
                "headline": item.get("headline"),
                "source": item.get("source"),
                "url": item.get("url"),
                "published_at": item.get("published_at"),
                "sentiment": item.get("sentiment", "neutral"),
            })
    return news_items


async def _store_news_items(db, user_id: int, assets: list[dict]) -> None:
    for asset in assets:
        for item in asset.get("news", []):
            await db.execute(
                "INSERT OR IGNORE INTO investment_news "
                "(user_id, investment_id, symbol, headline, source, url, published_at, sentiment) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    user_id,
                    asset.get("id"),
                    asset.get("symbol"),
                    item.get("headline"),
                    item.get("source"),
                    item.get("url"),
                    str(item.get("published_at") or ""),
                    item.get("sentiment", "neutral"),
                ),
            )
    await db.commit()


def _notification_key(user_id: int, prefix: str, symbol: str, headline: str = "", bucket: str = "") -> str:
    checksum = zlib.adler32(f"{user_id}:{symbol}:{headline}:{bucket}".encode("utf-8"))
    date_key = datetime.now().strftime("%Y-%m-%d")
    return f"{user_id}:{prefix}:{date_key}:{checksum}"


async def _sync_notifications(db, user_id: int, assets: list[dict], news_items: list[dict]) -> None:
    for asset in assets:
        change = abs(_to_float(asset.get("change_percent")))
        if change >= PRICE_ALERT_THRESHOLD:
            direction = "up" if _to_float(asset.get("change_percent")) >= 0 else "down"
            title = f"{asset['name']} moved {change:.1f}% today"
            message = (
                f"{asset['name']} is {direction} {change:.1f}% today. "
                "This is an awareness alert, not a recommendation."
            )
            await db.execute(
                "INSERT OR IGNORE INTO portfolio_notifications "
                "(user_id, investment_id, symbol, notification_type, title, message, event_key) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    user_id,
                    asset.get("id"),
                    asset.get("symbol"),
                    "price_change",
                    title,
                    message,
                    _notification_key(user_id, "price", asset.get("symbol") or asset["name"], bucket=str(int(change))),
                ),
            )

    for item in news_items[:10]:
        if item.get("sentiment") == "neutral":
            continue
        title = f"{item['asset_name']}: market news update"
        message = f"{item['headline']} This is an awareness alert, not a recommendation."
        await db.execute(
            "INSERT OR IGNORE INTO portfolio_notifications "
            "(user_id, symbol, notification_type, title, message, event_key) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (
                user_id,
                item.get("symbol"),
                "news",
                title,
                message,
                _notification_key(user_id, "news", item.get("symbol") or item["asset_name"], item.get("headline", "")),
            ),
        )
    await db.commit()


async def get_portfolio_notifications(db, user_id: int, limit: int = 12, unread_only: bool = False) -> list[dict]:
    query = (
        "SELECT id, symbol, notification_type, title, message, is_read, created_at "
        "FROM portfolio_notifications WHERE user_id = ?"
    )
    params = [user_id]
    if unread_only:
        query += " AND is_read = 0"
    query += " ORDER BY created_at DESC, id DESC LIMIT ?"
    params.append(limit)

    cursor = await db.execute(query, tuple(params))
    rows = await cursor.fetchall()
    return [dict(row) for row in rows]


def _portfolio_health_score(assets: list[dict], total_value: float) -> dict:
    if not assets:
        return {
            "score": 0,
            "summary": "No investments tracked yet.",
            "diversification": "Not enough data",
            "concentration": "Not enough data",
            "risk": "Not enough data",
            "performance": "Not enough data",
        }

    type_count = len({item["type"] for item in assets})
    largest_position = max((item.get("current_value", 0) for item in assets), default=0)
    largest_weight = (largest_position / total_value) if total_value else 1
    direct_stock_value = sum(item.get("current_value", 0) for item in assets if item["type"] == "stock")
    direct_stock_ratio = (direct_stock_value / total_value) if total_value else 0
    average_return = sum(item.get("gain_loss_percent", 0) for item in assets) / max(len(assets), 1)

    diversification_score = 30 if type_count >= 3 else 22 if type_count == 2 else 12
    concentration_score = 30 if largest_weight <= 0.35 else 18 if largest_weight <= 0.5 else 8
    risk_score = 20 if direct_stock_ratio <= 0.35 else 12 if direct_stock_ratio <= 0.55 else 6
    performance_score = 20 if average_return >= 5 else 15 if average_return >= 0 else 10 if average_return >= -5 else 6
    total_score = min(100, diversification_score + concentration_score + risk_score + performance_score)

    if total_score >= 80:
        summary = "Portfolio looks balanced with manageable concentration."
    elif total_score >= 60:
        summary = "Portfolio is workable, but concentration or diversification can improve."
    else:
        summary = "Portfolio needs review for concentration, risk, or diversification gaps."

    if type_count >= 3:
        diversification_text = "Good diversification across asset types."
    elif type_count == 2:
        diversification_text = "Moderate diversification. Another asset bucket would reduce single-theme risk."
    else:
        diversification_text = "Low diversification. The portfolio is leaning on one asset type."

    if largest_weight <= 0.35:
        concentration_text = "No single position dominates the portfolio."
    elif largest_weight <= 0.5:
        concentration_text = "One position is becoming heavy and should be monitored."
    else:
        concentration_text = "One position dominates the portfolio and raises concentration risk."

    if direct_stock_ratio <= 0.35:
        risk_text = "Direct-stock exposure is moderate."
    elif direct_stock_ratio <= 0.55:
        risk_text = "Direct-stock exposure is elevated and may need trimming over time."
    else:
        risk_text = "Direct-stock exposure is high relative to the rest of the portfolio."

    if average_return >= 5:
        performance_text = "Recent overall performance is strong."
    elif average_return >= 0:
        performance_text = "Recent overall performance is stable."
    else:
        performance_text = "Recent overall performance is under pressure."

    return {
        "score": total_score,
        "summary": summary,
        "diversification": diversification_text,
        "concentration": concentration_text,
        "risk": risk_text,
        "performance": performance_text,
    }
