"""
Chrysos — Auth Router
POST /auth/verify — Verify Firebase token and return user info
GET  /auth/me     — Get current authenticated user
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from auth_middleware import get_current_user, verify_firebase_token
from database import get_db

router = APIRouter()


class TokenRequest(BaseModel):
    id_token: str


@router.post("/auth/verify")
async def verify_token(req: TokenRequest):
    """Verify Firebase token and return/create local user."""
    firebase_user = await verify_firebase_token(req.id_token)
    if not firebase_user:
        return {"error": "Invalid token", "authenticated": False}

    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id, name, email FROM users WHERE firebase_uid = ?",
            (firebase_user["uid"],),
        )
        row = await cursor.fetchone()

        if row:
            return {
                "authenticated": True,
                "user_id": row[0],
                "name": row[1],
                "email": row[2],
            }

        # Create new user
        cursor = await db.execute(
            "INSERT INTO users (firebase_uid, email, name) VALUES (?, ?, ?)",
            (firebase_user["uid"], firebase_user["email"], firebase_user["name"] or "User"),
        )
        await db.commit()
        return {
            "authenticated": True,
            "user_id": cursor.lastrowid,
            "name": firebase_user["name"] or "User",
            "email": firebase_user["email"],
        }
    finally:
        await db.close()


@router.get("/auth/me")
async def get_me(user_id: int = Depends(get_current_user)):
    """Get current user's profile info."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id, name, email, age, monthly_income, risk_profile, "
            "current_savings, current_investments, goals FROM users WHERE id = ?",
            (user_id,),
        )
        row = await cursor.fetchone()
        if not row:
            return {"error": "User not found"}
        return dict(row)
    finally:
        await db.close()
