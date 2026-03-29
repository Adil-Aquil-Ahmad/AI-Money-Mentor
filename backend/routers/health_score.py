"""
Chrysos — Money Health Score Router
GET /api/health-score — Calculate a 0-100 financial health score with improvement tips.
"""
from fastapi import APIRouter, Depends
from auth_middleware import get_current_user
from database import get_db
import json

router = APIRouter()


@router.get("/health-score")
async def health_score(user_id: int = Depends(get_current_user)):
    """Calculate Money Health Score (0-100) with category breakdown."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        row = await cursor.fetchone()
        if not row:
            return {"score": 0, "message": "Please set up your profile first."}

        p = dict(row)
        income = p.get("monthly_income") or 0
        expenses = p.get("monthly_expenses") or 0
        savings = p.get("current_savings") or 0
        investments = p.get("current_investments") or 0
        debt = p.get("current_debt") or 0
        has_efund = p.get("has_emergency_fund", 0)
        efund_months = p.get("emergency_fund_months") or 0
        has_insurance = p.get("has_insurance", 0)

        categories = {}
        suggestions = []
        total = 0

        # 1. Emergency Fund (25 points)
        if has_efund and efund_months >= 6:
            categories["Emergency Fund"] = {"score": 25, "max": 25, "status": "Excellent"}
            total += 25
        elif has_efund and efund_months >= 3:
            categories["Emergency Fund"] = {"score": 15, "max": 25, "status": "Good"}
            total += 15
            suggestions.append("Grow your emergency fund to cover 6 months of expenses.")
        elif has_efund:
            categories["Emergency Fund"] = {"score": 8, "max": 25, "status": "Needs Work"}
            total += 8
            suggestions.append("Your emergency fund is too small. Target 3-6 months of expenses.")
        else:
            categories["Emergency Fund"] = {"score": 0, "max": 25, "status": "Missing"}
            suggestions.append("START HERE: Build an emergency fund of 3-6 months expenses immediately.")

        # 2. Savings Rate (25 points)
        if income > 0 and expenses > 0:
            rate = (income - expenses) / income * 100
            if rate >= 30:
                s = 25
                status = "Excellent"
            elif rate >= 20:
                s = 20
                status = "Good"
                suggestions.append("Try to increase savings rate above 30%.")
            elif rate >= 10:
                s = 12
                status = "Fair"
                suggestions.append("Your savings rate is below 20%. Look for expenses to cut.")
            elif rate > 0:
                s = 5
                status = "Low"
                suggestions.append("Your savings rate is very low. Create a strict budget.")
            else:
                s = 0
                status = "Negative"
                suggestions.append("You're spending more than you earn! This needs immediate attention.")
            categories["Savings Rate"] = {"score": s, "max": 25, "status": status, "detail": f"{rate:.1f}%"}
            total += s
        else:
            categories["Savings Rate"] = {"score": 0, "max": 25, "status": "Unknown"}
            suggestions.append("Set your income and expenses to track your savings rate.")

        # 3. Investments (25 points)
        if investments > 0 and income > 0:
            inv_ratio = investments / (income * 12)
            if inv_ratio >= 2:
                s = 25
                status = "Excellent"
            elif inv_ratio >= 1:
                s = 18
                status = "Good"
                suggestions.append("Keep investing! Target 2x your annual income in investments.")
            elif inv_ratio >= 0.5:
                s = 12
                status = "Growing"
                suggestions.append("Increase your SIP amount to build investment corpus faster.")
            else:
                s = 6
                status = "Starting"
                suggestions.append("Your investments are low. Start or increase SIP contributions.")
            categories["Investments"] = {"score": s, "max": 25, "status": status}
            total += s
        elif investments > 0:
            categories["Investments"] = {"score": 10, "max": 25, "status": "Has Some"}
            total += 10
        else:
            categories["Investments"] = {"score": 0, "max": 25, "status": "None"}
            suggestions.append("Start investing! Even ₹500/month SIP in an index fund helps.")

        # 4. Debt & Insurance (25 points)
        debt_score = 0
        if debt <= 0:
            debt_score += 15
        elif income > 0:
            dti = debt / (income * 12)
            if dti < 0.2:
                debt_score += 12
            elif dti < 0.4:
                debt_score += 8
                suggestions.append("Moderate debt level. Focus on paying off high-interest loans.")
            else:
                debt_score += 3
                suggestions.append("High debt! Prioritize repayment — start with highest interest rate.")
        else:
            debt_score += 5

        if has_insurance:
            debt_score += 10
        else:
            suggestions.append("Get term life insurance and health insurance for financial protection.")

        categories["Debt & Insurance"] = {"score": debt_score, "max": 25, "status": "See details"}
        total += debt_score

        # Overall grade
        if total >= 80:
            grade = "A"
            message = "Excellent financial health! Keep up the great work. 🌟"
        elif total >= 60:
            grade = "B"
            message = "Good financial health with room for improvement. 💪"
        elif total >= 40:
            grade = "C"
            message = "Fair — you need to work on a few areas. Let's improve together! 📈"
        elif total >= 20:
            grade = "D"
            message = "Below average — but every journey starts somewhere. Let's build a plan! 🎯"
        else:
            grade = "F"
            message = "Needs urgent attention. Follow the suggestions below to get started. ⚡"

        return {
            "score": total,
            "max_score": 100,
            "grade": grade,
            "message": message,
            "categories": categories,
            "suggestions": suggestions,
        }
    finally:
        await db.close()
