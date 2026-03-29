"""
Chrysos — FIRE Calculator Router
POST /api/fire — Calculate time to financial independence and monthly SIP projections.
"""
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional
import math

router = APIRouter()


class FireInput(BaseModel):
    monthly_sip: float = 10000
    expected_return: float = 12.0        # annual % return
    target_corpus: float = 10000000      # target amount (default 1 crore)
    current_investments: float = 0
    monthly_expenses: float = 30000      # for FIRE number calc
    inflation_rate: float = 6.0          # annual %


@router.post("/fire")
async def fire_calculator(data: FireInput):
    """Calculate FIRE projections with year-by-year growth data."""
    monthly_rate = data.expected_return / 100 / 12
    inflation_monthly = data.inflation_rate / 100 / 12

    # FIRE number = 25x annual expenses (4% rule)
    fire_number = data.monthly_expenses * 12 * 25

    # Time to reach target with SIP + existing investments
    if monthly_rate > 0 and data.monthly_sip > 0:
        # FV = P * [(1+r)^n - 1] / r + PV * (1+r)^n
        # Solve for n months
        months = _months_to_target(
            data.monthly_sip, monthly_rate, data.current_investments, data.target_corpus
        )
        months_to_fire = _months_to_target(
            data.monthly_sip, monthly_rate, data.current_investments, fire_number
        )
    else:
        months = 0
        months_to_fire = 0

    years = months / 12
    years_to_fire = months_to_fire / 12

    # Year-by-year projection (for chart)
    projection = _yearly_projection(
        data.monthly_sip,
        data.expected_return / 100,
        data.current_investments,
        max(int(years) + 5, 30),  # project 5 years beyond target or 30 years
    )

    # Milestones
    milestones = _find_milestones(projection, data.target_corpus, fire_number)

    # Total invested vs total value
    total_invested = data.current_investments + (data.monthly_sip * months)
    total_value = data.target_corpus
    wealth_gained = total_value - total_invested

    return {
        "fire_number": round(fire_number),
        "target_corpus": round(data.target_corpus),
        "years_to_target": round(years, 1),
        "months_to_target": round(months),
        "years_to_fire": round(years_to_fire, 1),
        "total_invested": round(total_invested),
        "wealth_gained": round(wealth_gained),
        "projection": projection,
        "milestones": milestones,
        "inputs": {
            "monthly_sip": data.monthly_sip,
            "expected_return": data.expected_return,
            "current_investments": data.current_investments,
        },
    }


def _months_to_target(sip: float, monthly_rate: float, pv: float, target: float) -> float:
    """Calculate months needed to reach target with SIP + existing corpus."""
    if monthly_rate <= 0 or sip <= 0:
        return 0
    try:
        # target = sip * [(1+r)^n - 1]/r + pv * (1+r)^n
        # Let x = (1+r)^n
        # target = sip * (x - 1) / r + pv * x
        # target = (sip/r + pv) * x - sip/r
        # x = (target + sip/r) / (sip/r + pv)
        a = sip / monthly_rate + pv
        if a <= 0:
            return 0
        x = (target + sip / monthly_rate) / a
        if x <= 0:
            return 0
        n = math.log(x) / math.log(1 + monthly_rate)
        return max(0, n)
    except (ValueError, ZeroDivisionError):
        return 0


def _yearly_projection(sip: float, annual_rate: float, pv: float, years: int) -> list:
    """Generate year-by-year investment growth projection."""
    monthly_rate = annual_rate / 12
    data = []
    for y in range(years + 1):
        months = y * 12
        if monthly_rate > 0 and sip > 0:
            fv_sip = sip * ((1 + monthly_rate) ** months - 1) / monthly_rate
        else:
            fv_sip = sip * months
        fv_existing = pv * (1 + monthly_rate) ** months
        total = fv_sip + fv_existing
        invested = pv + sip * months

        data.append({
            "year": y,
            "invested": round(invested),
            "value": round(total),
            "gains": round(total - invested),
        })
    return data


def _find_milestones(projection: list, target: float, fire_number: float) -> list:
    """Find years when key milestones are reached."""
    milestones = []
    checkpoints = [
        (1000000, "₹10 Lakh"),
        (2500000, "₹25 Lakh"),
        (5000000, "₹50 Lakh"),
        (10000000, "₹1 Crore"),
        (25000000, "₹2.5 Crore"),
        (50000000, "₹5 Crore"),
        (100000000, "₹10 Crore"),
    ]
    reached = set()
    for point in projection:
        for amount, label in checkpoints:
            if label not in reached and point["value"] >= amount:
                milestones.append({"year": point["year"], "label": label, "value": point["value"]})
                reached.add(label)
    return milestones
