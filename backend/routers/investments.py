"""
Current investments router.
CRUD for tracked holdings plus portfolio summary, news, and notifications.
"""
import json
from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from auth_middleware import get_current_user
from database import get_db
from services.portfolio_service import (
    build_portfolio_snapshot,
    normalize_asset_type,
    refresh_user_investment_total,
)

router = APIRouter()


class InvestmentPayload(BaseModel):
    type: str = Field(..., description="stock, mutual_fund, sip, gold, crypto, cash, other")
    name: str
    symbol: Optional[str] = None
    amount_invested: float = 0
    quantity: Optional[float] = None
    avg_price: Optional[float] = None
    sip_amount: Optional[float] = None
    purchase_date: Optional[str] = None  # "YYYY-MM-DD" — used for P&L since invested
    currency: Optional[str] = "INR"
    meta: Optional[dict] = None


class InvestmentUpdate(BaseModel):
    type: Optional[str] = None
    name: Optional[str] = None
    symbol: Optional[str] = None
    amount_invested: Optional[float] = None
    quantity: Optional[float] = None
    avg_price: Optional[float] = None
    sip_amount: Optional[float] = None
    currency: Optional[str] = None
    meta: Optional[dict] = None


@router.get("/investments")
async def list_investments(user_id: int = Depends(get_current_user)):
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT * FROM current_investments WHERE user_id = ? ORDER BY created_at DESC, id DESC",
            (user_id,),
        )
        rows = await cursor.fetchall()
        items = [dict(row) for row in rows]
        for item in items:
            try:
                item["meta"] = json.loads(item.get("meta_json") or "{}")
            except Exception:
                item["meta"] = {}
        return {"items": items}
    finally:
        await db.close()


@router.get("/investments/portfolio")
async def get_portfolio(user_id: int = Depends(get_current_user)):
    db = await get_db()
    try:
        snapshot = await build_portfolio_snapshot(db, user_id, include_news=True)
        return snapshot
    finally:
        await db.close()


@router.get("/investments/news")
async def get_investment_news(user_id: int = Depends(get_current_user), limit: int = 12):
    db = await get_db()
    try:
        await build_portfolio_snapshot(db, user_id, include_news=True)
        cursor = await db.execute(
            "SELECT id, investment_id, symbol, headline, source, url, published_at, sentiment, created_at "
            "FROM investment_news WHERE user_id = ? ORDER BY created_at DESC, id DESC LIMIT ?",
            (user_id, limit),
        )
        rows = await cursor.fetchall()
        return {"items": [dict(row) for row in rows]}
    finally:
        await db.close()


@router.get("/investments/notifications")
async def get_notifications(user_id: int = Depends(get_current_user), limit: int = 12, unread_only: bool = False):
    db = await get_db()
    try:
        await build_portfolio_snapshot(db, user_id, include_news=True)
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
        return {"items": [dict(row) for row in rows]}
    finally:
        await db.close()


@router.post("/investments")
async def create_investment(payload: InvestmentPayload, user_id: int = Depends(get_current_user)):
    db = await get_db()
    try:
        cursor = await db.execute(
            "INSERT INTO current_investments "
            "(user_id, type, name, symbol, amount_invested, quantity, avg_price, sip_amount, purchase_date, currency, meta_json) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                user_id,
                normalize_asset_type(payload.type),
                payload.name.strip(),
                (payload.symbol or "").strip() or None,
                payload.amount_invested,
                payload.quantity,
                payload.avg_price,
                payload.sip_amount,
                payload.purchase_date,
                payload.currency or "INR",
                json.dumps(payload.meta or {}),
            ),
        )
        await db.commit()
        await refresh_user_investment_total(db, user_id)
        return {"status": "created", "id": cursor.lastrowid}
    finally:
        await db.close()


@router.put("/investments/{investment_id}")
async def update_investment(investment_id: int, payload: InvestmentUpdate, user_id: int = Depends(get_current_user)):
    db = await get_db()
    try:
        data = payload.model_dump(exclude_none=True)
        if not data:
            return {"status": "no_changes"}

        if "type" in data:
            data["type"] = normalize_asset_type(data["type"])
        if "meta" in data:
            data["meta_json"] = json.dumps(data.pop("meta") or {})

        set_clause = ", ".join(f"{field} = ?" for field in data.keys())
        values = list(data.values()) + [user_id, investment_id]
        await db.execute(
            f"UPDATE current_investments SET {set_clause}, updated_at = CURRENT_TIMESTAMP "
            "WHERE user_id = ? AND id = ?",
            values,
        )
        await db.commit()
        await refresh_user_investment_total(db, user_id)
        return {"status": "updated"}
    finally:
        await db.close()


@router.delete("/investments/{investment_id}")
async def delete_investment(investment_id: int, user_id: int = Depends(get_current_user)):
    db = await get_db()
    try:
        await db.execute(
            "DELETE FROM current_investments WHERE user_id = ? AND id = ?",
            (user_id, investment_id),
        )
        await db.commit()
        await refresh_user_investment_total(db, user_id)
        return {"status": "deleted"}
    finally:
        await db.close()


@router.post("/investments/notifications/{notification_id}/read")
async def mark_notification_read(notification_id: int, user_id: int = Depends(get_current_user)):
    db = await get_db()
    try:
        await db.execute(
            "UPDATE portfolio_notifications SET is_read = 1 WHERE user_id = ? AND id = ?",
            (user_id, notification_id),
        )
        await db.commit()
        return {"status": "updated"}
    finally:
        await db.close()
