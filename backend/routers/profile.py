"""
Chrysos — Profile Router (v2 — Auth)
CRUD endpoints for user financial profile with risk profiling.
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Optional, List
from auth_middleware import get_current_user
from database import get_db

router = APIRouter()


class ProfileUpdate(BaseModel):
    name: Optional[str] = None
    age: Optional[str] = None  # Encrypted string
    monthly_income: Optional[str] = None # Encrypted string
    monthly_expenses: Optional[str] = None
    current_savings: Optional[str] = None
    current_investments: Optional[str] = None
    current_debt: Optional[str] = None
    has_insurance: Optional[str] = None
    has_emergency_fund: Optional[str] = None
    emergency_fund_months: Optional[str] = None
    risk_profile: Optional[str] = None          
    goals: Optional[List[str]] = None

class TransientRiskAssessment(BaseModel):
    age: int = 30
    monthly_income: float = 0
    current_debt: float = 0
    current_savings: float = 0
    has_emergency_fund: int = 0


@router.get("/profile")
async def get_profile(user_id: int = Depends(get_current_user)):
    """Get user profile."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        row = await cursor.fetchone()
        if not row:
            return {"error": "User not found"}
        profile = dict(row)
        # Parse goals JSON string
        import json
        try:
            profile["goals"] = json.loads(profile.get("goals", "[]"))
        except Exception:
            profile["goals"] = []
        return profile
    finally:
        await db.close()


@router.post("/profile")
async def update_profile(profile: ProfileUpdate, user_id: int = Depends(get_current_user)):
    """Create or update user profile."""
    import json
    db = await get_db()
    try:
        updates = {}
        data = profile.model_dump(exclude_none=True)

        if "goals" in data:
            data["goals"] = json.dumps(data["goals"])
        if "has_insurance" in data:
            data["has_insurance"] = 1 if data["has_insurance"] else 0
        if "has_emergency_fund" in data:
            data["has_emergency_fund"] = 1 if data["has_emergency_fund"] else 0

        if not data:
            return {"status": "no changes"}

        # Build UPDATE query dynamically
        set_clause = ", ".join(f"{k} = ?" for k in data.keys())
        values = list(data.values()) + [user_id]

        await db.execute(
            f"UPDATE users SET {set_clause}, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            values,
        )
        await db.commit()

        return {"status": "updated", "fields": list(data.keys())}
    finally:
        await db.close()


@router.post("/profile/risk-assessment")
async def risk_assessment(data: TransientRiskAssessment, user_id: int = Depends(get_current_user)):
    """Transiently assess risk profile based on decrypted client payload without storing it."""
    try:
        age = data.age
        income = data.monthly_income
        debt = data.current_debt
        savings = data.current_savings
        has_efund = data.has_emergency_fund

        score = 0
        reasons = []

        # Age factor
        if age < 25:
            score += 3
            reasons.append("Young age allows more risk")
        elif age < 35:
            score += 2
            reasons.append("Still have time for recovery")
        elif age < 50:
            score += 1
            reasons.append("Moderate time horizon")
        else:
            reasons.append("Shorter time horizon — prefer stability")

        # Income factor
        if income > 100000:
            score += 2
            reasons.append("High income provides cushion")
        elif income > 50000:
            score += 1
            reasons.append("Decent income level")

        # Debt factor
        if debt > 0 and income > 0 and debt > income * 12:
            score -= 2
            reasons.append("High debt reduces risk capacity")

        # Emergency fund
        if has_efund:
            score += 1
            reasons.append("Emergency fund provides safety net")

        # Savings
        if savings > income * 6:
            score += 1
            reasons.append("Good savings buffer")

        # Determine risk level
        if score >= 5:
            risk = "high"
        elif score >= 3:
            risk = "medium"
        else:
            risk = "low"

        return {
            "risk_profile": risk,
            "score": score,
            "max_score": 7,
            "reasons": reasons,
        }
    except Exception as e:
        return {"error": str(e)}
