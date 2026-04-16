from fastapi import APIRouter, Query, Body, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import logging

from database import get_db

router = APIRouter()
logger = logging.getLogger("alerts_api")

class FcmTokenReq(BaseModel):
    user_id: int
    token: str

class AlertModel(BaseModel):
    id: int
    stock_symbol: str
    type: str
    message: str
    confidence: float
    is_read: bool
    timestamp: str

@router.post("/register_token")
async def register_token(payload: FcmTokenReq):
    """
    Called by the Flutter app upon logging in / gaining permission, 
    so we can route notifications per user.
    """
    db = await get_db()
    try:
        await db.execute(
            "UPDATE users SET fcm_token = ? WHERE id = ?",
            (payload.token, payload.user_id)
        )
        await db.commit()
    except Exception as e:
        logger.error("Error setting FCM token: %s", e)
        raise HTTPException(status_code=500, detail="Database Error")
    finally:
        await db.close()

    return {"status": "success", "message": "Token registered."}

@router.get("", response_model=List[AlertModel])
async def fetch_alerts(user_id: int = Query(...), unread: bool = Query(True), limit: int = Query(20)):
    """
    Fetches the history of strictly isolated notifications for the requesting User ID.
    Optionally filters by unread and enforces pagination limits.
    """
    db = await get_db()
    try:
        query = "SELECT id, stock_symbol, type, message, confidence, is_read, timestamp FROM alerts WHERE user_id = ?"
        params = [user_id]
        
        if unread:
            query += " AND is_read = 0"
            
        query += " ORDER BY timestamp DESC LIMIT ?"
        params.append(limit)
        
        cursor = await db.execute(query, tuple(params))
        rows = await cursor.fetchall()
        
        alerts = []
        for r in rows:
            alerts.append({
                "id": r[0],
                "stock_symbol": r[1],
                "type": r[2],
                "message": r[3],
                "confidence": r[4] or 0.0,
                "is_read": bool(r[5]),
                "timestamp": str(r[6])
            })
        return alerts
    finally:
        await db.close()

@router.post("/mark_read")
async def mark_read(alert_id: int = Body(..., embed=True), user_id: int = Body(..., embed=True)):
    """Marks a specific alert as read securely via user_id bounds."""
    db = await get_db()
    try:
        await db.execute(
            "UPDATE alerts SET is_read = 1 WHERE id = ? AND user_id = ?",
            (alert_id, user_id)
        )
        await db.commit()
        return {"status": "success"}
    finally:
        await db.close()
